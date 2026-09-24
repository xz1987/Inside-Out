// Hand-written mirrors of packages/contracts/schemas/*.json.
// If you change a schema, change the matching type here and the fixtures.

export const FIGURE_IDS = ['joy', 'sadness', 'anger', 'fear'] as const;
export type FigureId = (typeof FIGURE_IDS)[number];

export interface FedFigure {
  id: FigureId;
  concentration: number;
  feed: number;
  evidence: string;
  voiceLine: string;
  confidence: number;
}

export interface EventInterpretationV1 {
  schemaVersion: 'event-interpretation.v1';
  eventId: string;
  summary: string;
  turningPoint: string;
  sourceType: 'voice' | 'message' | 'replay';
  figures: FedFigure[];
  relationshipCues: { figures: [FigureId, FigureId]; reason: string }[];
  objectCandidate: { name: string; source: 'literal' | 'symbolic' } | null;
  uncertainties: string[];
}

export interface EcosystemSnapshotV1 {
  schemaVersion: 'ecosystem-snapshot.v1';
  figures: { id: FigureId; level: number; exp: number; energy: number }[];
  relationships: { figures: [FigureId, FigureId]; score: number }[];
  seedMemories: {
    id: string;
    title: string;
    ownerFigureId: FigureId;
    state: 'visible' | 'masked';
    objectId: string | null;
    objectName: string | null;
  }[];
}

export interface EcosystemResolutionV1 {
  schemaVersion: 'ecosystem-resolution.v1';
  simulationMode: true;
  scenarioId: 'mvp_evolve_raid_mask_v1';
  promotedRelationship: { figures: [FigureId, FigureId]; before: number; delta: number; after: number; reason: string };
  evolution: { figureId: FigureId; beforeExp: number; feedApplied: number; threshold: 100; afterExp: number; mocked: true };
  raid: {
    attackerFigureId: FigureId;
    victimFigureId: FigureId;
    targetMemoryId: string;
    targetObjectId: string | null;
    result: 'success';
    mocked: true;
  };
  aftermath: { victimFinalLevel: 1; memoryFinalState: 'masked' };
  explanation: [string, string, string];
}

export interface ClientSessionResponseV1 {
  schemaVersion: 'client-session-response.v1';
  sessionId: string;
  traceId: string;
  interpretation: EventInterpretationV1;
  resolution: EcosystemResolutionV1;
  fallback: { interpretation: boolean; resolution: boolean };
}
