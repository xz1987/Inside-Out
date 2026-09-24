# PRD — Retrospective Memory Ecosystem for iOS

**版本：** MVP v0.1  
**日期：** 2026-09-24  
**平台：** iOS  
**状态：** Product logic draft  
**上游概念文档：** `emotion-pet-ecosystem.md`、`retrospective-memory-ecosystem.md`

> **Current MVP scope notice：** 当前可实现原型的权威范围见 **Section 28–36**。Section 5–17 描述完整产品未来可能使用的系统逻辑；Section 18–26 保留为 post-MVP 参考，不属于本轮开发范围。当前 MVP 只真实实现 daily-event input 与 interpretation，变形、掠夺、降级和 memory mask 均为预设 mock narrative。

> **修订记录（2026-09-24，实现过程中的产品 / 技术决策）** — 各条款旁均有“修订”说明，原文保留：
>
> | 位置 | 修订内容 |
> |---|---|
> | §29 信息架构 | 增加 Home / Figures / Memories 底部 tab；主流程仍为线性 |
> | §30 页面内容 | 语音优先首页（大麦克风），文字为次要入口；不使用 segmented control |
> | §30 Input Rules | 文字输入取消 15 字最低限制，只拒绝空白 |
> | §31 C、`MVP-UI-07`、`MVP-FR-03` | 关系只在本次共同出现的 Figure 之间产生，两两各一段；单个 Figure 不产生关系 |
> | §31 D、`MVP-UI-08`、`MVP-FR-04` | 取消手动调整解读；纠错方式为重新讲述（Edit and ask again） |
> | §38.2 / §38.3 | 使用 Cornell 网关；`LLM_HOST`、共用 `OPENAI_API_KEY`、reasoning effort |
> | §39.1、§40.2、§42.1 | 语音转文字在手机端；不实现音频上传；iOS 调用 `/sessions/run` |
> | §40.2 | 请求 / 响应字段改为 camelCase，列出实际格式与错误码 |
> | §41 | Contract 以 `packages/contracts/schemas/` 为准；新增 `voiceLine`、`explanation`、`promotedRelationships` 等 |

---

## 1. Product Summary

Retrospective Memory Ecosystem 是一个以回顾仪式为唯一输入方式的情绪养成 iOS app。

用户在想保存某个重要 moment 时，通过 voice recording 或 message 讲述事件。系统识别哪些情绪 figure 参与了这段记忆、每只 figure 的浓度，并把 input 转化为：

- Figure EXP；
- 可消耗 Energy；
- 一段带版本的 Event Memory；
- 从事件中提取的 Memory Object。

每只 figure 不只代表一种情绪，也需要保护属于自己或自己共同参与的 memories。随着新输入和 replay，figure 会变强；它们会围绕 memories 和 objects 形成联盟、借贷、敌对、争抢、守护与篡改关系。

Figure 的互动不是预写死的剧情。系统会在明确资格、成本和概率规则内随机选择互动，使生态每次都有变化，同时保留可解释性和可追溯性。

### 核心体验命题

> **Every emotion tries to preserve the memories that prove why it exists.**

---

## 2. Problem Statement

传统日记把情绪当作 event 的静态标签：用户记录一次，内容便保持不变。但真实的回忆会随着当前情绪、重复回想和后来的经历而变化。

本产品希望把这种变化变成可见、可互动的系统：

- Event 不是只属于时间线，也属于曾参与它的 figure；
- Replay 不只是查看，而是再次给参与者能量；
- Figure 越强，越有能力保护自己的 memory，也越可能侵入别人的 memory；
- 共同持有 memories 或 objects 的 figure 会形成联盟；
- 竞争失败、借能量、篡改和修复都会改变 figure 之间的关系；
- 用户可以看到“现在是谁在替我讲述这段记忆”。

---

## 3. Goals and Non-goals

### 3.1 MVP Goals

1. 让用户完成一次有仪式感的 retrospective voice/message input。
2. 让用户理解一个 event 可以有多只 figure 共同参与。
3. 让新 input 和 replay 都能真实改变 figure 的 Energy 与能力。
4. 让每只 figure 主动保护自己参与的 memories。
5. 让不同浓度的 figure 出现差异化且带受限随机性的互动。
6. 支持联盟、敌对、争抢、篡改、防御和盟友借能量。
7. 确保 Event Log 的所有改动有原始来源和版本历史。
8. 用最少 iOS 页面形成可测试的完整闭环。

### 3.2 Non-goals

- 不做实时或后台监听；
- 不把系统结果描述为心理诊断；
- 不允许 figure 永久删除 Source Archive；
- 不在 MVP 中加入陌生人社交、排行榜或 PvP；
- 不要求用户每天打卡；
- 不用付费或广告作为解锁 memory 的条件；
- 不在 MVP 中支持无限 emotion typology；
- 不让纯随机事件绕过浓度、关系、成本和 cooldown。

---

## 4. Design Principles

### 4.1 Retrospective Only

每次 input 必须由用户主动发起，并明确指向一个已经发生的 moment 或 event。

### 4.2 Memories Have Provenance

Figure 可以争夺 custody、改变 Visible Event Log 或遮蔽其他视角，但不能改写原始录音、message、创建时间和版本历史。

### 4.3 Every Interaction Has a Cost

保护、篡改、掠夺、借贷和修复都消耗 Energy，防止强 figure 无限扩张。

### 4.4 Random but Explainable

系统先计算行为资格与权重，再进行随机抽取。每次结果必须能够解释：

- 为什么这个 figure 可以行动；
- 为什么选择这个 memory；
- 为什么这次是守护、协商、掠夺或篡改；
- 消耗和获得了多少 Energy；
- 哪些关系因此改变。

### 4.5 Emotional Plurality

没有天然正确或错误的 figure。Joy 也可以遮蔽痛苦，Anger 也可以成功保护重要边界。

### 4.6 No Invisible Permanent Loss

Visible Event Log 可以被 mask、lock 或 rewrite，但用户永远能看到“这里发生过变化”。原始内容只能由用户主动删除。

---

## 5. Core Domain Model

### 5.1 Figure

```yaml
Figure:
  id: anger
  name: Anger
  lifetime_exp: 1240
  level: 7
  energy: 68
  energy_capacity: 100
  ecosystem_concentration: 0.42
  ability:
    protect: 1.15
    raid: 1.05
    tamper: 1.10
    negotiate: 0.85
  owned_memory_ids: []
  protected_memory_ids: []
  held_object_ids: []
  cooldowns: {}
```

### 5.2 Energy、EXP 与 Concentration

三个数值不可混用：

| 数值 | 性质 | 用途 |
|---|---|---|
| `Lifetime EXP` | 累积、不会被战斗消耗 | 升级并解锁长期能力 |
| `Energy` | 当前资源，会获得和消耗 | 守护、篡改、掠夺、借贷 |
| `Concentration` | 相对影响力 | 决定行为池、目标选择和叙述权 |

建议 MVP 数值范围：

- Lifetime EXP：无上限；
- Level：1–10；
- Energy：0–100；
- Ecosystem Concentration：四只 figure 合计为 100%。

### 5.3 Event Memory

```yaml
EventMemory:
  id: event_001
  source_archive_id: archive_001
  current_version_id: version_004
  importance: 0.82
  replay_count: 5
  integrity: 47
  participant_stakes:
    anger: 0.50
    fear: 0.25
    sadness: 0.15
    joy: 0.10
  custodians: [anger]
  co_owners: [fear]
  protected_by: [anger]
  memory_object_ids: [object_001]
  status: active
```

### 5.4 Memory Object

```yaml
MemoryObject:
  id: object_001
  source_event_id: event_001
  name: "一本被合上的笔记本"
  state: clear
  rarity: uncommon
  holder_ids: [anger]
  shared_by: []
  protection_bonus: 8
```

### 5.5 Relationship

每对 figure 共享一个 `Relationship Score`：

```yaml
Relationship:
  figures: [anger, fear]
  score: -18
  status: rival
  shared_memory_count: 2
  shared_object_count: 0
  outstanding_loans: 12
  recent_conflicts: 2
```

建议范围为 `-100` 至 `+100`：

| 分数 | 状态 | 基础效果 |
|---|---|---|
| `61–100` | Bonded Alliance | 高概率保护、借能量、共同持有 |
| `21–60` | Alliance | 可以响应求援和交换 object |
| `-20–20` | Neutral / Unstable | 视 memory 情况合作或竞争 |
| `-60–-21` | Rival | 提高挑战、争抢和拒绝借贷概率 |
| `-100–-61` | Hostile | 高概率篡改、掠夺和报复 |

---

## 6. Event Ingestion Logic

### 6.1 输入来源

MVP 只接受：

- `Retrospective Voice Recording`
- `Retrospective Message`

系统不接受被动监听产生的 event。

### 6.2 Event 解析

每个 input 被拆成一个或多个 event。每个 event 提取：

- What happened；
- Who was involved；
- Where / when；
- Turning point；
- Current interpretation；
- Emotional evidence；
- Concrete objects；
- Uncertainty；
- User-rated importance。

### 6.3 Figure 参与资格

一只 figure 被加入 event，需要满足至少一个条件：

1. 情绪证据分数达到系统阈值；
2. 用户主动添加该 figure；
3. 用户确认系统提出的候选 figure；
4. Replay 时用户明确邀请一只原本缺席的 figure 重新观看。

AI 的低置信度判断不能自动获得长期 stake。

### 6.4 Participant Stake

每只参与 figure 获得一个 event 内的 stake：

```text
Participant Stake
= 语义情绪强度 50%
+ 语音/文字表达强度 20%
+ 叙述篇幅 15%
+ 用户确认调整 15%
```

所有参与者的 stake 归一化为 100%。

### 6.5 Custody 与 Ownership

- Stake 最高者成为 `Primary Custodian`；
- Stake ≥ 20% 的其他 figure 成为 `Co-owner`；
- Stake < 20% 的 figure 是 `Witness`；
- 用户可以手动提升 Witness 为 Co-owner；
- Custodian 负责主动保护 memory，但不等于拥有事实真相。

### 6.6 EXP 与 Energy 奖励

```text
Base Event Value
= Importance × Input Richness × Confirmation

Figure EXP
= Base Event Value × Participant Stake

Energy Gain
= min(20, Figure EXP × 0.25)
```

MVP 建议：一次 ritual 为单只 figure 提供 `2–20 Energy`，避免单次输入直接造成 takeover。

### 6.7 Object Extraction

每个 event 在 MVP 中最多提取一个 Memory Object：

- 优先选择 input 中真实出现且与 turning point 有关的物品；
- 没有明确物品时，可以生成象征性 object，但必须标记 `symbolic`；
- 用户确认名称、含义与初始持有者；
- 共同持有 object 会提高 figure 间联盟关系。

---

## 7. Replay Logic

Replay 不是零成本查看，而是一次记忆再激活。

### 7.1 Replay 类型

| Replay 类型 | 被加强的对象 | 影响 |
|---|---|---|
| `Current Version` | 当前 narrator 与当前可见参与者 | 可能巩固现有篡改版本 |
| `Original Ritual` | 原始参与者 | 按最初 stake 分配 Energy |
| `Figure Perspective` | 被选择的 figure | 增强该 figure 与 memory 的连接 |
| `Mutation Timeline` | 所有曾参与修改的 figure | 少量关系与认知 EXP，不直接提高攻击能力 |

### 7.2 Replay 奖励递减

防止用户通过重复点击无限刷 Energy：

| 同一 event 的近期 Replay 次数 | Energy multiplier |
|---|---|
| 第 1 次 | `1.0` |
| 第 2 次 | `0.6` |
| 第 3 次 | `0.3` |
| 第 4 次及以后 | `0.1` |

24 小时后部分恢复。用户仍可以继续 replay，但不再产生大量战斗资源。

### 7.3 Replay 对 Memory Integrity 的影响

被反复 replay 的 memory 更难被掠夺或篡改：

```text
Memory Integrity
= Base Integrity
+ round(8 × ln(1 + Replay Count))
+ Object Protection Bonus
+ Active Guard Energy
```

因此：

- Replay 会加强相关 figure；
- Replay 也会加固 memory；
- 越熟悉、越常被回顾的 memory，攻击成本越高；
- Replay 当前篡改版本可能同时强化侵占者，因此 replay 选择本身有后果。

---

## 8. Figure Concentration

### 8.1 计算建议

```text
Raw Influence
= Current Energy × 0.45
+ Recent Confirmed EXP × 0.35
+ Held Memory Weight × 0.10
+ Held Object Weight × 0.10

Concentration_i
= Raw Influence_i / Sum(All Raw Influence)
```

使用最近 30 天滚动窗口，使 figure 可以变化但不会因一次 event 瞬间失控。

