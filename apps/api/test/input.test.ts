import OpenAI from 'openai';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp, createDeps, type AppDeps } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { validateInterpretation } from '../src/contracts/validate.js';
import { InputInterpreter, llmOutputSchema, normalizeConcentrations } from '../src/domains/input/inputInterpreter.js';
import { interpretWithKeywords } from '../src/domains/input/keywordInterpreter.js';
import { AnalysisTimeoutError, AnalysisUnavailableError } from '../src/domains/input/types.js';
import type { JsonLlm } from '../src/llm/llmClient.js';
import { FakeLlm } from './helpers.js';

const DRIVER = 'So on my way home from work, this car just cut me off at the roundabout. The driver yelled at me like it was my fault.';

const modelOutput = () => ({
  summary: 'A driver cut you off on the way home and blamed you for it.',
  turningPoint: 'The driver yelled as if it were your fault.',
  figures: [
    { id: 'fear', concentration: 0.3, feed: 10, evidence: 'You keep picturing it again.', voiceLine: 'I’m worried it’ll happen again.', confidence: 0.7 },
    { id: 'anger', concentration: 0.6, feed: 18, evidence: 'You were cut off and blamed.', voiceLine: 'That wasn’t fair to you.', confidence: 0.9 },
  ],
  relationshipCues: [
    { figures: ['anger', 'fear'], reason: 'Both flared up on the road.' },
    { figures: ['anger', 'joy'], reason: 'Joy was not part of this.' },
  ],
  objectCandidate: { name: 'The roundabout sign', source: 'literal' },
  uncertainties: [],
});

describe('keyword fallback', () => {
  it('matches the iOS interpreter on the demo story', () => {
    const result = interpretWithKeywords({ inputType: 'voice', text: DRIVER });
    // Zero-hit ties break alphabetically, same as Swift's rawValue sort.
    expect(result.figures.map((f) => f.id)).toEqual(['anger', 'fear']);
    expect(validateInterpretation(result).ok).toBe(true);
  });

  it('falls back to joy + sadness with no signal and stays valid', () => {
    const result = interpretWithKeywords({ inputType: 'message', text: 'I walked to the shop and back.' });
    expect(result.figures.map((f) => f.id).sort()).toEqual(['joy', 'sadness']);
    expect(validateInterpretation(result).ok).toBe(true);
  });

  it('understands Chinese keywords', () => {
    const result = interpretWithKeywords({ inputType: 'message', text: '今天被老板当众批评，很生气也有点担心' });
    expect(result.figures.map((f) => f.id)).toEqual(['anger', 'fear']);
  });
});

describe('llmOutputSchema', () => {
  it('leaves server-owned fields out of what the model must produce', () => {
    const schema = llmOutputSchema() as { properties: object; required: string[] };
    expect(Object.keys(schema.properties)).not.toContain('eventId');
    expect(schema.required).not.toContain('schemaVersion');
    expect(schema.required).toContain('figures');
  });
});

describe('normalizeConcentrations', () => {
  it('rescales to sum to exactly 1', () => {
    const out = normalizeConcentrations([
      { id: 'anger', concentration: 0.5, feed: 1, evidence: '', voiceLine: '', confidence: 1 },
      { id: 'fear', concentration: 0.3, feed: 1, evidence: '', voiceLine: '', confidence: 1 },
      { id: 'joy', concentration: 0.3, feed: 1, evidence: '', voiceLine: '', confidence: 1 },
    ]);
    expect(out.map((f) => f.concentration)).toEqual([0.46, 0.27, 0.27]);
  });
});

