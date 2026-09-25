# Sprint Tracker — Inside Out MVP

以 `docs/retrospective-memory-ios-prd.md` Section 28–37 为范围基准。
每完成一项：勾选 checkbox，并在文末「进度日志」追加一条记录（日期 + 做了什么 + 相关文件/commit）。

状态标记：`[x]` 完成 · `[~]` 进行中/部分完成 · `[ ]` 未开始 · `[-]` 决定不做（附原因）

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

- [x] Message 输入：「or type it instead」底部弹层；**不设最少字数**（只拦截空白），后端上限 4000 字符防误粘贴
- [x] 语音录制（AVFoundation）：录音按钮、时长、暂停/继续/结束、删除重录、录音中 active state
- [x] 语音转文字：已决定放在手机端（Apple Speech framework），后端只收文字、不做音频上传
- [x] 语音 ≥ 5 秒有效输入校验
- [x] 语音为主入口、文字为次入口（UI 层面）
- [x] Listening 屏：Apple Speech 实时转写逐行展示 + Figure 按关键词实时变大
- [x] 错误状态：分析失败保留 input + 「Tap Done to try again」、后端不可达回退本地、麦克风/语音权限拒绝与转录失败提示
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
- [-] ~~确认前修改 interpretation：增减 Figure、调浓度、改 summary（MVP-FR-04 / MVP-UI-08）~~ — **决定不做**：分配完全交给 AI。用户可以自己选会导致不真实的行为，也与“情绪有自己的意志”的核心设定冲突。纠错途径改为“重新讲一遍”（Edit and ask again），用户能改讲法，不能改数值。结果页只展示“谁和谁得到加分”。
- [x] Most fed 视觉（C 位 + 更大 + 更亮）、EXP bar 当前值 → 本次增量动画
- [x] Relationship before/after：共同参与的 Figure **两两**各一段（1 个 → 0 段，2 个 → 1 段，3 个 → 3 段），结果页逐行显示 “X & Y grew closer 12 → 19”，delta 由 Domain B 计算；保存时全部写入；离线时由本地分数 +8 计算
- [x] 3 个 Figure 的结果页布局：最高者居中、另两个分列两侧，三列窄版名字/EXP/台词，底部关系列表；此前第三个被喂的 Figure 会被错误地显示成未参与
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
- [x] 真机安装验收通过；Bundle Identifier 保持 `com.yourteam.InsideOutMVP`，Development Team 由每位开发者在本地 Xcode 选择，不写入仓库
- [ ] CI 与双人 GitHub 协作流程（PRD §44、§48）

---

## 进度日志

### 2026-09-24（Sprint 1：真实语音输入）
- 新增 `SpeechRecordingService.swift`：AVFoundation 录制到临时 `.m4a`，Apple Speech 实时/最终转写，支持暂停、继续、结束与删除重录；可用时要求手机端识别。
- Listening 流程移除写死示例句，接入真实时长与转写；录音 active 光圈、暂停状态、逐行 transcript 和 Figure 关键词反应均由实时状态驱动。
- `Done` 在累计录音达到 5 秒前禁用并显示剩余秒数；最终转写为空、权限拒绝或识别失败均停留在可恢复状态。
- 后端接口保持只接收 transcript 字符串，不上传音频；加入 Microphone / Speech Recognition usage descriptions。
- Xcode 27 / iOS 27 `iPhone 18 Pro` 模拟器无警告构建成功，安装并启动成功（PID 35209）；当前 Xcode 已无原 sprint 记录的 iPhone 17 Pro runtime。
- 修复模拟器录音有计时但 Speech 立即中断：Simulator 不再强制使用缺失/不稳定的 on-device speech asset，允许 Apple Speech hosted service；真机仍在支持时强制端侧识别。模拟器错误现在会显示错误 domain/code，并提示检查 `I/O › Audio Input › Mac microphone`。
- 修复实体机结束录音后最终转写报 “cannot open”：释放 `AVAudioFile` 写入句柄并完成 `.m4a` 封装后再交给 Speech；若最终文件转写仍失败但实时 transcript 已有效，则安全回退到实时文字继续分析，不丢失用户输入。
- 实体 iPhone 验收通过：可识别真实语音，结束录音后的 “cannot open” 不再出现。
- 录音完成后的 Listening UI 改为 “Recorded”：主麦克风与 Pause 不再假装可操作，仍可删除重录或点 Done 重试分析。
- 项目文件不提交 `DEVELOPMENT_TEAM`，两位开发者各自在 Xcode Signing & Capabilities 选择 Team；Bundle Identifier 保持 `com.yourteam.InsideOutMVP`。
- 提交前验证：generic iOS device 无签名构建通过，后端 80/80 测试与 TypeScript typecheck 通过。

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

