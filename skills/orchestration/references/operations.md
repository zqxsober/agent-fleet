# Native operations and safety rules

## 角色安装

插件安装不会自动把角色写入 `$CODEX_HOME/agents`。用户明确选择安装 companion roles 后，
运行：

```sh
sh plugins/agent-fleet/scripts/install-agents.sh
sh plugins/agent-fleet/scripts/install-agents.sh --check
```

可以用 `--target-dir PATH` 指定测试或自定义目录，也可以用 `--check-role luna|terra|evidence|reviewer`
只检查当前 route 选中的角色。安装脚本的规则：

- 缺失的普通文件才会安装；
- 已存在且 byte-exact 的文件保持不动；
- 修改过、符号链接、目录、设备文件、不可读或任何冲突都 fail closed；
- 不删除未知文件，不编辑 `config.toml`，不修改默认 agent 路由；
- 安装后做 exactness check，完成后在新 task 验证。

目标目录必须是明确的非根目录，不能用 `/`、空路径或未解析的宽泛 glob。

## Route 与 preflight

| Route | 选中的角色 | 派发前检查 |
| --- | --- | --- |
| `solo` | none | 无 native role |
| `delegate` | Luna 或 Terra | 只检查被选中的实现 role |
| `evidence` | Evidence Analyst | 只检查 evidence role |
| `audit` | Reviewer | 只检查 reviewer role |
| `full` | 一个实现 role + Reviewer | 先检查实现 role，验证后再检查 reviewer |

运行时公开 spawn/details 元数据优先；如能看到 role、model、effort、sandbox、permission profile，
必须与 TOML 和 route 一致。缺失、冲突、不可用或不可观测都停止受影响 lane，禁止静默 fallback。
不要附加 per-spawn model/reasoning override。

`sandbox_mode = "read-only"` 是 reviewer/evidence 的请求，不等于已经观察到隔离。若实际
权限变宽，只有在硬隔离不是硬要求、prompt 明确禁止修改、且主会话保存精确 before/after
状态时才能继续，并在最终报告中说明残余风险；若隔离不可观测或发生任何变更，停止并不
宣称只读 verdict。

## 父会话验收

主会话必须直接完成：

1. 检查完整工作树 diff 和 changed-file scope；
2. 重新执行 packet 中要求的测试/构建/查询/产物检查；
3. 核对角色报告中的事实、模型/effort、sandbox 和权限证据；
4. 判断是否需要升级 route，记录新证据；
5. 只有满足用户目标、范围、验证和安全边界后才报告完成。

`fix-first` 后不能沿用旧审查结果；`rethink` 不是完成状态。若实现角色返回 partial/blocked，
主会话应缩小范围、补充 packet 或选择带证据的升级，而不是强行宣布成功。

## 用户工作流安全

- 维护当前工作树，不 reset、checkout、clean、commit、push、merge 或 force-push。
- Java/MyBatis 先读项目规则，追踪实际调用链；不根据命名或单次慢测量断言根因。
- DB/MCP 默认只读；任何写、删、DDL、kill connection、生产变更需当前任务明确授权。
- 不读取、保存、打印或写入密钥/token；只报告安全的存在性或缺失事实。
- 本地 macOS 签名和构建证据不能升级为 notarization；未授权不复制到 `/Applications`。
