#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACT_SCRIPT="$ROOT_DIR/scripts/pr-contract-test.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

gh() {
  if [ "${GH_FIXTURE_MODE:-}" = "metadata_error" ]; then
    echo "fake metadata failure" >&2
    return 1
  fi

  case "$*" in
    *"--json title --template"*)
      printf '%s\n' "$GH_FIXTURE_TITLE"
      ;;
    *"--json body --template"*)
      printf '%s\n' "$GH_FIXTURE_BODY"
      ;;
    *"--json files --jq"*)
      printf '%s\n' "$GH_FIXTURE_FILES"
      ;;
    *"--json commits --jq"*)
      printf '%s\n' "$GH_FIXTURE_COMMITS"
      ;;
    *)
      echo "unexpected fake gh call: $*" >&2
      return 2
      ;;
  esac
}

export -f gh

set_common_fixture() {
  GH_FIXTURE_MODE=""
  GH_FIXTURE_TITLE="feat(harness): 계약 검사 실행 테스트"
  GH_FIXTURE_COMMITS="feat(harness): 계약 검사 실행 테스트"
  GH_FIXTURE_FILES="docs/harness.md"
  GH_FIXTURE_BODY="$(cat <<'BODY'
## 배경 · 문제

계약 게이트의 동작을 실행 기반으로 검증합니다.

## 변경 요약

제목·본문·범위 검사를 수행합니다.

## 범위 판단

하네스 테스트 범위입니다.

## 연결 문서

관련 운영 문서입니다.

## 검증

실행 기반 테스트입니다.

## 리뷰 포인트

오탐과 누락을 확인합니다.
BODY
)"
}

run_case() {
  local name="$1"
  local expected_status="$2"
  local expected_text="$3"
  local output
  local actual_status

  set_common_fixture
  case "$name" in
    valid)
      ;;
    prose_tbd)
      GH_FIXTURE_BODY="$GH_FIXTURE_BODY

- 설명: TBD라는 용어를 설명합니다."
      ;;
   placeholder_tbd)
     GH_FIXTURE_BODY="$GH_FIXTURE_BODY

- 검증 결과: TBD (추가 예정)"
     ;;
    mixed_operations)
      GH_FIXTURE_FILES=$'backend/src/main/java/example/ExampleController.java\n.github/workflows/example.yml'
      ;;
    mixed_backend_frontend)
      GH_FIXTURE_FILES=$'backend/src/main/java/example/ExampleController.java\nfrontend/src/components/Example.tsx\nspecs/api-spec.md\nspecs/ui-spec.md'
      ;;
    api_contract_missing)
      GH_FIXTURE_FILES="backend/src/main/java/example/ExampleController.java"
      ;;
    ui_contract_missing)
      GH_FIXTURE_FILES="frontend/src/components/Example.tsx"
      ;;
    contracts_with_exception)
      GH_FIXTURE_FILES=$'backend/src/main/java/example/ExampleController.java\nfrontend/src/components/Example.tsx\nspecs/api-spec.md\nspecs/ui-spec.md'
      GH_FIXTURE_BODY="$GH_FIXTURE_BODY

- 예외 적용 여부: 있음
- 같은 PR에 포함한 이유: 같은 기능의 API와 UI 계약을 함께 검증합니다."
      ;;
    ui_test_scenario_contract)
      GH_FIXTURE_FILES=$'frontend/src/components/Example.tsx\nspecs/test-scenarios.md'
      ;;
    metadata_error)
      GH_FIXTURE_MODE="metadata_error"
      ;;
    *)
      fail "알 수 없는 fixture: $name"
      ;;
  esac

  export GH_FIXTURE_MODE GH_FIXTURE_TITLE GH_FIXTURE_COMMITS GH_FIXTURE_FILES GH_FIXTURE_BODY
  set +e
  output="$(bash "$CONTRACT_SCRIPT" 999 2>&1)"
  actual_status=$?
  set -e

  if [ "$actual_status" -ne "$expected_status" ]; then
    printf '%s\n' "$output" >&2
    fail "$name 종료 코드가 다릅니다: expected=$expected_status actual=$actual_status"
  fi

  if ! grep -Fq -- "$expected_text" <<< "$output"; then
    printf '%s\n' "$output" >&2
    fail "$name 출력에 기대한 문구가 없습니다: $expected_text"
  fi
}

run_case valid 0 "PR contract passed"
run_case prose_tbd 0 "PR contract passed"
run_case placeholder_tbd 1 "미완성 placeholder 값"
run_case mixed_operations 1 "기능 코드와 CI/운영/자동화 변경은 별도 PR"
run_case mixed_backend_frontend 1 "backend/** 와 frontend/** 변경은 기본적으로 별도 PR"
run_case api_contract_missing 1 "API 구현 계약 변경에는 api-spec.md"
run_case ui_contract_missing 1 "UI 구현 계약 변경에는 ui-spec.md 또는 test-scenarios.md"
run_case contracts_with_exception 0 "PR contract passed"
run_case ui_test_scenario_contract 0 "PR contract passed"
run_case metadata_error 1 "PR #999 메타데이터 조회 실패"

echo "PR contract execution tests passed"
