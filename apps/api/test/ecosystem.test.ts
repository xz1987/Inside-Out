import OpenAI from 'openai';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp, createDeps, type AppDeps } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import type { EcosystemSnapshotV1, EventInterpretationV1 } from '../src/contracts/types.js';
import { loadFixture, validateResolution, validateSessionResponse } from '../src/contracts/validate.js';
import { EcosystemDirector } from '../src/domains/ecosystem/ecosystemDirector.js';
import { chooseRaidTarget, resolveScenario, ScenarioError } from '../src/domains/ecosystem/scenario.js';
import { InputInterpreter } from '../src/domains/input/inputInterpreter.js';
import type { JsonLlm } from '../src/llm/llmClient.js';
import { FakeLlm, unconfiguredLlm } from './helpers.js';

const interpretation = () => loadFixture<EventInterpretationV1>('event-interpretation.valid.json');
const snapshot = () => loadFixture<EcosystemSnapshotV1>('ecosystem-snapshot.valid.json');
const DRIVER = 'So on my way home from work, this car just cut me off at the roundabout. The driver yelled at me like it was my fault.';

const soloJoy = (): EventInterpretationV1 => ({
  ...interpretation(),
  figures: [{ id: 'joy', concentration: 1, feed: 18, evidence: 'Mia brought you coffee.', voiceLine: 'That lit me up.', confidence: 0.9 }],
  relationshipCues: [],
});

const trio = (): EventInterpretationV1 => ({
  ...interpretation(),
  figures: [
    { id: 'sadness', concentration: 0.5, feed: 18, evidence: 'e', voiceLine: 'v', confidence: 0.9 },
    { id: 'fear', concentration: 0.3, feed: 12, evidence: 'e', voiceLine: 'v', confidence: 0.8 },
    { id: 'anger', concentration: 0.2, feed: 6, evidence: 'e', voiceLine: 'v', confidence: 0.7 },
  ],
  relationshipCues: [{ figures: ['fear', 'sadness'], reason: 'Doubt and hurt arrived together.' }],
});

const narration = () => ({
  relationshipReasons: ['Anger and Fear both stood guard on that road home.'],
  explanation: [
    'Anger grew into a new shape after that drive home.',
    'It carried off “Mia brought you coffee without asking” from Joy.',
    'Joy is back at Level 1, so that coffee memory is masked for now.',
  ],
});

describe('scenario rules', () => {
  it('reproduces the checked-in resolution fixture from the fixture inputs', () => {
    expect(resolveScenario(interpretation(), snapshot())).toEqual(loadFixture('ecosystem-resolution.valid.json'));
  });

  it('is deterministic', () => {
    expect(resolveScenario(interpretation(), snapshot())).toEqual(resolveScenario(interpretation(), snapshot()));
  });

  it('stages the evolution exactly at the threshold', () => {
    const { evolution } = resolveScenario(interpretation(), snapshot());
    expect(evolution).toMatchObject({ figureId: 'anger', beforeExp: 82, feedApplied: 18, afterExp: 100 });
  });

  it('prefers a victim that sat the event out, then the highest level', () => {
    // anger evolved, fear was fed; joy (Lv5) beats sadness (Lv2)
    expect(chooseRaidTarget('anger', interpretation(), snapshot()).ownerFigureId).toBe('joy');
  });

  it('never raids the evolved Figure or a masked memory', () => {
    const snap = snapshot();
    snap.seedMemories = snap.seedMemories.map((m) => (m.ownerFigureId === 'joy' ? { ...m, state: 'masked' as const } : m));
    const target = chooseRaidTarget('anger', interpretation(), snap);
    expect(target.ownerFigureId).not.toBe('anger');
    expect(target.ownerFigureId).not.toBe('joy');
  });

  it('promotes no bond when only one Figure took part', () => {
    const { promotedRelationships, raid } = resolveScenario(soloJoy(), snapshot());
    expect(promotedRelationships).toEqual([]);
    expect(raid.attackerFigureId).toBe('joy');
    expect(raid.victimFigureId).not.toBe('joy');
  });

  it('bonds every pair when three Figures took part, strongest first', () => {
    const { promotedRelationships } = resolveScenario(trio(), snapshot());
    expect(promotedRelationships.map((r) => r.figures)).toEqual([
      ['sadness', 'fear'], ['sadness', 'anger'], ['fear', 'anger'],
    ]);
    expect(promotedRelationships.map((r) => r.delta)).toEqual([8, 6, 5]); // round((a+b)/4), min 4
    expect(promotedRelationships[0].reason).toBe('Doubt and hurt arrived together.');
    // anger–fear starts from its existing score of 12
    expect(promotedRelationships[2]).toMatchObject({ before: 12, after: 17 });
  });

  it('treats a missing relationship as starting from 0', () => {
    const snap = snapshot();
    snap.relationships = [];
    expect(resolveScenario(interpretation(), snap).promotedRelationships[0]).toMatchObject({ before: 0, after: 8 });
  });

  it('throws ScenarioError when there is nothing to raid', () => {
    const snap = snapshot();
    snap.seedMemories = snap.seedMemories.filter((m) => m.ownerFigureId === 'anger');
    expect(() => resolveScenario(interpretation(), snap)).toThrow(ScenarioError);
  });

  it('always produces a contract-valid resolution', () => {
    for (const interp of [interpretation(), soloJoy(), trio()]) {
      expect(validateResolution(resolveScenario(interp, snapshot())).ok).toBe(true);
    }
  });
});

