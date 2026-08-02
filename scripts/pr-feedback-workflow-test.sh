#!/usr/bin/env bash
set -euo pipefail

# `PR Feedback Detector` 워크플로의 동시성 계약을 고정한다.
#
# 배경: 그룹 키에 `github.event.workflow_run.id`가 들어 있던 동안, 그 값이 실행마다
# 고유해서 같은 대상에 대한 repair가 전부 다른 그룹으로 분류됐다. 그룹 선언은
# 있었지만 중복 억제가 전혀 일어나지 않았고, 이벤트 수만큼 잡이 그대로 실행됐다.
# YAML 신택스 검증(`workflow-ci-test.sh`의 ruby 파싱)만으로는 이 결함을 잡을 수
# 없어 계약 테스트로 고정한다.
#
# 참고: `pr-feedback-detector-test.sh`는 같은 이름의 셸 스크립트 동작을 검증하며
# 이 파일과 관심사가 다르다.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/pr-feedback-detector.yml"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="$3"
    if [ "$expected" != "$actual" ]; then
        fail "$label (expected $expected, got $actual)"
    fi
}

[ -f "$WORKFLOW" ] || fail "워크플로 파일이 없습니다: $WORKFLOW"

group_line="$(grep -F 'group: jdsnack-review-repair-' "$WORKFLOW" || true)"
[ -n "$group_line" ] && [ "$(printf '%s\n' "$group_line" | grep -c .)" -eq 1 ] \
    || fail 'repair 잡의 concurrency group 줄을 정확히 하나 찾지 못했습니다.'

# 실행마다 달라지는 식별자를 그룹 키에 쓰면 그룹이 매번 새로 생겨 무력화된다.
case "$group_line" in
    *'workflow_run.id'*)
        fail 'concurrency group에 workflow_run.id가 있습니다. 실행마다 고유한 값이라 중복 억제가 무력화됩니다. workflow_run.head_branch를 쓰세요.'
        ;;
esac

# 그룹 키는 "무엇을 고치는가"를 좁은 범위부터 순서대로 폴백해야 한다.
expected_order='issue.number pull_request.number workflow_run.head_branch github.run_id'
previous=-1
for term in $expected_order; do
    case "$group_line" in
        *"$term"*) ;;
        *) fail "concurrency group에 폴백 항목이 없습니다: $term" ;;
    esac
    prefix="${group_line%%$term*}"
    position="${#prefix}"
    if [ "$position" -le "$previous" ]; then
        fail "concurrency group의 폴백 순서가 잘못됐습니다. 기대 순서: $expected_order"
    fi
    previous="$position"
done

# 샘플 payload로 GitHub Actions의 `||` 폴백이 실제 group 값으로 계산되는지 확인한다.
# `github.run_id`는 이벤트 payload가 아니라 workflow context이므로 별도 인자로 주입한다.
group_expression="$(printf '%s\n' "$group_line" | sed -E 's/.*\$\{\{ (.*) \}\}.*/\1/')"
expected_expression='github.event.issue.number || github.event.pull_request.number || github.event.workflow_run.head_branch || github.run_id'
assert_eq "$expected_expression" "$group_expression" 'concurrency group expression'

resolve_group() {
    local payload="$1"
    local run_id="$2"
    local term
    local value

    for term in $group_expression; do
        [ "$term" = '||' ] && continue
        value=''
        case "$term" in
            github.event.issue.number)
                value="$(printf '%s' "$payload" | jq -r '.issue.number // empty')"
                ;;
            github.event.pull_request.number)
                value="$(printf '%s' "$payload" | jq -r '.pull_request.number // empty')"
                ;;
            github.event.workflow_run.head_branch)
                value="$(printf '%s' "$payload" | jq -r '.workflow_run.head_branch // empty')"
                ;;
            github.run_id)
                value="$run_id"
                ;;
            *)
                fail "unsupported concurrency group term: $term"
                ;;
        esac
        if [ -n "$value" ]; then
            printf 'jdsnack-review-repair-%s\n' "$value"
            return 0
        fi
    done

    fail 'concurrency group expression produced no value'
}

workflow_run_payload='{"workflow_run":{"head_branch":"codex/fix-repair-job-debounce"}}'
issue_comment_payload='{"issue":{"number":182}}'
workflow_dispatch_payload='{}'
assert_eq \
    'jdsnack-review-repair-codex/fix-repair-job-debounce' \
    "$(resolve_group "$workflow_run_payload" 701)" \
    'workflow_run group value'
assert_eq \
    'jdsnack-review-repair-182' \
    "$(resolve_group "$issue_comment_payload" 702)" \
    'issue_comment group value'
assert_eq \
    'jdsnack-review-repair-703' \
    "$(resolve_group "$workflow_dispatch_payload" 703)" \
    'workflow_dispatch group value'

# 진행 중인 repair를 취소하면 Codex 디스패치가 중간에 끊겨 작업이 유실될 수 있다.
# 중복 억제는 취소가 아니라 대기열 접기로 달성한다.
grep -Fq 'cancel-in-progress: false' "$WORKFLOW" \
    || fail 'repair 잡은 cancel-in-progress: false를 유지해야 합니다. 진행 중 작업을 취소하면 Codex 디스패치가 유실될 수 있습니다.'

printf 'PR feedback detector workflow contract passed\n'
