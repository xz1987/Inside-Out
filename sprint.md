# Sprint Tracker — Inside Out MVP

以 `docs/retrospective-memory-ios-prd.md` Section 28–37 为范围基准。
每完成一项：勾选 checkbox，并在文末「进度日志」追加一条记录（日期 + 做了什么 + 相关文件/commit）。

状态标记：`[x]` 完成 · `[~]` 进行中/部分完成 · `[ ]` 未开始

---

## Sprint 0 — UI 改造

- [x] 在 Claude Design 出核心 UI 稿（语音优先首页、Listening、Feed 结果页、Figures 总览、Memories）— 源文件在 `design/`
- [~] 四只 Figure 的拟人彩球形象（Joy / Sadness / Anger / Fear）：SwiftUI 代码绘制，idle/fed 两种表情 + 各自待机动画已完成；evolved 形态未做
- [x] 按设计稿重写 SwiftUI 视图，替换现有表单式布局（`Features/Journal/`）
- [x] Feed 数值以游戏化方式浮现在 Figure 上方（+18、EXP 条、bond +8）

- [ ] 结果页 Replay 按钮接真实录音回放（目前只切换文字）
- [x] 摘要：接后端后由 LLM 生成（离线回退时仍是原文截断）

> 注：设计稿加了 Figures / Memories 两个 tab，超出 PRD §29 的线性 MVP 结构；数据目前只在内存里，重启即重置。

## Sprint 1 — Functional Input（PRD §30）

- [x] Message 输入：「or type it instead」底部弹层 + 15 字符下限校验
- [ ] 语音录制（AVFoundation）：录音按钮、时长、暂停/继续/结束、删除重录、录音中 active state
- [ ] 语音转文字：已决定放在手机端（Apple Speech framework），后端只收文字、不做音频上传
- [ ] 语音 ≥ 5 秒有效输入校验
- [x] 语音为主入口、文字为次入口（UI 层面）
- [~] Listening 屏：转写逐行展示 + Figure 按关键词实时变大已完成，但转写内容目前是写死的示例句（等真实录音接入后替换）
- [~] 错误状态：分析失败保留 input + 「Tap Done to try again」✓、后端不可达回退本地 ✓；麦克风权限拒绝、转录失败待语音接入后做
- [ ] 可选 prompt chips
- [x] Loading 状态：Listening 页 Done/麦克风显示 “Thinking…”，打字弹层按钮显示 “Your Figures are listening…”；离开页面后迟到的结果会被丢弃

## Sprint 2 — Functional Interpretation（PRD §31、§37–41）

- [x] 本地 fallback 解析器 `LocalEventInterpreter`（关键词匹配）
- [x] 结果页基础：event summary、Figure Feed、浓度、证据解释、promoted relationship
- [x] 后端脚手架：`apps/api`（Node 20 + TypeScript + Express 5），Cornell 网关兼容的 LLM client，`/health`，trace id，JSON 错误
- [x] Contracts v1：`packages/contracts` 4 个 JSON Schema + fixtures，Ajv 校验 + PRD §41.5 规则，26 个测试
- [x] 确认 Cornell 网关支持 strict JSON Schema 输出（`npm run smoke:llm`：`openai.gpt-5-mini`，`json_schema` 模式，约 2.5 s）
- [x] Orchestrator `POST /api/v1/sessions/run`（A → 校验 → B → 校验 → 合并；A 失败不调 B；B 文案失败用模板并标 fallback）
- [x] Domain A — `POST /api/v1/events/interpret`：prompt `input-v1`、strict JSON Schema 输出、服务端校验 + 1 次纠错重试、无 key 时关键词回退、503/502 错误语义
- [x] Domain A prompt 调优 → `input-v2`：summary 一句话 ≤16 词（英文实测 10–13 词，中文 31 字，适配结果卡片两行），uncertainties ≤2；Figure 组合与 Feed 与 v1 一致
- [x] Domain B — `POST /api/v1/ecosystem/resolve`：确定性规则决定变形/掠夺/降级/Mask/关系前后值，LLM（`ecosystem-mvp-v1`）只写关系理由和三步解释，只看 summary 不看原文
- [x] iOS 改为调用 `/sessions/run`：发送 Figure 状态 / 关系分数 / 种子记忆作为 snapshot；目前只用返回的 relationship，evolution / raid / explanation 留给 Sprint 3
- [x] iOS 端接入 `/api/v1/events/interpret`（`APIClient` + `RemoteEventInterpreter`），后端不可达时回退本地关键词并在结果页标注 “Offline guess”
- [ ] 确认前修改 interpretation：增减 Figure、调浓度、改 summary（MVP-FR-04）
- [x] Most fed 视觉（C 位 + 更大 + 更亮）、EXP bar 当前值 → 本次增量动画
- [x] Relationship before/after：结果页显示 “Anger & Fear grew closer 12 → 19”，delta 由 Domain B 计算；保存时更新关系分数；单个 Figure 也显示与其最亲近 Figure 的关系（不画连线）；离线时由本地分数 +8 计算
- [x] 查看原文 + Edit input：摘要卡片右上角 “原话” 图标 / 点卡片 → “What you said” 面板 → “Edit and ask again” 回到首页并预填打字弹层（语音输入也走文字编辑）

