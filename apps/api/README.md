# Inside Out API

One backend origin for the iOS app (PRD §37–40). AI keys live here only —
never in the Xcode project.

## Setup

```bash
cd apps/api
cp .env.example .env      # then fill in OPENAI_API_KEY
npm install
npm run smoke:llm         # checks the gateway + whether strict JSON Schema output works
npm run dev               # http://localhost:3000/health
```

Defaults target the Cornell AI gateway (`LLM_HOST=https://api.ai.it.cornell.edu`),
which is OpenAI-compatible: `/v1` is appended automatically and model ids get the
`openai.` prefix (e.g. `openai.gpt-5-mini`). For direct OpenAI, set
`LLM_HOST=https://api.openai.com/v1`.

One `OPENAI_API_KEY` serves both domains. `INPUT_DOMAIN_API_KEY` /
`ECOSYSTEM_DOMAIN_API_KEY` override it per domain when you have separate keys.

## Layout

```
src/
  config.ts              env → per-domain LLM config (base URL, model prefix, key fallback)
  llm/llmClient.ts       OpenAI SDK wrapper; strict json_schema with json_object fallback
  contracts/validate.ts  Ajv validation of packages/contracts schemas + PRD §41.5 rules
  contracts/types.ts     TypeScript mirrors of the schemas
  app.ts / index.ts      Express app: trace ids, JSON errors, /health
scripts/smoke-llm.ts     gateway check (never prints the key)
test/                    vitest: contract fixtures + app/config
```

## Endpoints

| Route | Status |
|---|---|
| `GET /health` | done |
| `POST /api/v1/events/interpret` (Domain A) | next |
| `POST /api/v1/ecosystem/resolve` (Domain B) | next |
| `POST /api/v1/sessions/run` (orchestrator, what iOS calls) | next |

Speech-to-text happens on the phone, so the backend only receives text and
there is no audio upload endpoint.

## Scripts

`npm test` · `npm run typecheck` · `npm run build` · `npm start`
