#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jdsnack-autonomous-auth.XXXXXX")"
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT HUP INT TERM

trusted_bash_bin="$(command -v bash)"
trusted_env_bin="$(command -v env)"
trusted_mktemp_bin="$(command -v mktemp)"
trusted_chmod_bin="$(command -v chmod)"
trusted_rm_bin="$(command -v rm)"
trusted_path="$(dirname "$trusted_env_bin"):$(dirname "$trusted_mktemp_bin"):$(dirname "$trusted_chmod_bin"):$(dirname "$trusted_rm_bin")"
askpass_capture="$TEST_ROOT/askpass-capture"
auth_repo="$TEST_ROOT/auth-repo"
mkdir -p "$auth_repo"

cat > "$TEST_ROOT/trusted-git" <<EOF
#!$trusted_bash_bin
if [ -n "\${GIT_ASKPASS-}" ] && [ -x "\${GIT_ASKPASS-}" ]; then
  printf '%s\n' askpass-present > '$askpass_capture'
else
  printf '%s\n' askpass-missing > '$askpass_capture'
fi
EOF
chmod 700 "$TEST_ROOT/trusted-git"

eval "$(sed -n '/^run_trusted_github_git() (/,/^)/p' "$ROOT_DIR/scripts/autonomous-spec-loop.sh")"
run_trusted_git() {
  case "$*" in
    *"remote get-url origin"*)
      printf '%s\n' 'https://github.com/silverThunder09/jdsnack-agent-os-project.git'
      ;;
    *)
      "$TRUSTED_GIT_BIN" "$@"
      ;;
  esac
}

REPO="$auth_repo"
STATE_DIR="$TEST_ROOT"
GH_TOKEN=fixture-token
TRUSTED_ENV_BIN="$trusted_env_bin"
TRUSTED_MKTEMP_BIN="$trusted_mktemp_bin"
TRUSTED_CHMOD_BIN="$trusted_chmod_bin"
RM_BIN="$trusted_rm_bin"
TRUSTED_PATH="$trusted_path"
TRUSTED_GIT_BIN="$TEST_ROOT/trusted-git"
export REPO STATE_DIR GH_TOKEN TRUSTED_ENV_BIN TRUSTED_MKTEMP_BIN TRUSTED_CHMOD_BIN RM_BIN TRUSTED_PATH TRUSTED_GIT_BIN

run_trusted_github_git -C "$auth_repo" ls-remote origin
askpass_state="$(<"$askpass_capture")"
if [ "$askpass_state" != askpass-present ]; then
  printf 'FAIL: trusted Git lost the askpass boundary (%s)\n' "${askpass_state:-missing-result}" >&2
  exit 1
fi

printf 'Autonomous GitHub askpass boundary contract passed\n'
