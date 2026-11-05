// Inside Out physical installation — 8 pumps + BLE protocol v1.
// Target board: Arduino UNO R4 WiFi.
//
// This sketch is derived from reference/emotion_pumps_4ch_1.ino. The original
// four assignments are unchanged and four matching pumps are appended.
//
// IMPORTANT: GPIO pins drive external motor-driver inputs only. Never power a
// pump directly from an Arduino pin. Pumps require an appropriate external
// supply, driver/transistor, flyback protection, and common ground.

#include <ArduinoBLE.h>

const uint8_t NUM_PUMPS = 8;

// Physical array order preserves the four-channel baseline, then appends four.
const uint8_t PIN[NUM_PUMPS] = {3, 5, 9, 10, 6, 2, 11, 4};
const char CODE[NUM_PUMPS] = {'A', 'W', 'B', 'X', 'C', 'Y', 'D', 'Z'};
const bool IS_AIR[NUM_PUMPS] = {true, false, true, false, true, false, true, false};

// New pumps inherit settings from the existing pump of the same medium.
const uint8_t DUTY[NUM_PUMPS] = {200, 255, 200, 255, 200, 255, 200, 255};
const unsigned long MS_PER_UNIT[NUM_PUMPS] = {40, 150, 40, 150, 40, 150, 40, 150};
const unsigned long MAX_QUEUE[NUM_PUMPS] = {8000, 30000, 8000, 30000, 8000, 30000, 8000, 30000};
const unsigned long MAX_TOTAL[NUM_PUMPS] = {20000, 90000, 20000, 90000, 20000, 90000, 20000, 90000};

// Frozen app order [anger, joy, anxiety, sadness, disgust, fear,
// embarrassment, boredom] -> physical [A, Z, C, W, X, Y, D, B].
// Joy and Boredom intentionally exchange their complete pin/medium mapping:
// Joy is now the D4 water channel; Boredom is now the D9 air channel.
const uint8_t APP_TO_PHYSICAL[NUM_PUMPS] = {0, 7, 4, 1, 3, 5, 6, 2};

unsigned long queueMs[NUM_PUMPS] = {0};
// Manual test time is deliberately separate: it is per-command safety-clamped
// but never consumes or is blocked by the interpretation cumulative limit.
unsigned long testQueueMs[NUM_PUMPS] = {0};
unsigned long totalMs[NUM_PUMPS] = {0};
bool outputActive[NUM_PUMPS] = {false};
bool outputUsesTestQueue[NUM_PUMPS] = {false};
unsigned long lastTick = 0;

// BLE protocol v1 — must match docs/ble-protocol-v1.md and iOS codec.
const char* SERVICE_UUID = "FEE7D000-6A7A-4F3D-9E31-1A51D8E10000";
const char* COMMAND_UUID = "FEE7D001-6A7A-4F3D-9E31-1A51D8E10000";
const char* STATUS_UUID = "FEE7D002-6A7A-4F3D-9E31-1A51D8E10000";

const uint8_t PROTOCOL_VERSION = 1;
const uint8_t OP_FILL = 0x01;
const uint8_t OP_STOP = 0x02;
const uint8_t OP_TEST = 0x03;
const uint8_t STATUS_ACK = 0x00;
const uint8_t STATUS_REJECTED = 0x01;
const uint8_t STATUS_STOPPED = 0x02;
const uint8_t COMMAND_LENGTH = 13;
const uint8_t STATUS_LENGTH = 6;

enum RejectCode : uint8_t {
  REJECT_BAD_LENGTH = 1,
  REJECT_BAD_VERSION = 2,
  REJECT_BAD_CHECKSUM = 3,
  REJECT_BAD_OPERATION = 4,
  REJECT_BAD_DELTA = 5
};

BLEService balloonService(SERVICE_UUID);
BLECharacteristic commandCharacteristic(COMMAND_UUID, BLEWrite, COMMAND_LENGTH, true);
BLECharacteristic statusCharacteristic(STATUS_UUID, BLERead | BLENotify, STATUS_LENGTH, true);

