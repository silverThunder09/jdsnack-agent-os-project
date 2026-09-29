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
assert_contains "$ROUTER" "- 'compose.yaml'"
assert_contains "$ROUTER" "- 'backend/Dockerfile'"
assert_contains "$ROUTER" "- 'frontend/Dockerfile'"
assert_contains "$ROUTER" "- '.agent-os/**'"
assert_contains "$ROUTER" "- '.github/pull_request_template.md'"
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

container_filter="$(sed -n '/^            container:/,/^            docs:/p' "$ROUTER")"
case "$container_filter" in
    *"- 'backend/**'"*) ;;
    *)
        printf 'Container runtime gate must include backend source changes\n' >&2
        exit 1
        ;;
esac
case "$container_filter" in
    *"- 'frontend/**'"*) ;;
    *)
        printf 'Container runtime gate must include frontend source changes\n' >&2
        exit 1
        ;;
esac

# Flyway migration을 실제 PostgreSQL 프로파일로 검증하는 잡(Issue #175).
# H2만 쓰는 게이트로는 PostgreSQL 연결·마이그레이션 동작을 확인할 수 없어 추가된 잡이며,
# 집계 게이트에 연결돼 있지 않으면 실패해도 머지를 막지 못한다.
assert_contains "$ROUTER" 'name: Verify Flyway migrations on PostgreSQL'
assert_contains "$ROUTER" 'image: postgres:16'
assert_contains "$ROUTER" 'com.jdsnack.schema.PostgresMigrationTest'
assert_contains "$ROUTER" 'needs.postgres_schema.result'
grep -Fq 'needs: [detect, pr_contract, backend, postgres_schema,' "$ROUTER" || {
    printf 'PR CI Gate must depend on postgres_schema in %s\n' "$ROUTER" >&2
    exit 1
}

test -x "$ROOT_DIR/scripts/docs-harness.sh"

printf 'PR CI router contract passed\n'