### 8.2 浓度状态

| 浓度 | 状态 | 可进入的主要行为池 |
|---|---|---|
| `0–10%` | Isolated | 躲藏、旁观、请求帮助、放弃守护、造成 mask/lock |
| `11–25%` | Faint | 小额守护、寻求联盟、共享 object、避免冲突 |
| `26–45%` | Present | 守护、协商、共同 replay、交换 object、有限挑战 |
| `46–64%` | Dominant | 宣称 custody、强化防线、施压、挑战 narrator |
| `65–79%` | Aggressive | 可主动篡改或掠夺非己方 memory |
| `80–100%` | Takeover | 高概率扩张、重写多个 event、压制弱 figure |

Takeover 不应是奖励状态。它能获得更大控制力，但每次行动成本和多方敌意也更高。

---

## 9. Constrained Random Interaction Engine

用户要求每次在 Isolation 与 Takeover 两个极端之间随机出现不同互动。MVP 使用三阶段事件引擎：

```text
1. Eligibility：谁现在有资格行动？
2. Weighting：哪些行为和目标更可能被选择？
3. Resolution：投入 Energy 后，结果是什么？
```

### 9.1 Eligibility

Figure 必须满足以下条件才会进入一次 interaction draw：

- 不在 cooldown；
- Energy 高于行为最低成本；
- 当前存在可互动的 memory、object 或 figure；
- 行为与浓度状态匹配；
- 同一 event 没有处于临时安全期；
- 用户没有把目标设为 `Protected from Autonomous Conflict`。

### 9.2 Interaction Pool

| Interaction | 最低浓度 | 最低 Energy | 典型目标 |
|---|---:|---:|---|
| Observe | 0% | 0 | 任意相关 memory |
| Request Witness | 5% | 2 | 盟友或共同参与者 |
| Guard Memory | 10% | 5 | 自己参与的 memory |
| Share Object | 15% | 4 | 中立或正向关系 figure |
| Lend Energy | 20% | 5 | 盟友 |
| Negotiate Custody | 25% | 8 | 共同 memory |
| Challenge Narrator | 40% | 12 | 自己参与但非 narrator 的 memory |
| Tamper Component | 65% | 动态 | 不属于自己的 memory 成分 |
| Raid Memory/Object | 65% | 动态 | 非己方 custody/object |
| Takeover Chain | 80% | 动态 | 多个主题相近的 memories |

### 9.3 行为权重

不是所有 eligible 行为概率相同：

```text
Behavior Weight
= Concentration Modifier
× Relationship Modifier
× Shared Memory Modifier
× Energy Confidence
× Recent Outcome Modifier
× Small Random Jitter
```

建议 random jitter 限制在 `0.85–1.15`，避免随机值推翻主要逻辑。

### 9.4 关系对概率的影响

- 正向关系增加 Guard、Lend、Share、Joint Replay；
- 负向关系增加 Challenge、Tamper、Raid；
- 共同 memory/object 增加结盟概率，也增加 custody dispute 的可能；
- 一次成功援助降低未来互相攻击概率；
- 一次成功掠夺显著增加 retaliation 权重；
- 连续冲突会触发 cooldown，防止无限报复循环。

### 9.5 可复现随机性

每次 interaction 保存 random seed、候选行为和最终权重。用户不需要看到数学细节，但可以点击 `Why did this happen?` 查看简化解释。

---

## 10. Memory Protection Logic

### 10.1 Figure 的守护责任

Figure 会自动尝试保护：

1. 自己是 Primary Custodian 的 memory；
2. 自己 stake ≥ 20% 的共同 memory；
3. 自己持有 object 所指向的 memory；
4. 用户明确委托它保护的 memory。

### 10.2 Active Guard

Figure 可以把一部分 Energy 存入 memory，形成 Guard Reserve：

```text
Guard Strength
= Reserved Energy × Protect Ability
+ Relationship Support
+ Object Protection Bonus
```

Guard Reserve 在没有攻击时不会每天消失，但 figure 无法同时把这部分 Energy 用于掠夺。

### 10.3 用户保护

用户可以为重要 memory 设置：

- `Anchor Fact`：指定句子不可被 rewrite；
- `Protected Object`：object 不可被转移；
- `Conflict Pause`：暂时不参与自动争抢；
- `Source Only Replay`：默认 replay 原始 ritual。

用户保护不是一种 figure Energy，因此不会破坏 figure 之间的游戏经济。

---

## 11. Alliance、Rivalry 与共同持有

### 11.1 联盟形成

以下事件增加关系分数：

| 事件 | Relationship change |
|---|---:|
| 共同参与一个 confirmed event | `+2` |
| 共同持有 memory | `+3` |
| 共同持有 object | `+5` |
| 成功借出 Energy | `+4` |
| 联合保护成功 | `+6` |
| Shared Reconstruction | `+8` |

共同持有不自动等于永久联盟。两个 figure 可能因为同一 memory 变得亲密，也可能因为谁有权讲述它而产生争抢。

### 11.2 敌对形成

| 事件 | Relationship change |
|---|---:|
| Challenge Narrator | `-3` |
| Tamper Attempt | `-8` |
| Tamper Success | `-12` |
| Raid Attempt | `-10` |
| Raid Success | `-18` |
| 拒绝紧急借贷 | `-2` |
| 未偿还 Energy Loan | 每周期 `-2` |

### 11.3 负面关系反馈

负面关系会提高未来 attack 权重，但必须设置上限：

```text
Hostility Attack Bonus = min(35%, abs(negative relationship) × 0.35%)
```

避免关系跌到最低后形成无法停止的攻击循环。

---

## 12. Tamper Logic

Tamper 是修改已有 memory 中的某个成分，但不转移整个 memory 的 custody。

### 12.1 可篡改成分

- Event title；
- Current summary；
- Narrative order；
- Visual emphasis；
- Figure visibility；
- Object appearance；
- Current interpretation；
- 某个 segment 的 mask 状态。

### 12.2 不可篡改成分

- Source Archive；
- 创建时间；
- 用户设置的 Anchor Fact；
- Mutation History；
- 用户手动删除记录之外的 provenance。

### 12.3 发起条件

Figure 可以发起 Tamper，当且仅当：

- Concentration ≥ 65%；
- Energy ≥ 动态成本；
- 它不是目标成分的当前 owner；
- 目标 memory 与 figure 存在语义或 object 连接；
- 目标不在 cooldown 或 Conflict Pause；
- Tamper 概率抽取成功。

### 12.4 Tamper 成本

```text
Tamper Cost
= 10
+ round(1.8 × Memory Integrity)
+ round(4 × ln(1 + Replay Count))
+ Protected Component Bonus
```

实际产品数值上线前需调参；MVP 可以对最终成本设 `15–60 Energy` 上限。

### 12.5 Tamper 结果

成功时：

- 生成新的 Visible Event Log version；
- 攻击方获得该 component 的 influence；
- 防守方损失已投入的防御 Energy；
- 双方关系下降；
- 被修改内容显示 mutation 痕迹；
- Source Archive 不变。

失败时：

- Visible Event Log 不改变；
- 攻击方损失部分 Energy；
- 防守方消耗实际用于抵抗的 Energy；
- 防守方获得少量 Protect EXP；
- 目标进入 temporary immunity。

---

## 13. Raid Logic

Raid 是争夺 memory custody 或 Memory Object 的持有权。

### 13.1 Raid 类型

- `Object Raid`：争夺 extracted object；
- `Custody Raid`：争夺 Primary Custodian；
- `Fragment Raid`：夺取一个 event segment 的 narration right；
- `Chain Raid`：Takeover figure 对主题相似 memories 发起连续扩张；MVP 只展示概念，暂不实现。

### 13.2 Raid Target Weight

Figure 更可能攻击：

- 与自己当前主题高度相关的 memory；
- 被敌对 figure 持有的 memory；
- 含有稀有 object 的 memory；
- 近期频繁 replay 的 memory；
- 防守方 Energy 较低的 memory；
- 自己曾经参与但被排除的 memory。

### 13.3 Raid 成本

```text
Raid Cost
= 15
+ Memory Integrity
+ Replay Resistance
+ Object Rarity Cost
+ Existing Guard Strength
```

Replay 越多，memory 越稳固，所需攻击 Energy 越高。

### 13.4 Resolution

```text
Attack Power
= Committed Attack Energy
× Raid Ability
× Random Factor [0.90, 1.10]

Defense Power
= Memory Integrity
+ Defender Energy × Protect Ability
+ Ally Loan Energy
+ Object Protection Bonus
× Random Factor [0.95, 1.05]
```

- `Attack Power > Defense Power`：Raid 成功；
- 否则：Raid 失败；
- 平局默认防守成功。

### 13.5 Raid 成功

- Object holder 或 Primary Custodian 转移；
- 原参与 stake 和 Source Archive 不改变；
- 攻击方消耗全部 committed Energy；
- 防守方损失实际投入的 Defense Energy；
- 防守方 Energy 额外下降 `0–10`，取决于 object rarity；
- 关系分数下降；
- 目标 memory 获得 `contested` 状态；
- 生成可 replay 的 conflict event。

### 13.6 Raid 失败与 Energy Refund

这里采用以下产品假设：**Raid 失败后，攻击方会根据目标 object/memory 状态收回一部分未耗尽 Energy；其余被视为冲突成本。**

| 目标状态 | 攻击方返还比例 |
|---|---:|
| 普通、无人守护 | `60%` |
| Shared Object / Co-owned Memory | `40%` |
| Active Guard | `25%` |
| Protected Object / Anchor Memory | `10%` |
| Sealed / Highly Consolidated | `0%` |

返还比例根据目标在攻击开始前的状态确定，防止攻击方在结果后选择最有利解释。

防守方只消耗实际用于抵抗的 Energy；未使用部分返回。

### 13.7 Cooldowns

- 单只 figure 每完成一次主动攻击，至少等待 2 个 ritual/replay action；
- 同一个 memory 被攻击后获得 24 小时 immunity；
- 同一对 figure 连续发生 2 次冲突后，必须先抽取一次非攻击 interaction；
- Takeover 也不能绕过 cooldown。

---

## 14. Ally Energy Loan Logic

当被攻击 figure 的可用 Defense Energy 不足时，可以向盟友借 Energy。

### 14.1 可请求对象

盟友需满足：

- Relationship Score > 20；
- 与目标 memory 或 object 有共同 stake，或与防守方存在 Alliance；
- Energy 高于自己的最低安全储备；
- 不在冲突 cooldown；
- 没有与攻击方处于更高等级的 Alliance，或愿意承担关系损失。

### 14.2 借贷接受概率

```text
Loan Acceptance Probability
= 25%
+ Relationship Bonus
+ Shared Memory Bonus
+ Object Connection Bonus
- Self-risk Penalty
- Existing Debt Penalty
```

概率限制在 `10–85%`。

### 14.3 借贷顺序

1. 防守方计算 Energy shortfall；
2. 按关系、共同 memory 和可用 Energy 排序盟友；
3. 最多向两名盟友请求；
4. 每名盟友独立进行受限随机判断；
5. 借到的 Energy 直接进入当前 Defense，不进入日常可用余额；
6. 结果写入 Loan Ledger。

### 14.4 偿还

- 防守方未来获得新 EXP 时，默认将 20% Energy Gain 用于还贷；
- 盟友可以主动免除部分债务，增加关系；
- 长期不偿还会缓慢降低关系和未来接受概率；
- 用户可以查看 debt，但不能直接购买 Energy 偿还。

### 14.5 联盟保护结果

联合保护成功：

- 所有参与者获得 Protect EXP；
- Relationship Score 上升；
- memory 可以变为 Shared Protected Memory；
- 攻击方与所有防守参与者关系下降。

联合保护失败：

- Loan 仍记录，但偿还比例降低；
- 盟友获得少量 Witness EXP；
- 可能触发 Rescue、Withdrawal 或 Retaliation 候选事件。

---

## 15. Interaction Examples Across Concentration States

每次系统更新状态时，从符合资格的行为池中随机选择 0–2 个 interaction。以下是两个极端之间的示例，不代表固定剧情。

| Figure 状态 | 可随机出现的互动 |
|---|---|
| Isolated | 躲进 sealed memory、拒绝 replay、请求某个 object 陪伴、让相关 fragment 进入 lock |
| Faint | 向盟友请求见证、贡献少量守护 Energy、把 object 暂借给强 figure、让自己的文字短暂显影 |
| Present | 与共同持有者巡逻 memory、交换 object、协商 narrator、联合 replay、保护弱 figure 的 fragment |
| Dominant | 宣称主叙述权、要求重新分配 custody、为多个 memory 建立 guard、挑战另一个 narrator |
| Aggressive | 篡改 title、抢夺 object、掠夺 fragment、攻击敌对 figure 的 custody、迫使盟友选边 |
| Takeover | 连续重写相似 memories、隔离敌对 figure、把多个 objects 收进同一领地、引发联盟联合防御 |