### 2026-09-24（产品决策：取消用户手动调整解读）
- 决定不实现 MVP-FR-04 / MVP-UI-08（确认前增减 Figure、调浓度、改摘要）。理由：情绪分配应完全由 AI 决定；允许手动选择会带来不真实的行为（例如为了喂某个 Figure 而调数值），与产品“情绪自己争夺记忆”的设定不符。
- 保留 “Edit and ask again”（重新讲述后重新解读）作为唯一纠错途径，同时覆盖语音转写出错的情况。
- 结果页维持现状：直接展示被喂的 Figure、Feed、关系加分，“Save this memory” 即确认。
- 已在 PRD §31 D、MVP-UI-08、MVP-FR-04 旁补充修订说明（见下方 “PRD 修订说明” 条目）。

### 2026-09-24（取消最少字数限制）
- 产品决策：输入不设最少字数（PRD §30 原为 ≥15 字符），“tired” 这样的一个词也是有效的情绪瞬间。iOS 只拦截空白输入；后端改为 1–4000 字符，4000 仅防止误粘贴超长文本拖垮额度与响应时间。
- 验证：输入 “tired” → Sadness +6，摘要 “You felt tired.”，关系 “Sadness & Joy 9 → 13”。后端测试 71 个通过（新增单个词可通过的用例）。
- 排查粘贴问题：app 内长按 → Paste 正常；问题出在 Mac 剪贴板未同步到模拟器（Claude 内嵌模拟器面板不转发 ⌘V）。可用 `pbpaste | xcrun simctl pbcopy booted` 后长按粘贴，或在 Simulator.app 窗口中 ⌘V。

### 2026-09-24（修正：关系只在共同参与的 Figure 之间产生）
- 问题：输入 “tired” 只喂了 Sadness，结果页却显示 “Sadness & Joy grew closer 9 → 13”，保存后 Joy–Sadness 真的 +4。原因是按 PRD §31 C 实现了“单个 Figure 时沿用已有关系”的规则。
- 产品决策：PRD 该条款有误。关系只在本次事件中共同出现的 Figure 之间产生；单个 Figure 不产生关系。已修订 PRD §31 C、MVP-UI-07、MVP-FR-03，并保留修订说明。
- Contract：`ecosystem-resolution.v1.promotedRelationship` 允许为 `null`（仍是 v1：尚未发布）。
- 后端：`choosePromotedPair` 单 Figure 返回 null；Domain B prompt 升级为 `ecosystem-mvp-v2`（无关系时 relationshipReason 为 null，不允许编造关系），模型无法凭空生成关系。测试 74 个通过。
- iOS：`ResolutionDTO.promotedRelationship` 可选，且只接受两个 Figure 都在本次被喂名单中的关系。
- 验证（真实网关）：“tired” → 仅 Sadness +4，无关系；房租上涨 → Anger & Fear 12 → 20。

### 2026-09-24（多段关系：共同参与的 Figure 两两建立关系，分支 `feat/multi-bonds`）
- 产品决策：同一事件中出现的 Figure 两两之间都增加关系（3 个 Figure → 3 段）。PRD §31 C、MVP-UI-07、MVP-FR-03 已修订并保留说明。
- Contract：`promotedRelationship`（单个/可空）改为 `promotedRelationships` 数组（0–3，最强在前）。v1 尚未发布，原地修改并在 contracts README 说明。Session 校验新增：关系只能在被喂的 Figure 之间，且数量必须等于 C(n,2)。
- 后端：`choosePromotedPairs` 生成所有两两组合，delta=max(4, round((feedA+feedB)/4))；Domain B 文案改为 `relationshipReasons` 数组（数量不符或有空行 → 回退模板）；`ecosystem-mvp-v2` prompt 同步（未发布，原地修改）。测试 80 个通过。
- iOS：`EventAnalysis.promotedRelationships`；新增共享的 `ResultLayout`（1/2/3 个 Figure 的坐标，舞台与结果页共用）和 `BondList`；3 个 Figure 时不画弧线，窄列（122pt）显示名字/EXP/台词；百分比标签不超出屏幕。
- 修复：此前 3 个 Figure 时第三个被喂的 Figure 会被放到边缘、变暗且不显示 Feed。
- 验证（真实网关）：朋友争执 → Anger/Joy/Fear 三列 + 3 段关系（Anger & Joy −4→3、Anger & Fear 12→19、Joy & Fear 0→5）；别车 → Anger/Fear/Sadness 三段；房租 → Anger/Fear 两列 + 弧线 + 1 段（12→21）。

### 2026-09-24（PRD 修订说明）
- 为所有与实现不一致的 PRD 条款加上 “修订（2026-09-24）” 说明，原文保留（取消的需求用删除线）：§29 信息架构（底部 tab）、§30 语音优先输入页、§30 取消 15 字下限、§31 C 关系规则（已有）、§31 D + MVP-UI-08 + MVP-FR-04 取消手动调整、§38.2/§38.3 Cornell 网关与环境变量、§39.1 + §40.2 uploads + §42.1 手机端转写与实际流程、§40.2 实际请求/响应格式与错误码、§41 contract 以代码为准及新增字段。
- PRD 开头新增 “修订记录” 总表，方便另一位开发者一次看到全部改动。
