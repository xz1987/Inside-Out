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
| `POST /api/v1/events/interpret` (Domain A) | done |
| `POST /api/v1/ecosystem/resolve` (Domain B) | done |
| `POST /api/v1/sessions/run` (orchestrator, what iOS calls) | done |

Speech-to-text happens on the phone, so the backend only receives text and
there is no audio upload endpoint.

## Domain A — `POST /api/v1/events/interpret`

```json
// request
{ "inputType": "voice", "text": "So on my way home…", "importance": 0.7 }
// 200
{ "schemaVersion": "event-interpretation.v1", "interpretation": { … }, "fallback": false,
  "promptVersion": "input-v1", "traceId": "…" }
```

- `text` is 15–4000 characters (already transcribed on the phone).
- No key configured → keyword fallback (same logic as the iOS app), `fallback: true`.
- Model output breaks the contract → one corrective retry, then `502 analysis_unavailable`.
- Timeout / network / 5xx → `503 analysis_timeout` with `retryable: true`.
- Logs never include the user's text.

Prompt: `src/domains/input/prompts/input-v1.ts`. Bump the version on any behaviour change.
`npm run try:input` runs it against the real gateway on sample memories
(`npm run try:input -- "your text"` for your own).

## Domain B — `POST /api/v1/ecosystem/resolve`

Body: `{ interpretation, snapshot }` (both validated). Returns
`{ resolution: EcosystemResolutionV1, fallback, promptVersion, traceId }`.

The staged MVP outcome is decided in code (`src/domains/ecosystem/scenario.ts`),
so the same inputs always give the same story:

- **Evolves**: the most-fed Figure, staged to start `feed` short of 100 EXP.
- **Bond**: Domain A's cue for the top two Figures (delta ≈ combined feed / 4, min 4);
  a lone Figure reuses its strongest existing bond (+4, "Existing memory connection").
- **Raid target**: a visible seed memory not owned by the evolved Figure — prefer
  a Figure that sat the event out, then the highest level. Always succeeds.
- **Aftermath**: victim to Level 1, memory masked.

The LLM (`ecosystem-mvp-v1`) only rewrites the bond reason and the three-step
explanation, and only sees the summary — never the raw memory text. Any LLM
problem falls back to template wording with `fallback: true`; no raidable memory
→ `422 scenario_unavailable`.

## Orchestrator — `POST /api/v1/sessions/run` (what iOS calls)

Body: `{ inputType, text, importance?, snapshot, sessionId? }`. Runs Domain A →
validate → Domain B → validate and returns `ClientSessionResponseV1` with
`fallback: { interpretation, resolution }`. If Domain A fails (503/502), Domain B
is not called. Typical latency on the Cornell gateway: A ≈ 3–8 s, B ≈ 2 s.

## Scripts

`npm test` · `npm run typecheck` · `npm run build` · `npm start` · `npm run smoke:llm` · `npm run try:input`