### 示例 A：共同 Memory 形成联盟

- Sadness 和 Joy 都在毕业 event 中拥有 ≥20% stake；
- 两者共同持有一张车票 object；
- 系统抽到 `Joint Replay`；
- 双方获得少量 Energy，关系 `+5`；
- 车票变为 Shared Object；
- 未来其中一方被攻击时，另一方的 loan acceptance probability 上升。

### 示例 B：负面关系提高篡改概率

- Anger 曾成功抢走 Fear 的 presentation memory；
- 双方关系下降到 `-48`；
- Fear 通过新 event 升到 67% concentration；
- 系统增加 Fear 对 Anger-owned memories 的 Tamper/Raid weight；
- 但仍需通过 Energy、integrity 与 cooldown 检查，不会自动报复。

### 示例 C：弱 Figure 借 Energy 守护

- Sadness 只有 14 Energy，却需要保护一段与 Joy 共同持有的 goodbye memory；
- 所需防御为 28；
- Sadness 向 Joy 请求 14 Energy；
- 因双方共享 object 且关系为 +57，借贷概率较高；
- Joy 借出 Energy 后，双方联合防御；
- 若成功，memory 获得 Shared Protected 状态。

---

## 16. Memory State Machine

```text
Created
  ↓
Active
  ├── Guarded
  ├── Shared
  ├── Contested
  │     ├── Tampered
  │     └── Raided
  ├── Masked
  └── Locked

Tampered / Raided / Masked / Locked
  ↓ new ritual, replay, alliance, or reconstruction
Reconstructed
  ↓
Active / Shared / Guarded
```

Source Archive 始终独立于该状态机。

---

## 17. Core User Flows

### Flow A — 创建新 Memory

```text
Home
→ Start Ritual
→ Voice / Message Input
→ Review Event Extraction
→ Confirm Figure Mix
→ Confirm Object
→ Save Memory
→ See Figure EXP and Energy Result
→ Return to Habitat
```

### Flow B — Replay 并加强 Figure

```text
Memories
→ Open Event
→ Choose Replay Type
→ Replay
→ Show Energy + Integrity Changes
→ Resolve Possible Interaction
→ View Updated Relationships
```

### Flow C — 自动争抢 / 篡改

```text
Energy or Concentration Update
→ Interaction Eligibility Check
→ Weighted Random Draw
→ Attack Intent Created
→ Defender Commits Energy
→ Optional Ally Loan
→ Resolve Conflict
→ Update Memory Version / Custody
→ Update Energy and Relationships
→ Show Conflict Story
```

### Flow D — 保护旧 Memory

```text
Event Detail
→ Assign Guardian
→ Commit Guard Energy
→ Optional Anchor Fact / Protected Object
→ Memory becomes Guarded
→ Energy removed from general pool
```

---

## 18. Post-MVP Full-product Information Architecture Reference

### Bottom Navigation

建议使用四个主入口：

1. `Habitat`
2. `Memories`
3. `Ritual` — 中央主按钮
4. `Figures`

Settings 从 Habitat 右上角进入。Conflict Resolution 作为全屏 sheet，而不是单独 tab。

---

## 19. Post-MVP Full-product Screens Reference

以下 **8 个页面/状态** 属于完整产品参考，并非当前 MVP 必须实现的页面。

### Screen 1 — Onboarding & Memory Consent

**目的：** 解释 retrospective 输入、记忆版本和隐私边界。

**必须包含：**

- 产品不是实时监听；
- Voice/message 如何被保存；
- Source Archive 与 Visible Event Log 的区别；
- Figure 可以修改可见版本，但不能改写原始档案；
- 麦克风、通知和本地数据权限；
- 开始使用按钮。

**MVP acceptance：** 用户未同意录音和 memory version 逻辑前，不能开始 voice ritual。

### Screen 2 — Habitat Home

**目的：** 一眼看见四只 figure 当前状态和生态变化。

**必须包含：**

- 四只 figure 的体型、Energy 和 concentration；
- 当前 Alliance / Rival 提示；
- 最近发生的守护、篡改、掠夺或借贷；
- 需要用户注意的 locked/contested memory；
- `Start Ritual` 主 CTA；
- 进入 Settings。

**MVP acceptance：** 用户能在 5 秒内判断哪只 figure 最强、哪只最弱、最近是否发生冲突。

### Screen 3 — Retrospective Ritual Capture

**目的：** 录入重要 moment。

**必须包含：**

- Voice / Message 模式切换；
- 主 prompt：`What happened, and what stays with you now?`；
- 录音状态、暂停、继续、结束；
- message 输入；
- 重要度选择；
- 放弃且不保存；
- 明确的隐私状态。

**MVP acceptance：** 用户可以只用语音、只用文字或混合输入完成 ritual。

### Screen 4 — Event & Figure Review

**目的：** 在写入长期系统前，让用户确认 AI 提取结果。

**必须包含：**

- Event summary；
- Turning point 和 uncertainty；
- Figure participants；
- 每只 figure 的浓度 slider；
- Custodian / Co-owner / Witness 预览；
- Extracted Object 名称、含义和初始 holder；
- EXP 与 Energy 预计变化；
- Edit、Reject、Confirm。

**MVP acceptance：** 所有 AI 判断都可修改；未确认内容不能进入长期 EXP。

### Screen 5 — Ritual Result

**目的：** 展示保存 event 对生态造成的结果。

**必须包含：**

- 新 Event Memory 卡片；
- EXP / Energy 动画；
- Object extraction；
- Figure concentration 的 before/after；
- 新联盟、敌对或 custody 变化；
- 进入 Event Detail 或返回 Habitat。

**MVP acceptance：** 用户能理解“为什么某只 figure 变强”。

### Screen 6 — Memories Library

**目的：** 浏览所有 event 和当前记忆状态。

**必须包含：**

- 时间线和 object 两种浏览方式；
- Filter：Figure、Active、Guarded、Contested、Tampered、Masked、Locked；
- 当前 narrator；
- Replay count；
- Mutation indicator；
- 搜索。

**MVP acceptance：** 用户能找到一段被修改或 locked 的 memory，并看出状态差异。

### Screen 7 — Event Detail & Replay

**目的：** 查看、重播、保护和比较一段 memory。

**必须包含：**

- Current Visible Version；
- Figure participants 与 stake；
- Custodian、Co-owner 和 Guardian；
- Memory Object；
- Replay 类型选择；
- Replay count 与 Memory Integrity；
- Commit Guard Energy；
- Anchor Fact / Protect Object；
- Mutation History；
- Original Ritual 入口；
- `Why did this change?`。

**MVP acceptance：** 用户可以比较当前版本与至少一个历史版本，并完成一次 replay 或 guard。

### Screen 8 — Figure Profile & Relationships

**目的：** 理解单只 figure 的力量、领地和社会关系。

**必须包含：**

- Lifetime EXP、Level、Energy、Concentration；
- Protect / Raid / Tamper 能力；
- Owned、Co-owned、Protected memories；
- Held / Shared objects；
- 与其他 figure 的关系分数与状态；
- Energy loan/debt；
- 最近 interaction；
- 当前 cooldown。

**MVP acceptance：** 用户能解释该 figure 为什么可能守护、借贷或攻击某个 memory。

### Full-screen State — Conflict Resolution

Conflict Resolution 可作为 Screen 7 或 Habitat 上方弹出的全屏 sheet，不需要独立 tab，但必须是完整状态。

**必须包含：**

- 攻击方、目标和行为类型；
- 所需 Energy 与 replay/integrity 成本；
- 防守方投入；
- 盟友借贷请求与响应；
- 成功或失败；
- Energy refund；
- ownership/version/relationship 变化；
- `Why did this happen?`；
- View Memory。

**MVP acceptance：** 用户无需理解公式，也能知道双方付出了什么、memory 改变了什么。

---

## 20. Future Full-system Functional Requirements

### Input and Analysis

- `FR-01` 用户必须主动开始每次 ritual。
- `FR-02` 支持 voice、message 和混合 input。
- `FR-03` 系统可从 input 生成一个或多个 event。
- `FR-04` 用户可以编辑 figure 类型和浓度。
- `FR-05` 未确认分析不得进入长期 EXP 或 Energy。
- `FR-06` 每个 MVP event 最多生成一个 object。

### Memory and Replay

- `FR-07` 每个 event 必须保留 Source Archive、Visible Version 和 Mutation History。
- `FR-08` Replay 必须记录类型、次数和 Energy 结果。
- `FR-09` Replay 奖励必须递减。
- `FR-10` Replay count 必须提高攻击成本。
- `FR-11` 用户可以设置 Anchor Fact、Protected Object 和 Conflict Pause。

### Figure Economy

- `FR-12` Lifetime EXP、Energy 和 Concentration 必须分开存储和展示。
- `FR-13` 新 input 和 replay 都可以增强相关 figure。
- `FR-14` 所有攻击和防御行为必须消耗 Energy。
- `FR-15` Figure 必须优先保护自己参与或持有的 memory。

### Relationships and Conflict

- `FR-16` 共同 memory/object 必须影响 relationship。
- `FR-17` 负面 relationship 必须提高攻击权重，但不能绕过资格检查。
- `FR-18` Concentration ≥ 65% 才能主动 Tamper/Raid。
- `FR-19` 攻击成本必须随 replay count 和 integrity 增加。
- `FR-20` 防守方 Energy 不足时可以请求最多两个盟友。
- `FR-21` 借贷、偿还和免除必须被记录。
- `FR-22` 攻击失败必须按目标状态计算 refund。
- `FR-23` 所有冲突必须更新 relationship 和 cooldown。
- `FR-24` Figure 不得修改 Source Archive。

### Explainability

- `FR-25` 每个自动 interaction 必须保存候选行为、权重和 random seed。
- `FR-26` 用户可查看简化版 `Why did this happen?`。
- `FR-27` 每次 memory mutation 必须生成新 version。
- `FR-28` Mask/Lock 不得完全隐藏“变化发生过”的事实。

---

## 21. Non-functional Requirements

### Privacy

- 原始录音默认本地加密存储；
- 远程 transcription/analysis 前必须明确说明；
- 用户可以选择分析后删除原始音频；
- 删除前展示会影响的 memories、replays 和 evidence；
- 不从通讯录自动识别他人身份；
- 通知内容默认不展示敏感 event 摘要。

### Reliability

- 所有 Energy、ownership、relationship 变更使用事务式写入；
- Conflict resolution 必须幂等，避免 app 重开后重复扣点；
- Mutation History append-only；
- 随机结果必须可由 seed 复现；
- 离线 ritual 可以暂存，联网后再分析。

### Accessibility

- 不只依赖颜色表达 figure 和关系；
- Figure 动画支持 Reduce Motion；
- VoiceOver 能读出 Energy、Concentration 和 memory state；
- Masked text 需有文字替代说明；
- 所有 replay 可关闭声音并阅读 transcript。

### iOS Interaction Guidance

- 主导航采用 iOS 标准 TabView / NavigationStack 模式；
- 图标优先使用 SF Symbols；
- 使用 semantic colors，支持 Light/Dark Mode；
- 冲突动画不能阻止用户退出或查看原始版本；
- 麦克风录制必须持续显示系统级可感知状态。

---

## 22. Safety and Economy Guardrails

### 22.1 防止强者恒强

- Replay Energy 递减；
- 高浓度 figure 的主动攻击成本提高；
- Takeover 状态增加多方结盟防守概率；
- 单个 figure 不能同时守护无限 memories；
- 连续攻击触发 cooldown；
- 弱 figure 可通过 Witness、Loan 和 Shared Reconstruction 恢复，而不必先赢得战斗。

### 22.2 防止记忆永久丢失

- Source Archive 不受 figure 行为影响；
- 用户可以查看 mutation 存在；
- Raid 只改变 custody/holder，不改变原始参与者；
- Tamper 必须创建新版本；
- 用户可以暂停自动冲突；
- 不允许自动删除 event 或 object。

### 22.3 防止随机结果不可理解

- Random jitter 不超过主要权重的 ±15%；
- 没有资格的行为不会进入抽取池；
- 每次最多出现两个自动 interaction；
- 所有 interaction 都有 explanation；
- 关键 memory 可由用户主动保护。

---

## 23. Analytics and Validation

### Product Metrics

- Ritual completion rate；
- Figure mix edit rate；
- Object confirmation/edit rate；
- Replay rate by type；
- Event Detail revisit rate；
- Conflict explanation open rate；
- Memory protection usage；
- Ally loan acceptance rate；
- Masked/locked memory revisit rate；
- User-triggered Conflict Pause rate；
- Source Archive deletion rate。

