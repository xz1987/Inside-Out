# Contracts

Versioned JSON Schemas shared by the backend and the iOS app (PRD §41, §43.1).

| Schema | Produced by | Consumed by |
|---|---|---|
| `event-interpretation.v1` | Domain A (Input Interpreter) | Domain B, iOS |
| `ecosystem-snapshot.v1` | iOS (current Figure state) | Domain B |
| `ecosystem-resolution.v1` | Domain B (Ecosystem Director) | iOS Screens 3–5 |
| `client-session-response.v1` | `POST /api/v1/sessions/run` | iOS |

Rules:
- Every object is `additionalProperties: false` with all properties required,
  so the schemas can be sent to the LLM as strict structured-output schemas.
- Rules JSON Schema can't express (concentrations sum to 1, attacker ≠ victim,
  arithmetic) live in `apps/api/src/contracts/validate.ts`.
- `promotedRelationships` has one entry per pair of Figures that took part in the
  event together — 0 for a lone Figure, 1 for two, 3 for three. Bonds only grow
  between Figures that were in the same event. (Changed in place while v1 is
  unreleased; earlier drafts had a single `promotedRelationship`.)
- `exp` and `energy` are integers 0–100 on the wire. The iOS app currently stores
  energy as 0–1 and converts at the boundary.
- A schema change needs its own PR, updated fixtures, and a bumped version for
  breaking changes.

`fixtures/*.valid.json` mirror the iOS seed data and are checked by `apps/api` tests.
