#!/bin/sh
# Repository-local verification for Agent Fleet.

set -eu

pass() {
  printf '%s\n' "PASS: $*"
}

fail() {
  printf '%s\n' "FAIL: $*" >&2
  exit 1
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd -- "$script_dir/.." && pwd) || exit 1
manifest=$plugin_dir/.codex-plugin/plugin.json
skill=$plugin_dir/skills/orchestration/SKILL.md
contracts=$plugin_dir/skills/orchestration/references/role-contracts.md
operations=$plugin_dir/skills/orchestration/references/operations.md
installer=$script_dir/install-agents.sh

[ -f "$manifest" ] && [ ! -L "$manifest" ] || fail "missing manifest: $manifest"
[ -f "$skill" ] || fail "missing orchestration skill: $skill"
[ -f "$contracts" ] || fail "missing role contracts: $contracts"
[ -f "$operations" ] || fail "missing operations reference: $operations"
[ -f "$installer" ] || fail "missing installer: $installer"

python3 - "$manifest" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)

assert data["name"] == "agent-fleet"
assert data["version"] == "0.1.0"
assert data["skills"] == "./skills/"
interface = data["interface"]
for key in ("displayName", "shortDescription", "longDescription", "developerName", "category"):
    assert isinstance(interface.get(key), str) and interface[key]
prompts = interface["defaultPrompt"]
assert isinstance(prompts, list) and 1 <= len(prompts) <= 3
assert all(isinstance(prompt, str) and len(prompt) <= 128 for prompt in prompts)
assert "[TODO:" not in json.dumps(data, ensure_ascii=False)
PY
pass 'manifest is valid and contains no TODO placeholders'

python3 - "$plugin_dir/agents" <<'PY'
import sys
import tomllib
from pathlib import Path

root = Path(sys.argv[1])
expected = {
    "agent-fleet-luna-implementer.toml": ("agent_fleet_luna_implementer", "gpt-5.6-luna", "max", None),
    "agent-fleet-terra-implementer.toml": ("agent_fleet_terra_implementer", "gpt-5.6-terra", "high", None),
    "agent-fleet-evidence-analyst.toml": ("agent_fleet_evidence_analyst", "gpt-5.6-sol", "high", "read-only"),
    "agent-fleet-reviewer.toml": ("agent_fleet_reviewer", "gpt-5.6-sol", "high", "read-only"),
}
for filename, values in expected.items():
    path = root / filename
    assert path.is_file() and not path.is_symlink(), path
    with path.open("rb") as handle:
        data = tomllib.load(handle)
    name, model, effort, sandbox = values
    assert data["name"] == name
    assert data["model"] == model
    assert data["model_reasoning_effort"] == effort
    if sandbox is None:
        assert "sandbox_mode" not in data
    else:
        assert data["sandbox_mode"] == sandbox
    assert data["developer_instructions"].strip()
PY
pass 'all four role TOMLs are valid and pinned to their intended lanes'

sh -n "$installer"
pass 'installer shell syntax is valid'

grep -q 'mode: solo | delegate | evidence | audit | full' "$skill" || fail 'route modes are incomplete'
grep -q '本插件不会自动触发 subagent' "$skill" || fail 'default-no-spawn invariant is missing'
grep -q 'SELECTIVE ROUTE' "$skill" || fail 'route declaration is missing'
grep -q 'OBJECTIVE' "$contracts" || fail 'worker packet contract is missing'
grep -q 'sandbox_mode = "read-only"' "$operations" || fail 'read-only operation rule is missing'
pass 'selective routing and safety contracts are present'

tmp_base=${TMPDIR:-/tmp}
case "$tmp_base" in
  /*) ;;
  *) tmp_base=/tmp ;;
esac
tmp_dir=$(mktemp -d "$tmp_base/agent-fleet-verify.XXXXXX") ||
  fail 'could not create disposable verification directory'
cleanup() {
  case "$tmp_dir" in
    "$tmp_base"/agent-fleet-verify.*) rm -rf "$tmp_dir" ;;
    *) printf '%s\n' "REFUSING cleanup of unexpected directory: $tmp_dir" >&2 ;;
  esac
}
trap cleanup 0 HUP INT TERM

target=$tmp_dir/agents
sh "$installer" --target-dir "$target" >/dev/null
sh "$installer" --target-dir "$target" --check >/dev/null
sh "$installer" --target-dir "$target" --check-role reviewer >/dev/null
pass 'installer installs and checks all roles plus a selective reviewer check'

printf '%s\n' 'user-owned content' > "$target/agent-fleet-luna-implementer.toml"
if sh "$installer" --target-dir "$target" >/dev/null 2>&1; then
  fail 'installer overwrote a conflicting role file'
fi
[ "$(sed -n '1p' "$target/agent-fleet-luna-implementer.toml")" = 'user-owned content' ] ||
  fail 'conflicting role file changed after failed install'
pass 'installer fails closed on a conflicting destination'

printf '%s\n' 'verification complete'