### Qualitative Questions

1. 用户是否能区分 EXP、Energy 和 Concentration？
2. 用户是否理解 replay 会强化某个版本？
3. 自动冲突感觉像有生命的生态，还是像无意义的数值惩罚？
4. Figure 保护自己的 memory 是否符合用户对情绪的直觉？
5. 联盟和借贷是否让共同情绪显得更有关系？
6. 篡改是否具有戏剧性，同时仍保留用户的控制感？
7. 用户能否理解 Raid 夺走的是 custody，而不是原始事实？

---

## 24. Post-MVP Full Build Roadmap

### Phase 1 — Memory Ritual Foundation

- Onboarding；
- Voice/message ritual；
- Event extraction review；
- Figure mix；
- EXP/Energy；
- Object extraction；
- Memories Library；
- Event Detail。

### Phase 2 — Replay and Protection

- Replay types；
- Replay diminishing returns；
- Memory Integrity；
- Guard Energy；
- Anchor Fact / Protected Object；
- Figure Profile。

### Phase 3 — Social Ecology

- Relationship Score；
- Shared memory/object；
- Alliance / Rival states；
- Energy loan ledger；
- Constrained random interaction engine。

### Phase 4 — Conflict

- Tamper；
- Object Raid；
- Custody Raid；
- Defense and ally loans；
- Refund；
- Cooldown；
- Conflict Resolution UI；
- Mutation History comparison。

---

## 25. Future Full-system Acceptance Scenario

完整系统未来达标时，以下故事应当能够真实发生；当前 MVP 只会 mock 其中的变形、掠夺与 mask 部分：

1. 用户通过 voice ritual 记录一次重要 event；
2. 系统识别 Anger、Fear 和 Sadness，用户调整浓度并确认；
3. Anger 成为 Custodian，Fear 成为 Co-owner；
4. Event 提取出一个 Memory Object；
5. 用户 replay 两次，Anger 和 Fear 获得 Energy，memory integrity 上升；
6. Anger 与 Fear 因共同 memory 形成较弱 alliance；
7. Joy 因后续 event 变成 Aggressive，并抽中对该 object 的 Raid；
8. Anger 自动投入 Energy 保护；
9. Anger Energy 不足，向 Fear 请求借贷；
10. Fear 基于关系和共同 stake 随机决定是否借出；
11. 系统解决 Raid，计算成功/失败、refund、Energy 和关系变化；
12. 用户从 Conflict Resolution 看懂发生原因；
13. 若 memory 被篡改，用户可以比较新版本、旧版本和 Source Archive；
14. 用户可以保护关键事实或暂停未来冲突。

---

## 26. Post-MVP Open Product Decisions

以下问题应通过 prototype testing 决定，而不是现在写死：

1. Interaction 是在 ritual/replay 后立即发生，还是延迟到下次打开 app？
2. 用户能否主动命令 figure 发起 Raid，还是只能观察自动行为？
3. Energy loan 是否必须偿还，还是允许盟友 gift？
4. Raid 失败后的 refund 比例是否足够有风险感？
5. Replay Current Version 是否应明确警告“这会强化当前 narrator”？
6. Locked memory 是否允许用户随时查看 Source Archive？
7. 用户手动保护是否完全阻止自动攻击，还是只增加防御成本？
8. Figure 能否拒绝用户委托的守护任务？

### MVP 推荐答案

- Interaction 只在 ritual、replay 或用户打开 app 时结算，不在后台偷偷发生；
- 用户不能主动命令攻击，只能通过 replay、守护和邀请 figure 影响生态；
- Loan 默认偿还，但盟友可随机 gift；
- Current Version replay 显示轻量影响提示；
- 用户随时可以进入 Source Archive；
- `Conflict Pause` 完全阻止自动攻击；
- Figure 可以因 Energy 不足拒绝新增守护，但不能丢弃已有 memory。

---

## 27. Final System Loop

```text
Retrospective Ritual
        ↓
Event + Figure Participants + Concentration
        ↓
EXP + Energy + Memory Object
        ↓
Custody + Co-ownership + Protection
        ↓
New Input / Replay strengthens Figures and Memory
        ↓
Concentration changes Interaction Pool
        ↓
Guard / Alliance / Loan / Challenge / Tamper / Raid
        ↓
Energy, Relationship, Ownership and Event Version change
        ↓
User replays or records a new retrospective ritual
        ↓
The ecosystem remembers differently again
```

> **A figure grows by being remembered, survives by protecting its memories, and becomes dangerous when it needs other memories to prove its version of the self.**

---

## 28. Current MVP Definition — Linear Narrative Prototype

### 28.1 MVP 要验证的核心假设

当前 MVP 不验证完整 Energy economy、随机 interaction 或长期 memory simulation，只验证用户是否能够理解下面这条最小叙事：

```text
我讲述今天发生的一件事
        ↓
系统识别哪些 Figure 得到 Feed
        ↓
系统识别哪一对 Figure 的关系被促进
        ↓
其中一只 Figure 因 EXP 达标发生变形
        ↓
变形后的 Figure 成功掠夺另一只 Figure 的 Memory
        ↓
被掠夺 Figure 降到最低级
        ↓
与它相关的 Memory 被 Masked
```

### 28.2 真实功能与 Mock 功能边界

| 模块 | MVP 类型 | 实现要求 |
|---|---|---|
| Daily event voice/message input | Functional | 接收用户实际输入 |
| Event summary | Functional | 根据本次输入生成或调用分析结果 |
| Which figure gets fed | Functional | 输出本次获得 Feed 的 Figure 和数量 |
| Which relationship is promoted | Functional | 输出被促进的一对 Figure 和原因 |
| EXP 达标 | Mock | 使用预设阈值和补点让目标 Figure 必然达标 |
| Figure 变形 | Mock | 使用固定 before/after asset 和动画 |
| Raid 发起与判定 | Mock | 不计算真实攻击、防御、随机数或 Energy |
| Raid success | Mock | 结果固定为成功 |
| Victim 降到最低级 | Mock | 直接从预设等级变为 Level 1 |
| Related memory masked | Mock | 对预设 memory 应用固定 mask visual |

### 28.3 Mock 的产品表达

在 prototype code 和测试记录中，所有模拟结果必须标记为：

```yaml
simulation_mode: true
scenario_id: "mvp_evolve_raid_mask_v1"
```

面向测试用户时，推荐在进入体验前说明：

> “This prototype uses a staged evolution and memory-conflict sequence to demonstrate the future system.”

这样用户仍可评价概念与体验，但不会误以为 Raid 是真实算法根据其个人情绪做出的结论。

---

## 29. MVP Information Architecture

当前 MVP 使用线性 `NavigationStack`，不需要完整 TabView、Memory Library、Figure Library 或 Settings。

> **修订（2026-09-24）— 信息架构**：按 Claude Design 设计稿，App 增加底部 tab：Home（Screen 1 输入）、Figures（Figure 等级 / 能量 / 关系一览）、Memories（已保存的记忆列表）。主流程 Screen 1 → Screen 2（→ Screen 3–5）仍然是线性的，tab 只在 Home / Figures / Memories 页显示，结果页和后续 mock 叙事页不显示 tab。


### 最小页面结构

```text
Screen 1 — Daily Event Input
        ↓
Screen 2 — Interpretation & Feeding
        ↓
Screen 3 — EXP Threshold & Transformation
        ↓
Screen 4 — Mock Raid Success
        ↓
Screen 5 — Aftermath & Masked Memory
```

Screen 5 内包含一个可展开的 `Masked Memory Detail` 状态，不单独增加主流程页面。

### 导航原则

- 主流程只能向前推进，避免用户跳过因果关系；
- Screen 1–2 支持返回修改 input；
- 一旦进入 Screen 3 的 mock narrative，不再重新运行 analysis；
- Screen 5 提供 `Replay Demo` 和 `Start Over`；
- `Start Over` 重置所有 mock 状态，但可以选择保留上一条 input 方便重复测试。

---

## 30. Screen 1 — Talk About a Daily Event

### 页面目的

让用户通过 voice 或 message 回顾今天发生的一件具体事情。

### Primary Prompt

> **Talk about a daily event.**  
> What happened, and what part of it stays with you now?

### 页面内容

- 页面标题：`Today's Moment`；
- 一句简短说明：`Choose one event you want your figures to remember.`；
- Voice / Message segmented control；
- Voice 模式：
  - 录音按钮；
  - 录音时长；
  - 暂停、继续、结束；
  - 删除并重录；
  - 录音中的明显 active state；
- Message 模式：
  - 多行文本输入；
  - 建议长度 1–500 words；
- 可选 prompt chips：
  - `Something that surprised me`
  - `Something that stayed unresolved`
  - `A small win`
  - `A difficult interaction`
- 主按钮：`Let the figures listen`；
- 次按钮：`Clear`。

> **修订（2026-09-24）— 语音优先的输入页**：按设计稿，Screen 1 不再使用 Voice / Message segmented control。首页中央是大号麦克风按钮（“Tap to tell me”），四个 Figure 围绕它；文字输入是次要入口（“or type it instead” → 底部弹层，按钮 “Share with my Figures”）。标题改为 “What stayed with you today?”。录音中的 Listening 页实时显示转写，并让相关 Figure 放大靠近。prompt chips 暂未实现。


### Input Rules

- 至少需要 5 秒有效语音或 15 个字符；

> **修订（2026-09-24）— 取消文字最少字数**：文字输入不设最少字数，只拒绝空白输入（“tired” 这样一个词也是有效的情绪瞬间）。后端仅保留 4000 字符上限，用于防止误粘贴超长文本。语音 ≥5 秒的规则暂不变，待真实录音接入后再评估。

- 空输入时主按钮 disabled；
- Voice 和 Message 可以二选一，当前 MVP 不要求混合输入；
- 用户提交后显示分析 loading state；
- Loading 文案：`The figures are listening to how you remember it…`。

### Error States

- 麦克风权限拒绝：保留 Message 模式并提供系统设置入口；
- 转录失败：允许重试或改为手动 message；
- 分析失败：保留原始 input，不自动清除；
- 网络断开：显示 retry，不进入假分析结果。

### Acceptance Criteria

- `MVP-UI-01` 用户可以提交一段有效语音或 message；
- `MVP-UI-02` 麦克风录制状态清晰可见；
- `MVP-UI-03` 失败后 input 不丢失；
- `MVP-UI-04` 成功提交后进入 Screen 2。

---

## 31. Screen 2 — Interpretation & Feeding

### 页面目的

向用户解释：系统如何理解这件事、哪些 Figure 得到 Feed、哪一段 Figure relationship 被促进。

### 页面标题

`What the figures heard`

### 页面层级

#### A. Event Summary

- 1–3 句事件摘要；
- 可展开查看原始 transcript/message；
- 标记 `Your event`，不使用诊断语言；
- 提供 `Edit input` 返回 Screen 1。

#### B. Figure Feeding Result

只展示得到 Feed 的 Figure；最多 3 只。

每张 Figure Card 包含：

- Figure 名称与形象；
- Feed amount，例如 `+18 Feed`；
- 参与浓度，例如 `Anger 52%`；
- 一句证据解释，例如：
  - `Anger noticed that you were interrupted.`
  - `Fear noticed uncertainty about what would happen next.`
- EXP bar 的当前值和本次增加值；
- 第一名标记：`Most fed`。

#### C. Promoted Relationship

展示被促进的一对 Figure：

```text
Anger  ← +8 →  Fear
They both participated in the same memory.
```

必须包含：

- 两只 Figure；
- Relationship before / after；
- 被促进的原因；
- 关系只在**本次事件中共同出现的 Figure** 之间产生，**两两之间各促进一段**：1 个 Figure → 0 段（不显示关系区块），2 个 → 1 段，3 个 → 3 段。

> **修订（2026-09-24）**：原条款为“只促进一段关系；只有一个 Figure 得到 Feed 时，使用该 Figure 与 mock memory 中已有 co-owner 的关系作为 demo pair，并显示 `Existing memory connection`”。这会让没有参与这件事的 Figure 获得关系加分，而同一事件中的第三个 Figure 却得不到关系，与“关系来自共同经历”的设定不符，已改为上述规则。

#### D. Confirmation

- 主按钮：`Feed the figures`；
- 次按钮：`Adjust interpretation`；
- 当前 MVP 最多允许：
  - 增减 Figure；
  - 调整浓度；
  - 修改 event summary；
- 用户确认后，系统选择 Feed 最高的 Figure 作为后续 mock 中的 `Evolved Figure`。