## Sprint 3 — Mock Narrative（PRD §32–35）

- [~] Seed data：4 只 Figure 的 level / EXP / energy / 7 日趋势；关系分数（与 contract fixture 一致）；5 条种子 memory，其中 4 条带 seedID + object（每个 Figure 各拥有一条，可被掠夺）；threshold 由后端 mock 规则决定
- [ ] 显式状态机 `input_ready → … → memory_masked → demo_complete`（不依赖动画推断状态）
- [ ] 所有 mock 结果标记 `simulation_mode: true`、`scenario_id: mvp_evolve_raid_mask_v1`，UI 显示 demo 标识
- [ ] Screen 3 — EXP 达标 + 变形（Feed 最高者为 Evolved Figure）
- [ ] Screen 4 — 固定成功的 Raid（夺取 seed memory/object，attacker ≠ victim）
- [ ] Screen 5 — Victim 降为 Level 1、相关 memory Masked（保留 provenance）、三步因果解释
- [ ] 结束操作：Replay demo / Start over / Keep my event / Discard everything
- [ ] 本地持久化（SwiftData）：只存真实 input + analysis，mock state 不落库

## Sprint 4 — Testing & Polish（PRD §36.3、§47）

- [~] Reduce Motion：开启后 Figure 待机动画、光圈、心跳等循环动画全部静止；转场 crossfade 未专门处理
- [ ] VoiceOver labels
- [ ] Analytics 埋点（验证 §36.5：80% 用户能答出 6 个问题）
- [ ] 单元测试：解析器、状态机
- [ ] 端到端原型测试（§36.4 的 14 步路径）

## 工程杂项

- [x] 首次在完整 iOS SDK 下编译通过，模拟器可运行
- [x] 修复缺少 Launch Screen 导致的兼容模式黑边（`INFOPLIST_KEY_UILaunchScreen_Generation = YES`）
- [ ] 替换 bundle ID 占位符 `com.yourteam.InsideOutMVP`，配置 Development Team，真机安装
- [ ] CI 与双人 GitHub 协作流程（PRD §44、§48）

---

## 进度日志

### 2026-09-24
- Clone 仓库到本地，iPhone 17 Pro 模拟器（iOS 26.3）构建并运行成功。
- 修复 Launch Screen 缺失导致的黑边：`apps/ios/InsideOutApp.xcodeproj/project.pbxproj` Debug/Release 各加 `INFOPLIST_KEY_UILaunchScreen_Generation = YES`。
- 验证现有 Screen 1 → Screen 2 流程可用（输入 → Anger/Fear Feed + relationship +8）。
- 整理 UI 改造方向，产出 Claude Design 提示词（语音优先、拟人彩球 Figure、游戏化数值）。
- 建立本 sprint tracker。

### 2026-09-24（UI 改造）
- 导入 Claude Design 导出包到 `design/`（`Inside Out.dc.html`、`Figure.dc.html`）。
- 新增 `Features/Journal/`：`Theme.swift`（配色、SF Rounded 代替 Nunito、390×844 画板等比缩放）、`FigureView.swift`（拟人彩球，idle/fed 表情与待机动画）、`JournalView.swift`（Home / Listening / 底部 tab / 打字弹层 / toast）、`ResultOverlay.swift`（Who got fed）、`FiguresScreen.swift`、`MemoriesScreen.swift`、`JournalViewModel.swift`。
- 新增 `Models/FigureState.swift`（Figure 等级/EXP/能量/趋势 + 种子 memory，内存态）。
- `FigureFeed` 增加 `voiceLine`；`LocalEventInterpreter` 暴露 `signalCounts(in:)` 供 Listening 实时反应，并补充关键词（cut me off / yelled / shaky / happen again 等）。
- 删除旧的 `Features/DailyEvent/`。
- 与设计稿的有意偏差：麦克风文案 “Hold to tell me” → “Tap to tell me”（实际交互是点按）；结果页 Replay 移到时间行，避免摘要卡片压住 +N；结果页主次 Figure、颜色、连线渐变按真实解析结果动态决定，而非写死 Anger/Fear。
- 模拟器验证：语音(示例)→结果→保存→Figures→Memories、打字→结果（Joy+Fear）两条路径均通过。

