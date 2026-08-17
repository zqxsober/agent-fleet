# Agent Fleet

[English](README.en.md) | 中文

Agent Fleet 是一个面向 Codex 的 native subagent 角色池，参考
[Sol Advisor](https://github.com/DannyMac180/sol-advisor) 的风险门控思想，重点覆盖
Java/MyBatis 后端、数据库证据、macOS 构建和 Git 工作树纪律。

最重要的行为约束：**安装角色不等于启动角色，角色池也不等于每个会话都开 subagent。**
每个任务都从 `solo` 开始；只有当主会话判断并行执行或独立审查能带来明确收益时，才选择
其它路线。默认最多一个辅助角色，`full` 只用于明确的高风险例外。

## 安装

将下面命令中的 `/path/to/codex-marketplace` 替换为本地 marketplace 目录：

```sh
codex plugin marketplace add /path/to/codex-marketplace
codex plugin add agent-fleet@personal
```

安装插件后，按需安装四个 companion custom-agent 模板。这个脚本只会创建缺失文件，遇到
被修改、符号链接、非普通文件或内容冲突的目标会 fail closed，不会覆盖它们：

```sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "agent-fleet@personal") | .source.path')"
test -n "$plugin_dir" && test "$plugin_dir" != null
sh "$plugin_dir/scripts/install-agents.sh"
```

安装完成后启动新 task，使 Codex 发现新的 native roles。插件本身不会修改 Codex 默认
agent 路由，也不会让每个新 task 自动派发 subagent。

## 使用

安装并启用插件后，通常不需要在每个 task 中手动输入 `$agent-fleet:orchestration`。
直接描述你的任务即可；当任务确实涉及复杂排查、并行实现或独立审查时，Codex 会自动匹配
这套调度规则，先判断是否值得启用 subagent。简单任务保持 `solo`，不会因为插件已安装而
自动启动角色。

如果你想显式指定这套规则，只需要一句话：

```text
按 Agent Fleet 规则处理，默认 solo，只有必要时才启用 subagent。
```

一旦判断确实需要调用角色，主会话会先输出类似下面的声明：

```text
SELECTIVE ROUTE
mode: solo
role: none
risk: 单模块、边界清晰，直接实现并验证的成本最低
expected_gain: 不启用 subagent
```

可选路线：

| 路线 | 默认 | 适用场景 | 角色数量 |
| --- | --- | --- | --- |
| `solo` | 是 | 小改动、明确问题、单文件、直接回答、用户要求不改代码 | 0 |
| `delegate` | 否 | 架构已定且可完整交给一个实现角色的边界任务 | 1 |
| `evidence` | 否 | 需要独立只读追踪代码、配置、权限、DB 或运行证据再决策 | 1 |
| `audit` | 否 | 主会话已实现并验证，但需要独立只读审查 | 1 |
| `full` | 例外 | 明确的高风险或大影响面任务：实现后再审查 | 2，顺序执行 |

`delegate` 选择常规实现角色或风险实现角色；`evidence` 使用只读证据分析角色；
`audit/full` 使用只读最终审查角色。任何角色不可用、模型/权限/隔离信息冲突或不可观测时，
主会话必须停止该 lane，不能静默替换模型或角色。

## 工作流边界

- 先读项目 `AGENTS.md`、README、模块构建规则和现有 diff，再编写 worker packet。
- Java/MyBatis 任务沿 controller → service → mapper/XML → SQL → 配置/缓存/权限/序列化
  追踪；保留接口、事务边界、权限边界和 XML 层级格式。
- DB 默认只读；执行计划、锁、数据源和权限事实要与推测区分。写入、删除、DDL、kill
  connection、生产变更仍需当前任务明确授权。
- 不提交、不 push、不 reset/checkout 用户已有改动；worker 只修改明确拥有的文件。
- macOS 任务优先 shell-first build/test；本地签名不等于 notarization，未经授权不安装到
  `/Applications`。
- 返回实际命令和证据；“看起来成功”不能替代测试、diff、日志、DB 或构建结果。

## 本地验证

在插件仓库根目录执行：

```sh
sh scripts/verify.sh
python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/plugin-creator/scripts/validate_plugin.py" .
```

更新已安装插件时，使用 plugin-creator 的 cachebuster/reinstall 流程，并在新 task 验证；
不要手工改 marketplace 配置。