> **修订（2026-09-24）— 取消手动调整解读**：不实现 `Adjust interpretation`（增减 Figure、调整浓度、修改 summary）。情绪分配完全交给 AI：允许用户自己选择会导致不真实的行为（例如为了喂某个 Figure 而调数值），也与“情绪有自己的意志、自己争夺记忆”的设定冲突。唯一的纠错途径是**重新讲一遍**：结果页可查看原话，并通过 “Edit and ask again” 带着原文回到输入页修改后重新提交——用户能改讲法，不能改数值；这也覆盖语音转写出错的情况。主按钮为 “Save this memory”（即确认并喂给 Figure）。受影响条款：`MVP-UI-08`、`MVP-FR-04`。


### Feed 输出数据

```yaml
analysis_result:
  event_summary: "I was interrupted while presenting an idea."
  figures:
    - id: anger
      concentration: 0.52
      feed: 18
      evidence: "You felt your chance to speak was taken away."
    - id: fear
      concentration: 0.31
      feed: 10
      evidence: "You were unsure how others would judge the idea."
  promoted_relationship:
    figures: [anger, fear]
    delta: 8
    reason: "Shared participation in the same event."
```

### Acceptance Criteria

- `MVP-UI-05` 用户能看出哪只 Figure 获得最多 Feed；
- `MVP-UI-06` 每次 Feed 必须显示基于 input 的简短理由；
- `MVP-UI-07` 显示本次共同参与的 Figure 之间两两被促进的全部 relationship（2 个 Figure → 1 段，3 个 → 3 段），每段含 before → after；只有一个 Figure 时不显示；
- ~~`MVP-UI-08` 用户可以修改 Figure mix 后再确认；~~（已取消，见 §31 D 修订说明）
- `MVP-UI-09` 确认后进入固定 transformation mock。

---

## 32. Screen 3 — Mock EXP Threshold & Transformation

### 页面目的

展示 Figure 因本次 Feed 达到 EXP threshold，并完成一次视觉变形。

### Mock 规则

- `Evolved Figure = Screen 2 中 Feed 最高的 Figure`；
- 系统在进入页面前把该 Figure 的旧 EXP 设置为：

```text
EXP Threshold - Current Feed
```

- 加上本次 Feed 后，EXP 必然刚好达到或略微超过 threshold；
- 不运行真实等级曲线；
- 不把 mock EXP 写入长期用户档案。

### 页面状态

#### State A — Threshold Reached

- Figure 当前形态；
- EXP bar 从旧值增长到 threshold；
- 文案：`[Figure] has enough experience to change.`；
- 本次 event 的 memory card 在背景中发光；
- 主按钮：`Let it transform`。

#### State B — Transformation

- 旧形态收缩或被光包围；
- 新形态出现；
- 展示 1 个新视觉特征和 1 个叙事能力；
- 示例：
  - `New trait: Reinforced claws`
  - `New ability preview: Can challenge another figure's memory`
- 标记：`Staged prototype evolution`，可使用小型 info button 说明这是 demo。
- 主按钮：`See what it does next`。

### Asset Requirements

每只基础 Figure 至少需要：

- Level 1 静态形象；
- Mock evolved 静态形象；
- EXP bar 色彩 token；
- 简短 transform animation；
- Reduce Motion 时的 crossfade 替代动画。

MVP 可以只为一只默认 Figure 制作完整资产。如果最高 Feed 不是该 Figure，则使用同一 mock 逻辑但显示预设 demo Figure，并增加文案：`For this prototype, the story continues with Anger.`。更推荐为四只 Figure 准备简单 before/after 素材，以保持叙事连续。

### Acceptance Criteria

- `MVP-UI-10` 用户能看懂“本次 Feed 使 EXP 达标”；
- `MVP-UI-11` 变形前后有明确视觉差异；
- `MVP-UI-12` 页面明确这是 staged prototype outcome；
- `MVP-UI-13` 完成动画后只能进入 Screen 4 或退出 demo。

---

## 33. Screen 4 — Mock Successful Raid

### 页面目的

展示变形后的 Figure 使用新能力，成功掠夺一段不属于自己的 Memory 或 Memory Object。

### Mock Scenario Setup

当前 MVP 不计算：

- Raid eligibility；
- Energy cost；
- Replay resistance；
- Defender protection；
- Ally loan；
- Random probability；
- 成功或失败判定。

进入该页面时，结果固定为 `Raid Success`。

### Target Selection

系统从 seed data 中选择一个不属于 Evolved Figure 的 memory：

```yaml
raid_fixture:
  target_memory_id: "memory_seed_joy_01"
  target_title: "The afternoon I finally felt included"
  current_owner: joy
  memory_object: "A yellow paper ticket"
  replay_count: 3
```

如果 Evolved Figure 本身是 Joy，则 target 自动切换为另一只 Figure 的 fixture，确保 attacker 与 victim 不同。

### 页面叙事结构

#### State A — Intent

- Evolved Figure 进入另一只 Figure 的 memory 区域；
- 展示目标 memory card 和 object；
- 文案解释动机，但不宣称为真实算法：
  - `[Figure] wants this memory to support its new version of the story.`
- 主按钮：`Continue the staged encounter`。

#### State B — Raid

- Attacker 与 Victim 的视觉对峙；
- Memory Object 从 Victim 一侧移动到 Attacker；
- 不显示虚假的复杂公式；
- 可以显示固定的 demo 数值变化：
  - Attacker `Power 80 → 55`
  - Victim `Power 24 → 0`
- 页面角落保留 `Demo outcome`。

#### State C — Success

- 状态标题：`Memory taken`；
- 展示：
  - 新 holder；
  - 原 owner；
  - 被夺取的 memory/object；
  - Victim 即将降级的提示；
- 主按钮：`See the aftermath`。

### Acceptance Criteria

- `MVP-UI-14` 用户能识别 attacker、victim 和被夺取对象；
- `MVP-UI-15` Raid 结果固定成功且无需真实运算；
- `MVP-UI-16` UI 明确这是 staged/demo outcome；
- `MVP-UI-17` 成功后 object holder 在 mock state 中发生转移；
- `MVP-UI-18` 进入 Screen 5 时 Victim 被设置为 minimum level。

---

## 34. Screen 5 — Mock Aftermath & Masked Memory

### 页面目的

展示 Raid 对被掠夺 Figure 和其相关 memory 造成的后果：Figure 降到最低级，Memory 被 masked。

### 页面标题

`After the raid`

### 页面结构

#### A. Victim Downgrade

- Victim Figure 从原始等级降为 `Level 1 — Minimum`；
- EXP bar 清空到预设最低值；
- Figure 形态缩小、失去部分纹理或进入低活跃状态；
- 文案：
  - `[Victim] no longer has enough strength to keep this memory fully visible.`
- 避免使用死亡、消失或惩罚性语言。

#### B. Masked Memory Card

- 显示被影响的 memory card；
- 标题局部遮挡；
- 摘要变为模糊文本或缺失 fragment；
- 显示原 owner、current holder 和 `Masked` badge；
- Mask 不能让页面完全空白，至少保留：
  - Memory 曾存在；
  - 哪只 Figure 与它有关；
  - 它何时被 masked；
  - 这是 Raid 的 mock 后果。

#### C. Masked Memory Detail — 展开状态

用户点击 memory card 后，在同一页面展开：

```text
What remains visible:
“That afternoon, I remember…”

Masked fragment:
[ This part is currently held out of view ]

Why it changed:
Joy fell to minimum level after the staged raid.
```

不展示原始敏感内容，但保留 `View original input used for this prototype`，返回用户 Screen 1 的原始 input，而不是伪造被 mask 的内容。

#### D. Final Explanation

用三行解释因果链：

```text
1. [Attacker] evolved after receiving Feed.
2. It took a Memory from [Victim].
3. [Victim] fell to Level 1, so the related Memory became Masked.
```

### 页面操作

- `Replay demo`：从 Screen 3 重新播放 transformation；
- `Start over`：返回 Screen 1 并重置全部 mock 状态；
- `Keep my event`：只保存 Screen 1–2 的真实 input/analysis，丢弃 mock 变形和冲突状态；
- `Discard everything`：删除本轮 input 和所有 session state。

### Acceptance Criteria

- `MVP-UI-19` Victim 明确显示为最低级；
- `MVP-UI-20` 至少一段与 Victim 相关的 memory 显示 Masked；
- `MVP-UI-21` Masked 状态保留 provenance，而不是假装 memory 不存在；
- `MVP-UI-22` 用户能通过三步解释理解 Feed → Raid → Mask 的因果；
- `MVP-UI-23` 用户可以只保存真实 input/analysis，不保存 mock state；
- `MVP-UI-24` Start over 能可靠重置 demo。

---

## 35. MVP Demo Data and State Model

### 35.1 Session State

```yaml
mvp_session:
  id: "session_001"
  simulation_mode: true
  scenario_id: "mvp_evolve_raid_mask_v1"

  real_input:
    mode: "voice"
    transcript: "..."
    event_summary: "..."

  interpretation:
    fed_figures: []
    promoted_relationship: {}

  mock_story:
    evolved_figure_id: null
    transformation_complete: false
    attacker_figure_id: null
    victim_figure_id: null
    target_memory_id: null
    raid_result: "success"
    victim_final_level: 1
    memory_final_state: "masked"
```

### 35.2 Seed Figures

四只 Figure 各需要最小 fixture：

```yaml
seed_figure:
  id: joy
  display_name: "Joy"
  starting_level: 3
  minimum_level: 1
  starting_exp: 72
  threshold_exp: 100
  owned_memory_id: "memory_seed_joy_01"
  object_id: "object_seed_joy_01"
```

### 35.3 Mock State Transition

```text
input_ready
→ analysis_ready
→ analysis_confirmed
→ threshold_reached
→ transformation_complete
→ raid_intent
→ raid_success
→ victim_minimum_level
→ memory_masked
→ demo_complete
```

每次转移都必须是显式、可测试的状态，不能依赖动画是否播放完成来推断业务状态。

---

## 36. Current MVP Requirements and Build Order

### 36.1 Functional Requirements

- `MVP-FR-01` 用户可以通过 voice 或 message 输入一个 daily event。
- `MVP-FR-02` 系统返回 event summary、fed figures、Feed amount 和 concentration。
- `MVP-FR-03` 系统为本次获得 Feed 的 Figure 两两返回一段 promoted relationship（`promotedRelationships` 数组：1 个 Figure → 空，2 个 → 1 段，3 个 → 3 段），不涉及未参与的 Figure。
- ~~`MVP-FR-04` 用户可以在确认前修改 interpretation。~~（已取消：分配完全由 AI 决定，纠错方式为重新讲述，见 §31 D 修订说明）
- `MVP-FR-05` Feed 最高的 Figure 被选为 Evolved Figure，或明确切换至预设 demo Figure。
- `MVP-FR-06` EXP threshold 和 transformation 使用固定 mock 数据。
- `MVP-FR-07` Raid 必须使用固定 fixture，且结果固定成功。
- `MVP-FR-08` Raid 后 Victim 必须进入 Level 1。
- `MVP-FR-09` Victim 的相关 memory 必须进入 Masked 状态。
- `MVP-FR-10` Mock state 不得写入真实长期 profile。
- `MVP-FR-11` 用户可以只保存真实 input 与 interpretation。
- `MVP-FR-12` 用户可以重置整个 demo。

### 36.2 Explicitly Out of Scope

当前 MVP 不实现：

- 真实长期 EXP/Level economy；
- 真实 replay 奖励；
- 真实随机 interaction engine；
- 真实 Raid/Tamper 成本和胜负计算；
- Figure 自动保护 memory；
- 盟友、借贷和 Energy refund；
- 多次 Raid 或 retaliation；
- 完整 Memories Library；
- Figure relationship graph；
- 跨 session 的 conflict persistence；
- 后台自动 interaction；
- Push notification；
- 新 emotion typology。

### 36.3 Build Order

#### Sprint 1 — Functional Input

- Screen 1；
- Voice/message input；
- transcription；
- analysis request/fixture fallback；
- loading/error states。

#### Sprint 2 — Functional Interpretation

- Screen 2；
- Figure Feed cards；
- promoted relationship；
- edit/confirm；
- session state。

#### Sprint 3 — Mock Narrative

- Screen 3 transformation；
- Screen 4 successful Raid；
- Screen 5 downgrade and Mask；
- deterministic state transitions；
- reset/replay demo。

#### Sprint 4 — Testing and Polish

- Reduce Motion；
- VoiceOver labels；
- error recovery；
- mock disclosure；
- analytics；
- end-to-end prototype test。

### 36.4 MVP End-to-end Acceptance Scenario

MVP 达标时，以下路径必须稳定完成：

