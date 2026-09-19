#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <PR_NUMBER>" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

PR_NUMBER="$1"

if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "ERROR: PR_NUMBER는 숫자여야 합니다: $PR_NUMBER" >&2
  exit 2
fi

command -v gh >/dev/null 2>&1 \
  || { echo "ERROR: GitHub CLI(gh)가 필요합니다." >&2; exit 1; }

gh_pr_view() {
  local label="$1"
  shift
  local output

  if ! output="$(gh pr view "$PR_NUMBER" "$@" 2>&1)"; then
    echo "ERROR: PR #$PR_NUMBER 메타데이터 조회 실패 ($label): $output" >&2
    exit 1
  fi

  printf '%s\n' "$output"
}

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1 && python3 -c 'import re' >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1 && python -c 'import re' >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "ERROR: PR 제목·커밋 summary의 언어 검증에는 실행 가능한 Python이 필요합니다." >&2
  exit 1
fi

pr_title="$(gh_pr_view "title" --json title --template '{{.title}}')"
pr_body="$(gh_pr_view "body" --json body --template '{{.body}}')"
files="$(gh_pr_view "files" --json files --jq '.files[].path')"
commits="$(gh_pr_view "commits" --json commits --jq '.commits[].messageHeadline')"

errors=()
warnings=()

add_error() {
  errors+=("$1")
}

has_korean_or_technical_summary() {
  "$PYTHON_BIN" - "$1" <<'PY'
import re
import sys

summary = sys.argv[1].strip()
if re.search(r"[가-힣]", summary):
    raise SystemExit(0)

tokens = summary.split()
technical_token = re.compile(r"(?=.*(?:[/_.:#$<>-]|\d|[A-Z]{2,}|[a-z][A-Z]))[A-Za-z0-9_./:#$<>-]+$")
raise SystemExit(0 if tokens and all(technical_token.fullmatch(token) for token in tokens) else 1)
PY
}

validate_conventional_title() {
  local label="$1"
  local line="$2"
  local pattern='^(feat|fix|docs|test|refactor|style|chore|ci|perf|build|revert)(\([a-z0-9][a-z0-9._/-]*\)): .+'

  if [[ ! "$line" =~ $pattern ]]; then
    add_error "$label이 Conventional Commits 형식이 아닙니다: $line"
    return
  fi

  local summary="${line#*: }"
  if ! has_korean_or_technical_summary "$summary"; then
    add_error "$label summary는 한국어 문장 또는 고정된 기술 식별자로 작성해야 합니다: $line"
  fi
}

validate_conventional_title "PR 제목" "$pr_title"

while IFS= read -r commit; do
  [ -z "$commit" ] && continue
  validate_conventional_title "커밋 제목" "$commit"
done <<< "$commits"

required_sections=(
  "## 배경 · 문제"
  "## 변경 요약"
  "## 구현한 기능"
  "## 수행한 테스트"
  "## 범위 판단"
  "## 보안 영향"
  "## 연결 문서"
  "## 검증"
  "## 영향 범위"
  "## 리뷰 포인트"
  "## 자체 리뷰 결과"
  "## 실패 시 Issue"
)

for section in "${required_sections[@]}"; do
  if ! grep -Fq -- "$section" <<< "$pr_body"; then
    add_error "PR 본문 필수 섹션이 없습니다: $section"
  fi
done

if grep -Eiq -- '^[[:space:]]*(TBD([[:space:][:punct:]]|$)|[-*][[:space:]]+TBD([[:space:][:punct:]]|$)|[-*][[:space:]]*[^:]+:[[:space:]]*TBD([[:space:][:punct:]]|$))' <<< "$pr_body"; then
  add_error "PR 본문에 미완성 placeholder 값(TBD)이 남아 있습니다."
fi

has_feature=0
has_operations=0
has_backend=0
has_frontend=0
has_api_implementation=0
has_ui_implementation=0
has_api_contract_doc=0
has_ui_contract_doc=0
while IFS= read -r file; do
  case "$file" in
    backend/*)
      has_feature=1
      has_backend=1
      ;;
    frontend/*)
      has_feature=1
      has_frontend=1
      ;;
    .agent-os/specs/*|docs/architecture/*)
      has_feature=1
      ;;
    .github/*|.agent-os/operations/*|.agent-os/standards/*|.claude/*|.agents/*|scripts/*|.githooks/*|AGENTS.md|CLAUDE.md|backends.json|Dockerfile|docker-compose*.yml|docker-compose*.yaml|compose*.yml|compose*.yaml)
      has_operations=1
      ;;
  esac

  case "$file" in
    backend/*/controller/*|backend/*/api/*|backend/*Controller.java|backend/*Controller.kt|backend/*Controller.ts|backend/*Controller.js)
      has_api_implementation=1
      ;;
    frontend/src/components/*|frontend/src/hooks/*|frontend/src/pages/*|frontend/src/routes/*|frontend/src/services/*)
      has_ui_implementation=1
      ;;
    *api-spec.md)
      has_api_contract_doc=1
      ;;
    *ui-spec.md|*test-scenarios.md)
      has_ui_contract_doc=1
      ;;
  esac
done <<< "$files"

scope_exception=0
if grep -Eq -- '예외 적용 여부:[[:space:]]*있음' <<< "$pr_body" \
    && grep -Eq -- '같은 PR에 포함한 이유:[[:space:]]*[^[:space:]]' <<< "$pr_body"; then
  scope_exception=1
fi

if [ "$has_feature" -eq 1 ] && [ "$has_operations" -eq 1 ]; then
  if [ "$scope_exception" -eq 1 ]; then
    warnings+=("기능 코드와 운영/CI 변경이 함께 있지만 PR 본문에 명시된 예외 사유가 있습니다.")
  else
    add_error "기능 코드와 CI/운영/자동화 변경은 별도 PR로 분리해야 합니다. PR 본문에 허용된 예외 사유도 없습니다."
  fi
fi

if [ "$has_backend" -eq 1 ] && [ "$has_frontend" -eq 1 ]; then
  if [ "$scope_exception" -eq 1 ]; then
    warnings+=("backend/** 와 frontend/** 변경이 함께 있지만 PR 본문에 명시된 같은 기능의 예외 사유가 있습니다.")
  else
    add_error "backend/** 와 frontend/** 변경은 기본적으로 별도 PR로 분리해야 합니다. PR 본문에 허용된 예외 사유도 없습니다."
  fi
fi

if [ "$has_api_implementation" -eq 1 ] && [ "$has_api_contract_doc" -eq 0 ]; then
  add_error "API 구현 계약 변경에는 api-spec.md 갱신이 필요합니다."
fi

if [ "$has_ui_implementation" -eq 1 ] && [ "$has_ui_contract_doc" -eq 0 ]; then
  add_error "UI 구현 계약 변경에는 ui-spec.md 또는 test-scenarios.md 갱신이 필요합니다."
fi

echo "PR contract: #$PR_NUMBER"
echo "- title: $pr_title"
echo "- feature scope: $has_feature"
echo "- operations scope: $has_operations"
echo "- backend scope: $has_backend"
echo "- frontend scope: $has_frontend"
echo "- API contract doc: $has_api_contract_doc"
echo "- UI contract doc: $has_ui_contract_doc"

if [ "${#warnings[@]}" -gt 0 ]; then
  printf '%s\n' "${warnings[@]}" | sed 's/^/- WARNING: /'
fi

if [ "${#errors[@]}" -gt 0 ]; then
  printf '%s\n' "${errors[@]}" | sed 's/^/- ERROR: /' >&2
  exit 1
fi

echo "PR contract passed"
