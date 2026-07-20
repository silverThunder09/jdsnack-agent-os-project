#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROUTER="$ROOT_DIR/.github/workflows/pr-ci-router.yml"

assert_contains() {
    local file="$1"
    local expected="$2"
    grep -Fq -- "$expected" "$file" || {
        printf 'Missing expected text in %s: %s\n' "$file" "$expected" >&2
        exit 1
    }
}

assert_not_contains() {
    local file="$1"
    local unexpected="$2"
    if grep -Fq -- "$unexpected" "$file"; then
        printf 'Unexpected text in %s: %s\n' "$file" "$unexpected" >&2
        exit 1
    fi
}

for workflow in backend-ci.yml frontend-ci.yml container.yml docs-harness.yml; do
    file="$ROOT_DIR/.github/workflows/$workflow"
    assert_not_contains "$file" '  pull_request:'
done

assert_contains "$ROUTER" 'name: PR CI Router'
assert_contains "$ROUTER" "- 'backend/**'"
assert_contains "$ROUTER" "- 'frontend/**'"
assert_contains "$ROUTER" "- 'backend/Dockerfile'"
assert_contains "$ROUTER" "- 'frontend/Dockerfile'"
assert_contains "$ROUTER" "- '.agent-os/**'"
assert_contains "$ROUTER" "- '.github/workflows/**'"
assert_contains "$ROUTER" 'name: PR CI Gate'
assert_contains "$ROUTER" 'name: Test and build backend'
assert_contains "$ROUTER" 'name: Test and build frontend'
assert_contains "$ROUTER" 'name: Build backend container'
assert_contains "$ROUTER" 'name: Run compose smoke test'
assert_contains "$ROUTER" 'name: Validate Agent OS docs'
assert_contains "$ROUTER" 'name: Workflow CI'
assert_contains "$ROUTER" 'run: bash scripts/docs-harness.sh'
assert_contains "$ROUTER" 'run: bash scripts/workflow-ci-test.sh'
assert_not_contains "$ROUTER" 'uses: ./.github/workflows/'

test -x "$ROOT_DIR/scripts/docs-harness.sh"

printf 'PR CI router contract passed\n'
