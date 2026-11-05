# Physical Installation Integration — Task Sets

Status: Sets 0–6 implemented; physical-device and hardware bench checks pending
Last updated: 2026-10-31

Source of truth for product and protocol decisions:
[`physical-installation-core-spec.md`](physical-installation-core-spec.md).

Use these status markers:

- `[ ]` not started
- `[~]` partial/in progress
- `[x]` completed and verified
- `[-]` intentionally excluded, with reason

Work one set at a time unless a later set is needed only for a small compile
stub. After every set, update its Evidence block and the Execution Log at the
end of this file. Also append a dated summary to the repository `sprint.md`.

## Set 0 — Freeze decisions and preserve hardware baseline

- [x] Record the eight-emotion taxonomy, colors, media, and app channel order.
- [x] Record the legacy-preserving eight-pump pin map.
- [x] Record direct Interpretation-only architecture and local ecosystem scope.
- [x] Record fill-only delta semantics and configurable defaults.
- [x] Preserve the supplied four-channel Arduino sketch in the repository.
- [x] Create staged task sets and repository documentation entry points.

Acceptance:

- Another developer can identify what is already implemented versus target
  behavior without opening the conversation history.
- No API key or secret is committed.
- The original four pump/pin assignments are unchanged in the reference copy.

Evidence:

- `docs/physical-installation-core-spec.md`
- `docs/physical-installation-task-sets.md`
- `hardware/arduino/reference/emotion_pumps_4ch_1.ino`

## Set 1 — Eight-emotion contracts and domain model

- [x] Expand Swift `FigureKind` to the eight frozen internal IDs.
- [x] Add display names, colors, symbols, media, and stable app channel indices.
- [x] Expand seed Figure state, memories, relationships, and local keyword
  interpreter without inventing unsupported model output.
- [x] Update shared JSON schema/fixtures to permit 1...4 unique emotions.
- [x] Update relationship validation for all participating pairs: 0, 1, 3, or
  6 relationships for 1, 2, 3, or 4 participating Figures.
- [x] Update TypeScript domain types and validation so old four-emotion-only
  assumptions cannot silently pass.
- [x] Add contract tests for all eight emotions, four-emotion maximum, duplicate
  rejection, ordering, and invalid emotion rejection.
- [x] Keep current four-Figure UI compiling through temporary generic layouts
  if visual work is deferred to Set 4.

Acceptance:

- Contracts and iOS models agree on exact raw values and order.
- A valid four-emotion response decodes; a fifth emotion fails validation.
- Existing backend tests and iOS build pass.

Evidence to record:

- Commit: working tree (not committed)
- Contract test command/result: `npm test -- --run` → 84/84 passed;
  `npm run typecheck` → passed.
- Xcode build command/result: generic iOS Simulator Debug build →
  `BUILD SUCCEEDED`; XCTest target build → `TEST BUILD SUCCEEDED`.

## Set 2 — Direct Interpretation client on iPhone

- [x] Add ignored local configuration placeholders for direct Interpretation
  base URL, model, and API key; never add a real key.
- [x] Implement a dedicated `DirectEventInterpreter` using the existing
  Interpretation prompt/semantics and the updated strict response schema.
- [x] Do not invoke the Ecosystem domain from the direct installation path.
- [x] Convert model relationship cues into local pair updates in the app.
- [x] Preserve the existing backend interpreter as a selectable development
  path until direct mode is verified.
- [x] Ensure request/response/error logs never contain the API key or full
  participant transcript.
- [x] Treat timeout, malformed output, missing key, and keyword fallback as
  non-actuating results.
- [x] Add decoder, request-construction, redaction, and failure tests using a
  mocked URL session; tests must not spend real quota.
- [~] Validate one explicit physical-iPhone request with the dedicated demo key.
  The direct path builds and mocked transport passes; no key is present in the
  gitignored local config, so this quota-spending check remains for the owner.

Acceptance:

- A physical iPhone can interpret text without the local Node server.
- The returned result contains 1...4 valid Figures.
- Ecosystem state updates locally; no Ecosystem API request occurs.
- No secret exists in tracked files or build logs.

Evidence to record:

- Commit: working tree (not committed)
- Mock test result: 10/10 XCTest passed, including strict request construction,
  mocked decode, timeout/malformed response, four-Figure/six-pair output, and
  fifth-Figure rejection.
- Physical iPhone result: pending owner-provided local demo key.
- Secret scan result: no real API key found in tracked files; only documented
  placeholders/examples.

## Set 3 — Installation settings and actuation policy

- [x] Add `InstallationSettings` persisted locally with defaults 5 / 25 / 100.
- [x] Add Installation Mode and foreground-only Auto Connect settings.
- [x] Implement pure `ActuationPolicy` converting up to four Figure Feeds into
  an eight-value normalized delta command.
- [x] Clamp participating values to minimum, per-event maximum, and remaining
  per-channel session capacity.
