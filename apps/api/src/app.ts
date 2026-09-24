import { randomUUID } from 'node:crypto';
import express, { type ErrorRequestHandler, type RequestHandler } from 'express';
import type { AppConfig } from './config.js';
import { LlmClient } from './llm/llmClient.js';
import { ContractError } from './contracts/validate.js';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      traceId: string;
    }
  }
}

export interface AppDeps {
  config: AppConfig;
  inputLlm: LlmClient;
  ecosystemLlm: LlmClient;
}

export function createDeps(config: AppConfig): AppDeps {
  return {
    config,
    inputLlm: new LlmClient(config.llm.input),
    ecosystemLlm: new LlmClient(config.llm.ecosystem),
  };
}

const traceId: RequestHandler = (req, res, next) => {
  const incoming = req.header('x-trace-id');
  req.traceId = incoming && /^[\w-]{1,64}$/.test(incoming) ? incoming : randomUUID();
  res.setHeader('x-trace-id', req.traceId);
  next();
};

const errorHandler: ErrorRequestHandler = (error, req, res, _next) => {
  if (error instanceof ContractError) {
    console.error(`[${req.traceId}] contract violation`, error.errors);
    res.status(502).json({ error: { code: 'contract_violation', message: 'Upstream result failed validation' }, traceId: req.traceId });
    return;
  }
  if (error?.type === 'entity.parse.failed') {
    res.status(400).json({ error: { code: 'invalid_json', message: 'Request body is not valid JSON' }, traceId: req.traceId });
    return;
  }
  console.error(`[${req.traceId}]`, error);
  res.status(500).json({ error: { code: 'internal', message: 'Something went wrong' }, traceId: req.traceId });
};

export function createApp(deps: AppDeps) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '256kb' }));
  app.use(traceId);

  app.get('/health', (req, res) => {
    res.json({
      status: 'ok',
      env: deps.config.appEnv,
      llm: {
        input: { configured: deps.inputLlm.configured, model: deps.config.llm.input.model, promptVersion: deps.config.llm.input.promptVersion },
        ecosystem: { configured: deps.ecosystemLlm.configured, model: deps.config.llm.ecosystem.model, promptVersion: deps.config.llm.ecosystem.promptVersion },
      },
      traceId: req.traceId,
    });
  });

  // Domain routes land here in the next PRs:
  //   POST /api/v1/events/interpret   (Domain A)
  //   POST /api/v1/ecosystem/resolve  (Domain B)
  //   POST /api/v1/sessions/run       (orchestrator)

  app.use((req, res) => {
    res.status(404).json({ error: { code: 'not_found', message: `No route for ${req.method} ${req.path}` }, traceId: req.traceId });
  });
  app.use(errorHandler);
  return app;
}
