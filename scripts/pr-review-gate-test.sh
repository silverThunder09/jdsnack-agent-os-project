#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE_SCRIPT="$ROOT_DIR/scripts/pr-review-gate.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

gh() {
  case "$*" in
    *"--json title,body --template"*)
      printf '%s\n' "$GH_FIXTURE_BODY"
      ;;
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
    *"pr checks"*)
      printf '%s\n' 'PR CI Gate\tpass'
      ;;
    *)
      echo "unexpected fake gh call: $*" >&2
      return 2
      ;;
  esac
}

export -f gh

set_common_fixture() {
  GH_FIXTURE_TITLE="chore(harness): 리뷰 게이트 실행 테스트"
  GH_FIXTURE_COMMITS="chore(harness): 리뷰 게이트 실행 테스트"
  GH_FIXTURE_FILES="docs/harness.md"
  GH_FIXTURE_BODY="$(cat <<'BODY'
## 배경 · 문제

리뷰 게이트의 계약 결과 전달을 실행 기반으로 검증합니다.

## 변경 요약

계약 성공과 실패의 종료 코드를 확인합니다.

## 구현한 기능

리뷰 게이트 계약 전달 기능입니다.

## 수행한 테스트

계약 결과를 검증합니다.

## 범위 판단

하네스 테스트 범위입니다.

## 보안 영향

민감정보를 다루지 않습니다.

## 연결 문서

관련 운영 문서입니다.

## 검증

실행 기반 테스트입니다.

## 영향 범위

하네스 리뷰 게이트입니다.

## 리뷰 포인트

계약 실패가 게이트 실패로 전달되는지 확인합니다.

## 자체 리뷰 결과

계약 테스트로 검증합니다.

## 실패 시 Issue

없음.
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
    invalid_contract)
      GH_FIXTURE_TITLE="fix(harness): recover Windows automation runtime"
      GH_FIXTURE_COMMITS="fix(harness): recover Windows automation runtime"
      ;;
    *)
      fail "알 수 없는 fixture: $name"
      ;;
  esac

  export GH_FIXTURE_TITLE GH_FIXTURE_COMMITS GH_FIXTURE_FILES GH_FIXTURE_BODY
  set +e
  output="$(bash "$GATE_SCRIPT" 999 2>&1)"
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

run_case valid 0 "- PASS: 제목·커밋·본문·범위 계약을 통과했습니다."
run_case invalid_contract 1 "- FAIL: scripts/pr-contract-test.sh가 PR 계약 위반을 발견했습니다."

echo "PR review gate execution tests passed"