- [x] Support multiple non-zero deltas in one command.
- [x] Track eight session totals independently.
- [x] Start a new software session after setup without presenting a physical
  reset reminder.
- [x] Never retain a command produced while BLE is not ready.
- [x] Add unit tests for min/max clamping, capacity exhaustion, four concurrent
  channels, zero values, and disconnected gating.

Acceptance:

- The policy has no CoreBluetooth dependency and is fully unit-testable.
- The same Feed and settings always produce the same eight deltas.
- Disconnect/reconnect cannot replay an older event.

Evidence to record:

- Commit: working tree (not committed)
- Unit test result: included in the 10/10 passing XCTest suite.
- Settings persistence check: isolated `UserDefaults` suite round-trip passed.

## Set 4 — Eight-Figure SwiftUI and visual system

- [x] Extend design tokens for the eight frozen colors and accessibility
  contrast, especially the white Bored Figure.
- [x] Create/revise Figure assets in the approved fuzzy fiber/yarn language.
- [x] Preserve transparent acrylic, cobalt-blue environment, and pink/orange
  edge-lighting cues without copying the screenshot composition literally.
- [x] Make Figure overview support eight Figures.
- [x] Make interpretation result support one, two, three, or four participating
  Figures without clipping.
- [x] Make relationship display support up to six pairs for four Figures.
- [x] Add Installation Settings UI and BLE status presentation.
- [x] Add accessibility labels and Reduce Motion behavior for new Figures and
  installation controls.
- [~] Verify relevant screens at multiple iPhone sizes and Dynamic Type sizes.
  iPhone 17e at standard and Accessibility XXXL passed without clipping; the
  second simulator became unstable during installation, so a second-device
  screenshot remains a visual QA follow-up rather than a code blocker.

Acceptance:

- All eight Figures are visually distinct without relying on color alone.
- A four-Figure result remains legible on the smallest supported iPhone.
- Settings can be changed without exposing the direct API key.

Evidence to record:

- Commit: working tree (not committed)
- Simulator/device screenshots: `design/installation/set4-home-iphone17e.png`
  and `design/installation/set4-home-accessibility-xxxl.png`.
- Accessibility/Reduce Motion notes: every Figure has a non-color face/symbol
  identity and label; `Ticker` pauses at a deterministic frame when Reduce
  Motion is enabled; controls use native labels. Accessibility XXXL inspected.

## Set 5 — BLE abstraction, mock hardware, and stable state machine

- [x] Define `BalloonLinkProtocol`, connection states, command, status, and
  error types independent of CoreBluetooth.
- [x] Implement `MockBalloonLink` for simulator UI and deterministic tests.
- [x] Implement `CoreBluetoothBalloonLink` for one peripheral at a time.
- [x] Add Bluetooth usage description and foreground-only lifecycle handling.
- [x] Scan by service UUID and subscribe to status notifications.
- [x] Use write-with-response, protocol version, sequence ID, matching ACK,
  timeout, and at most one retry.
- [x] Reject commands unless state is `ready`.
- [x] Drop an unacknowledged event after retry; never replay it after reconnect.
- [x] Expose Stop Current Pumps and per-channel minimum test commands.
- [x] Keep UUIDs and byte encoding in one codec/configuration boundary so they
  can be reconciled with the final Arduino sketch without domain/UI changes.

Acceptance:

- Mock mode demonstrates connected, sending, acknowledged, timeout, fault, and
  disconnect states.
- CoreBluetooth code builds for a generic physical iOS device.
- No BLE code is required by model, relationship, or memory logic.

Evidence to record:

- Commit: working tree (not committed)
- BLE codec tests: command/status round trips, corrupted checksum rejection,
  matching sequence enforcement, Stop packet, and all eight-channel test packet
  semantics are included in the 19/19 passing XCTest suite.
- Mock state-machine walkthrough: deterministic scanning → connecting → ready,
  ACK, reject/fault, timeout with exactly one retry, and disconnect/no-replay
  cases passed on the iPhone 17 simulator.
- Generic-device build result: unsigned Debug build for
  `generic/platform=iOS` → `BUILD SUCCEEDED`.
- Protocol handoff: `docs/ble-protocol-v1.md`.

## Set 6 — Eight-channel Arduino overlay and ArduinoBLE peripheral

- [x] Create an eight-channel sketch derived from the preserved four-channel
  baseline; do not overwrite the reference file.
- [x] Keep A/D3, W/D5, B/D9, and X/D10 unchanged.
- [x] Append C/D6, Y/D2, D/D11, and Z/D4.
- [x] Use PWM for the four air pumps and full digital on/off for water pumps.
- [x] Reuse existing air settings for new air pumps and existing water settings
  for new water pumps.
- [x] Preserve non-blocking simultaneous pump operation.
- [x] Fix total-runtime accounting so one loop tick cannot overshoot remaining
  `MAX_TOTAL`.
- [x] Add ArduinoBLE peripheral service, command characteristic, and status/ACK
  notifications matching Set 5.
