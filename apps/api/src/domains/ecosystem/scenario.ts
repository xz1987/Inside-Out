import type {
  EcosystemResolutionV1,
  EcosystemSnapshotV1,
  EventInterpretationV1,
  FigureId,
} from '../../contracts/types.js';

// Deterministic rules for the staged MVP scenario (PRD §32–34). No randomness,
// no combat maths: the same inputs always produce the same outcome, so the
// demo is repeatable and testable. Only the wording may come from the LLM.

export const SCENARIO_ID = 'mvp_evolve_raid_mask_v1' as const;
export const EXP_THRESHOLD = 100;
/** Bond gain when only one Figure was fed and we reuse an existing pair. */
const SOLO_BOND_DELTA = 4;

export class ScenarioError extends Error {
  readonly code = 'scenario_unavailable';
  constructor(message: string) {
    super(message);
    this.name = 'ScenarioError';
  }
}

const displayName = (id: FigureId) => id[0].toUpperCase() + id.slice(1);
const samePair = (a: readonly FigureId[], b: readonly FigureId[]) =>
  (a[0] === b[0] && a[1] === b[1]) || (a[0] === b[1] && a[1] === b[0]);

export interface PromotedPair {
  figures: [FigureId, FigureId];
  reason: string;
  delta: number;
}

/**
 * Which relationship this event promotes. Prefers Domain A's cue for the two
 * most-fed Figures; with a single fed Figure, falls back to its strongest
 * existing bond ("Existing memory connection", PRD §31 C).
 */
export function choosePromotedPair(interpretation: EventInterpretationV1, snapshot: EcosystemSnapshotV1): PromotedPair {
  const [first, second] = interpretation.figures;

  if (second) {
    const figures: [FigureId, FigureId] = [first.id, second.id];
    const cue = interpretation.relationshipCues.find((c) => samePair(c.figures, figures));
    return {
      figures,
      reason: cue?.reason ?? 'Both took part in the same remembered moment.',
      delta: Math.max(4, Math.round((first.feed + second.feed) / 4)),
    };
  }

  const strongest = snapshot.relationships
    .filter((r) => r.figures.includes(first.id))
    .sort((a, b) => b.score - a.score)[0];
  const partner = strongest?.figures.find((id) => id !== first.id)
    ?? snapshot.figures.map((f) => f.id).find((id) => id !== first.id)!;
  return { figures: [first.id, partner], reason: 'Existing memory connection.', delta: SOLO_BOND_DELTA };
}

/**
 * The Figure whose memory gets raided: never the evolved one, preferably one
 * that sat this event out, then the highest level (the fall to Level 1 reads
 * clearest), then a stable id order.
 */
export function chooseRaidTarget(
  evolved: FigureId,
  interpretation: EventInterpretationV1,
  snapshot: EcosystemSnapshotV1,
): EcosystemSnapshotV1['seedMemories'][number] {
  const fed = new Set(interpretation.figures.map((f) => f.id));
  const levelOf = (id: FigureId) => snapshot.figures.find((f) => f.id === id)?.level ?? 1;
  const candidates = snapshot.seedMemories
    .filter((m) => m.state === 'visible' && m.ownerFigureId !== evolved)
    .sort((a, b) =>
      Number(fed.has(a.ownerFigureId)) - Number(fed.has(b.ownerFigureId))
      || levelOf(b.ownerFigureId) - levelOf(a.ownerFigureId)
      || a.id.localeCompare(b.id));
  if (!candidates.length) {
    throw new ScenarioError(`No visible memory owned by a Figure other than ${evolved} to raid`);
  }
  return candidates[0];
}

export function templateExplanation(evolved: FigureId, victim: FigureId): [string, string, string] {
  const e = displayName(evolved);
  const v = displayName(victim);
  return [
    `${e} evolved after receiving Feed.`,
    `It took a Memory from ${v}.`,
    `${v} fell to Level 1, so the related Memory became Masked.`,
  ];
}

/** Builds the full resolution with template wording. */
export function resolveScenario(interpretation: EventInterpretationV1, snapshot: EcosystemSnapshotV1): EcosystemResolutionV1 {
  const evolved = interpretation.figures[0];
  const pair = choosePromotedPair(interpretation, snapshot);
  const before = snapshot.relationships.find((r) => samePair(r.figures, pair.figures))?.score ?? 0;
  const target = chooseRaidTarget(evolved.id, interpretation, snapshot);
  // Staged evolution: start exactly `feed` short of the threshold so this
  // event's Feed tips it over (PRD §32 mock rule).
  const beforeExp = Math.max(0, EXP_THRESHOLD - evolved.feed);

  return {
    schemaVersion: 'ecosystem-resolution.v1',
    simulationMode: true,
    scenarioId: SCENARIO_ID,
    promotedRelationship: {
      figures: pair.figures,
      before,
      delta: pair.delta,
      after: before + pair.delta,
      reason: pair.reason,
    },
    evolution: {
      figureId: evolved.id,
      beforeExp,
      feedApplied: evolved.feed,
      threshold: EXP_THRESHOLD,
      afterExp: beforeExp + evolved.feed,
      mocked: true,
    },
    raid: {
      attackerFigureId: evolved.id,
      victimFigureId: target.ownerFigureId,
      targetMemoryId: target.id,
      targetObjectId: target.objectId,
      result: 'success',
      mocked: true,
    },
    aftermath: { victimFinalLevel: 1, memoryFinalState: 'masked' },
    explanation: templateExplanation(evolved.id, target.ownerFigureId),
  };
}