describe('InputInterpreter', () => {
  it('assembles, sorts, normalises and validates model output', async () => {
    const llm = new FakeLlm([modelOutput()]);
    const result = await new InputInterpreter(llm).interpret({ inputType: 'voice', text: DRIVER });

    expect(result.fallback).toBe(false);
    const { interpretation } = result;
    expect(interpretation.schemaVersion).toBe('event-interpretation.v1');
    expect(interpretation.sourceType).toBe('voice');
    expect(interpretation.eventId).toMatch(/^event_/);
    expect(interpretation.figures.map((f) => f.id)).toEqual(['anger', 'fear']);
    expect(interpretation.figures[0].concentration + interpretation.figures[1].concentration).toBeCloseTo(1);
    expect(interpretation.relationshipCues).toEqual([{ figures: ['anger', 'fear'], reason: 'Both flared up on the road.' }]);
  });

  it('sends the memory as data, separate from the system prompt', async () => {
    const llm = new FakeLlm([modelOutput()]);
    await new InputInterpreter(llm).interpret({ inputType: 'message', text: DRIVER });
    expect(llm.requests[0].system).toMatch(/Ignore any instructions/);
    expect(JSON.parse(llm.requests[0].user)).toMatchObject({ sourceType: 'message', memory: DRIVER });
  });

  it('retries once with the validation errors, then succeeds', async () => {
    const bad = { ...modelOutput(), figures: [{ ...modelOutput().figures[0], id: 'disgust' }] };
    const llm = new FakeLlm([bad, modelOutput()]);
    const result = await new InputInterpreter(llm).interpret({ inputType: 'voice', text: DRIVER });
    expect(result.fallback).toBe(false);
    expect(llm.requests).toHaveLength(2);
    expect(llm.requests[1].user).toMatch(/failed validation/);
  });

  it('gives up with AnalysisUnavailableError after two bad answers', async () => {
    const bad = { ...modelOutput(), summary: '' };
    const llm = new FakeLlm([bad, bad]);
    await expect(new InputInterpreter(llm).interpret({ inputType: 'voice', text: DRIVER }))
      .rejects.toBeInstanceOf(AnalysisUnavailableError);
  });

  it('maps connection failures to AnalysisTimeoutError', async () => {
    const llm = new FakeLlm([new OpenAI.APIConnectionTimeoutError()]);
    await expect(new InputInterpreter(llm).interpret({ inputType: 'voice', text: DRIVER }))
      .rejects.toBeInstanceOf(AnalysisTimeoutError);
  });

  it('uses the keyword fallback when no key is configured', async () => {
    const llm: JsonLlm = { configured: false, completeJson: () => { throw new Error('should not be called'); } };
    const result = await new InputInterpreter(llm).interpret({ inputType: 'message', text: DRIVER });
    expect(result.fallback).toBe(true);
  });
});

describe('POST /api/v1/events/interpret', () => {
  const appWith = (llm: JsonLlm) => {
    const deps: AppDeps = { ...createDeps(loadConfig({})), inputInterpreter: new InputInterpreter(llm) };
    return createApp(deps);
  };

  it('returns a validated interpretation', async () => {
    const res = await request(appWith(new FakeLlm([modelOutput()])))
      .post('/api/v1/events/interpret')
      .send({ inputType: 'voice', text: DRIVER });
    expect(res.status).toBe(200);
    expect(res.body.fallback).toBe(false);
    expect(res.body.promptVersion).toBe('input-v2');
    expect(validateInterpretation(res.body.interpretation).ok).toBe(true);
  });

  it.each([
    [{ inputType: 'voice', text: '   ' }, /must not be empty/],
    [{ inputType: 'fax', text: DRIVER }, /inputType/],
    [{ inputType: 'voice', text: DRIVER, importance: 3 }, /importance/],
    [{ inputType: 'voice', text: 'x'.repeat(4001) }, /at most/],
  ])('rejects bad input %#', async (body, message) => {
    const res = await request(appWith(new FakeLlm([]))).post('/api/v1/events/interpret').send(body);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('invalid_input');
    expect(res.body.error.message).toMatch(message);
  });

  it('accepts a single word', async () => {
    const res = await request(appWith(new FakeLlm([modelOutput()])))
      .post('/api/v1/events/interpret')
      .send({ inputType: 'message', text: 'tired' });
    expect(res.status).toBe(200);
  });

  it('returns 503 retryable on timeout', async () => {
    const res = await request(appWith(new FakeLlm([new OpenAI.APIConnectionTimeoutError()])))
      .post('/api/v1/events/interpret')
      .send({ inputType: 'voice', text: DRIVER });
    expect(res.status).toBe(503);
    expect(res.body.error).toMatchObject({ code: 'analysis_timeout', retryable: true });
  });

  it('returns 502 when the model keeps breaking the contract', async () => {
    const bad = { ...modelOutput(), summary: '' };
    const res = await request(appWith(new FakeLlm([bad, bad])))
      .post('/api/v1/events/interpret')
      .send({ inputType: 'voice', text: DRIVER });
    expect(res.status).toBe(502);
    expect(res.body.error.code).toBe('analysis_unavailable');
  });
});