- [x] Map app channel order to physical pump order explicitly.
- [x] Stop and clear queued pump time immediately on BLE disconnect or STOP.
- [x] Retain Serial debug/test commands for bench work where practical.
- [x] Compile for Arduino UNO R4 WiFi and record board package/library versions.

Acceptance:

- Original four physical connections still respond to their original tests.
- Four appended channels respond to their new tests.
- One command can run any combination of up to eight channels concurrently.
- Disconnect and STOP turn all outputs off and clear queued time.

Evidence to record:

- Commit: working tree (not committed)
- Arduino compile result/version: `arduino-cli` 1.5.1,
  `arduino:renesas_uno:unor4wifi` core 1.6.0, ArduinoBLE 2.1.0 → compile
  passed; 88,620 bytes flash (33%), 9,692 bytes RAM (29%). Warnings are in
  official library/core sources, not the sketch.
- Bench test matrix: recorded in
  `hardware/arduino/emotion_pumps_8ch_ble/README.md`; pending because no UNO R4
  or pumps were connected to this Mac.
- BLE scanner result: pending physical board upload; `arduino-cli board list`
  found no connected UNO R4 during this run.

## Set 7 — App-to-board integration

- [ ] Reconcile final service UUIDs, characteristics, packet bytes, and ACK
  status between Swift and Arduino codec implementations.
- [ ] Connect a physical iPhone to the UNO R4 WiFi.
- [ ] Test each emotion through the App's per-channel test control.
- [ ] Test one event with one emotion and one event with four emotions.
- [ ] Confirm an event triggers immediately after valid interpretation and ACK.
- [ ] Confirm no command is sent when disconnected and no missed command is
  replayed after reconnect.
- [ ] Confirm session totals and Arduino totals remain coherent through normal
  use, STOP, reconnect, and new-session setup.
- [ ] Confirm direct Interpretation works without the Node backend running.
- [ ] Run a repeated-event soak test before attaching the final installation.

Acceptance:

- Voice/message -> direct interpretation -> app state -> BLE -> expected pump
  channels completes on a physical iPhone.
- Four pumps can start from one event without blocking app interaction.
- Failure states are visible and do not create delayed actuation.

Evidence to record:

- Commit:
- Device/board versions:
- End-to-end cases and outcomes:
- Soak-test count/result:

## Set 8 — Calibration, documentation, and handoff

- [ ] Calibrate air and water milliseconds per normalized unit using the final
  installation and record values per channel.
- [ ] Revisit default 5 / 25 / 100 only after measured trials.
- [ ] Document operator setup, start, stop, reconnect, and recovery procedures.
- [ ] Update `implementation-settings.md` from target language to verified
  current behavior.
- [ ] Update README run instructions for Direct Interpretation and BLE.
- [ ] Remove temporary mocks from non-Debug builds.
- [ ] Run iOS build/tests, backend regression tests, Arduino compile, and final
  physical walkthrough.
- [ ] Record known limitations and deferred hardware/safety work.

Acceptance:

- A collaborator can clone the repository, add only their local key/signing,
  flash the documented board sketch, and reproduce the installation flow.
- Documentation matches verified code and hardware behavior.

Evidence to record:

- Commit:
- Calibration table:
- Final test commands/results:
- Known limitations:

## Execution Log

Append one row after each completed or partial set.

| Date | Set | Status | Commit/branch | Verification and notes |
|---|---:|---|---|---|
| 2026-10-29 | 0 | complete | working tree | Core spec, task sets, and four-channel hardware baseline recorded |
| 2026-10-30 | 1 | complete | working tree | Eight-emotion Swift/TypeScript/contracts implemented; 84 backend tests, typecheck, and iOS build passed |
| 2026-10-30 | 2 | implementation complete; device-key check pending | working tree | Direct Interpretation client and local relationships implemented; mocked request/decode/failure tests passed; no local demo key available |
| 2026-10-30 | 3 | complete | working tree | Persisted 5/25/100 settings and pure eight-channel fill policy implemented; persistence/policy XCTest passed |
| 2026-10-30 | 4 | implementation complete; second-size QA pending | working tree | Eight fuzzy Figures, 1–4 result layout, six bonds, settings UI, accessibility and Reduce Motion implemented; iPhone 17e standard + Accessibility XXXL inspected |
| 2026-10-31 | 5 | complete | working tree | BLE abstraction, CoreBluetooth + Mock transports, sequence/ACK/retry state machine, foreground lifecycle, Stop/test controls, and protocol doc implemented; generic iOS build + 19/19 XCTest passed |
| 2026-10-31 | 6 | implementation complete; physical bench pending | working tree | Preserved four pins, appended four channels, ArduinoBLE v1 protocol, duplicate-sequence safety, non-blocking simultaneous pumping, STOP/disconnect safety, and serial tests implemented; UNO R4 WiFi compile passed with core 1.6.0 + ArduinoBLE 2.1.0 |
