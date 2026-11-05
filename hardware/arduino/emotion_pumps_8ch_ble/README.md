# Eight-channel BLE pump controller

Target: Arduino UNO R4 WiFi
Sketch: `emotion_pumps_8ch_ble.ino`

The sketch preserves the supplied four-channel baseline and adds four pumps.
It implements the protocol in `docs/ble-protocol-v1.md`.

## Verified toolchain

- Arduino CLI: 1.5.1
- FQBN: `arduino:renesas_uno:unor4wifi`
- Arduino UNO R4 Boards core: 1.6.0
- ArduinoBLE: 2.1.0
- UNO R4 WiFi ESP32-S3 connectivity firmware requirement: 0.2.0 or later

Compile from the repository root:

```sh
arduino-cli compile \
  --fqbn arduino:renesas_uno:unor4wifi \
  --build-path /private/tmp/insideout-arduino-build \
  hardware/arduino/emotion_pumps_8ch_ble
```

Verified result: 88,772 bytes program storage (33%) and 9,732 bytes dynamic
memory (29%). Warnings emitted with `--warnings all` originate in the official
ArduinoBLE/core sources; the sketch compiles without its own warning.

## Wiring map

GPIO pins drive external motor-driver inputs, not pumps directly.

| Code | Emotion | Medium | Pin | Output |
|---|---|---|---:|---|
| A | Anger | air | D3 | PWM 200/255 |
| W | Sadness | water | D5 | digital on/off |
| B | Bored | air | D9 | PWM 200/255 |
| X | Disgusted | water | D10 | digital on/off |
| C | Anxiety | air | D6 | PWM 200/255 |
| Y | Fear | water | D2 | digital on/off |
| D | Embarrassed | air | D11 | PWM 200/255 |
| Z | Joy | water | D4 | digital on/off |

App order is explicitly adapted to physical order:

```text
[anger, joy, anxiety, sadness, disgust, fear, embarrassment, boredom]
 -> [A, Z, C, W, X, Y, D, B]
```

## Serial bench commands

Use 9600 baud with newline:

- `TA`, `TW`, `TB`, `TX`, `TC`, `TY`, `TD`, `TZ`: queue one channel for up to two seconds.
- `A20,W10,B20,X10,C20,Y10,D20,Z10`: queue any combination concurrently.
- `STOP`: immediately turn every output off and clear all queues.
- `RESET`: STOP plus reset cumulative limits.
- `STATUS`: print all queue and cumulative times.

Serial `T*` and App Hardware Control tests use the unlimited cumulative test
queue. Each individual pulse remains bounded by `MAX_QUEUE`; tests do not
consume or stop at the interpreted-fill `MAX_TOTAL`.

## Physical bench matrix

No UNO R4 was connected during the implementation run, so these rows are the
required physical acceptance matrix, not claimed pass results.

| Channel | Test | Expected | Current result |
|---|---|---|---|
| A / Anger / D3 | `TA` | Only legacy air pump A runs with PWM | Pending board |
| W / Sadness / D5 | `TW` | Only legacy water pump W switches fully on | Pending board |
| B / Boredom / D9 | `TB` | Only legacy air pump B runs with PWM | Pending board |
| X / Disgust / D10 | `TX` | Only legacy water pump X switches fully on | Pending board |
| C / Anxiety / D6 | `TC` | Only appended air pump C runs with PWM | Pending board |
| Y / Fear / D2 | `TY` | Only appended water pump Y switches fully on | Pending board |
| D / Embarrassment / D11 | `TD` | Only appended air pump D runs with PWM | Pending board |
| Z / Joy / D4 | `TZ` | Only appended water pump Z switches fully on | Pending board |
| All eight | `A5,W5,B5,X5,C5,Y5,D5,Z5` | Eight queues begin concurrently | Pending board |
| Safety | `STOP` during the prior command | All outputs turn off and queues become zero | Pending board |
| BLE safety | Disconnect iPhone while pumps run | All outputs turn off and queues become zero | Pending board |

## Safety boundary

- Use a suitable external supply, driver/transistor stage, flyback protection,
  and common ground. Arduino GPIO cannot power pumps directly.
- The current timing and duty values are inherited starting points, not final
  liquid/pressure calibration.
- Disconnect and STOP clear queued work and turn every output off.
- Hardware cumulative limits remain authoritative even when the app starts a
  new software session.
