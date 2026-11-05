// Reference snapshot supplied 2026-10-29.
// Preserve this file unchanged; derive the eight-channel BLE sketch separately.

// 情绪挤压 demo：4 路泵（2 气泵 + 2 水泵）
// 在原来的 2 路版本（D3 气泵 / D5 水泵）上加了两路，其余逻辑不变。
// 串口 9600，每条指令以换行结尾。
//
// 指令：
//   A60,W30   气泵 A 强度 60，水泵 W 强度 30（0-100，可只写一路，如 A60）
//   A60,W30,B20,X10   四路可以同时写，多路同时运行
//   TA / TW / TB / TX   单独测试某一路，各转 2 秒
//   STOP      立刻停泵并清空待运行时间
//   RESET     把累计运行时间清零（放完气/水之后再用）
//
// 压力上限靠"累计运行时间上限"实现：到上限后不再充，直到 RESET。
//
// 接线（都是带 ~ 的 PWM 脚）：
//   A = 气泵 1 -> D3   （原有）
//   W = 水泵 1 -> D5   （原有）
//   B = 气泵 2 -> D9   （新增）
//   X = 水泵 2 -> D10  （新增）
//   不要用 D0 / D1（USB 串口）

const uint8_t  NUM = 4;
const uint8_t  PIN[NUM]          = {3, 5, 9, 10};         // 都是带 ~ 的 PWM 脚
const char     CODE[NUM]         = {'A', 'W', 'B', 'X'};  // A,B = 气；W,X = 水
const uint8_t  DUTY[NUM]         = {200, 255, 200, 255};  // PWM 力度 0-255，先调这个
const unsigned long MS_PER_UNIT[NUM] = {40, 150, 40, 150};          // 强度 1 对应的运行毫秒数
const unsigned long MAX_QUEUE[NUM]   = {8000, 30000, 8000, 30000};  // 单次排队的最长运行时间
const unsigned long MAX_TOTAL[NUM]   = {20000, 90000, 20000, 90000}; // 累计上限，相当于压力上限

unsigned long queueMs[NUM] = {0, 0, 0, 0};  // 还要转多久
unsigned long totalMs[NUM] = {0, 0, 0, 0};  // 已经转了多久（累计）
unsigned long lastTick;

char buf[40];
uint8_t len = 0;

void setup() {
  for (uint8_t i = 0; i < NUM; i++) {
    pinMode(PIN[i], OUTPUT);
    analogWrite(PIN[i], 0);
  }
  Serial.begin(9600);
  lastTick = millis();
  Serial.println(F("ready"));
}

void loop() {
  readSerial();
  runPumps();
}

void readSerial() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      if (len > 0) {
        buf[len] = '\0';
        handleLine(buf);
        len = 0;
      }
    } else if (len < sizeof(buf) - 1) {
      buf[len++] = toupper(c);
    }
  }
}

void handleLine(char* line) {
  if (strcmp(line, "STOP") == 0) {
    for (uint8_t i = 0; i < NUM; i++) queueMs[i] = 0;
  } else if (strcmp(line, "RESET") == 0) {
    for (uint8_t i = 0; i < NUM; i++) { queueMs[i] = 0; totalMs[i] = 0; }
  } else if (line[0] == 'T' && line[1] != '\0') {
    for (uint8_t i = 0; i < NUM; i++)
      if (line[1] == CODE[i]) queueMs[i] = 2000;
  } else {
    // 例如 "A60,W30"
    char* tok = strtok(line, ",");
    while (tok != NULL) {
      for (uint8_t i = 0; i < NUM; i++) {
        if (tok[0] == CODE[i]) {
          int v = constrain(atoi(tok + 1), 0, 100);
          queueMs[i] = min(queueMs[i] + (unsigned long)v * MS_PER_UNIT[i], MAX_QUEUE[i]);
        }
      }
      tok = strtok(NULL, ",");
    }
  }
  printStatus();
}

void runPumps() {
  unsigned long now = millis();
  unsigned long dt = now - lastTick;
  lastTick = now;

  for (uint8_t i = 0; i < NUM; i++) {
    if (queueMs[i] > 0 && totalMs[i] < MAX_TOTAL[i]) {
      analogWrite(PIN[i], DUTY[i]);
      unsigned long run = min(dt, queueMs[i]);
      queueMs[i] -= run;
      totalMs[i] += run;
    } else {
      analogWrite(PIN[i], 0);
      if (totalMs[i] >= MAX_TOTAL[i] && queueMs[i] > 0) {
        queueMs[i] = 0;
        Serial.print(CODE[i]);
        Serial.println(F(" reached limit"));
      }
    }
  }
}

void printStatus() {
  for (uint8_t i = 0; i < NUM; i++) {
    Serial.print(CODE[i]);
    Serial.print(F(" queue="));
    Serial.print(queueMs[i]);
    Serial.print(F("ms total="));
    Serial.print(totalMs[i]);
    Serial.print(F("ms  "));
  }
  Serial.println();
}