### 2026-09-24（后端第 1 步：脚手架 + contracts，分支 `chore/contracts-v1`）
- 参考课程示例 `DEA6400-main/node-js/simple-app`：Cornell 网关 `https://api.ai.it.cornell.edu` + `/v1`，模型名加 `openai.` 前缀，`developer` role，单个 `OPENAI_API_KEY`。
- 新增 `apps/api`：`config.ts`（每个 domain 独立 key/model/prompt 版本，缺省回退到 `OPENAI_API_KEY`）、`llm/llmClient.ts`（优先 strict `json_schema`，网关不支持时回退 `json_object`）、`contracts/validate.ts`、`app.ts`（`/health`、trace id、JSON 404/400/500）、`scripts/smoke-llm.ts`。
- 新增 `packages/contracts`：`event-interpretation.v1`（新增 `voiceLine`）、`ecosystem-snapshot.v1`（seed memory 加 title/objectName）、`ecosystem-resolution.v1`（新增三步 `explanation`）、`client-session-response.v1`（带 `fallback` 标记）+ 对应 fixtures。
- 决定：语音转文字在手机端，后端不做音频上传。
- 验证：typecheck、26 个 vitest、build、本地启动 `/health` 均通过。尚未用真实 key 调网关。
- 用真实 key 跑 `npm run smoke:llm`：Cornell 网关 + `openai.gpt-5-mini` 返回正确，strict `json_schema` 可用，约 2.5 s。

### 2026-09-24（后端第 2 步：Domain A，分支 `feat/input-domain-v1`）
- 新增 `src/domains/input/`：`inputInterpreter.ts`（组装 server 字段、按 feed 排序、浓度归一化、过滤无效 relationship cue、Ajv 校验、失败带错误信息重试 1 次）、`keywordInterpreter.ts`（iOS 关键词解析的 TS 移植，无 key 时兜底）、`prompts/input-v1.ts`。
- 新增 `src/routes/events.ts`：请求校验（inputType、text 15–4000 字、importance 0–1），日志只记结构不记原文。
- `reasoning_effort` 实测（gpt-5-mini / Cornell）：默认 9–16 s；`low` 3.4–7.5 s 质量基本不变；`minimal` 2.5–3.8 s 但会凑数加 Figure。默认设为 `low`，可用 `*_REASONING_EFFORT` 覆盖，`off` 省略参数。
- 真实样例（`npm run try:input`）：英文别车、中文组会被否定、Mia 送咖啡、买牛奶（只给 1 个 Figure）、prompt 注入（未被带偏）、中文交论文后空落 — 结果均合理，中文输入全程中文输出。
- 测试 45 个全部通过（FakeLlm，不耗额度）；本地 HTTP 端到端调用通过。

### 2026-09-24（iOS 接入 Domain A，分支 `feat/input-ios-flow`）
- 新增 `Services/APIClient.swift`（默认 `http://localhost:3000`，可用 scheme 环境变量 `API_BASE_URL` 覆盖；DTO 对应 `event-interpretation.v1`）、`Services/RemoteEventInterpreter.swift`（后端不可达 → 本地关键词；5xx → 抛错让用户重试；把 relationshipCues 映射成结果页的 bond）。
- `EventAnalysis.promotedRelationship` 改为可选（只有 1 个 Figure 时不显示连线），新增 `isKeywordGuess`；`EventInterpreting` 增加 `source` 参数。
- `JournalViewModel`：`isInterpreting` / `interpretError`、导航计数防止迟到结果覆盖当前页面。
- 结果页：单个 Figure 居中、100% 标签隐藏、未参与的 Figure 分散在两侧；离线时摘要下方显示 “Offline guess from keywords”。
- 模拟器验证（真实 Cornell 网关）：语音示例 → Anger+Fear（7.6 s）；打字 “Mia 送咖啡” → 仅 Joy 居中（3.8 s）；停掉后端 → 离线回退并标注；无效 key → 显示 “Something went wrong / Tap Done to try again”，输入保留；日志中无 key。
- 注意：`http://localhost` 在模拟器上无需 ATS 例外；真机需改 `API_BASE_URL` 为局域网 IP / HTTPS 隧道（PRD §45.2）。

