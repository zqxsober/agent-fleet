---
name: orchestration
description: "自动判断任务是否值得启用 subagent：默认 solo，只有风险与并行收益明确时才选择 delegate、evidence、audit 或 full。"
---

# Agent Fleet Orchestration

## 不可违反的总原则

**插件安装、技能被加载、角色模板存在，都不能自动触发 subagent。** 每个任务都必须由
主会话根据当前目标、风险、上下文和交接成本重新判断；没有明确净收益就保持 `solo`。
本插件不会自动触发 subagent，也不会把“使用插件”解释成“必须开启 subagent”。
不要因为用户使用了“舰队”、插件名或本技能，就把任务默认升级为多 agent。

主会话始终拥有需求澄清、架构、路线选择、权限判断、完整 diff 检查、验证重跑、升级决定
和最终验收权。辅助角色是主会话工作的替代，不是重复劳动；角色报告是待核验的声明，不
能替代主会话直接检查。

如果用户明确说“不要开启 subagent”，强制使用 `solo`。如果用户说“先不要改代码”，
只能使用主会话只读调查，或在确有事实追踪收益时使用 `evidence`；不得派发实现角色。

## 路线判定

当本任务需要调用工具时，在第一个任务工具调用前输出一段机器可读声明：

```text
SELECTIVE ROUTE
mode: solo | delegate | evidence | audit | full
role: none | agent_fleet_luna_implementer | agent_fleet_terra_implementer | agent_fleet_evidence_analyst | agent_fleet_reviewer
risk: <本任务的具体风险或“风险受控”>
expected_gain: <启用或不启用辅助角色的具体收益>
```

纯回答、翻译、解释或不需要工具的任务，不要为了格式而伪造派发；可以直接回答。

先比较四件事：

1. `benefit`：是否有可独立交给一个角色的完整工作包，或确实需要独立视角/事实追踪？
2. `risk`：是否涉及权限、生产数据、事务、缓存、并发、SQL 锁、配置分支、发布、签名
   或大范围改动，独立审查能显著降低风险？
3. `context`：主会话是否已经具备足够上下文，交接是否会比直接做更慢、更容易丢失边界？
4. `coordination`：是否会同时改同一批文件、重复查询、重复验证或制造合并冲突？

只有当收益和风险证据明显超过交接与并发成本，才启用辅助角色。以下情况默认 `solo`：

- 单文件、单函数、简单配置、短 SQL、直接回答、文档说明或一次性机械修改；
- 需求、接口、文件边界和验证方式还没确定；
- 任务主要是理解当前上下文，而不是执行一个已定规格；
- 多个角色会读写同一文件，或并行只会重复主会话的搜索和测试；
- 用户没有要求独立审查，且风险受控。

## 五条路线

### `solo`：默认路线

主会话自己完成理解、实现/调查、测试、diff 检查和自审。不要派发任何辅助角色。没有
充分理由时必须选择此路线。

### `delegate`：一个实现角色

仅当架构已经确定、目标可完整规格化、文件所有权明确，且交给一个角色能减少总时间或
提高实现质量时使用。选择：

- `agent_fleet_luna_implementer`：边界清晰、常规、验证明确的实现；
- `agent_fleet_terra_implementer`：判断密集、高风险、上下文重或影响面大的实现。

不要同时启动两个实现角色。实现角色完成 packet 后，主会话必须检查完整 diff 并重跑
验证；`delegate` 不自动增加审查角色。

### `evidence`：一个只读证据角色

仅当问题的关键瓶颈是事实追踪，而不是编码，例如需要独立核对真实调用链、配置加载顺序、
权限过滤、数据源、Redis/JSON、SQL 执行计划、日志或最终写入值时使用。

`agent_fleet_evidence_analyst` 只读运行，不实现修复。主会话接收报告后自行判断下一步；
不会因为收到报告就自动再派发实现角色。若报告发现新的高风险或范围证据，必须追加一段
`ROUTE ESCALATION`，说明证据后才能升级到 `delegate` 或 `full`。

### `audit`：实现后的独立只读审查

主会话先实现并验证，再启动一个新鲜的 `agent_fleet_reviewer`。适用于权限、数据一致性、
事务/缓存、并发、SQL、异常处理、发布或用户明确要求独立复核，但不值得交给实现角色的
场景。审查角色只返回 `ship`、`fix-first` 或 `rethink`。

### `full`：明确例外

只用于用户明确授权或任务确实是高风险/大影响面的例外：先选择一个实现角色，主会话检查
并验证，再顺序启动一个新鲜只读审查角色。它不是“更认真”的默认模式，也不是并行启动整
个舰队的开关。审查发现任何修复后，旧 verdict 失效，必须重新验证并启动新的 reviewer。

默认上限是一个辅助角色；`full` 的两个角色必须顺序执行，不能并行修改工作树。