describe('EcosystemDirector', () => {
  it('keeps the decided outcome and only swaps in the wording', async () => {
    const llm = new FakeLlm([narration()]);
    const { resolution, fallback } = await new EcosystemDirector(llm).resolve(interpretation(), snapshot());
    const template = resolveScenario(interpretation(), snapshot());

    expect(fallback).toBe(false);
    expect(resolution.explanation).toEqual(narration().explanation);
    expect(resolution.promotedRelationships[0].reason).toBe(narration().relationshipReasons[0]);
    expect({ ...resolution, explanation: template.explanation, promotedRelationships: template.promotedRelationships })
      .toEqual(template);
  });

  it('words every bond for three Figures, in order', async () => {
    const reply = { ...narration(), relationshipReasons: ['one', 'two', 'three'] };
    const { resolution, fallback } = await new EcosystemDirector(new FakeLlm([reply])).resolve(trio(), snapshot());
    expect(fallback).toBe(false);
    expect(resolution.promotedRelationships.map((r) => r.reason)).toEqual(['one', 'two', 'three']);
  });

  it('never lets the model add a bond for a lone Figure', async () => {
    const reply = { ...narration(), relationshipReasons: ['Joy and Sadness are old friends.'] };
    const { resolution, fallback } = await new EcosystemDirector(new FakeLlm([reply])).resolve(soloJoy(), snapshot());
    expect(resolution.promotedRelationships).toEqual([]);
    expect(fallback).toBe(true); // count mismatch → template wording

    const empty = { ...narration(), relationshipReasons: [] };
    const second = await new EcosystemDirector(new FakeLlm([empty])).resolve(soloJoy(), snapshot());
    expect(second.fallback).toBe(false);
    expect(second.resolution.promotedRelationships).toEqual([]);
  });

  it('falls back when the model returns the wrong number of reasons', async () => {
    const reply = { ...narration(), relationshipReasons: ['only one'] };
    const { fallback, resolution } = await new EcosystemDirector(new FakeLlm([reply])).resolve(trio(), snapshot());
    expect(fallback).toBe(true);
    expect(resolution.promotedRelationships).toHaveLength(3);
  });

  it('sends the summary but never the raw memory text', async () => {
    const llm = new FakeLlm([narration()]);
    await new EcosystemDirector(llm).resolve(interpretation(), snapshot());
    const story = JSON.parse(llm.requests[0].user);
    expect(story.eventSummary).toBe(interpretation().summary);
    expect(story).not.toHaveProperty('memory');
    expect(story.raidedMemory.title).toBe('Mia brought you coffee without asking');
  });

  it.each([
    ['LLM error', new OpenAI.APIConnectionTimeoutError()],
    ['wrong shape', { relationshipReasons: ['x'], explanation: ['only one'] }],
    ['empty line', { relationshipReasons: ['x'], explanation: ['a', '', 'c'] }],
    ['empty reason', { relationshipReasons: [' '], explanation: ['a', 'b', 'c'] }],
    ['too long', { relationshipReasons: ['x'], explanation: ['a'.repeat(200), 'b', 'c'] }],
  ])('falls back to the template on %s', async (_label, reply) => {
    const { resolution, fallback } = await new EcosystemDirector(new FakeLlm([reply])).resolve(interpretation(), snapshot());
    expect(fallback).toBe(true);
    expect(resolution).toEqual(resolveScenario(interpretation(), snapshot()));
  });

  it('uses the template without calling the LLM when no key is configured', async () => {
    const { fallback } = await new EcosystemDirector(unconfiguredLlm).resolve(interpretation(), snapshot());
    expect(fallback).toBe(true);
  });
});

