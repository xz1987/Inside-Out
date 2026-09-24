# API configuration placeholder

The current MVP runs its event interpretation locally in the iOS app so the
first two screens work before credentials exist.

Two server-side environment variables are reserved for the next integration:

```dotenv
INPUT_DOMAIN_API_KEY=
ECOSYSTEM_DOMAIN_API_KEY=
```

- `INPUT_DOMAIN_API_KEY` will interpret a new daily event or replay into a
  stable event structure and Figure feed recommendation.
- `ECOSYSTEM_DOMAIN_API_KEY` will consume that structure and determine
  relationship promotion and future ecosystem interactions.

Fill the ignored local `apps/api/.env` later. Keep `.env.example` blank and
committed. Never copy either key into Swift, an `.xcconfig`, `Info.plist`, or an
installed iPhone app.

