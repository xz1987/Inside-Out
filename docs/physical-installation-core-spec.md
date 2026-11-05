# Physical Installation Integration — Core Specification

Status: product decisions frozen; software/firmware Sets 0–6 implemented
Last updated: 2026-10-31

This document is the source of truth for connecting the iPhone app to the
physical eight-pump installation. The eight-Figure contracts/UI, Direct
Interpretation path, local actuation policy/settings, iOS BLE foundation, and
eight-channel Arduino overlay are implemented. Physical board/pump validation
and app-to-board integration remain future Set 7 work.

Implementation work and evidence are tracked in
[`physical-installation-task-sets.md`](physical-installation-task-sets.md).

## 1. Experience boundary

- One physical iPhone.
- One foreground iOS app.
- One installation.
- One participant at a time.
- The operator completes physical setup before starting the app experience.
- After setup, a valid interpretation triggers the installation immediately;
  there is no per-event confirmation or reset reminder.
- Figure growth, relationships, memories, and ecosystem state remain in the
  app. The installation responds only to the current event's Figure Feed.

## 2. Emotion taxonomy and app channel order

The following order is stable across the model schema, Swift domain model,
installation command, tests, and UI accessibility labels.

| App channel | Internal ID | UI label | Color | Medium |
|---:|---|---|---|---|
| 0 | `anger` | Angry | red | air |
| 1 | `joy` | Joy | yellow | water |
| 2 | `anxiety` | Anxiety | orange | air |
| 3 | `sadness` | Sadness | blue | water |
| 4 | `disgust` | Disgusted | green | water |
| 5 | `fear` | Fear | purple | water |
| 6 | `embarrassment` | Embarrassed | pink | air |
| 7 | `boredom` | Bored | white | air |

Use noun-form internal IDs for stable code and contract values. UI copy may use
the adjective labels above.

## 3. Model interpretation rules

- Input remains retrospective voice or message text.
- Speech-to-text remains on the iPhone; audio is not uploaded.
- One interpretation returns between one and four participating emotions.
- Results are ordered by strongest Feed first.
- The direct iOS client reuses the existing Interpretation domain prompt and
  response semantics.
- The iOS app does not call the Ecosystem model/domain for the installation
  path.
- Relationship updates are computed and stored in the app for every pair of
  Figures participating in the event.
- Invalid, unrecognized, timed-out, or local keyword fallback results never
  actuate hardware.

The direct API key is supplied through ignored local Xcode configuration. No
secret or real key may be committed. This prevents accidental Git exposure but
does not make a key embedded in an installed demo app secret; use a dedicated,
limited, revocable installation key.

## 4. Actuation semantics

The installation is fill-only. Commands therefore represent increments, not
absolute target levels.

Default normalized settings:

| Setting | Default | Meaning |
|---|---:|---|
| Minimum change | 5 | Smallest non-zero delta sent for a participating Figure |
| Maximum change per event | 25 | Largest delta sent to one channel for one event |
| Air interpretation total | 100 | App-side cumulative cap for each air channel; configurable to 500 |
| Water interpretation total | 100 | App-side cumulative cap for each water channel; configurable to 600 |

Rules:

1. Convert each valid Figure Feed into a normalized `0...100` delta.
2. A participating Figure is clamped to the configured minimum and per-event
   maximum.
3. Clamp again against that channel's remaining air/water interpretation
   capacity.
4. Send all eight channel values in one command; zero means no change.
5. Multiple non-zero channels may run concurrently.
6. Send only while Installation Mode is active and BLE state is `ready`.
7. If hardware is disconnected, update the app ecosystem but do not queue,
   replay, or send the missed physical command after reconnection.
8. A new installation session resets app-side totals. Hardware remains the
   final authority for its own cumulative run limits.
9. Manual Test uses a separate BLE operation. It has a safe per-tap duration
   but no cumulative test limit and does not consume interpretation totals.

## 5. Legacy-preserving pump and pin map

The original four pump assignments stay unchanged. Four pumps are appended.