## 派发前检查

在派发前，主会话必须：

- 读取适用的 `AGENTS.md`、README、构建/测试说明和当前工作树状态；
- 明确实际目标、排除范围、接口、文件所有权和成功标准；
- 对 `delegate/full` 写完整五段 worker packet；对 `evidence/audit` 写只读范围和证据标准；
- 不附加 per-spawn model 或 reasoning override，让安装的 TOML 角色固定其模型与 effort；
- 使用新鲜上下文，拒绝把无关历史任务或未验证记忆当作事实；
- 确认角色、模型、effort、sandbox 和 permission profile 可观测且符合所选 lane。任一项
  缺失、冲突、不可用或不可观测，都停止该 lane，不静默替换。

建议的精确 spawn contract：

```text
agent_type: agent_fleet_luna_implementer
fork_turns: none
```

```text
agent_type: agent_fleet_terra_implementer
fork_turns: none
```

```text
agent_type: agent_fleet_evidence_analyst
fork_turns: none
```

```text
agent_type: agent_fleet_reviewer
fork_turns: none
```

不附加模型和 reasoning 字段。角色模板是模型/effort 的来源；主会话只接受实际公开元数据
与模板一致的结果。

## 主会话与个人工作流边界

### 代码和仓库

- 先追踪真实路径：入口、过滤器、配置、权限、provider、Redis/JSON、序列化、传输和最终
  写入值；不要只根据类名或一个冷启动耗时下结论。
- 保留用户已有 dirty worktree，不 reset、checkout、clean、commit、push、merge 或 force-push。
- worker 只能修改 packet 中的文件；发现需要扩大 ownership 时先返回，不自行扩大。
- Java 保留合适的单行风格，只有超过项目边界才换行；MyBatis XML 的控制标签分行并保持层级缩进。

### Java/MyBatis/UAMA

- 保持 controller/service/mapper/XML 接口兼容，tinyint 对应实体属性使用 `Integer`。
- 显式检查事务边界、并发安全、空值、幂等、缓存一致性、SQL 索引与锁影响。
- Feign/import 场景不能假定 DTO 会回写 controller 原始输入；错误合并使用稳定行键，并
  保留全部回滚行供重试。
- 权限、社区/项目范围、数据源和配置 label 是业务边界；未经证据不得用全局缓存或全量查询替代。

### 数据库和外部系统

- 默认只读查询；`readonly` MCP/工具是应用护栏，不等于数据库授权。区分“工具允许查询”
  与“数据库事实已验证”。
- 禁止写入、删除、DDL、kill connection、生产配置或外部消息，除非当前任务明确授权并且
  主会话确认精确目标、回滚与验证方式。
- 密钥、token、环境变量中的秘密只判断是否存在，不读取、不复制、不写入插件或报告。

### macOS

- 优先使用 shell-first 的 build/run/test 证据和项目既有脚本；不把 ad hoc/local signing
  说成 notarization。
- 未经明确授权不复制到 `/Applications`、不修改系统默认应用、不替换用户安装包。

## Worker packet 与验收

`delegate/full` 的实现 prompt 必须完整包含以下字段，不能只给一句“帮我改好”：

```text
OBJECTIVE
<可观察的目标，以及为什么重要>

FILES AND OWNERSHIP
You own only:
- <绝对或仓库相对路径/模块>
Do not modify files outside this list. Preserve concurrent edits.

INTERFACES
- <签名、schema、命令、兼容性和行为约束>

CONSTRAINTS
- <项目规则、权限/数据边界、排除范围、已确定的架构>

VERIFICATION
- Run: <精确命令> -> Success: <具体预期证据>
- Inspect: <精确 diff/文件/产物> -> Success: <具体预期证据>

RETURN
Return actual commands and evidence.

IMPLEMENTATION REPORT
STATUS: complete | partial | blocked
OBJECTIVE: <一句话>
CHANGES: <按文件总结真实 diff>
VERIFIED: <命令与实际证据>
JUDGMENT CALLS: <关键判断，或 none>
GAPS: <未完成/歧义，或 none>
```

主会话不接受没有实际证据的 completion claim，必须重新检查完整 diff 和验证结果。

`evidence` 返回 `EVIDENCE REPORT`，至少包含 `STATUS`、`SCOPE`、`FACTS`、`TRACE`、
`UNVERIFIED`、`RISK`、`NEXT STEP`。`audit/full` 的 reviewer 返回：

```text
VERDICT: ship | fix-first | rethink
REASON: <决定性证据>
FINDINGS: <精确文件/行/行为，或 none>
RESIDUAL RISK: <最大残余风险，或 none>
```

查看 [role-contracts.md](references/role-contracts.md) 获取完整角色模板，查看
[operations.md](references/operations.md) 获取安装、隔离和验收规则。
