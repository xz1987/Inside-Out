# Inside Out — Daily Event MVP

This repository contains the smallest iPhone prototype for the retrospective
emotion-Figure concept.

## Current experience

1. Enter one daily event.
2. Let the local prototype interpreter analyze it.
3. See which Figures receive Feed.
4. See which Figure relationship is promoted.

## Open in Xcode

Open:

```text
apps/ios/InsideOutApp.xcodeproj
```

Then:

1. Select the `InsideOutApp` target.
2. Open Signing & Capabilities.
3. Choose your Development Team.
4. Replace `com.yourteam.InsideOutMVP` with a unique bundle identifier if
   Xcode requests it.
5. Select an iPhone simulator or connected iPhone.
6. Choose Product → Run.

The current machine used to scaffold the repository only has Apple Command Line
Tools selected, so the project has not yet been compiled with a full iOS SDK.

## API keys later

Two blank server-side variables are ready in `apps/api/.env`:

```dotenv
INPUT_DOMAIN_API_KEY=
ECOSYSTEM_DOMAIN_API_KEY=
```

The local `.env` is ignored by Git. Do not put these keys into the Xcode app.

## Documentation

- `docs/retrospective-memory-ios-prd.md`
- `docs/implementation-settings.md`