### 2026-09-24（后端：Domain B + Orchestrator，分支 `feat/ecosystem-domain-v1`）
- 新增 `src/domains/ecosystem/`：`scenario.ts`（确定性规则：Feed 最高者变形、EXP 设为 100−feed 刚好达标；关系优先用 Domain A 的 cue，delta≈(feedA+feedB)/4 最小 4，单 Figure 时沿用其最强已有关系 +4；掠夺目标优先选本次未参与、等级最高的 Figure 的可见记忆；受害者降到 Level 1、记忆 masked）、`ecosystemDirector.ts`（LLM 只改写文案，任何失败回退模板）、`prompts/ecosystem-mvp-v1.ts`。
- 新增路由 `routes/ecosystem.ts`（400 输入校验、422 无可掠夺记忆）、`routes/sessions.ts`（Orchestrator）；Domain A 错误映射抽成 `sendAnalysisError` 共用。
- 规则用 fixture 输入可完全复现 `ecosystem-resolution.valid.json`（测试覆盖）。
- 真实网关端到端（3 个样例，均无 fallback）：初版 11–12 s（A 5–6 s + B 5–6 s）。B 改用 `reasoning_effort: minimal` 后约 2 s，总计 5–10 s，文案质量不变 → B 默认 `minimal`、A 保持 `low`。
- 修正：单 Figure 时 LLM 会编造另一个 Figure 也参与了事件；prompt 增加 `bothInEvent` 标记后改为“通过已有的共同记忆变得更亲近”。
- 测试 70 个全部通过（新增 25 个：规则、Director 回退、两个路由、Orchestrator 不在 A 失败时调用 B）。

### 2026-09-24（Sprint 2 收尾①：查看原文 + Edit input，分支 `feat/result-details`）
- `ResultOverlay`：摘要卡片加 `text.quote` 按钮，卡片可点；新增 `OriginalInputSheet`（显示完整原话、来源与时长、可选中复制、“Edit and ask again”）。
- `JournalViewModel`：`lastInputText` 记录实际发送的文本；`editLastInput()` 回到首页，等结果页面板收起后（450 ms）打开预填好的打字弹层。
- 模拟器验证：语音示例 → 结果 → 查看原话 → Edit → 首页打字弹层已预填原文。

### 2026-09-24（Sprint 2 收尾②：iOS 改调 `/sessions/run` + 关系前后值，分支 `feat/result-details`）
- `Models/FigureState.swift`：新增 `FigurePair`（无序 Figure 对）+ 种子关系分数；`MemoryEntry` 增加 `seedID` / `objectName`，种子记忆扩到 5 条（每个 Figure 拥有 1 条可掠夺的）；新增 `EcosystemContext`。
- `RelationshipPromotion` 增加 `before` / `after`；`EventInterpreting.interpret` 增加 `context` 参数。
- `APIClient`：改为 `runSession`（`/api/v1/sessions/run`，超时 45 s），新增 `SnapshotDTO`（由 context 生成，energy 0–1 → 0–100）、`SessionResponseDTO` / `ResolutionDTO`；移除不再使用的 `/events/interpret` 调用。
- `RemoteEventInterpreter`：关系取自 Domain B 的 promotedRelationship（含单 Figure 情况）；后端不可达时用本地关系分数补 before。
- `JournalViewModel`：`relationships` 状态；保存时写入 after。结果页底部显示 “X & Y grew closer  before → after”。
- 模拟器验证（真实网关）：别车 → “Anger & Fear 12 → 19，+7 bond”；保存后打字 Mia 咖啡 → 仅 Joy，“Joy & Sadness 9 → 13”；再次别车 → “19 → 27”（保存生效）；停掉后端 → 离线仍显示 “19 → 27” 并标注 Offline guess。

### 2026-09-24（Sprint 2 收尾③：Domain A prompt `input-v2`，分支 `feat/result-details`）
- 新增 `prompts/input-v2.ts` 并设为默认（v1 保留，可用 `INPUT_PROMPT_VERSION=input-v1` 对比）。
- 真实网关对比：摘要从 v1 的 17–30 词降到 10–13 词（中文 31 字），不再被结果卡片截断；uncertainties 最多 2 条；Figure 组合、Feed、速度（4–7 s）不变；prompt 注入样例仍未被带偏。
- `.env.example` 不再写死 prompt 版本（改为注释），本地 `.env` 中对应两行已注释，默认跟随代码最新版本。
