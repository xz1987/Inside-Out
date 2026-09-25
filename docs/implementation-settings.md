# Current implementation settings

## Implemented scope

1. The user records or writes about one daily event.
2. Voice is recorded locally with AVFoundation and transcribed on the phone with
   Apple Speech; audio is never uploaded to the backend.
3. The interpreter selects the Figures to feed, assigns Feed and concentration,
   and promotes the relevant relationships.
4. The result explains why each Figure participated.

## Voice input

- Tap the home microphone to start recording.
- The Listening screen shows real elapsed time and partial transcription.
- The main microphone and the explicit control pause/resume recording.
- “Delete & re-record” discards the local temporary file and starts over.
- “Done” is enabled after 5 seconds of accumulated recorded time, then performs
  a final transcription before sending text to the existing session endpoint.
- Microphone and Speech Recognition permissions are declared in generated
  `Info.plist` settings.

The Simulator can verify build, launch, and UI states, but microphone input and
Speech authorization require final validation on a signed physical iPhone. For
development, Simulator builds allow Apple Speech's hosted recognition because
the Simulator may not contain usable on-device speech assets; signed iPhone
builds still require on-device recognition whenever the device supports it.

## Current interpretation mode

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

- Replay
- Transformation
- Raid
- Memory masking
- Long-term persistence
