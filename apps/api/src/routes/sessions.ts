import { randomUUID } from 'node:crypto';
import { Router } from 'express';
import type { ClientSessionResponseV1 } from '../contracts/types.js';
import { assertValid, validateSessionResponse, validateSnapshot } from '../contracts/validate.js';
import type { EcosystemDirector } from '../domains/ecosystem/ecosystemDirector.js';
import type { InputInterpreter } from '../domains/input/inputInterpreter.js';
import { sendScenarioError } from './ecosystem.js';
import { parseRitualInput, sendAnalysisError } from './events.js';

/**
 * The one endpoint iOS calls (PRD §40.2): Domain A → validate → Domain B →
 * validate → combine. If Domain A fails, Domain B is not called (§42.3).
 */
export function sessionsRouter(interpreter: InputInterpreter, director: EcosystemDirector): Router {
  const router = Router();

  router.post('/api/v1/sessions/run', async (req, res, next) => {
    const body = (req.body ?? {}) as Record<string, unknown>;
    const parsed = parseRitualInput(body);
    if (!parsed.ok) {
      res.status(400).json({ error: { code: 'invalid_input', message: parsed.message }, traceId: req.traceId });
      return;
    }
    const snapshot = validateSnapshot(body.snapshot);
    if (!snapshot.ok) {
      res.status(400).json({ error: { code: 'invalid_input', message: `snapshot: ${snapshot.errors.join('; ')}` }, traceId: req.traceId });
      return;
    }
    const sessionId = typeof body.sessionId === 'string' && /^[\w-]{1,64}$/.test(body.sessionId)
      ? body.sessionId
      : `session_${randomUUID()}`;

    try {
      const started = Date.now();
      const input = await interpreter.interpret(parsed.input);
      const afterA = Date.now();
      const ecosystem = await director.resolve(input.interpretation, snapshot.value);

      const response: ClientSessionResponseV1 = assertValid(validateSessionResponse({
        schemaVersion: 'client-session-response.v1',
        sessionId,
        traceId: req.traceId,
        interpretation: input.interpretation,
        resolution: ecosystem.resolution,
        fallback: { interpretation: input.fallback, resolution: ecosystem.fallback },
      }), 'client-session-response.v1');

      // Shape only — never the user's text.
      console.log(`[${req.traceId}] session ok A=${afterA - started}ms B=${Date.now() - afterA}ms`
        + ` figures=${input.interpretation.figures.map((f) => f.id).join(',')}`
        + ` evolved=${response.resolution.evolution.figureId} victim=${response.resolution.raid.victimFigureId}`
        + ` fallback=${JSON.stringify(response.fallback)}`);
      res.json(response);
    } catch (error) {
      if (sendAnalysisError(error, req, res) || sendScenarioError(error, req, res)) return;
      next(error);
    }
  });

  return router;
}
