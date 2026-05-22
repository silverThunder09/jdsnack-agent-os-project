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

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI(gh)가 필요합니다." >&2
  exit 1
fi

if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "ERROR: PR_NUMBER는 숫자여야 합니다: $PR_NUMBER" >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

files_path="$tmp_dir/files.txt"
body_path="$tmp_dir/body.md"
checks_path="$tmp_dir/checks.txt"

gh pr view "$PR_NUMBER" --json title,body --template '{{.body}}' > "$body_path"
pr_title="$(gh pr view "$PR_NUMBER" --json title --template '{{.title}}')"
gh pr view "$PR_NUMBER" --json files --jq '.files[].path' > "$files_path"

if ! gh pr checks "$PR_NUMBER" > "$checks_path" 2>&1; then
  checks_failed=1
else
  checks_failed=0
fi

agents=()
warnings=()

add_agent() {
  local agent="$1"
  local existing
  for existing in "${agents[@]}"; do
    if [ "$existing" = "$agent" ]; then
      return
    fi
  done
  agents+=("$agent")
}

has_backend=0
has_frontend=0
has_specs=0
has_github=0
has_ops=0
has_security=0
has_docker=0
has_scripts=0

while IFS= read -r file; do
  case "$file" in
    backend/*)
      has_backend=1
      add_agent "Backend Engineer"
      add_agent "QA Reviewer"
      ;;
    frontend/*)
      has_frontend=1
      add_agent "Frontend Engineer"
      add_agent "QA Reviewer"
      ;;
    .agent-os/specs/*|docs/api/*|docs/architecture/*)
      has_specs=1
      add_agent "Spec Steward"
      add_agent "QA Reviewer"
      ;;
    .github/*|.github/workflows/*)
      has_github=1
      add_agent "DevOps Steward"
      add_agent "Release Captain"
      ;;
    Dockerfile|docker-compose*.yml|docker/*)
      has_docker=1
      add_agent "DevOps Steward"
      add_agent "Release Captain"
      ;;
    scripts/*)
      has_scripts=1
      add_agent "DevOps Steward"
      add_agent "Release Captain"
      ;;
    .agent-os/operations/*|.agent-os/standards/git-*|.agent-os/standards/definition-of-done.md)
      has_ops=1
      add_agent "Release Captain"
      ;;
  esac

  case "$file" in
    *security*|*.env*|*secret*|*gemini*|*Gemini*|*log*|*Log*)
      has_security=1
      add_agent "Security Reviewer"
      add_agent "QA Reviewer"
      ;;
  esac
done < "$files_path"

if [ "${#agents[@]}" -eq 0 ]; then
  add_agent "QA Reviewer"
fi

if [ "$has_backend" -eq 1 ] && [ "$has_frontend" -eq 1 ]; then
  warnings+=("backend/** 와 frontend/** 변경이 같은 PR에 있습니다. PR 범위 예외 사유가 필요합니다.")
fi

if { [ "$has_backend" -eq 1 ] || [ "$has_frontend" -eq 1 ]; } && { [ "$has_github" -eq 1 ] || [ "$has_scripts" -eq 1 ]; }; then
  warnings+=("기능 코드와 자동화 변경이 같은 PR에 있습니다. 운영 변경 분리 여부를 확인하세요.")
fi

if { [ "$has_backend" -eq 1 ] || [ "$has_frontend" -eq 1 ]; } && [ "$has_ops" -eq 1 ]; then
  warnings+=("기능 코드와 운영/표준 문서 변경이 같은 PR에 있습니다. 같은 PR 허용 조건을 확인하세요.")
fi

if [ "$has_docker" -eq 1 ] && { [ "$has_backend" -eq 1 ] || [ "$has_frontend" -eq 1 ]; }; then
  warnings+=("Docker/컨테이너 변경과 기능 코드가 함께 있습니다. 배포 영향과 PR 범위를 확인하세요.")
fi

required_sections=(
  "## 변경 요약"
  "## 범위 판단"
  "## 연결 문서"
  "## 담당 에이전트 검사"
  "## Handoff 요약"
  "## 검증"
  "## 리뷰 포인트"
)

missing_sections=()
for section in "${required_sections[@]}"; do
  if ! grep -Fq "$section" "$body_path"; then
    missing_sections+=("$section")
  fi
done

echo "# PR Review Gate"
echo
echo "## PR"
echo
echo "- 번호: #$PR_NUMBER"
echo "- 제목: $pr_title"
echo
echo "## 변경 파일"
echo
sed 's/^/- /' "$files_path"
echo
echo "## 필수 리뷰 에이전트"
echo
printf '%s\n' "${agents[@]}" | sed 's/^/- /'
echo
echo "## PR 본문 섹션 확인"
echo
if [ "${#missing_sections[@]}" -eq 0 ]; then
  echo "- PASS: 필수 섹션이 모두 있습니다."
else
  printf '%s\n' "${missing_sections[@]}" | sed 's/^/- MISSING: /'
fi
echo
echo "## 범위 경고"
echo
if [ "${#warnings[@]}" -eq 0 ]; then
  echo "- 없음"
else
  printf '%s\n' "${warnings[@]}" | sed 's/^/- WARNING: /'
fi
echo
echo "## CI 상태"
echo
if [ "$checks_failed" -eq 0 ]; then
  sed 's/^/- /' "$checks_path"
else
  echo "- gh pr checks 조회 실패 또는 실패 체크 존재"
  sed 's/^/  /' "$checks_path"
fi
echo
echo "## 리뷰 리포트 템플릿"
echo
cat .agent-os/operations/agent-review-report-template.md
