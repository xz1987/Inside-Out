import dotenv from 'dotenv';

dotenv.config({ quiet: true });

export type Domain = 'input' | 'ecosystem';

export interface LlmDomainConfig {
  domain: Domain;
  apiKey: string | undefined;
  baseURL: string;
  /** Model id as sent to the gateway (prefixed with "openai." off openai.com). */
  model: string;
  promptVersion: string;
  /** Sent as reasoning_effort; undefined omits it (use "off" for non-reasoning models). */
  reasoningEffort: ReasoningEffort | undefined;
}

export type ReasoningEffort = 'minimal' | 'low' | 'medium' | 'high';
const REASONING_EFFORTS: readonly string[] = ['minimal', 'low', 'medium', 'high'];

export interface AppConfig {
  port: number;
  appEnv: string;
  llm: Record<Domain, LlmDomainConfig>;
}

/** Same rule as the course example: the base URL must end with /v1. */
export function normalizeBaseURL(host: string | undefined): string {
  const base = (host || 'https://api.openai.com/v1').trim();
  return base.endsWith('/v1') ? base : base.replace(/\/$/, '') + '/v1';
}

export function isOpenAIHost(baseURL: string): boolean {
  return baseURL.includes('openai.com');
}

/** The Cornell gateway expects provider-prefixed ids, e.g. "openai.gpt-5-mini". */
export function gatewayModel(model: string, baseURL: string): string {
  if (isOpenAIHost(baseURL) || model.startsWith('openai.')) return model;
  return `openai.${model}`;
}

/**
 * Defaults measured on gpt-5-mini via the Cornell gateway:
 * - input "low": ~3–7 s vs ~9–16 s by default, same quality ("minimal" padded Figures);
 * - ecosystem "minimal": ~2 s vs ~5–6 s at "low"; it only words a decided outcome.
 * "off" omits the parameter for models that don't support it.
 */
function parseEffort(value: string | undefined, fallback: ReasoningEffort): ReasoningEffort | undefined {
  if (value === undefined) return fallback;
  if (value === 'off') return undefined;
  if (!REASONING_EFFORTS.includes(value)) throw new Error(`Invalid reasoning effort: ${value}`);
  return value as ReasoningEffort;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const baseURL = normalizeBaseURL(env.LLM_HOST || env.LLM_BASE_URL);
  const blank = (value: string | undefined) => (value && value.trim() ? value.trim() : undefined);
  const domain = (name: Domain, prefix: 'INPUT' | 'ECOSYSTEM', defaultPrompt: string, defaultEffort: ReasoningEffort): LlmDomainConfig => ({
    domain: name,
    apiKey: blank(env[`${prefix}_DOMAIN_API_KEY`]) ?? blank(env.OPENAI_API_KEY),
    baseURL,
    model: gatewayModel(blank(env[`${prefix}_DOMAIN_MODEL`]) ?? 'gpt-5-mini', baseURL),
    promptVersion: blank(env[`${prefix}_PROMPT_VERSION`]) ?? defaultPrompt,
    reasoningEffort: parseEffort(blank(env[`${prefix}_REASONING_EFFORT`]), defaultEffort),
  });

  return {
    port: Number(env.PORT) || 3000,
    appEnv: env.APP_ENV || 'development',
    llm: {
      input: domain('input', 'INPUT', 'input-v2', 'low'),
      ecosystem: domain('ecosystem', 'ECOSYSTEM', 'ecosystem-mvp-v1', 'minimal'),
    },
  };
}