describe('HTTP', () => {
  const appWith = (inputLlm: JsonLlm, ecosystemLlm: JsonLlm) => {
    const deps: AppDeps = {
      ...createDeps(loadConfig({})),
      inputInterpreter: new InputInterpreter(inputLlm),
      ecosystemDirector: new EcosystemDirector(ecosystemLlm),
    };
    return createApp(deps);
  };
  const inputReply = () => {
    const { schemaVersion: _v, eventId: _e, sourceType: _s, ...rest } = interpretation();
    return rest;
  };

  describe('POST /api/v1/ecosystem/resolve', () => {
    it('returns a validated resolution', async () => {
      const res = await request(appWith(unconfiguredLlm, new FakeLlm([narration()])))
        .post('/api/v1/ecosystem/resolve')
        .send({ interpretation: interpretation(), snapshot: snapshot(), simulationMode: true, scenarioId: 'mvp_evolve_raid_mask_v1' });
      expect(res.status).toBe(200);
      expect(res.body.fallback).toBe(false);
      expect(validateResolution(res.body.resolution).ok).toBe(true);
    });

    it('rejects invalid inputs with 400', async () => {
      const bad = snapshot();
      bad.figures = bad.figures.slice(0, 3);
      const res = await request(appWith(unconfiguredLlm, unconfiguredLlm))
        .post('/api/v1/ecosystem/resolve')
        .send({ interpretation: interpretation(), snapshot: bad });
      expect(res.status).toBe(400);
      expect(res.body.error.message).toMatch(/snapshot/);
    });

    it('rejects simulationMode false', async () => {
      const res = await request(appWith(unconfiguredLlm, unconfiguredLlm))
        .post('/api/v1/ecosystem/resolve')
        .send({ interpretation: interpretation(), snapshot: snapshot(), simulationMode: false });
      expect(res.status).toBe(400);
    });

    it('returns 422 when the snapshot has nothing to raid', async () => {
      const snap = snapshot();
      snap.seedMemories = [];
      const res = await request(appWith(unconfiguredLlm, unconfiguredLlm))
        .post('/api/v1/ecosystem/resolve')
        .send({ interpretation: interpretation(), snapshot: snap });
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('scenario_unavailable');
    });
  });

  describe('POST /api/v1/sessions/run', () => {
    it('runs A then B and returns a validated session', async () => {
      const inputLlm = new FakeLlm([inputReply()]);
      const ecosystemLlm = new FakeLlm([narration()]);
      const res = await request(appWith(inputLlm, ecosystemLlm))
        .post('/api/v1/sessions/run')
        .send({ inputType: 'voice', text: DRIVER, snapshot: snapshot(), sessionId: 'abc-123' });

      expect(res.status).toBe(200);
      expect(validateSessionResponse(res.body).ok).toBe(true);
      expect(res.body.sessionId).toBe('abc-123');
      expect(res.body.fallback).toEqual({ interpretation: false, resolution: false });
      expect(res.body.resolution.evolution.figureId).toBe(res.body.interpretation.figures[0].id);
      expect(inputLlm.requests).toHaveLength(1);
      expect(ecosystemLlm.requests).toHaveLength(1);
    });

    it('does not call Domain B when Domain A fails', async () => {
      const ecosystemLlm = new FakeLlm([narration()]);
      const res = await request(appWith(new FakeLlm([new OpenAI.APIConnectionTimeoutError()]), ecosystemLlm))
        .post('/api/v1/sessions/run')
        .send({ inputType: 'voice', text: DRIVER, snapshot: snapshot() });
      expect(res.status).toBe(503);
      expect(ecosystemLlm.requests).toHaveLength(0);
    });

    it('still succeeds with template wording when Domain B’s LLM fails', async () => {
      const res = await request(appWith(new FakeLlm([inputReply()]), new FakeLlm([new OpenAI.APIConnectionTimeoutError()])))
        .post('/api/v1/sessions/run')
        .send({ inputType: 'voice', text: DRIVER, snapshot: snapshot() });
      expect(res.status).toBe(200);
      expect(res.body.fallback).toEqual({ interpretation: false, resolution: true });
      expect(res.body.resolution.explanation[0]).toBe('Anger evolved after receiving Feed.');
    });

    it('works fully offline with both fallbacks flagged', async () => {
      const res = await request(appWith(unconfiguredLlm, unconfiguredLlm))
        .post('/api/v1/sessions/run')
        .send({ inputType: 'message', text: DRIVER, snapshot: snapshot() });
      expect(res.status).toBe(200);
      expect(res.body.fallback).toEqual({ interpretation: true, resolution: true });
      expect(res.body.sessionId).toMatch(/^session_/);
    });

    it('requires a valid snapshot', async () => {
      const res = await request(appWith(unconfiguredLlm, unconfiguredLlm))
        .post('/api/v1/sessions/run')
        .send({ inputType: 'voice', text: DRIVER });
      expect(res.status).toBe(400);
      expect(res.body.error.message).toMatch(/snapshot/);
    });
  });
});
