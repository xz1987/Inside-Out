import { Router, type Request, type Response } from 'express';
import { assertValid, validateInterpretation, validateResolution, validateSnapshot } from '../contracts/validate.js';
import type { EcosystemDirector } from '../domains/ecosystem/ecosystemDirector.js';
import { SCENARIO_ID, ScenarioError } from '../domains/ecosystem/scenario.js';

/** Maps Domain B failures to HTTP. Returns false if not handled. */
export function sendScenarioError(error: unknown, req: Request, res: Response): boolean {
  if (!(error instanceof ScenarioError)) return false;
  res.status(422).json({ error: { code: error.code, message: error.message, retryable: false }, traceId: req.traceId });
  return true;
}

/** Domain B route (PRD §40.2) — mostly for debugging; iOS uses /sessions/run. */
export function ecosystemRouter(director: EcosystemDirector): Router {
  const router = Router();

  router.post('/api/v1/ecosystem/resolve', async (req, res, next) => {
    const { interpretation, snapshot, simulationMode, scenarioId } = (req.body ?? {}) as Record<string, unknown>;
    if (simulationMode !== undefined && simulationMode !== true) {
      res.status(400).json({ error: { code: 'invalid_input', message: 'MVP only supports simulationMode: true' }, traceId: req.traceId });
      return;
    }
    if (scenarioId !== undefined && scenarioId !== SCENARIO_ID) {
      res.status(400).json({ error: { code: 'invalid_input', message: `Unknown scenarioId; expected ${SCENARIO_ID}` }, traceId: req.traceId });
      return;
    }
    const checkedInterpretation = validateInterpretation(interpretation);
    const checkedSnapshot = validateSnapshot(snapshot);
    if (!checkedInterpretation.ok || !checkedSnapshot.ok) {
      const errors = [
        ...(checkedInterpretation.ok ? [] : checkedInterpretation.errors.map((e) => `interpretation${e}`)),
        ...(checkedSnapshot.ok ? [] : checkedSnapshot.errors.map((e) => `snapshot${e}`)),
      ];
      res.status(400).json({ error: { code: 'invalid_input', message: errors.join('; ') }, traceId: req.traceId });
      return;
    }

    try {
      const started = Date.now();
      const result = await director.resolve(checkedInterpretation.value, checkedSnapshot.value);
      const resolution = assertValid(validateResolution(result.resolution), 'ecosystem-resolution.v1');
      console.log(`[${req.traceId}] resolve ok in ${Date.now() - started}ms fallback=${result.fallback}`
        + ` evolved=${resolution.evolution.figureId} victim=${resolution.raid.victimFigureId}`);
      res.json({
        schemaVersion: 'ecosystem-resolution.v1',
        resolution,
        fallback: result.fallback,
        promptVersion: director.promptVersion,
        traceId: req.traceId,
      });
    } catch (error) {
      if (!sendScenarioError(error, req, res)) next(error);
    }
  });

  return router;
}