1. 用户说出或写下一件 daily event；
2. 系统生成 event summary；
3. 系统指出至少一只 Figure 获得 Feed；
4. 系统指出一对 Figure 的 relationship 得到促进；
5. 用户确认 interpretation；
6. Feed 最高的 Figure 通过 mock 达到 EXP threshold；
7. Figure 完成 mock transformation；
8. 变形后的 Figure 对 seed memory 发起 staged Raid；
9. Raid 固定成功；
10. Victim 降为 Level 1；
11. Victim 对应 memory 进入 Masked 状态；
12. 用户理解三步因果链；
13. 用户可以保留真实 input/analysis，同时丢弃所有 mock conflict state；
14. 用户可以重置并再次演示。

### 36.5 Success Criteria

原型测试中，至少 80% 的用户应能在不看研究员解释的情况下回答：

1. 哪只 Figure 被 Feed？
2. 哪两只 Figure 的 relationship 被促进？
3. 哪只 Figure 发生了变形？
4. 哪只 Figure 发起了 Raid？
5. 哪只 Figure 降到了最低级？
6. 为什么相关 memory 被 Masked？

如果用户无法回答第 6 个问题，说明 Screen 5 的因果表达不足，不应优先增加更多战斗规则。

---

## 37. MVP Technical Architecture

### 37.1 Architecture Goal

技术架构需要同时满足：

1. 两个 AI domain 使用不同 API key、不同 system configuration 和不同责任边界；
2. 两位开发者可以分别实现两个 domain，再通过 GitHub Pull Request 合并；
3. iOS app 不保存任何第三方 AI API key；
4. 两个 domain 只通过稳定、可验证的结构化 contract 交流；
5. MVP 最终只需通过 Xcode 直接安装到实体 iPhone；不进入 TestFlight 或 App Store Connect。

### 37.2 Recommended Topology

```text
┌──────────────────────────────────────────────────────┐
│                    iPhone App                        │
│  SwiftUI + AVFoundation + SwiftData                  │
│                                                      │
│  Daily Event Input → Result Screens → Mock Narrative │
└──────────────────────────┬───────────────────────────┘
                           │ HTTPS
                           │ one public API surface
                           ▼
┌──────────────────────────────────────────────────────┐
│              Backend API / Orchestrator              │
│  Authentication · Validation · Logging · Sequencing  │
│                                                      │
│  POST /api/v1/events/interpret                       │
│  POST /api/v1/ecosystem/resolve                      │
│  POST /api/v1/sessions/run                           │
└───────────────┬──────────────────────┬───────────────┘
                │                      │
                ▼                      ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│ Domain A                 │  │ Domain B                 │
│ Input & Memory Interpreter│  │ Ecosystem Director      │
│                          │  │                          │
│ INPUT_DOMAIN_API_KEY     │  │ ECOSYSTEM_DOMAIN_API_KEY │
│ Input prompt/config      │  │ Ecosystem prompt/config  │
│ Event schema             │  │ Interaction schema       │
└───────────────┬──────────┘  └─────────────┬────────────┘
                │                           │
                └──────── structured ───────┘
                         JSON contract
```

### 37.3 Important Terminology Correction

API key 只负责身份认证和用量归属；它本身不包含“全局设置”。每个 domain 的行为应由以下内容共同定义：

- 独立 API key；
- 独立 model configuration；
- 独立 system prompt；
- 独立 JSON output schema；
- 独立 timeout/retry policy；
- 独立 usage logging；
- 独立测试 fixtures 与 evals。

因此，技术上应称为两个 `AI Domain Profiles`，而不只是两个 key。

---

## 38. API Key and Security Boundary

### 38.1 Keys Must Be Server-side Only

两个第三方 AI API key 均不得出现在：

- Swift source；
- `Info.plist`；
- `.xcconfig`；
- iOS Keychain；
- bundled JSON；
- GitHub repository；
- 任何由 Xcode 安装到设备的 `.app` bundle；
- client-visible network response。

