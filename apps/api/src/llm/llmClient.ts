import OpenAI from 'openai';
import type { LlmDomainConfig } from '../config.js';

export type JsonMode = 'json_schema' | 'json_object';

export interface JsonCompletion<T> {
  data: T;
  mode: JsonMode;
  model: string;
}

export interface CompleteJsonRequest {
  system: string;
  user: string;
  schemaName: string;
  /** Full contract schema; a gateway-safe copy is derived via `toLlmSchema`. */
  schema: object;
}

export class LlmNotConfiguredError extends Error {
  constructor(domain: string) {
    super(`No API key configured for the ${domain} domain`);
    this.name = 'LlmNotConfiguredError';
  }
}

/**
 * One client per AI domain, so each can use its own key, model and prompt
 * version (PRD §37.3). Works against api.openai.com and the Cornell gateway.
 */
export class LlmClient {
  private readonly openai: OpenAI | undefined;

  constructor(readonly config: LlmDomainConfig, openai?: OpenAI) {
    this.openai = openai ?? (config.apiKey
      ? new OpenAI({ apiKey: config.apiKey, baseURL: config.baseURL, timeout: 30_000, maxRetries: 1 })
      : undefined);
  }

  get configured(): boolean {
    return this.openai !== undefined;
  }

  /**
   * Ask for JSON matching `schema`. Prefers strict structured output; if the
   * gateway rejects `json_schema`, retries once in plain JSON mode with the
   * schema in the prompt. Callers must still validate the result.
   */
  async completeJson<T>(request: CompleteJsonRequest): Promise<JsonCompletion<T>> {
    if (!this.openai) throw new LlmNotConfiguredError(this.config.domain);

    try {
      const response = await this.openai.chat.completions.create({
        model: this.config.model,
        messages: [
          { role: 'developer', content: request.system },
          { role: 'user', content: request.user },
        ],
        response_format: {
          type: 'json_schema',
          json_schema: { name: request.schemaName, strict: true, schema: toLlmSchema(request.schema) as Record<string, unknown> },
        },
      });
      return { data: parseJson<T>(response.choices[0]?.message?.content), mode: 'json_schema', model: this.config.model };
    } catch (error) {
      if (!isUnsupportedResponseFormat(error)) throw error;
    }

    const response = await this.openai.chat.completions.create({
      model: this.config.model,
      messages: [
        {
          role: 'developer',
          content: `${request.system}\n\nRespond with a single JSON object that matches this JSON Schema exactly. No prose.\n${JSON.stringify(toLlmSchema(request.schema))}`,
        },
        { role: 'user', content: request.user },
      ],
      response_format: { type: 'json_object' },
    });
    return { data: parseJson<T>(response.choices[0]?.message?.content), mode: 'json_object', model: this.config.model };
  }
}

function parseJson<T>(content: string | null | undefined): T {
  if (!content) throw new Error('LLM returned an empty message');
  return JSON.parse(content) as T;
}

function isUnsupportedResponseFormat(error: unknown): boolean {
  if (!(error instanceof OpenAI.APIError)) return false;
  if (error.status !== 400 && error.status !== 422) return false;
  return /response_format|json_schema|structured/i.test(error.message);
}

/** Keywords some OpenAI-compatible gateways reject in strict mode. The full
 *  contract is still enforced by Ajv after the response comes back. */
const STRIPPED_KEYWORDS = new Set([
  '$schema', '$id', 'title', 'minLength', 'maxLength', 'minimum', 'maximum', 'minItems', 'maxItems', 'format',
]);

export function toLlmSchema(schema: unknown): unknown {
  if (Array.isArray(schema)) return schema.map(toLlmSchema);
  if (!schema || typeof schema !== 'object') return schema;

  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(schema)) {
    if (STRIPPED_KEYWORDS.has(key)) continue;
    if (key === 'const') {
      out.enum = [value];
      continue;
    }
    out[key] = toLlmSchema(value);
  }
  return out;
}
