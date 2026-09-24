import { randomUUID } from 'node:crypto';
import type { EventInterpretationV1, FedFigure } from '../../contracts/types.js';
import { loadSchema, validateInterpretation } from '../../contracts/validate.js';
import { isTransientLlmError, LlmNotConfiguredError, type JsonLlm } from '../../llm/llmClient.js';
import { interpretWithKeywords } from './keywordInterpreter.js';
import { INPUT_PROMPT_V1 } from './prompts/input-v1.js';
import {
  AnalysisTimeoutError,
  AnalysisUnavailableError,
  type InterpretResult,
  type RitualInput,
} from './types.js';

/** Fields the server fills in itself rather than asking the model for. */
const SERVER_FIELDS = ['schemaVersion', 'eventId', 'sourceType'] as const;

type LlmInterpretation = Omit<EventInterpretationV1, (typeof SERVER_FIELDS)[number]>;

/** The contract schema minus server-owned fields — what the model must return. */
export function llmOutputSchema(): object {
  const schema = structuredClone(loadSchema('event-interpretation.v1')) as {
    properties: Record<string, unknown>;
    required: string[];
  };
  for (const field of SERVER_FIELDS) delete schema.properties[field];
  schema.required = schema.required.filter((field) => !(SERVER_FIELDS as readonly string[]).includes(field));
  return schema;
}

const PROMPTS: Record<string, string> = { 'input-v1': INPUT_PROMPT_V1 };

/**
 * Domain A (PRD §39.1): turns one retrospective input into an
 * EventInterpretationV1. Never decides ecosystem outcomes.
 */
export class InputInterpreter {
  private readonly schema = llmOutputSchema();
  private readonly system: string;

  constructor(private readonly llm: JsonLlm, readonly promptVersion = 'input-v1') {
    const prompt = PROMPTS[promptVersion];
    if (!prompt) throw new Error(`Unknown input prompt version: ${promptVersion}`);
    this.system = prompt;
  }

  async interpret(input: RitualInput): Promise<InterpretResult> {
    if (!this.llm.configured) {
      return { interpretation: interpretWithKeywords(input), fallback: true };
    }

    const user = JSON.stringify({ sourceType: input.inputType, importance: input.importance ?? null, memory: input.text });
    let lastErrors: string[] = [];

    // One corrective retry when the model's output breaks the contract.
    for (let attempt = 0; attempt < 2; attempt++) {
      const message = attempt === 0
        ? user
        : `${user}\n\nYour previous answer failed validation: ${lastErrors.join('; ')}. Return a corrected JSON object.`;

      let completion;
      try {
        completion = await this.llm.completeJson<LlmInterpretation>({
          system: this.system,
          user: message,
          schemaName: 'event_interpretation',
          schema: this.schema,
        });
      } catch (error) {
        if (error instanceof LlmNotConfiguredError) {
          return { interpretation: interpretWithKeywords(input), fallback: true };
        }
        if (error instanceof SyntaxError) {
          lastErrors = ['response was not valid JSON'];
          continue;
        }
        if (isTransientLlmError(error)) throw new AnalysisTimeoutError(error);
        throw error;
      }

      const candidate = assemble(completion.data, input);
      const result = validateInterpretation(candidate);
      if (result.ok) return { interpretation: result.value, fallback: false, llmMode: completion.mode };
      lastErrors = result.errors;
    }

    throw new AnalysisUnavailableError(lastErrors);
  }
}

/** Adds server-owned fields and repairs harmless numeric drift before validation. */
export function assemble(raw: LlmInterpretation, input: RitualInput): unknown {
  if (!raw || typeof raw !== 'object' || !Array.isArray(raw.figures)) return raw;

  const figures = [...raw.figures]
    .map((f) => ({ ...f, feed: Math.max(0, Math.min(40, Math.round(Number(f.feed)))) }))
    .sort((a, b) => b.feed - a.feed);

  const listed = new Set(figures.map((f) => f.id));
  const relationshipCues = Array.isArray(raw.relationshipCues)
    ? raw.relationshipCues.filter((c) => c.figures?.[0] !== c.figures?.[1] && c.figures.every((id) => listed.has(id)))
    : raw.relationshipCues;

  return {
    ...raw,
    schemaVersion: 'event-interpretation.v1',
    eventId: `event_${randomUUID()}`,
    sourceType: input.inputType,
    figures: normalizeConcentrations(figures),
    relationshipCues,
  };
}

/** Rescales concentrations to sum to exactly 1 at two decimals. */
export function normalizeConcentrations(figures: FedFigure[]): FedFigure[] {
  const total = figures.reduce((sum, f) => sum + (Number(f.concentration) || 0), 0);
  if (!(total > 0) || figures.some((f) => f.concentration < 0)) return figures;
  const scaled = figures.map((f) => ({ ...f, concentration: Math.round((f.concentration / total) * 100) / 100 }));
  const rest = scaled.slice(1).reduce((sum, f) => sum + f.concentration, 0);
  scaled[0].concentration = Math.round((1 - rest) * 100) / 100;
  return scaled;
}