OpenAI 官方 API 文档明确要求 API key 不应暴露在浏览器或 app 等 client-side code 中，应由服务端环境变量或 key-management service 加载。[OpenAI API authentication reference](https://developers.openai.com/api/reference/overview#authentication)

### 38.2 Server Secret Names

```dotenv
INPUT_DOMAIN_API_KEY=server-secret-only
ECOSYSTEM_DOMAIN_API_KEY=server-secret-only

INPUT_DOMAIN_MODEL=pinned-model-id
ECOSYSTEM_DOMAIN_MODEL=pinned-model-id

INPUT_PROMPT_VERSION=input-v1
ECOSYSTEM_PROMPT_VERSION=ecosystem-mvp-v1

LLM_BASE_URL=https://api.openai.com/v1
APP_ENV=development
```

Repository 只提交 `.env.example`，值必须为空或为 placeholder。

> **修订（2026-09-24）— 环境变量与 Cornell 网关**：实际使用 Cornell AI 网关（OpenAI 兼容，参考课程示例 `DEA6400/node-js/simple-app`）。
> - `LLM_HOST=https://api.ai.it.cornell.edu`（`/v1` 自动补全；旧名 `LLM_BASE_URL` 仍可用）；走 Cornell 时模型 id 自动加 `openai.` 前缀，如 `openai.gpt-5-mini`。
> - 新增 `OPENAI_API_KEY` 作为两个 domain 的共用 key；`INPUT_DOMAIN_API_KEY` / `ECOSYSTEM_DOMAIN_API_KEY` 可选，填写时优先生效。
> - 新增 `INPUT_REASONING_EFFORT`（默认 `low`）/ `ECOSYSTEM_REASONING_EFFORT`（默认 `minimal`），实测把延迟从 9–16 s 降到 A 约 3–7 s、B 约 2 s。
> - `*_PROMPT_VERSION` 默认跟随代码最新版本（当前 `input-v2`、`ecosystem-mvp-v2`），只在需要固定旧版本时设置。
> 详见 `apps/api/.env.example` 与 `apps/api/README.md`。


### 38.3 Recommended Key Isolation

如果使用同一 AI provider，推荐为两个 domain 创建两个 project-scoped service account/API key，而不是复制同一个 key：

- Input project：仅用于 transcription/input interpretation；
- Ecosystem project：仅用于 structured ecosystem decisions；
- 两边可分别设置预算、速率限制和用量追踪；
- 一个 key 泄漏时可以单独 revoke，不影响另一个 domain；
- GitHub secret 和 runtime hosting secret 分开管理。

> **修订（2026-09-24）**：Cornell 通常每人只发一个 key，因此两个 domain 默认共用 `OPENAI_API_KEY`；拿到独立 key 后可按上文分别配置，代码已支持。


### 38.4 App-to-Backend Authentication

第三方 API key 不在手机里，但 app 仍需证明自己可以调用 backend。

MVP 推荐：

- 每次安装生成匿名 `installation_id`；
- backend 为 installation 签发短期 session token；
- 所有 API 请求使用该短期 token；
- backend 进行 IP/install rate limit；
- 如果后续让非开发设备连接公开 backend，再加入 App Attest 或用户登录；当前 Xcode-only MVP 不实现；
- 不依赖一个永久 hard-coded app secret，因为它同样可以从安装包提取。

---

## 39. Domain Responsibilities

### 39.1 Domain A — Input & Memory Interpreter

### Responsibility

Domain A 负责理解“用户刚刚输入了什么”，不负责决定 Figure 之间随后如何行动。

### Inputs

- New event voice recording；

> **修订（2026-09-24）— 语音转文字放在手机端**：使用 Apple Speech framework 在 iPhone 上转写，后端只接收文字。Domain A 不做 transcription，不接收原始音频（隐私更好，也省去上传与保留策略）。

- New event message；
- Existing event replay request；
- 可选的 previous event metadata；
- 用户对重要度或 interpretation 的修改。

### Outputs

- Event summary；
- Event type 与 turning point；
- 参与 Figure；
- 每只 Figure 的 emotion concentration；
- Feed recommendation；
- 关系线索 `relationship_cues`；
- Extracted object candidate；
- Evidence snippets；
- Confidence；
- Uncertainty；
- Replay context。

### Must Not Do

- 不决定 Raid；
- 不决定 transformation；
- 不修改 ecosystem state；
- 不直接改变 relationship score；
- 不决定 memory mask；
- 不返回自由格式的生态故事供客户端解析。

### 39.2 Domain B — Ecosystem Director

### Responsibility

Domain B 只接收 Domain A 的结构化输出和当前 `EcosystemSnapshot`，决定本轮哪些 Figure relationship/interactions 应被展示。

### Inputs

- Validated `EventInterpretationV1`；
- Current `EcosystemSnapshotV1`；
- `simulation_mode`；
- `scenario_id`；
- Prompt/config version。

### Outputs

- Which relationship is promoted；
- Feed 应如何应用到 figure state；
- 本轮 narrative steps；
- Current MVP 的 mock transformation directive；
- Current MVP 的 fixed successful raid directive；
- Victim downgrade directive；
- Memory mask directive；
- 用户可见 explanation；
- State patch proposal。

### Must Not Do

- 不接收或保存原始 API key；
- 默认不读取原始音频；
- 不重新解释用户原话；
- 不修改 Source Archive；
- 不自行扩展 contract 字段；
- MVP 不运行真实随机 combat engine。

### Privacy Boundary

Domain B 原则上不需要看到完整原始 transcript。它接收：

- Event summary；
- Figure concentrations；
- Feed allocations；
- 去标识化 relationship cues；
- Object candidate；
- 必要 evidence snippets。

这样第二个 domain 可以完成生态决策，同时减少对原始个人叙述的暴露。

---

## 40. Backend Orchestrator

### 40.1 Why One Public Backend

iOS 不应分别调用两个 AI domain。推荐只暴露一个 backend origin，原因包括：

- iOS 只维护一套认证和错误处理；
- keys、prompts 和 model settings 都留在服务端；
- backend 可以在 Domain A 与 B 之间验证 schema；
- 可以独立更换任一 model/provider 而不更新 iPhone app；
- 两位开发者仍然可以分别维护内部 module；
- 方便统一 rate limit、trace ID 和 cost logging。

### 40.2 Public Endpoints

#### `POST /api/v1/events/interpret`

用于开发、调试和 Screen 1 → Screen 2。

> **修订（2026-09-24）— 实际请求 / 响应格式**：字段统一为 camelCase，与 JSON Schema 一致。
> - `POST /api/v1/events/interpret`：请求 `{ inputType: "voice" | "message", text, importance? }`；响应 `{ schemaVersion, interpretation, fallback, promptVersion, traceId }`。无 `audio_upload_id`。
> - `POST /api/v1/ecosystem/resolve`：请求 `{ interpretation, snapshot, simulationMode?, scenarioId? }`。
> - `POST /api/v1/sessions/run`（iOS 实际调用）：请求 `{ inputType, text, importance?, snapshot, sessionId? }`；响应 `ClientSessionResponseV1`，含 `fallback: { interpretation, resolution }`。
> - 错误统一为 `{ error: { code, message, retryable? }, traceId }`：Domain A 超时 503、输出不合规 502，快照无可掠夺记忆 422。


```yaml
request:
  session_id: "uuid"
  input_type: "message | voice | replay"
  text: "optional"
  audio_upload_id: "optional"
  replay_event_id: "optional"
  importance: 0.7

response:
  schema_version: "event-interpretation.v1"
  interpretation: {}
  trace_id: "uuid"
```

#### `POST /api/v1/ecosystem/resolve`

用于开发、调试和 Screen 2 → Screen 3。

```yaml
request:
  session_id: "uuid"
  interpretation: "EventInterpretationV1"
  ecosystem_snapshot: "EcosystemSnapshotV1"
  simulation_mode: true
  scenario_id: "mvp_evolve_raid_mask_v1"

response:
  schema_version: "ecosystem-resolution.v1"
  resolution: {}
  trace_id: "uuid"
```

#### `POST /api/v1/sessions/run`

面向 iOS 的推荐组合 endpoint。Backend 内部顺序调用 Domain A 与 Domain B，再返回 Screen 2–5 所需完整 payload。

```text
iOS request
  → validate input
  → Domain A
  → validate EventInterpretationV1
  → Domain B
  → validate EcosystemResolutionV1
  → combine ClientSessionResponseV1
  → iOS
```

#### `POST /api/v1/uploads/audio`

可选 multipart upload endpoint：

- 接收 `.m4a`；
- 校验 duration、MIME type 和大小；
- 返回短期 `audio_upload_id`；
- Domain A 完成 transcription 后按 retention policy 删除原始临时文件。

> **修订（2026-09-24）**：因语音转文字在手机端完成，**不实现** `/api/v1/uploads/audio`。


### 40.3 Internal Service Interfaces

```ts
interface InputInterpreter {
  interpret(input: RitualInput): Promise<EventInterpretationV1>;
}

interface EcosystemDirector {
  resolve(
    interpretation: EventInterpretationV1,
    snapshot: EcosystemSnapshotV1,
    scenario: ScenarioConfig
  ): Promise<EcosystemResolutionV1>;
}
```

这两个 interface 是两位开发者的 merge seam。任何一方只要通过 contract tests，就不需要了解另一方内部 prompt。

---

## 41. Structured Contracts

### 41.1 Contract Rule

Domain A 与 Domain B 之间禁止使用需要二次自然语言解析的自由文本。必须使用 versioned JSON Schema，并在服务端启用 strict structured output；OpenAI API 支持以 JSON Schema 约束结构化输出。[OpenAI Structured Outputs guide](https://developers.openai.com/api/docs/guides/structured-outputs)

> **修订（2026-09-24）— Contract 以代码为准**：权威 schema 在 `packages/contracts/schemas/`，下文示例仅供参考。与下文相比的变化：
> - `EventInterpretationV1.figures[]` 新增 `voiceLine`（Figure 在结果页说的一句话）；
> - `EcosystemSnapshotV1.seedMemories[]` 新增 `title`、`objectName`；
> - `EcosystemResolutionV1`：`promotedRelationship` 改为 `promotedRelationships` 数组（见 §31 C 修订），新增 `explanation`（Screen 5 的三步因果解释）；
> - 新增 `ClientSessionResponseV1`，含 `fallback` 标记。
> Cornell 网关已确认支持 strict JSON Schema 输出；服务端在返回前仍会用 Ajv 再校验一次，并检查 §41.5 中 schema 无法表达的规则。


### 41.2 `EventInterpretationV1`

```json
{
  "schemaVersion": "event-interpretation.v1",
  "eventId": "event_001",
  "summary": "I was interrupted while sharing an idea.",
  "turningPoint": "The conversation moved on before I finished.",
  "figures": [
    {
      "id": "anger",
      "concentration": 0.52,
      "feed": 18,
      "evidence": "The user described losing the chance to speak.",
      "confidence": 0.87
    },
    {
      "id": "fear",
      "concentration": 0.31,
      "feed": 10,
      "evidence": "The user was uncertain how others judged the idea.",
      "confidence": 0.76
    }
  ],
  "relationshipCues": [
    {
      "figures": ["anger", "fear"],
      "reason": "Both participated in the same event."
    }
  ],
  "objectCandidate": {
    "name": "A closed notebook",
    "source": "literal"
  },
  "uncertainties": [],
  "sourceType": "voice"
}
```

### 41.3 `EcosystemSnapshotV1`

```json
{
  "schemaVersion": "ecosystem-snapshot.v1",
  "figures": [
    { "id": "anger", "level": 2, "exp": 82, "energy": 45 },
    { "id": "fear", "level": 2, "exp": 61, "energy": 33 },
    { "id": "joy", "level": 3, "exp": 72, "energy": 24 },
    { "id": "sadness", "level": 2, "exp": 48, "energy": 30 }
  ],
  "relationships": [
    { "figures": ["anger", "fear"], "score": 12 }
  ],
  "seedMemories": [
    {
      "id": "memory_seed_joy_01",
      "ownerFigureId": "joy",
      "state": "visible",
      "objectId": "object_seed_joy_01"
    }
  ]
}
```

### 41.4 `EcosystemResolutionV1`

```json
{
  "schemaVersion": "ecosystem-resolution.v1",
  "simulationMode": true,
  "scenarioId": "mvp_evolve_raid_mask_v1",
  "promotedRelationship": {
    "figures": ["anger", "fear"],
    "before": 12,
    "delta": 8,
    "after": 20,
    "reason": "Shared participation in the new event."
  },
  "evolution": {
    "figureId": "anger",
    "beforeExp": 82,
    "feedApplied": 18,
    "threshold": 100,
    "afterExp": 100,
    "mocked": true
  },
  "raid": {
    "attackerFigureId": "anger",
    "victimFigureId": "joy",
    "targetMemoryId": "memory_seed_joy_01",
    "targetObjectId": "object_seed_joy_01",
    "result": "success",
    "mocked": true
  },
  "aftermath": {
    "victimFinalLevel": 1,
    "memoryFinalState": "masked"
  }
}
```

### 41.5 Validation Rules

- 所有 response 必须先由 backend schema validator 验证，再返回 iOS；
- `schemaVersion` mismatch 返回明确错误，不 silently coerce；
- Figure ID 只能来自 allowlist；
- Concentration 必须在 `0–1`；
- 所有 Figure concentration 总和允许 ±0.01 rounding error；
- Feed 不得为负数；
- MVP `simulationMode` 必须为 `true`；
- MVP `raid.result` 必须为 `success`；
- Victim 与 attacker 不能相同；
- `victimFinalLevel` 固定为 `1`；
- `memoryFinalState` 固定为 `masked`。

---

## 42. Request Flows

### 42.1 New Event Flow

```text
1. iOS records .m4a or accepts message
2. iOS uploads audio when needed
3. iOS sends RitualInput to backend
4. Backend assigns session_id + trace_id
5. Domain A transcribes/analyzes input
6. Backend validates EventInterpretationV1
7. Domain B receives interpretation + snapshot
8. Domain B returns mock ecosystem resolution
9. Backend validates EcosystemResolutionV1
10. iOS stores real interpretation locally
11. iOS holds mock resolution only in demo session state
12. Screens 2–5 render the returned payload
```

> **修订（2026-09-24）— 实际流程**：1. iOS 录音并在本机转写（或接收文字）→ 2. iOS 调用 `POST /api/v1/sessions/run`，发送文字 + 当前 `EcosystemSnapshotV1`（Figure 等级 / EXP / 能量、关系分数、种子记忆）→ 3. 后端生成 trace id，Domain A 解析 → 校验 → Domain B 决定 → 校验 → 合并返回 `ClientSessionResponseV1`。第 2、5 步中的音频上传与服务端转写不再存在。后端不可达时，iOS 用本地关键词解析兜底，并在结果页标注 “Offline guess”。


### 42.2 Replay Flow — Future-compatible

虽然当前 MVP 不实现 replay UI，但 Domain A contract 应预留 `sourceType: replay`：

```text
iOS selects existing event
→ backend loads/supplies event reference
→ Domain A returns replay interpretation
→ Domain B decides ecosystem interaction
→ same output contracts
```

Replay 不需要建立第三套 API key，也不应绕过 Domain A 直接进入 Domain B。

### 42.3 Failure Handling

| Failure | Backend behavior | iOS behavior |
|---|---|---|
| Domain A timeout | Retry once with same trace ID | 保留 input，显示 retry |
| Domain A invalid schema | Do not call Domain B | 显示 analysis unavailable |
| Domain B timeout | Return valid interpretation + mock fallback | Screen 2 正常；Screen 3 使用本地 fixture |
| Domain B invalid schema | Use checked-in fixture | 标记 `fallback simulation` |
| Audio upload fails | Do not discard local recording | 重试或转 message |
| Network offline | Queue local ritual | 恢复联网后由用户确认上传 |

---

## 43. Proposed Repository Structure

当前 `node-js/simple-app` 可以保留作为旧 web prototype 参考；iOS MVP 推荐在 repository root 新建独立 monorepo 结构，不继续把 mobile architecture 塞进旧 `server.js`。

```text
DEA6400-main/
├── apps/
│   ├── ios/
│   │   ├── MemoryEcosystem.xcodeproj/
│   │   ├── MemoryEcosystem/
│   │   │   ├── App/
│   │   │   │   ├── MemoryEcosystemApp.swift
│   │   │   │   ├── AppEnvironment.swift
│   │   │   │   └── RootCoordinator.swift
│   │   │   ├── Features/
│   │   │   │   ├── RitualInput/
│   │   │   │   │   ├── RitualInputView.swift
│   │   │   │   │   ├── RitualInputViewModel.swift
│   │   │   │   │   └── AudioRecorder.swift
│   │   │   │   ├── Interpretation/
│   │   │   │   │   ├── InterpretationView.swift
│   │   │   │   │   └── InterpretationViewModel.swift
│   │   │   │   ├── TransformationMock/
│   │   │   │   │   ├── TransformationView.swift
│   │   │   │   │   └── TransformationAnimator.swift
│   │   │   │   ├── RaidMock/
│   │   │   │   │   ├── RaidView.swift
│   │   │   │   │   └── RaidViewModel.swift
│   │   │   │   └── MaskedMemoryMock/
│   │   │   │       ├── AftermathView.swift
│   │   │   │       └── MaskedMemoryCard.swift
│   │   │   ├── Core/
│   │   │   │   ├── Networking/
│   │   │   │   │   ├── APIClient.swift
│   │   │   │   │   ├── APIEndpoint.swift
│   │   │   │   │   └── APIError.swift
│   │   │   │   ├── Models/
│   │   │   │   │   ├── EventInterpretation.swift
│   │   │   │   │   ├── EcosystemResolution.swift
│   │   │   │   │   └── MVPScenarioState.swift
│   │   │   │   ├── Persistence/
│   │   │   │   │   └── RitualStore.swift
│   │   │   │   └── DesignSystem/
│   │   │   │       ├── FigureTheme.swift
│   │   │   │       └── Components/
│   │   │   ├── Resources/
│   │   │   │   ├── Assets.xcassets/
│   │   │   │   ├── PreviewFixtures/
│   │   │   │   └── Localizable.xcstrings
│   │   │   └── Info.plist
│   │   ├── MemoryEcosystemTests/
│   │   └── Config/
│   │       ├── Debug.xcconfig
│   │       ├── Release.xcconfig
│   │       └── Example.xcconfig
│   │
│   └── api/
│       ├── src/
│       │   ├── index.ts
│       │   ├── app.ts
│       │   ├── routes/
│       │   │   ├── events.ts
│       │   │   ├── ecosystem.ts
│       │   │   ├── sessions.ts
│       │   │   └── uploads.ts
│       │   ├── domains/
│       │   │   ├── input/
│       │   │   │   ├── inputInterpreter.ts
│       │   │   │   ├── inputClient.ts
│       │   │   │   ├── inputConfig.ts
│       │   │   │   └── prompts/
│       │   │   │       └── input-v1.md
│       │   │   └── ecosystem/
│       │   │       ├── ecosystemDirector.ts
│       │   │       ├── ecosystemClient.ts
│       │   │       ├── ecosystemConfig.ts
│       │   │       ├── mockScenario.ts
│       │   │       └── prompts/
│       │   │           └── ecosystem-mvp-v1.md
│       │   ├── orchestration/
│       │   │   └── runSession.ts
│       │   ├── middleware/
│       │   │   ├── auth.ts
│       │   │   ├── rateLimit.ts
│       │   │   ├── requestId.ts
│       │   │   └── errorHandler.ts
│       │   ├── contracts/
│       │   │   └── generated/
│       │   └── observability/
│       │       ├── logger.ts
│       │       └── usageMetrics.ts
│       ├── test/
│       │   ├── contract/
│       │   ├── domains/
│       │   └── fixtures/
│       ├── package.json
│       ├── tsconfig.json
│       ├── .env.example
│       └── Dockerfile
│
├── packages/
│   └── contracts/
│       ├── openapi.yaml
│       ├── schemas/
│       │   ├── event-interpretation.v1.schema.json
│       │   ├── ecosystem-snapshot.v1.schema.json
│       │   ├── ecosystem-resolution.v1.schema.json
│       │   └── client-session-response.v1.schema.json
│       ├── fixtures/
│       │   ├── event-interpretation.valid.json
│       │   ├── ecosystem-resolution.valid.json
│       │   └── mvp-session.valid.json
│       └── README.md
│
├── docs/
│   ├── architecture/
│   │   ├── adr-001-two-ai-domains.md
│   │   ├── adr-002-server-side-keys.md
│   │   └── adr-003-mvp-mock-boundary.md
│   └── api/
│       └── local-development.md
│
├── .github/
│   ├── CODEOWNERS
│   ├── pull_request_template.md
│   └── workflows/
│       ├── api-ci.yml
│       ├── contracts-ci.yml
│       └── ios-ci.yml
│
├── node-js/
│   └── simple-app/                  # Existing web prototype, unchanged
├── retrospective-memory-ios-prd.md
├── .gitignore
└── README.md
```

### 43.1 Why Contracts Live Outside Both Apps

`packages/contracts` 同时属于两边、但不由任一 domain 私有：

- Backend 通过 JSON Schema runtime validation；
- iOS 根据 OpenAPI/schema 生成或维护 Codable structs；
- 两位开发者共享同一批 fixtures；
- schema change 必须单独 PR；
- contract CI 先通过，domain PR 才能 merge。

---

## 44. Two-developer GitHub Collaboration Plan

### 44.1 Ownership Split

#### Developer A — Input Domain + Screens 1–2

负责：

- Voice/message upload；
- Domain A prompt/config；
- EventInterpretation schema implementation；
- `/events/interpret`；
- Ritual Input page；
- Interpretation & Feeding page；
- Input-domain tests。

主要目录：

```text
apps/api/src/domains/input/
apps/api/src/routes/events.ts
apps/ios/.../Features/RitualInput/
apps/ios/.../Features/Interpretation/
```

#### Developer B — Ecosystem Domain + Screens 3–5

负责：

- Domain B prompt/config；
- Relationship promotion；
- MVP mock scenario；
- `/ecosystem/resolve`；
- Transformation mock；
- Raid mock；
- Masked-memory aftermath；
- Ecosystem-domain tests。

主要目录：

```text
apps/api/src/domains/ecosystem/
apps/api/src/routes/ecosystem.ts
apps/ios/.../Features/TransformationMock/
apps/ios/.../Features/RaidMock/
apps/ios/.../Features/MaskedMemoryMock/
```

#### Shared Integration Area

双方共同 review，但不在同一 feature PR 随意修改：

```text
packages/contracts/
apps/api/src/orchestration/
apps/ios/.../Core/Networking/
apps/ios/.../App/RootCoordinator.swift
```

### 44.2 Merge Order

```text
PR 0 — Repository scaffold + contracts + fixtures
          ↓
PR A1 — Domain A backend behind fixture tests
PR B1 — Domain B backend behind same contracts
          ↓ can progress in parallel
PR A2 — iOS Screens 1–2 using fixture first
PR B2 — iOS Screens 3–5 using fixture first
          ↓
PR 3 — Backend orchestration /sessions/run
          ↓
PR 4 — iOS API integration
          ↓
PR 5 — Physical iPhone QA + Xcode device run
```

### 44.3 Branch Names

```text
feat/input-domain-v1
feat/input-ios-flow
feat/ecosystem-domain-v1
feat/mock-narrative-ios
feat/session-orchestrator
chore/contracts-v1
release/mvp-0.1
```

### 44.4 Pull Request Rules

- 禁止直接 push 到 `main`；
- 每个 PR 至少由另一位开发者 review；
- Contract change 必须注明 breaking/non-breaking；
- Prompt change 必须更新 prompt version；
- API response change 必须同步 fixture；
- Backend tests、contract tests 和 iOS unit tests 必须通过；
- PR 不得包含 `.env`、API key、录音样本或真实用户 memory；
- UI PR 使用 synthetic event fixture 和截图；
- 两位开发者不在同一个 PR 同时重构 shared contract 与全部 UI。

### 44.5 Suggested `CODEOWNERS`

```text
/apps/api/src/domains/input/              @developer-a
/apps/ios/**/Features/RitualInput/        @developer-a
/apps/ios/**/Features/Interpretation/     @developer-a

/apps/api/src/domains/ecosystem/          @developer-b
/apps/ios/**/Features/TransformationMock/ @developer-b
/apps/ios/**/Features/RaidMock/           @developer-b
/apps/ios/**/Features/MaskedMemoryMock/   @developer-b

/packages/contracts/                      @developer-a @developer-b
/apps/api/src/orchestration/              @developer-a @developer-b
/apps/ios/**/Core/Networking/             @developer-a @developer-b
```

---

## 45. Local Development Configuration

### 45.1 Backend

```text
cd apps/api
cp .env.example .env
npm install
npm run dev
```

`.env` 由每位开发者本地创建且必须被 `.gitignore` 排除。不要在 terminal output、issue、PR 或截图中展示 key。

### 45.2 iOS

`Debug.xcconfig` 只包含非机密配置：

```text
API_BASE_URL = http:/$()/localhost:3000
SIMULATION_MODE = YES
SCENARIO_ID = mvp_evolve_raid_mask_v1
```

真机无法通过自己的 `localhost` 访问 Mac backend，因此真机开发需要以下之一：

- 使用 Mac 的局域网 IP，并确保同一网络和防火墙允许；
- 使用 HTTPS development tunnel；
- 直接连接已部署的 staging backend。

实体 iPhone 演示优先连接 HTTPS staging backend 或 HTTPS development tunnel。若使用局域网 Mac backend，只允许在 Debug configuration 中配置明确、最小范围的开发网络例外。

### 45.3 Configuration Separation

| Environment | iOS API URL | Backend keys | Data |
|---|---|---|---|
| Unit Test | Mock URLProtocol | None | Checked-in fixtures |
| Simulator Dev | Local backend | Local `.env` | Synthetic |
| Device Dev | LAN/tunnel/staging | Server secrets | Synthetic/test |
| Xcode Device Demo | HTTPS tunnel/staging, or restricted Debug LAN | Mac/hosting secrets | Synthetic/test |

---

## 46. iPhone Build and Xcode Installation Plan

### 46.1 iOS Technical Baseline

- SwiftUI app；
- Proposed deployment target：iOS 17+；
- `NavigationStack` for the five-screen linear flow；
- AVFoundation for `.m4a` voice recording；
- SwiftData for local real-input/interpretation persistence；
- `URLSession` with async/await for backend calls；
- Codable models matching `packages/contracts`；
- SF Symbols by symbol name；
- semantic system colors；
- Reduce Motion and VoiceOver support。

### 46.2 Required iOS Configuration

```text
Bundle Identifier: com.<your-team>.MemoryEcosystem
Display Name: Memory Ecosystem
Version: 0.1.0
Build: increment for every archive
```

`Info.plist` 至少需要：

- `NSMicrophoneUsageDescription`；
- 如果使用 Apple Speech framework，再加入 speech recognition usage description；
- Release build 的 App Transport Security 使用 HTTPS，不通过 arbitrary-load exception 绕过。

Bundle Identifier 必须替换为开发团队实际拥有且在 Apple Developer 中可注册的唯一标识，不应默认使用 Cornell 名义。

### 46.3 Install Directly on a Development iPhone

1. 在 Mac 安装当前受支持的 Xcode；
2. 打开 `MemoryEcosystem.xcodeproj`；
3. 在 Signing & Capabilities 选择开发团队；
4. 确保 Bundle Identifier 唯一；
5. 使用 USB 或已配对的 wireless connection 连接 iPhone；
6. 在 iPhone 打开 Developer Mode；
7. 在 Xcode 选择该 iPhone 作为 run destination；
8. `Product → Run`；
9. 验证 microphone permission、录音、network、mock flow 和 reset；
10. 卸载/重装后再次验证 clean-state flow。

Apple 官方说明 Xcode 可以将 app 构建并运行在配对的 physical device 上，且实体设备测试能覆盖 simulator 无法完全复现的设备行为。[Running your app on simulated or physical devices](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)

### 46.4 Xcode-only Collaboration and Installation

当前 MVP 不创建 App Store Connect record、不上传 archive、不使用 TestFlight。

两位开发者协作时：

1. 从 GitHub clone 同一 repository；
2. 分别创建自己的本地 backend `.env`，或共同使用一个 staging backend；
3. 在 Xcode 中选择各自可用的 Development Team；
4. 如两边签名团队不同，分别使用自己唯一的 development Bundle Identifier；
5. 通过 Swift fixture、backend contract test 和 GitHub CI 保证合并后的行为一致；
6. 最终演示 Mac checkout `main` 或 `release/mvp-0.1`；
7. 连接目标 iPhone，并由 Xcode 直接 build、sign、install 和 launch；
8. 不导出或手动分享 `.ipa`。

如果老师或另一位成员需要体验，当前方案要求他们能够访问 Mac/Xcode 和用于签名的 Apple account/team，并从 Xcode 安装到设备。面向无需 Xcode 的测试者分发属于未来范围。

### 46.5 Definition of “Installed on iPhone”

当前项目只有一个完成标准：`Xcode Device Complete`。

- App 从 Xcode 成功安装到一台实体 iPhone；
- 五页流程完成；
- Voice permission 与 recording 工作；
- Domain A 与 B 均可通过本地 HTTPS tunnel 或 staging backend 响应；
- mock flow 可以 reset；
- 关闭并重新打开 app 不崩溃；
- Server logs 可通过 trace ID 定位 Domain A 与 B；
- 两个 API key 都未出现在 app bundle、Xcode project 或 repository 中；
- 从 clean clone 到实体 iPhone 安装有可重复步骤。

---

## 47. Testing Strategy

### 47.1 Contract Tests

- Domain A fixture 必须通过 `EventInterpretationV1`；
- Domain B fixture 必须通过 `EcosystemResolutionV1`；
- Invalid figure ID 被拒绝；
- Attacker 与 victim 相同时被拒绝；
- `simulationMode: false` 在 MVP endpoint 被拒绝；
- Schema version mismatch 返回 409/422；
- 所有 Swift Codable fixtures 可以 decode。

### 47.2 Backend Tests

- Domain A 使用 fake AI client 测试；
- Domain B 使用 fake AI client 测试；
- API keys 缺失时启动检查失败并给出安全错误；
- Domain A failure 时不会调用 Domain B；
- Domain B failure 时返回 checked-in mock fallback；
- 相同 idempotency key 不重复创建 session；
- Logs 不包含完整 transcript、audio bytes 或 API key。

### 47.3 iOS Tests

- AudioRecorder permission states；
- RitualInput validation；
- Interpretation fixture decoding；
- Screen 2 修改/确认；
- Mock state transition 顺序；
- Start Over reset；
- Keep My Event 只保存真实 interpretation；
- Reduce Motion fallback；
- VoiceOver labels；
- Offline and timeout UI。

### 47.4 Physical Device Checklist

- 麦克风权限首次弹窗；
- 录音在锁屏/切后台时的预期处理；
- `.m4a` 上传大小和时长；
- Wi-Fi 与 cellular network；
- Dark Mode；
- Reduce Motion；
- iPhone 小屏幕没有按钮被遮挡；
- API timeout 后 input 仍在；
- Release build 不包含 Debug menu 和 secrets。

---

## 48. CI/CD and Deployment

### 48.1 GitHub Actions

#### `contracts-ci.yml`

- Validate JSON Schemas；
- Validate fixtures；
- Detect breaking schema changes；
- Ensure Swift fixtures decode。

#### `api-ci.yml`

- Install；
- Typecheck；
- Lint；
- Unit/contract tests；
- Build Docker image；
- Secret scan；
- No live AI call on pull requests。

#### `ios-ci.yml`

- Resolve Swift packages；
- Build for simulator；
- Run unit/UI tests；
- Check fixture decoding；
- Archive only on protected release workflow。

### 48.2 Runtime Deployment

Backend 部署环境需要：

- HTTPS；
- 两个独立 secrets；
- health check；
- request size limit；
- rate limit；
- structured logs；
- request/trace ID；
- timeout and retry；
- staging 与 production 分离；
- server-side deletion policy for uploaded audio。

### 48.3 Release Gate

在最终 Xcode 真机演示前必须确认：

- `git grep`/secret scanner 未发现 key；
- Device configuration 使用 HTTPS tunnel/staging URL，或受限的 Debug LAN 配置；
- Domain A/B contract tests 通过；
- Xcode device build 与 install 成功；
- microphone usage copy 完成；
- privacy/data retention 文案与真实实现一致；
- mock outcome disclosure 存在；
- backend staging health check 成功；
- 五页流程在实体 iPhone 完成一次。

---

## 49. Architecture Decisions Summary

| Decision | Choice | Reason |
|---|---|---|
| Mobile framework | SwiftUI | 原生 iOS、适合五页状态驱动 prototype |
| Public API | One backend origin | 简化 iOS、隐藏两个 keys |
| AI separation | Two domain modules + two keys | 清晰责任、独立成本/权限、方便并行开发 |
| Domain handoff | Versioned JSON Schema | 防止 prompt output drift |
| Mobile persistence | SwiftData | 单机 MVP 足够，方便保留真实 input |
| Backend persistence | MVP 可保持轻量/无状态 | Mock state 主要保存在 session；以后再接数据库 |
| Voice | AVFoundation `.m4a` upload | 真机录音简单，统一交给 Domain A |
| Ecosystem result | Server-produced, client-rendered | 后续可替换 mock 为真实 engine |
| Mock storage | Session-only | 防止模拟冲突污染真实用户档案 |
| Collaboration | Monorepo + shared contracts | 两人并行并可安全 merge |
| iPhone delivery | Xcode device run only | 当前只要求开发签名并直装实体 iPhone |

### Final Technical Loop

```text
iPhone records a retrospective event
        ↓
One secure backend receives it
        ↓
Input Domain interprets the memory
        ↓
Schema validation creates a stable handoff
        ↓
Ecosystem Domain decides the relationship and mock narrative
        ↓
Backend returns one versioned client payload
        ↓
SwiftUI renders Screens 2–5
        ↓
Real interpretation may persist locally
Mock conflict state is discarded or reset
```
