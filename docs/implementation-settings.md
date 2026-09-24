# Current implementation settings

## Implemented scope

1. The user writes about one daily event.
2. The local MVP interpreter selects two Figures to feed.
3. It assigns Feed amount and concentration.
4. It promotes one relationship between those Figures.
5. The result explains why each Figure participated.

## Current mode

`LocalEventInterpreter` is intentionally deterministic and runs without an API
key. It recognizes a small English/Chinese keyword set for Joy, Sadness, Anger,
and Fear. This is a functional UI fallback, not a psychological assessment.

## Future API boundary

The two future keys are stored only in `apps/api/.env`:

- `INPUT_DOMAIN_API_KEY`
- `ECOSYSTEM_DOMAIN_API_KEY`

The iOS app will call one backend origin. The backend—not the iPhone—will call
the two AI domains. See the full PRD for the versioned schema and merge plan.

## Xcode target

- Project: `apps/ios/InsideOutApp.xcodeproj`
- Target: `InsideOutApp`
- Platform: iPhone
- Deployment target: iOS 17+
- Bundle identifier placeholder: `com.yourteam.InsideOutMVP`
- Signing: Automatic; choose a Development Team in Xcode

## Current screens

### Input state

- Prompt: “Talk about a daily event”
- Multi-line message input
- Minimum 15 characters
- Loading and error states

### Interpretation state

- Event summary
- Two Figure Feed cards
- Feed amount
- Emotion concentration
- Evidence explanation
- One promoted relationship
- Start-over action

## Not implemented yet

- Voice recording
- Backend server
- Live model calls
- Replay
- Transformation
- Raid
- Memory masking
- Long-term persistence