// A retry carries the same sequence ID. Cache the last outcome so a lost ACK
// never applies the same fill twice.
bool hasLastSequence = false;
uint16_t lastSequence = 0;
uint8_t lastStatusCode = STATUS_ACK;
uint8_t lastStatusDetail = 0;

char serialBuffer[96];
uint8_t serialLength = 0;

void setPumpOutput(uint8_t index, bool on);
void stopAllPumps();
void resetAllTotals();
void queueNormalizedValue(uint8_t physicalIndex, uint8_t value);
void queueTestNormalizedValue(uint8_t physicalIndex, uint8_t value);
void readSerial();
void handleSerialLine(char* line);
void runPumps();
void printStatus();
void handleBLECommand(BLEDevice central, BLECharacteristic characteristic);
void handleBLEConnect(BLEDevice central);
void handleBLEDisconnect(BLEDevice central);
void sendStatus(uint8_t statusCode, uint16_t sequence, uint8_t detail);
uint8_t xorChecksum(const uint8_t* bytes, uint8_t count);

void setup() {
  for (uint8_t i = 0; i < NUM_PUMPS; i++) {
    pinMode(PIN[i], OUTPUT);
    setPumpOutput(i, false);
  }

  Serial.begin(9600);
  lastTick = millis();

  if (!BLE.begin()) {
    stopAllPumps();
    Serial.println(F("BLE init failed; pumps remain off"));
    while (true) delay(1000);
  }

  BLE.setDeviceName("Inside Out Balloons");
  BLE.setLocalName("Inside Out Balloons");
  BLE.setAdvertisedService(balloonService);
  balloonService.addCharacteristic(commandCharacteristic);
  balloonService.addCharacteristic(statusCharacteristic);
  BLE.addService(balloonService);

  BLE.setEventHandler(BLEConnected, handleBLEConnect);
  BLE.setEventHandler(BLEDisconnected, handleBLEDisconnect);
  commandCharacteristic.setEventHandler(BLEWritten, handleBLECommand);

  uint8_t initialStatus[STATUS_LENGTH] = {PROTOCOL_VERSION, STATUS_STOPPED, 0, 0, 0, 0};
  initialStatus[5] = xorChecksum(initialStatus, 5);
  statusCharacteristic.writeValue(initialStatus, STATUS_LENGTH);

  BLE.advertise();
  Serial.println(F("ready: serial + BLE advertising"));
}

void loop() {
  // Both paths are non-blocking so all active pumps and BLE stay responsive.
  BLE.poll();
  readSerial();
  runPumps();
}

void setPumpOutput(uint8_t index, bool on) {
  outputActive[index] = on;
  if (IS_AIR[index]) {
    analogWrite(PIN[index], on ? DUTY[index] : 0);
  } else {
    digitalWrite(PIN[index], on ? HIGH : LOW);
  }
}

void stopAllPumps() {
  for (uint8_t i = 0; i < NUM_PUMPS; i++) {
    queueMs[i] = 0;
    testQueueMs[i] = 0;
    outputUsesTestQueue[i] = false;
    setPumpOutput(i, false);
  }
}

void resetAllTotals() {
  stopAllPumps();
  for (uint8_t i = 0; i < NUM_PUMPS; i++) totalMs[i] = 0;
}

void queueNormalizedValue(uint8_t physicalIndex, uint8_t value) {
  if (value == 0 || physicalIndex >= NUM_PUMPS) return;
  if (totalMs[physicalIndex] >= MAX_TOTAL[physicalIndex]) return;

  unsigned long added = (unsigned long)value * MS_PER_UNIT[physicalIndex];
  unsigned long availableQueue = MAX_QUEUE[physicalIndex] - queueMs[physicalIndex];
  queueMs[physicalIndex] += min(added, availableQueue);
}

