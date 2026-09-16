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
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1 && python3 -c 'import re' >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1 && python -c 'import re' >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "ERROR: PR 제목·커밋 summary의 한국어 검증에는 실행 가능한 Python이 필요합니다." >&2
  exit 1
fi

pr_title="$(gh pr view "$PR_NUMBER" --json title --template '{{.title}}')"
pr_body="$(gh pr view "$PR_NUMBER" --json body --template '{{.body}}')"
files="$(gh pr view "$PR_NUMBER" --json files --jq '.files[].path')"
commits="$(gh pr view "$PR_NUMBER" --json commits --jq '.commits[].messageHeadline')"

errors=()
warnings=()

add_error() {
  errors+=("$1")
}

has_korean() {
  "$PYTHON_BIN" - "$1" <<'PY'
import re
import sys

raise SystemExit(0 if re.search(r"[가-힣]", sys.argv[1]) else 1)
PY
}

validate_conventional_title() {
  local label="$1"
  local line="$2"
  local pattern='^(feat|fix|docs|test|refactor|style|chore|ci|perf)(\([a-z0-9][a-z0-9._/-]*\))?: .+'

  if [[ ! "$line" =~ $pattern ]]; then
    add_error "$label이 Conventional Commits 형식이 아닙니다: $line"
    return
  fi

  local summary="${line#*: }"
  if ! has_korean "$summary"; then
    add_error "$label summary는 이 저장소의 기본 언어인 한국어로 작성해야 합니다: $line"
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
  "## 범위 판단"
  "## 연결 문서"
  "## 검증"
  "## 리뷰 포인트"
)

for section in "${required_sections[@]}"; do
  if ! grep -Fq -- "$section" <<< "$pr_body"; then
    add_error "PR 본문 필수 섹션이 없습니다: $section"
  fi
done

if grep -Eiq -- '\bTBD\b' <<< "$pr_body"; then
  add_error "PR 본문에 TBD가 남아 있습니다."
fi

has_feature=0
has_operations=0
while IFS= read -r file; do
  case "$file" in
    backend/*|frontend/*|.agent-os/specs/*|docs/architecture/*)
      has_feature=1
      ;;
    .github/*|.agent-os/operations/*|.agent-os/standards/*|.claude/*|.agents/*|scripts/*|.githooks/*|AGENTS.md|CLAUDE.md|backends.json|Dockerfile|docker-compose*.yml|compose*.yml)
      has_operations=1
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

echo "PR contract: #$PR_NUMBER"
echo "- title: $pr_title"
echo "- feature scope: $has_feature"
echo "- operations scope: $has_operations"

if [ "${#warnings[@]}" -gt 0 ]; then
  printf '%s\n' "${warnings[@]}" | sed 's/^/- WARNING: /'
fi

if [ "${#errors[@]}" -gt 0 ]; then
  printf '%s\n' "${errors[@]}" | sed 's/^/- ERROR: /' >&2
  exit 1
fi

echo "PR contract passed"
