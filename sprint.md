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
- [ ] 本地摘要：summary 目前是原文截断，接 LLM 后改为真正的摘要

> 注：设计稿加了 Figures / Memories 两个 tab，超出 PRD §29 的线性 MVP 结构；数据目前只在内存里，重启即重置。

## Sprint 1 — Functional Input（PRD §30）

- [x] Message 输入：「or type it instead」底部弹层 + 15 字符下限校验
- [ ] 语音录制（AVFoundation）：录音按钮、时长、暂停/继续/结束、删除重录、录音中 active state
- [ ] 语音转文字：已决定放在手机端（Apple Speech framework），后端只收文字、不做音频上传
- [ ] 语音 ≥ 5 秒有效输入校验
- [x] 语音为主入口、文字为次入口（UI 层面）
- [~] Listening 屏：转写逐行展示 + Figure 按关键词实时变大已完成，但转写内容目前是写死的示例句（等真实录音接入后替换）
- [ ] 错误状态：麦克风权限拒绝（回退文字 + 系统设置入口）、转录失败、分析失败保留 input、断网 retry
- [ ] 可选 prompt chips
- [ ] Loading 状态（新 UI 暂无；本地解析是瞬时的，接后端时需补）

## Sprint 2 — Functional Interpretation（PRD §31、§37–41）

- [x] 本地 fallback 解析器 `LocalEventInterpreter`（关键词匹配）
- [x] 结果页基础：event summary、Figure Feed、浓度、证据解释、promoted relationship
- [x] 后端脚手架：`apps/api`（Node 20 + TypeScript + Express 5），Cornell 网关兼容的 LLM client，`/health`，trace id，JSON 错误
- [x] Contracts v1：`packages/contracts` 4 个 JSON Schema + fixtures，Ajv 校验 + PRD §41.5 规则，26 个测试
- [x] 确认 Cornell 网关支持 strict JSON Schema 输出（`npm run smoke:llm`：`openai.gpt-5-mini`，`json_schema` 模式，约 2.5 s）
- [ ] Orchestrator `POST /api/v1/sessions/run`（A → 校验 → B → 校验 → 合并；§42.3 失败回退）
- [ ] Domain A — Input & Memory Interpreter（接 LLM，输出 §41 JSON contract）
- [ ] Domain B — Ecosystem Director（关系促进与后续互动）
- [ ] iOS 端接入后端，本地解析器保留为 fallback
- [ ] 确认前修改 interpretation：增减 Figure、调浓度、改 summary（MVP-FR-04）
- [x] Most fed 视觉（C 位 + 更大 + 更亮）、EXP bar 当前值 → 本次增量动画
- [ ] Relationship before/after 数值（目前只显示 +N bond）
- [ ] 可展开查看原始 transcript、`Edit input` 返回 Screen 1

## Sprint 3 — Mock Narrative（PRD §32–35）

- [~] Seed data：4 只 Figure 的 level / EXP / energy / 7 日趋势 + 3 条种子 memory 已加（`Models/FigureState.swift`）；threshold / owned memory / object 未加
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