void queueTestNormalizedValue(uint8_t physicalIndex, uint8_t value) {
  if (value == 0 || physicalIndex >= NUM_PUMPS) return;

  unsigned long added = (unsigned long)value * MS_PER_UNIT[physicalIndex];
  unsigned long availableQueue = MAX_QUEUE[physicalIndex] - testQueueMs[physicalIndex];
  testQueueMs[physicalIndex] += min(added, availableQueue);
}

void runPumps() {
  unsigned long now = millis();
  unsigned long dt = now - lastTick;
  lastTick = now;

  for (uint8_t i = 0; i < NUM_PUMPS; i++) {
    // Account only time for which the previous loop actually left this output
    // on. Clamp by queue and remaining total so accounting cannot overshoot the
    // authority limit in one loop tick.
    if (outputActive[i]) {
      if (outputUsesTestQueue[i]) {
        unsigned long run = min(dt, testQueueMs[i]);
        testQueueMs[i] -= run;
      } else {
        unsigned long remainingTotal = MAX_TOTAL[i] - min(totalMs[i], MAX_TOTAL[i]);
        unsigned long run = min(dt, min(queueMs[i], remainingTotal));
        queueMs[i] -= run;
        totalMs[i] += run;
      }
    }

    // Clamp and clear immediately at the hardware authority's cumulative cap,
    // then choose the output state for the next non-blocking loop interval.
    if (totalMs[i] >= MAX_TOTAL[i]) {
      totalMs[i] = MAX_TOTAL[i];
      if (queueMs[i] > 0) {
        queueMs[i] = 0;
        setPumpOutput(i, false);
        Serial.print(CODE[i]);
        Serial.println(F(" reached limit"));
      }
    }
    // Test pulses take priority and remain available even after interpreted
    // fills reach their cumulative cap. They do not change totalMs.
    if (testQueueMs[i] > 0) {
      outputUsesTestQueue[i] = true;
      setPumpOutput(i, true);
    } else {
      outputUsesTestQueue[i] = false;
      setPumpOutput(i, queueMs[i] > 0 && totalMs[i] < MAX_TOTAL[i]);
    }
  }
}

void handleBLEConnect(BLEDevice central) {
  // Retry de-duplication is connection-scoped. A relaunched iPhone app starts
  // its sequence counter again and must not collide with an earlier session.
  hasLastSequence = false;
  Serial.print(F("BLE connected: "));
  Serial.println(central.address());
}

void handleBLEDisconnect(BLEDevice central) {
  (void)central;
  stopAllPumps();
  hasLastSequence = false;
  Serial.println(F("BLE disconnected: pumps stopped and queue cleared"));
}

void handleBLECommand(BLEDevice central, BLECharacteristic characteristic) {
  (void)central;
  uint8_t packet[COMMAND_LENGTH] = {0};
  int length = characteristic.readValue(packet, COMMAND_LENGTH);
  uint16_t sequence = length >= 4 ? ((uint16_t)packet[2] << 8) | packet[3] : 0;

  if (length != COMMAND_LENGTH) {
    sendStatus(STATUS_REJECTED, sequence, REJECT_BAD_LENGTH);
    return;
  }
  if (packet[0] != PROTOCOL_VERSION) {
    sendStatus(STATUS_REJECTED, sequence, REJECT_BAD_VERSION);
    return;
  }
  if (xorChecksum(packet, COMMAND_LENGTH - 1) != packet[COMMAND_LENGTH - 1]) {
    sendStatus(STATUS_REJECTED, sequence, REJECT_BAD_CHECKSUM);
    return;
  }

  // The iPhone retries the identical sequence once if its notification was
  // lost. Repeat only the cached status, never the physical side effect.
  if (hasLastSequence && sequence == lastSequence) {
    sendStatus(lastStatusCode, lastSequence, lastStatusDetail);
    return;
  }

  uint8_t operation = packet[1];
  if (operation != OP_FILL && operation != OP_STOP && operation != OP_TEST) {
    sendStatus(STATUS_REJECTED, sequence, REJECT_BAD_OPERATION);
    return;
  }
  for (uint8_t i = 0; i < NUM_PUMPS; i++) {
    if (packet[4 + i] > 100) {
      sendStatus(STATUS_REJECTED, sequence, REJECT_BAD_DELTA);
      return;
    }
  }
  if (operation == OP_STOP) {
    for (uint8_t i = 0; i < NUM_PUMPS; i++) {
      if (packet[4 + i] != 0) {
        sendStatus(STATUS_REJECTED, sequence, REJECT_BAD_DELTA);
        return;
      }
    }
  }

  if (operation == OP_STOP) {
    stopAllPumps();
    hasLastSequence = true;
    lastSequence = sequence;
    lastStatusCode = STATUS_STOPPED;
    lastStatusDetail = 0;
    sendStatus(STATUS_STOPPED, sequence, 0);
    printStatus();
    return;
  }

  for (uint8_t appIndex = 0; appIndex < NUM_PUMPS; appIndex++) {
    if (operation == OP_TEST) {
      queueTestNormalizedValue(APP_TO_PHYSICAL[appIndex], packet[4 + appIndex]);
    } else {
      queueNormalizedValue(APP_TO_PHYSICAL[appIndex], packet[4 + appIndex]);
    }
  }
  hasLastSequence = true;
  lastSequence = sequence;
  lastStatusCode = STATUS_ACK;
  lastStatusDetail = 0;
  sendStatus(STATUS_ACK, sequence, 0);
  printStatus();
}

