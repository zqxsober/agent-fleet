#!/bin/sh
# Install Agent Fleet's exact native custom-agent templates without editing Codex config.

set -eu

usage() {
  cat <<'EOF'
Usage: install-agents.sh [--target-dir PATH] [--check] [--check-role ROLE ...]

Install the four Agent Fleet role templates into the target directory.
Normal mode installs only missing role files and never overwrites a modified,
unsafe, non-regular, or symlinked destination.

Without --target-dir, the target is "$CODEX_HOME/agents" when CODEX_HOME is
set, otherwise "$HOME/.codex/agents".

Options:
  --target-dir PATH                 Explicit destination directory.
  --check                           Verify all installed role files; do not mutate.
  --check-role ROLE                 Verify only luna, terra, evidence, or reviewer.
                                     Repeatable and implies --check.
  --help                            Show this help text.
EOF
}

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

role_selected() {
  role=$1
  if [ -z "$check_roles" ]; then
    return 0
  fi
  case ",$check_roles," in
    *,"$role",*) return 0 ;;
    *) return 1 ;;
  esac
}

role_file() {
  case "$1" in
    luna) printf '%s\n' 'agent-fleet-luna-implementer.toml' ;;
    terra) printf '%s\n' 'agent-fleet-terra-implementer.toml' ;;
    evidence) printf '%s\n' 'agent-fleet-evidence-analyst.toml' ;;
    reviewer) printf '%s\n' 'agent-fleet-reviewer.toml' ;;
    *) fail "unknown role '$1'" ;;
  esac
}

classify() {
  destination=$1
  template=$2
  if ! path_exists "$destination"; then
    printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then
    printf '%s\n' unsafe
  elif cmp -s "$template" "$destination"; then
    printf '%s\n' current
  else
    printf '%s\n' conflict
  fi
}

install_missing() {
  template=$1
  destination=$2
  staged=''

  if path_exists "$destination"; then
    fail "destination changed after preflight and will not be overwritten: $destination"
  fi
  staged=$(mktemp "$target_dir/.agent-fleet.XXXXXX") ||
    fail "could not stage template for installation: $destination"
  if ! cp "$template" "$staged"; then
    rm -f "$staged"
    fail "could not stage template for installation: $destination"
  fi
  if ! ln "$staged" "$destination"; then
    rm -f "$staged"
    fail "destination changed after preflight and will not be overwritten: $destination"
  fi
  rm -f "$staged" || fail "could not remove staging file: $staged"
  printf '%s\n' "INSTALLED: $destination"
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
template_dir=$script_dir/../agents

if [ -n "${CODEX_HOME-}" ]; then
  target_dir=$CODEX_HOME/agents
else
  [ -n "${HOME-}" ] || fail 'HOME is unset; pass --target-dir explicitly.'
  target_dir=$HOME/.codex/agents
fi

check_only=0
check_roles=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-dir)
      [ "$#" -ge 2 ] || fail '--target-dir requires a path.'
      [ -n "$2" ] || fail '--target-dir requires a non-empty path.'
      case "$2" in
        --*) fail '--target-dir must be an explicit path.' ;;
      esac
      target_dir=$2
      shift 2
      ;;
    --check)
      check_only=1
      shift
      ;;
    --check-role)
      [ "$#" -ge 2 ] || fail '--check-role requires luna, terra, evidence, or reviewer.'
      case "$2" in
        luna|terra|evidence|reviewer) ;;
        *) fail "unknown --check-role '$2'." ;;
      esac
      check_only=1
      check_roles=$check_roles$2,
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1 (run with --help for usage)."
      ;;
  esac
done

case "$target_dir" in
  /*) ;;
  *) target_dir=$(pwd -P)/$target_dir ;;
esac
case "$target_dir" in
  /|//) fail 'refusing to use the filesystem root as an agent target directory.' ;;
esac

for role in luna terra evidence reviewer; do
  template=$template_dir/$(role_file "$role")
  [ -f "$template" ] && [ ! -L "$template" ] ||
    fail "shipped template is missing or not a regular file: $template"
done

preflight_failed=0
for role in luna terra evidence reviewer; do
  role_selected "$role" || continue
  file=$(role_file "$role")
  template=$template_dir/$file
  destination=$target_dir/$file
  state=$(classify "$destination" "$template")
  if [ "$check_only" -eq 1 ]; then
    [ "$state" = current ] || {
      printf '%s\n' "ERROR: $role template is $state, not current: $destination" >&2
      preflight_failed=1
    }
  else
    case "$state" in
      current|missing) ;;
      *)
        printf '%s\n' "ERROR: $role destination is $state and will not be replaced: $destination" >&2
        preflight_failed=1
        ;;
    esac
  fi
done
[ "$preflight_failed" -eq 0 ] || exit 1

if [ "$check_only" -eq 1 ]; then
  if [ -n "$check_roles" ]; then
    printf '%s\n' "CHECK PASSED: selected role templates exactly match $template_dir."
  else
    printf '%s\n' "CHECK PASSED: all role templates exactly match $template_dir."
  fi
  exit 0
fi

if path_exists "$target_dir"; then
  [ -d "$target_dir" ] && [ ! -L "$target_dir" ] ||
    fail "target directory is not a real directory: $target_dir"
else
  mkdir -p "$target_dir" || fail "could not create target directory: $target_dir"
fi

for role in luna terra evidence reviewer; do
  file=$(role_file "$role")
  template=$template_dir/$file
  destination=$target_dir/$file
  state=$(classify "$destination" "$template")
  case "$state" in
    missing) install_missing "$template" "$destination" ;;
    current) printf '%s\n' "ALREADY CURRENT: $destination" ;;
    *) fail "$role destination changed after preflight: $destination ($state)" ;;
  esac
done

for role in luna terra evidence reviewer; do
  file=$(role_file "$role")
  template=$template_dir/$file
  destination=$target_dir/$file
  [ "$(classify "$destination" "$template")" = current ] ||
    fail "post-install exactness check failed: $destination"
done
printf '%s\n' "INSTALL PASSED: all four Agent Fleet roles exactly match $template_dir."
