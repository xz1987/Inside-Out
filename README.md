# Inside Out — Daily Event MVP

This repository contains the smallest iPhone prototype for the retrospective
emotion-Figure concept.

## Current experience

1. Enter one daily event.
2. Let Direct Interpretation or the development backend analyze it.
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

The project is verified with the full iOS SDK. The generic iOS Simulator Debug
build and the `InsideOutAppTests` target both compile successfully; the current
foundation test suite has 19 passing tests.

## API key setup

Two blank server-side variables are ready in `apps/api/.env`:

```dotenv
INPUT_DOMAIN_API_KEY=
ECOSYSTEM_DOMAIN_API_KEY=
```

The local `.env` is ignored by Git. These keys support the existing development
backend flow and do not belong in tracked Xcode files.

For the physical-installation path, copy
`apps/ios/Config/Local.xcconfig.example` to the ignored `Local.xcconfig` and add
a dedicated, limited, revocable Interpretation key there. The app calls only
the Interpretation model in this mode; relationships and ecosystem state are
resolved locally. Never commit `Local.xcconfig` or a real key.

## Documentation

- `docs/retrospective-memory-ios-prd.md`
- `docs/implementation-settings.md`
- `docs/physical-installation-core-spec.md` — frozen eight-emotion installation decisions
- `docs/physical-installation-task-sets.md` — staged implementation tracker and evidence log
- `docs/ble-protocol-v1.md` — iOS/Arduino UUID, packet, ACK, retry, and lifecycle boundary

Physical-installation Sets 0–6 are implemented: eight-emotion contracts, Direct
Interpretation, local actuation policy/settings, the eight-Figure UI, and the
iOS BLE/Mock transport foundation plus the compiled eight-channel UNO R4 WiFi
firmware. A
real-key physical-iPhone request and one additional device-size visual check
remain owner QA. Physical pump bench testing and iPhone-to-board integration
remain Set 7; no hardware pass is claimed without a connected board.