void sendStatus(uint8_t statusCode, uint16_t sequence, uint8_t detail) {
  uint8_t packet[STATUS_LENGTH] = {
    PROTOCOL_VERSION,
    statusCode,
    (uint8_t)(sequence >> 8),
    (uint8_t)(sequence & 0xFF),
    detail,
    0
  };
  packet[5] = xorChecksum(packet, 5);
  statusCharacteristic.writeValue(packet, STATUS_LENGTH);
}

uint8_t xorChecksum(const uint8_t* bytes, uint8_t count) {
  uint8_t result = 0;
  for (uint8_t i = 0; i < count; i++) result ^= bytes[i];
  return result;
}

void readSerial() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      if (serialLength > 0) {
        serialBuffer[serialLength] = '\0';
        handleSerialLine(serialBuffer);
        serialLength = 0;
      }
    } else if (serialLength < sizeof(serialBuffer) - 1) {
      serialBuffer[serialLength++] = toupper(c);
    }
  }
}

void handleSerialLine(char* line) {
  if (strcmp(line, "STOP") == 0) {
    stopAllPumps();
  } else if (strcmp(line, "RESET") == 0) {
    resetAllTotals();
    hasLastSequence = false;
  } else if (strcmp(line, "STATUS") == 0) {
    // Print only below.
  } else if (line[0] == 'T' && line[1] != '\0' && line[2] == '\0') {
    for (uint8_t i = 0; i < NUM_PUMPS; i++) {
      if (line[1] == CODE[i]) {
        testQueueMs[i] = min((unsigned long)2000, MAX_QUEUE[i]);
      }
    }
  } else {
    // Existing syntax remains valid: A60,W30,B20,X10. New codes may be mixed.
    char* token = strtok(line, ",");
    while (token != NULL) {
      for (uint8_t i = 0; i < NUM_PUMPS; i++) {
        if (token[0] == CODE[i]) {
          int value = constrain(atoi(token + 1), 0, 100);
          queueNormalizedValue(i, (uint8_t)value);
        }
      }
      token = strtok(NULL, ",");
    }
  }
  printStatus();
}

void printStatus() {
  for (uint8_t i = 0; i < NUM_PUMPS; i++) {
    Serial.print(CODE[i]);
    Serial.print(F(" queue="));
    Serial.print(queueMs[i]);
    Serial.print(F("ms total="));
    Serial.print(totalMs[i]);
    Serial.print(F("ms test="));
    Serial.print(testQueueMs[i]);
    Serial.print(F("ms  "));
  }
  Serial.println();
}
