import type { CompleteJsonRequest, JsonCompletion, JsonLlm } from '../src/llm/llmClient.js';

/** Returns (or throws) queued responses in order and records every request. */
export class FakeLlm implements JsonLlm {
  readonly configured = true;
  readonly requests: CompleteJsonRequest[] = [];
  constructor(private readonly queue: Array<unknown | Error>) {}
  async completeJson<T>(req: CompleteJsonRequest): Promise<JsonCompletion<T>> {
    this.requests.push(req);
    const next = this.queue.shift();
    if (next === undefined) throw new Error('FakeLlm: no queued response');
    if (next instanceof Error) throw next;
    return { data: structuredClone(next) as T, mode: 'json_schema', model: 'fake' };
  }
}

export const unconfiguredLlm: JsonLlm = {
  configured: false,
  completeJson: () => { throw new Error('should not be called'); },
};
