import type { EcosystemResolutionV1, EcosystemSnapshotV1, EventInterpretationV1 } from '../../contracts/types.js';
import { validateResolution } from '../../contracts/validate.js';
import type { JsonLlm } from '../../llm/llmClient.js';
import { ECOSYSTEM_PROMPT_MVP_V1 } from './prompts/ecosystem-mvp-v1.js';
import { ECOSYSTEM_PROMPT_MVP_V2 } from './prompts/ecosystem-mvp-v2.js';
import { resolveScenario } from './scenario.js';

export interface ResolveResult {
  resolution: EcosystemResolutionV1;
  /** true when the wording is the template because the LLM was skipped or failed. */
  fallback: boolean;
}

interface Narration {
  relationshipReasons: string[];
  explanation: [string, string, string];
}

const NARRATION_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['relationshipReasons', 'explanation'],
  properties: {
    relationshipReasons: { type: 'array', items: { type: 'string', maxLength: 200 }, maxItems: 3 },
    explanation: { type: 'array', items: { type: 'string', maxLength: 160 }, minItems: 3, maxItems: 3 },
  },
};

const PROMPTS: Record<string, string> = {
  'ecosystem-mvp-v1': ECOSYSTEM_PROMPT_MVP_V1,
  'ecosystem-mvp-v2': ECOSYSTEM_PROMPT_MVP_V2,
};

/**
 * Domain B (PRD §39.2). Outcomes come from deterministic scenario rules; the
 * LLM only words them. Never throws for LLM problems — the template wording is
 * always a valid answer (PRD §42.3: Domain B failure → mock fallback).
 */
export class EcosystemDirector {
  private readonly system: string;

  constructor(private readonly llm: JsonLlm, readonly promptVersion = 'ecosystem-mvp-v2') {
    const prompt = PROMPTS[promptVersion];
    if (!prompt) throw new Error(`Unknown ecosystem prompt version: ${promptVersion}`);
    this.system = prompt;
  }

  async resolve(interpretation: EventInterpretationV1, snapshot: EcosystemSnapshotV1): Promise<ResolveResult> {
    const template = resolveScenario(interpretation, snapshot);
    if (!this.llm.configured) return { resolution: template, fallback: true };

    try {
      const narration = await this.narrate(interpretation, snapshot, template);
      const bonds = template.promotedRelationships;
      const reasons = narration.relationshipReasons.map((r) => r.trim());
      const worded: EcosystemResolutionV1 = {
        ...template,
        // Only reword bonds that exist; the model can't add or drop one.
        promotedRelationships: bonds.map((bond, i) => ({ ...bond, reason: reasons[i] ?? '' })),
        explanation: narration.explanation.map((line) => line.trim()) as [string, string, string],
      };
      const checked = validateResolution(worded);
      if (checked.ok && reasons.length === bonds.length && reasons.every(Boolean) && worded.explanation.every(Boolean)) {
        return { resolution: checked.value, fallback: false };
      }
      console.warn('ecosystem narration rejected', checked.ok ? 'empty text' : checked.errors);
    } catch (error) {
      console.warn('ecosystem narration failed', (error as Error).message);
    }
    return { resolution: template, fallback: true };
  }

  /** Domain B sees the summary, never the raw transcript (PRD §39.2 privacy boundary). */
  private async narrate(
    interpretation: EventInterpretationV1,
    snapshot: EcosystemSnapshotV1,
    decided: EcosystemResolutionV1,
  ): Promise<Narration> {
    const memory = snapshot.seedMemories.find((m) => m.id === decided.raid.targetMemoryId);
    const name = (id: string) => id[0].toUpperCase() + id.slice(1);
    const story = {
      eventSummary: interpretation.summary,
      fedFigures: interpretation.figures.map((f) => ({ figure: name(f.id), feed: f.feed })),
      promotedRelationships: decided.promotedRelationships.map((rel) => ({
        figures: rel.figures.map(name),
        hint: rel.reason,
      })),
      evolvedFigure: name(decided.evolution.figureId),
      victimFigure: name(decided.raid.victimFigureId),
      raidedMemory: { title: memory?.title ?? 'a memory', object: memory?.objectName ?? null },
    };
    const { data } = await this.llm.completeJson<Narration>({
      system: this.system,
      user: JSON.stringify(story),
      schemaName: 'ecosystem_narration',
      schema: NARRATION_SCHEMA,
    });
    if (!data || !Array.isArray(data.explanation) || data.explanation.length !== 3
      || !Array.isArray(data.relationshipReasons) || !data.relationshipReasons.every((r) => typeof r === 'string')) {
      throw new Error('narration has the wrong shape');
    }
    return data;
  }
}