| Physical slot | Code | Emotion | Medium | Pin | Output mode | Origin |
|---:|---|---|---|---:|---|---|
| 0 | `A` | Angry | air | D3 | PWM | existing |
| 1 | `W` | Sadness | water | D5 | full on/off | existing |
| 2 | `B` | Bored | air | D9 | PWM | existing pin/pump; reassigned emotion |
| 3 | `X` | Disgusted | water | D10 | full on/off | existing |
| 4 | `C` | Anxiety | air | D6 | PWM | appended |
| 5 | `Y` | Fear | water | D2 | full on/off | appended |
| 6 | `D` | Embarrassed | air | D11 | PWM | appended |
| 7 | `Z` | Joy | water | D4 | full on/off | appended pin/pump; reassigned emotion |

The existing and new pumps of each medium use the same model and initial
calibration values. Air pumps inherit the current air-pump duty and timing;
water pumps inherit the current water-pump duty and timing. Per-channel
calibration can be added later without changing the map.

Do not assume app channel order equals physical array order. The BLE/Arduino
adapter owns this mapping:

```text
app [anger, joy, anxiety, sadness, disgust, fear, embarrassment, boredom]
 -> [A, Z, C, W, X, Y, D, B]
 -> pins [D3, D4, D6, D5, D10, D2, D11, D9]
```

The checked-in four-channel reference sketch is preserved at
`hardware/arduino/reference/emotion_pumps_4ch_1.ino`.

## 6. BLE software boundary

The final byte layout and UUID values may be reconciled with the hardware code,
but the app implementation must expose these stable concepts:

- `BalloonLinkProtocol` so UI/domain code is independent of CoreBluetooth.
- `MockBalloonLink` for simulator and automated testing.
- `CoreBluetoothBalloonLink` for a physical iPhone.
- One peripheral connection at a time.
- Scan by service UUID, not display name alone.
- Command characteristic uses write-with-response.
- Status characteristic uses notifications.
- Versioned command format.
- Monotonic sequence ID and matching acknowledgement.
- One command carries eight deltas so simultaneous pumps start from one event.
- Disconnect immediately changes state away from `ready`; no commands are
  accepted or retained in that state.
- The Arduino stops current queued motion on BLE disconnect.

The preserved hardware reference remains USB Serial only. The derived
`hardware/arduino/emotion_pumps_8ch_ble/` sketch implements BLE without
overwriting that baseline.

## 7. Installation settings in the app

Provide an Installation Settings screen with:

- Installation Mode on/off.
- BLE availability and connection state.
- Connected peripheral name.
- Minimum Change, default 5.
- Maximum Change Per Event, default 25.
- Maximum Session Total, default 100.
- Allow Concurrent Pumps, default on.
- Auto Connect while the app is foreground, default on.
- Read-only per-emotion session totals.
- Start New Session.
- Stop Current Pumps.
- Per-channel test using the configured minimum.
- Mock Hardware in Debug builds only.
- Interpretation configuration readiness without revealing the key.

Settings use normalized units. Hardware-specific milliseconds and duty values
remain in the installation adapter/Arduino layer.

## 8. Visual direction

The user-provided reference screenshot establishes visual language, not literal
composition:

- tactile fuzzy/yarn/fiber Figures;
- expressive eyes and emotion-specific posture;
- transparent acrylic/glass enclosure language;
- saturated cobalt-blue environment;
- pink and orange edge lighting;
- tangled or braided relationship threads;
- dimensional shadows rather than flat emoji styling.

SwiftUI owns layout, glass, lighting, state, and animation. Figure artwork may
use transparent image assets. The white Bored Figure must retain a cool-gray or
blue outline/shadow for contrast and accessibility.

## 9. Current-to-target architecture

```text
Current
iPhone Speech -> RemoteEventInterpreter -> local Node session endpoint
             -> Interpretation domain + Ecosystem domain
             -> four-Figure app result

Target installation mode
iPhone Speech -> DirectEventInterpreter -> Interpretation domain only
             -> 1...4 of eight Figures
             -> local relationship/ecosystem update
             -> ActuationPolicy
             -> BalloonLinkProtocol
             -> BLE eight-delta command
             -> Arduino UNO R4 WiFi
```

The existing Node backend remains in the repository for development and prior
flows. Installation Mode must not require it.

## 10. Out of scope until later hardware detail

- Final electrical driver and power design.
- Pressure, flow, or liquid-level sensors.
- Active deflation or water return.
- Final per-channel calibration.
- Mechanical emergency-stop design.
- Background Bluetooth operation.
- Multiple iPhones or multiple participants at once.
