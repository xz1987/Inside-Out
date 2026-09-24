import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp, createDeps } from '../src/app.js';
import { gatewayModel, loadConfig, normalizeBaseURL } from '../src/config.js';
import { toLlmSchema } from '../src/llm/llmClient.js';

describe('config', () => {
  it('appends /v1 like the course example', () => {
    expect(normalizeBaseURL('https://api.ai.it.cornell.edu')).toBe('https://api.ai.it.cornell.edu/v1');
    expect(normalizeBaseURL('https://api.ai.it.cornell.edu/')).toBe('https://api.ai.it.cornell.edu/v1');
    expect(normalizeBaseURL('https://api.openai.com/v1')).toBe('https://api.openai.com/v1');
  });

  it('prefixes models with "openai." only off openai.com', () => {
    expect(gatewayModel('gpt-5-mini', 'https://api.ai.it.cornell.edu/v1')).toBe('openai.gpt-5-mini');
    expect(gatewayModel('openai.gpt-5-mini', 'https://api.ai.it.cornell.edu/v1')).toBe('openai.gpt-5-mini');
    expect(gatewayModel('gpt-5-mini', 'https://api.openai.com/v1')).toBe('gpt-5-mini');
  });

  it('falls back to OPENAI_API_KEY for both domains', () => {
    const config = loadConfig({ OPENAI_API_KEY: 'shared', ECOSYSTEM_DOMAIN_API_KEY: 'eco' });
    expect(config.llm.input.apiKey).toBe('shared');
    expect(config.llm.ecosystem.apiKey).toBe('eco');
  });

  it('defaults reasoning effort to low and lets "off" omit it', () => {
    expect(loadConfig({}).llm.input.reasoningEffort).toBe('low');
    expect(loadConfig({ INPUT_REASONING_EFFORT: 'off' }).llm.input.reasoningEffort).toBeUndefined();
    expect(loadConfig({ ECOSYSTEM_REASONING_EFFORT: 'high' }).llm.ecosystem.reasoningEffort).toBe('high');
    expect(() => loadConfig({ INPUT_REASONING_EFFORT: 'turbo' })).toThrow(/Invalid reasoning effort/);
  });

  it('treats blank keys as missing', () => {
    const config = loadConfig({ OPENAI_API_KEY: '  ', INPUT_DOMAIN_API_KEY: '' });
    expect(config.llm.input.apiKey).toBeUndefined();
  });
});

describe('toLlmSchema', () => {
  it('strips keywords gateways may reject and turns const into enum', () => {
    const out = toLlmSchema({
      $id: 'x', title: 't', type: 'object',
      properties: { v: { type: 'string', const: 'a', maxLength: 3 }, n: { type: 'number', minimum: 0 } },
    });
    expect(out).toEqual({ type: 'object', properties: { v: { type: 'string', enum: ['a'] }, n: { type: 'number' } } });
  });
});

describe('app', () => {
  const app = createApp(createDeps(loadConfig({ LLM_HOST: 'https://api.ai.it.cornell.edu' })));

  it('reports health without leaking keys', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.llm.input).toEqual({ configured: false, model: 'openai.gpt-5-mini', promptVersion: 'input-v1' });
    expect(JSON.stringify(res.body)).not.toMatch(/apiKey/i);
    expect(res.headers['x-trace-id']).toBe(res.body.traceId);
  });

  it('echoes a safe incoming trace id', async () => {
    const res = await request(app).get('/health').set('x-trace-id', 'abc-123');
    expect(res.body.traceId).toBe('abc-123');
  });

  it('returns JSON 404s', async () => {
    const res = await request(app).post('/api/v1/nope');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('not_found');
  });

  it('returns JSON 400 for malformed bodies', async () => {
    const res = await request(app).post('/api/v1/nope').set('content-type', 'application/json').send('{bad');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('invalid_json');
  });
});
