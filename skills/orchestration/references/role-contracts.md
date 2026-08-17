# Agent Fleet role contracts

这些 contract 用于当前插件安装的 namespaced native custom agents。它们不会启动嵌套
Codex CLI，不会改变默认 agent 路由，也不会因为插件安装而自动运行。

## 共同 route contract

主会话在需要工具的任务首个工具调用前声明：

```text
SELECTIVE ROUTE
mode: solo | delegate | evidence | audit | full
role: <exact role name or none>
risk: <task-specific evidence>
expected_gain: <task-specific gain or why solo wins>
```

`solo` 默认；只有 route 证据变化才能升级，并追加：

```text
ROUTE ESCALATION
from: <old mode>
to: <new mode>
evidence: <newly observed risk or benefit>
```

不能静默降级，也不能在 `solo/delegate` 中因为“顺便看一下”偷偷加入 reviewer。

## 实现角色的五段 packet

每个 Luna/Terra prompt 必须包含：

```text
OBJECTIVE
<observable outcome and why it matters>

FILES AND OWNERSHIP
You own only:
- <exact file or module>
Preserve concurrent edits and do not modify files outside this list.

INTERFACES
- <signatures, types, schemas, commands, compatibility>

CONSTRAINTS
- <repository rules, data/permission boundaries, excluded scope>

VERIFICATION
- Run: <exact command>
  Success: <concrete expected evidence>
- Inspect: <exact diff/artifact/runtime evidence>
  Success: <concrete expected evidence>

RETURN
Return exact commands and actual evidence.

IMPLEMENTATION REPORT
STATUS: complete | partial | blocked
OBJECTIVE: <one-line restatement>
CHANGES: <file-by-file actual diff>
VERIFIED: <commands plus concrete output>
JUDGMENT CALLS: <open decisions, or none>
GAPS: <unfinished work, ambiguity, or none>
```

主会话负责完整 diff、验证重跑和 acceptance；worker 的报告不能替代这些检查。

## Luna 常规实现

精确 spawn：

```text
agent_type: agent_fleet_luna_implementer
fork_turns: none
```

只用于边界清晰、架构已定、可完整规格化的 routine implementation。遇到判断密集、高风险、
宽影响面或路由误分类，返回信号让主会话升级 Terra；不先自行重构。

## Terra 高风险实现

精确 spawn：

```text
agent_type: agent_fleet_terra_implementer
fork_turns: none
```

只用于已声明的高风险 delegate/full，或者前一条 Luna 结果新发现了高风险证据。它不能
静默替代 Luna，也不能跳过主会话的架构与 packet。

## Evidence 只读分析

精确 spawn：

```text
agent_type: agent_fleet_evidence_analyst
fork_turns: none
```

只用于 `evidence`。角色要求 read-only sandbox，但主会话仍需观察实际 sandbox 和 permission
profile；只读请求不可观测或发生任何变更时，不能宣称隔离成立。

返回：

```text
EVIDENCE REPORT
STATUS: complete | partial | blocked
SCOPE: <实际调查范围>
FACTS: <可复现事实，带文件/SQL/日志/命令证据>
TRACE: <调用链、配置链、权限链或数据链>
UNVERIFIED: <缺失或不可观测事实，或 none>
RISK: <对决策的影响>
NEXT STEP: <主会话应如何验证或决策>
```

它不实现修复、不修改文件、不提交，不把推断写成事实。

## Reviewer 只读审查

精确 spawn：

```text
agent_type: agent_fleet_reviewer
fork_turns: none
```

只用于 `audit/full`，且在主会话完成验证后用新鲜上下文启动。它必须检查真实 diff、接口、
约束和证据，严格只读，返回且只返回一个 verdict：

```text
REVIEW
VERDICT: ship | fix-first | rethink
REASON: <evidence-backed reason>
FINDINGS: <precise findings or none>
RESIDUAL RISK: <most important remaining risk or none>
```

任何修复都会让原 verdict 失效；修复后必须重新验证并新建 reviewer。Reviewer 不修复自己
发现的问题。
