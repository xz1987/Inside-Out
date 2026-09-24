import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Ajv2020, type ValidateFunction } from 'ajv/dist/2020.js';
import type {
  ClientSessionResponseV1,
  EcosystemResolutionV1,
  EcosystemSnapshotV1,
  EventInterpretationV1,
} from './types.js';

export type SchemaName =
  | 'event-interpretation.v1'
  | 'ecosystem-snapshot.v1'
  | 'ecosystem-resolution.v1'
  | 'client-session-response.v1';

/** Walks up from this file until it finds packages/contracts (works from src/ and dist/). */
export function findContractsDir(start = path.dirname(fileURLToPath(import.meta.url))): string {
  let dir = start;
  while (true) {
    const candidate = path.join(dir, 'packages', 'contracts');
    if (fs.existsSync(path.join(candidate, 'schemas'))) return candidate;
    const parent = path.dirname(dir);
    if (parent === dir) throw new Error('Could not locate packages/contracts');
    dir = parent;
  }
}

const contractsDir = findContractsDir();

export function loadSchema(name: SchemaName): object {
  return JSON.parse(fs.readFileSync(path.join(contractsDir, 'schemas', `${name}.schema.json`), 'utf8'));
}

export function loadFixture<T = unknown>(file: string): T {
  return JSON.parse(fs.readFileSync(path.join(contractsDir, 'fixtures', file), 'utf8')) as T;
}

const ajv = new Ajv2020({ allErrors: true, strict: true });
const names: SchemaName[] = ['event-interpretation.v1', 'ecosystem-snapshot.v1', 'ecosystem-resolution.v1', 'client-session-response.v1'];
for (const name of names) ajv.addSchema(loadSchema(name));

const compiled = new Map<SchemaName, ValidateFunction>();
function validatorFor(name: SchemaName): ValidateFunction {
  let fn = compiled.get(name);
  if (!fn) {
    fn = ajv.getSchema(`https://inside-out.local/schemas/${name}.schema.json`)!;
    compiled.set(name, fn);
  }
  return fn;
}

export type ValidationResult<T> = { ok: true; value: T } | { ok: false; errors: string[] };

export class ContractError extends Error {
  constructor(readonly schema: SchemaName, readonly errors: string[]) {
    super(`${schema} failed validation: ${errors.join('; ')}`);
    this.name = 'ContractError';
  }
}

function schemaErrors(name: SchemaName, value: unknown): string[] {
  const validate = validatorFor(name);
  if (validate(value)) return [];
  return (validate.errors ?? []).map((e) => `${e.instancePath || '/'} ${e.message}`);
}

// Rules JSON Schema can't express (PRD §41.5).

function interpretationRules(value: EventInterpretationV1): string[] {
  const errors: string[] = [];
  const ids = value.figures.map((f) => f.id);
  if (new Set(ids).size !== ids.length) errors.push('/figures ids must be unique');
  const total = value.figures.reduce((sum, f) => sum + f.concentration, 0);
  if (Math.abs(total - 1) > 0.01) errors.push(`/figures concentrations must sum to 1 (got ${total.toFixed(3)})`);
  value.relationshipCues.forEach((cue, i) => {
    if (cue.figures[0] === cue.figures[1]) errors.push(`/relationshipCues/${i} figures must differ`);
  });
  return errors;
}

function snapshotRules(value: EcosystemSnapshotV1): string[] {
  const ids = new Set(value.figures.map((f) => f.id));
  return ids.size === 4 ? [] : ['/figures must contain each Figure exactly once'];
}

function resolutionRules(value: EcosystemResolutionV1): string[] {
  const errors: string[] = [];
  const { promotedRelationships: rels, evolution, raid } = value;
  const seen = new Set<string>();
  rels.forEach((rel, i) => {
    if (rel.figures[0] === rel.figures[1]) errors.push(`/promotedRelationships/${i} figures must differ`);
    if (rel.after !== rel.before + rel.delta) errors.push(`/promotedRelationships/${i} after must equal before + delta`);
    const key = [...rel.figures].sort().join('+');
    if (seen.has(key)) errors.push(`/promotedRelationships/${i} duplicates another pair`);
    seen.add(key);
  });
  if (evolution.afterExp !== evolution.beforeExp + evolution.feedApplied) errors.push('/evolution afterExp must equal beforeExp + feedApplied');
  if (raid.attackerFigureId === raid.victimFigureId) errors.push('/raid attacker and victim must differ');
  if (raid.attackerFigureId !== evolution.figureId) errors.push('/raid attacker must be the evolved Figure');
  return errors;
}

function check<T>(name: SchemaName, value: unknown, rules: (v: T) => string[]): ValidationResult<T> {
  const errors = schemaErrors(name, value);
  if (errors.length) return { ok: false, errors };
  const ruleErrors = rules(value as T);
  return ruleErrors.length ? { ok: false, errors: ruleErrors } : { ok: true, value: value as T };
}

export const validateInterpretation = (value: unknown) =>
  check<EventInterpretationV1>('event-interpretation.v1', value, interpretationRules);

export const validateSnapshot = (value: unknown) =>
  check<EcosystemSnapshotV1>('ecosystem-snapshot.v1', value, snapshotRules);

export const validateResolution = (value: unknown) =>
  check<EcosystemResolutionV1>('ecosystem-resolution.v1', value, resolutionRules);

/** Bonds only between Figures fed in this event, and every such pair present. */
function sessionRules(v: ClientSessionResponseV1): string[] {
  const fed = v.interpretation.figures.map((f) => f.id);
  const errors: string[] = [];
  v.resolution.promotedRelationships.forEach((rel, i) => {
    if (!rel.figures.every((id) => fed.includes(id))) {
      errors.push(`/resolution/promotedRelationships/${i} names a Figure that was not fed`);
    }
  });
  const expected = (fed.length * (fed.length - 1)) / 2;
  if (v.resolution.promotedRelationships.length !== expected) {
    errors.push(`/resolution/promotedRelationships must have ${expected} pair(s) for ${fed.length} fed Figure(s)`);
  }
  return errors;
}

export const validateSessionResponse = (value: unknown) =>
  check<ClientSessionResponseV1>('client-session-response.v1', value, (v) => [
    ...interpretationRules(v.interpretation),
    ...resolutionRules(v.resolution),
    ...sessionRules(v),
  ]);

/** Validate or throw — for use right before data leaves the backend. */
export function assertValid<T>(result: ValidationResult<T>, schema: SchemaName): T {
  if (!result.ok) throw new ContractError(schema, result.errors);
  return result.value;
}
