# Balloon BLE Protocol v1 — iOS Foundation

Status: implemented by iOS Set 5 and Arduino Set 6; physical integration pending
Last updated: 2026-10-31

This document is the handoff boundary between the iPhone app and the Arduino
UNO R4 WiFi sketch. UUIDs and byte encoding are implemented on both sides and
the Set 6 sketch is compile-verified. They remain subject to Set 7 physical
iPhone/board validation; domain and UI code do not depend on them.

## GATT configuration

| Role | UUID | Behavior |
|---|---|---|
| Service | `FEE7D000-6A7A-4F3D-9E31-1A51D8E10000` | Advertised by one installation |
| Command | `FEE7D001-6A7A-4F3D-9E31-1A51D8E10000` | iPhone writes with response |
| Status | `FEE7D002-6A7A-4F3D-9E31-1A51D8E10000` | Arduino notifies ACK/reject/stopped |

The iPhone scans by service UUID, connects to only the first matching
peripheral, discovers both characteristics, enables Status notifications, and
becomes `ready` only after notification subscription succeeds.

## Command packet — 13 bytes

| Byte | Meaning |
|---:|---|
| 0 | Protocol version, currently `0x01` |
| 1 | Operation: `0x01` interpreted fill, `0x02` stop, `0x03` manual test |
| 2–3 | Big-endian `UInt16` sequence ID |
| 4–11 | Eight normalized deltas in frozen app channel order |
| 12 | XOR of bytes 0–11 |

Channel order is:

1. Anger
2. Joy
3. Anxiety
4. Sadness
5. Disgust
6. Fear
7. Embarrassment
8. Boredom

For `stop`, all delta bytes are zero. A per-channel setup test uses operation
`0x03` with only that channel set to the configured test amount. The board
safety-clamps each test packet but does not add it to interpreted-fill totals.

## Status packet — 6 bytes

| Byte | Meaning |
|---:|---|
| 0 | Protocol version, currently `0x01` |
| 1 | Status: `0x00` ACK, `0x01` rejected, `0x02` stopped |
| 2–3 | Big-endian sequence ID copied from the command |
| 4 | Detail/rejection code; otherwise zero |
| 5 | XOR of bytes 0–4 |

The app accepts a status only when its sequence ID matches the one pending
command. A malformed or mismatched notification cannot complete that command.
The Arduino caches the last result within the current BLE connection so an
identical retry only resends status; connect/disconnect clears that cache so a
restarted app cannot collide with an earlier session's sequence counter.

## Reliability and lifecycle

- Only one command may be pending.
- Commands are accepted only in `ready`.
- ACK timeout is two seconds in production.
- The same packet and sequence ID are retried once after the first timeout.
- A second timeout faults and drops the command.
- Disconnect, app backgrounding, manual disconnect, or transport failure drops
  any pending command; reconnect never replays it.
- CoreBluetooth runs only while the app is foregrounded and Installation Mode
  is active. Auto Connect starts scanning on foreground entry.
- `STOP` and manual `TEST` follow the same ACK rules as fill commands.

## Set 6 implementation

- Sketch: `hardware/arduino/emotion_pumps_8ch_ble/emotion_pumps_8ch_ble.ino`.
- Protocol version, sequence endianness, lengths, status codes, UUIDs, and XOR
  calculation match `BalloonPacketCodec`.
- A matching ACK is notified only after a command is validated and accepted.
- STOP immediately clears pump time and notifies `stopped` with the matching
  sequence ID.
- BLE disconnect stops all outputs and clears board-side pending work.
- Physical iPhone/board integration remains Set 7.
