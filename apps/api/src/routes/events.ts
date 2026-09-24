import { Router, type Request, type Response } from 'express';
import type { InputInterpreter } from '../domains/input/inputInterpreter.js';
import { AnalysisTimeoutError, AnalysisUnavailableError, type RitualInput } from '../domains/input/types.js';

/** Safety cap against accidental huge pastes (quota/latency); no minimum — a
 *  single word is a valid moment. */
export const MAX_TEXT_LENGTH = 4000;

type ParseResult = { ok: true; input: RitualInput } | { ok: false; message: string };

export function parseRitualInput(body: unknown): ParseResult {
  if (!body || typeof body !== 'object') return { ok: false, message: 'Body must be a JSON object' };
  const { inputType, text, importance } = body as Record<string, unknown>;

  if (inputType !== 'voice' && inputType !== 'message') {
    return { ok: false, message: 'inputType must be "voice" or "message"' };
  }
  if (typeof text !== 'string') return { ok: false, message: 'text must be a string' };
  const trimmed = text.trim();
  if (!trimmed) return { ok: false, message: 'text must not be empty' };
  if (trimmed.length > MAX_TEXT_LENGTH) return { ok: false, message: `text must be at most ${MAX_TEXT_LENGTH} characters` };
  if (importance !== undefined && (typeof importance !== 'number' || importance < 0 || importance > 1)) {
    return { ok: false, message: 'importance must be a number between 0 and 1' };
  }
  return { ok: true, input: { inputType, text: trimmed, importance: importance as number | undefined } };
}

/** Domain A route (PRD §40.2). Also used by the orchestrator in-process. */
export function eventsRouter(interpreter: InputInterpreter): Router {
  const router = Router();

  router.post('/api/v1/events/interpret', async (req, res, next) => {
    const parsed = parseRitualInput(req.body);
    if (!parsed.ok) {
      res.status(400).json({ error: { code: 'invalid_input', message: parsed.message }, traceId: req.traceId });
      return;
    }

    try {
      const started = Date.now();
      const result = await interpreter.interpret(parsed.input);
      // Log shape only — never the user's text.
      console.log(`[${req.traceId}] interpret ok in ${Date.now() - started}ms`
        + ` fallback=${result.fallback} mode=${result.llmMode ?? '-'} figures=${result.interpretation.figures.map((f) => f.id).join(',')}`);
      res.json({
        schemaVersion: 'event-interpretation.v1',
        interpretation: result.interpretation,
        fallback: result.fallback,
        promptVersion: interpreter.promptVersion,
        traceId: req.traceId,
      });
    } catch (error) {
      if (!sendAnalysisError(error, req, res)) next(error);
    }
  });

  return router;
}

/** Maps Domain A failures to HTTP (PRD §42.3). Returns false if not handled. */
export function sendAnalysisError(error: unknown, req: Request, res: Response): boolean {
  if (error instanceof AnalysisTimeoutError) {
    console.warn(`[${req.traceId}] interpret timeout`, (error.cause as Error | undefined)?.message);
    res.status(503).json({ error: { code: error.code, message: error.message, retryable: true }, traceId: req.traceId });
    return true;
  }
  if (error instanceof AnalysisUnavailableError) {
    console.warn(`[${req.traceId}] interpret invalid output`, error.details);
    res.status(502).json({ error: { code: error.code, message: error.message, retryable: true }, traceId: req.traceId });
    return true;
  }
  return false;
}
