# Agent Fleet

[English](README.en.md) | [中文](README.md)

Agent Fleet is a Codex-native subagent role pool inspired by the risk-gating
ideas in [Sol Advisor](https://github.com/DannyMac180/sol-advisor). It focuses on
Java/MyBatis backends, database evidence, macOS builds, and Git worktree discipline.

The most important rule is: **installing roles does not start roles, and the role
pool does not dispatch a subagent for every task.** Every task starts in `solo`.
The main session chooses another route only when parallel execution or independent
review provides a clear benefit. At most one helper role is used by default;
`full` is reserved for explicit high-risk exceptions.

## Installation

Replace `/path/to/codex-marketplace` below with the local marketplace directory:

```sh
codex plugin marketplace add /path/to/codex-marketplace
codex plugin add agent-fleet@personal
```

After installing the plugin, optionally install the four companion custom-agent
templates. The installer creates only missing files. It fails closed when a target
is modified, a symlink, a non-regular file, or otherwise conflicts, and never
overwrites an existing target:

```sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "agent-fleet@personal") | .source.path')"
test -n "$plugin_dir" && test "$plugin_dir" != null
sh "$plugin_dir/scripts/install-agents.sh"
```

Start a new task after installation so Codex can discover the native roles. The
plugin does not modify Codex's default agent routing and does not dispatch a
subagent for every new task.

## Usage

After the plugin is installed and enabled, you normally do not need to type
`$agent-fleet:orchestration` in every task. Describe the task directly. When the
task involves complex investigation, parallel implementation, or an independent
review, Codex can match these routing rules and first decide whether a subagent is
worth using. Simple tasks remain `solo`.

If you want to explicitly request these rules, use:

```text
Use the Agent Fleet rules: default to solo and enable a subagent only when necessary.
```

When a role is actually needed, the main session first emits a declaration such as:

```text
SELECTIVE ROUTE
mode: solo
role: none
risk: The task is small and well-scoped; direct implementation and verification are cheaper.
expected_gain: Do not enable a subagent.
```

Available routes:

| Route | Default | Use case | Roles |
| --- | --- | --- | --- |
| `solo` | Yes | Small changes, clear questions, single-file work, direct answers, or an explicit no-edit request | 0 |
| `delegate` | No | A bounded task with a settled design that can be fully assigned to one implementation role | 1 |
| `evidence` | No | Independent read-only tracing of code, configuration, permissions, databases, or runtime evidence before deciding | 1 |
| `audit` | No | The main session has implemented and verified the change but needs an independent read-only review | 1 |
| `full` | Exception | An explicitly high-risk or wide-impact task: implement first, then review | 2, sequentially |

`delegate` selects a regular or high-risk implementation role. `evidence` uses the
read-only evidence analyst. `audit` and `full` use the read-only final reviewer.
If a role is unavailable, or its model, permission, or isolation metadata conflicts
or cannot be observed, the main session must stop that lane rather than silently
substitute another role or model.

## Workflow boundaries

- Read the project's `AGENTS.md`, README, build rules, and existing diff before writing a worker packet.
- For Java/MyBatis tasks, trace controller → service → mapper/XML → SQL → configuration/cache/permissions/serialization while preserving interfaces, transaction boundaries, permission boundaries, and XML formatting.
- Treat database access as read-only by default. Distinguish execution plans, locks, data sources, and permission facts from assumptions. Writes, deletes, DDL, connection termination, and production changes require explicit authorization for the current task.
- Do not commit, push, reset, or checkout user-owned changes; workers may modify only files they explicitly own.
- For macOS tasks, prefer shell-first build and test evidence. Local signing is not notarization, and installation into `/Applications` requires authorization.
- Return actual commands and evidence. A claim that something “looks successful” does not replace tests, diffs, logs, database evidence, or build results.

## Local verification

Run these commands from the plugin repository root:

```sh
sh scripts/verify.sh
python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/plugin-creator/scripts/validate_plugin.py" .
```

When updating an installed plugin, use the plugin-creator cachebuster/reinstall
workflow and verify it in a new task. Do not edit marketplace configuration by hand.
