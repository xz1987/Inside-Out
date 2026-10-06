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

## Interpretation mode

The iOS app sends only transcript text and the ecosystem snapshot to the local
Node backend. The backend uses the two domain keys below and returns the model
interpretation. If the backend cannot be reached, `LocalEventInterpreter`
provides a deterministic English/Chinese keyword fallback and the result page
labels it as an offline guess.

## API boundary and physical iPhone setup

The two keys are stored only in `apps/api/.env`:

- `INPUT_DOMAIN_API_KEY`
- `ECOSYSTEM_DOMAIN_API_KEY`

The iOS app calls one backend origin. The backend—not the iPhone—calls the two
AI domains.

For Simulator, `Config/Debug.xcconfig` defaults to
`http://localhost:3000`. For a physical iPhone:

1. Duplicate `apps/ios/Config/Local.xcconfig.example` as
   `apps/ios/Config/Local.xcconfig`.
2. Set `API_BASE_URL = http:/$()/your-mac-name.local:3000`, or use an HTTPS
   tunnel/staging URL. `Local.xcconfig` is ignored by Git.
3. Run `npm run dev` in `apps/api`; it listens on `0.0.0.0` so the phone can
   reach the Mac.
4. Run the Debug app from Xcode and allow its Local Network permission.

If the Mac and iPhone are on campus/guest Wi-Fi and `.local` fails, the network
is probably isolating peers; use an HTTPS tunnel or a different local network.

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
- Blank-only input is rejected; there is no minimum character count
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
