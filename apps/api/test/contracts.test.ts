import { describe, expect, it } from 'vitest';
import {
  loadFixture,
  validateInterpretation,
  validateResolution,
  validateSessionResponse,
  validateSnapshot,
} from '../src/contracts/validate.js';

const clone = <T>(value: T): T => structuredClone(value);
const interpretation = loadFixture<any>('event-interpretation.valid.json');
const snapshot = loadFixture<any>('ecosystem-snapshot.valid.json');
const resolution = loadFixture<any>('ecosystem-resolution.valid.json');
const session = loadFixture<any>('client-session-response.valid.json');

describe('fixtures are valid', () => {
  it.each([
    ['interpretation', validateInterpretation, interpretation],
    ['snapshot', validateSnapshot, snapshot],
    ['resolution', validateResolution, resolution],
    ['session', validateSessionResponse, session],
  ] as const)('%s', (_name, validate, fixture) => {
    const result = validate(fixture);
    expect(result.ok ? [] : result.errors).toEqual([]);
  });
});

describe('EventInterpretationV1 rules', () => {
  it('rejects unknown Figure ids', () => {
    const bad = clone(interpretation);
    bad.figures[0].id = 'disgust';
    expect(validateInterpretation(bad).ok).toBe(false);
  });

  it('rejects concentrations that do not sum to 1', () => {
    const bad = clone(interpretation);
    bad.figures[0].concentration = 0.9;
    const result = validateInterpretation(bad);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.errors.join()).toMatch(/sum to 1/);
  });

  it('allows ±0.01 rounding error', () => {
    const ok = clone(interpretation);
    ok.figures[0].concentration = 0.665;
    expect(validateInterpretation(ok).ok).toBe(true);
  });

  it('rejects negative feed', () => {
    const bad = clone(interpretation);
    bad.figures[1].feed = -3;
    expect(validateInterpretation(bad).ok).toBe(false);
  });

  it('rejects duplicate Figures', () => {
    const bad = clone(interpretation);
    bad.figures[1].id = 'anger';
    expect(validateInterpretation(bad).ok).toBe(false);
  });

  it('rejects extra properties', () => {
    const bad = clone(interpretation);
    bad.mood = 'bad';
    expect(validateInterpretation(bad).ok).toBe(false);
  });

  it('rejects a schema version mismatch instead of coercing', () => {
    const bad = clone(interpretation);
    bad.schemaVersion = 'event-interpretation.v2';
    expect(validateInterpretation(bad).ok).toBe(false);
  });
});

describe('EcosystemResolutionV1 rules', () => {
  it('rejects attacker === victim', () => {
    const bad = clone(resolution);
    bad.raid.victimFigureId = 'anger';
    expect(validateResolution(bad).ok).toBe(false);
  });

  it('requires simulationMode true and a successful raid', () => {
    const notSimulated = clone(resolution);
    notSimulated.simulationMode = false;
    expect(validateResolution(notSimulated).ok).toBe(false);

    const failedRaid = clone(resolution);
    failedRaid.raid.result = 'failure';
    expect(validateResolution(failedRaid).ok).toBe(false);
  });

  it('pins the aftermath to Level 1 + masked', () => {
    const bad = clone(resolution);
    bad.aftermath.victimFinalLevel = 2;
    expect(validateResolution(bad).ok).toBe(false);
  });

  it('allows no promoted relationship', () => {
    const solo = clone(resolution);
    solo.promotedRelationship = null;
    expect(validateResolution(solo).ok).toBe(true);
  });

  it('checks relationship arithmetic', () => {
    const bad = clone(resolution);
    bad.promotedRelationship.after = 99;
    expect(validateResolution(bad).ok).toBe(false);
  });

  it('requires the attacker to be the evolved Figure', () => {
    const bad = clone(resolution);
    bad.evolution.figureId = 'fear';
    expect(validateResolution(bad).ok).toBe(false);
  });
});

describe('EcosystemSnapshotV1 rules', () => {
  it('requires all four Figures exactly once', () => {
    const bad = clone(snapshot);
    bad.figures[3].id = 'joy';
    expect(validateSnapshot(bad).ok).toBe(false);
  });
});
