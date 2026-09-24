import type { EventInterpretationV1 } from '../../contracts/types.js';

/** What the phone sends after on-device speech-to-text (or typed input). */
export interface RitualInput {
  inputType: 'voice' | 'message';
  text: string;
  /** Optional 0–1 weight the user gave the moment. */
  importance?: number;
}

export interface InterpretResult {
  interpretation: EventInterpretationV1;
  /** true when the keyword fallback produced this instead of the LLM. */
  fallback: boolean;
  /** Which structured-output mode the LLM ran in, when it ran. */
  llmMode?: 'json_schema' | 'json_object';
}

export class AnalysisUnavailableError extends Error {
  readonly code = 'analysis_unavailable';
  constructor(readonly details: string[]) {
    super('The interpretation could not be produced in the expected format');
    this.name = 'AnalysisUnavailableError';
  }
}

export class AnalysisTimeoutError extends Error {
  readonly code = 'analysis_timeout';
  constructor(cause?: unknown) {
    super('The language model did not respond in time', { cause });
    this.name = 'AnalysisTimeoutError';
  }
}
