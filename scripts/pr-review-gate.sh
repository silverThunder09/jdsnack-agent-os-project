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

review_scopes=()
warnings=()

add_review_scope() {
  local scope="$1"
  local existing
  if [ "${#review_scopes[@]}" -gt 0 ]; then
    for existing in "${review_scopes[@]}"; do
      if [ "$existing" = "$scope" ]; then
        return
      fi
    done
  fi
  review_scopes+=("$scope")
}

has_backend=0
has_frontend=0
has_specs=0
has_github=0
has_ops=0
has_security=0
has_docker=0
has_scripts=0
risk_level="Light"

while IFS= read -r file; do
  case "$file" in
    backend/*)
      has_backend=1
      add_review_scope "Backend/API contract"
      add_review_scope "Test coverage"
      ;;
    frontend/*)
      has_frontend=1
      add_review_scope "Frontend/UI contract"
      add_review_scope "Test coverage"
      ;;
    .agent-os/specs/*|docs/architecture/*)
      has_specs=1
      add_review_scope "Spec/traceability"
      add_review_scope "Test coverage"
      ;;
    .github/*|.github/workflows/*)
      has_github=1
      add_review_scope "CI/CD"
      add_review_scope "Release impact"
      ;;
    Dockerfile|docker-compose*.yml|docker/*)
      has_docker=1
      add_review_scope "Container/runtime"
      add_review_scope "Release impact"
      ;;
    scripts/*)
      has_scripts=1
      add_review_scope "Automation scripts"
      add_review_scope "Release impact"
      ;;
    .agent-os/operations/*|.agent-os/standards/git-*|.agent-os/standards/definition-of-done.md)
      has_ops=1
      add_review_scope "Operations policy"
      ;;
  esac

  case "$file" in
    *security*|*.env*|*secret*|*gemini*|*Gemini*|*log*|*Log*)
      has_security=1
      add_review_scope "Security/secrets"
      add_review_scope "Test coverage"
      ;;
  esac
done < "$files_path"

if [ "${#review_scopes[@]}" -eq 0 ]; then
  add_review_scope "General review"
fi

if [ "$has_github" -eq 1 ] || [ "$has_docker" -eq 1 ] || [ "$has_security" -eq 1 ] || [ "$has_ops" -eq 1 ]; then
  risk_level="High-risk"
elif [ "$has_backend" -eq 1 ] || [ "$has_frontend" -eq 1 ] || [ "$has_specs" -eq 1 ]; then
  risk_level="Standard"
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
  "## 배경 · 문제"
  "## 변경 요약"
  "## 범위 판단"
  "## 연결 문서"
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
echo "## 위험도 추정"
echo
echo "- ${risk_level}"
echo
echo "## 필수 확인 범위"
echo
printf '%s\n' "${review_scopes[@]}" | sed 's/^/- /'
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
cat <<'REPORT'
# Review Result

## Decision
- PASS / COMMENT / REQUEST_CHANGES

## Scope Check
- PR 목적:
- 변경 파일 범위:
- 범위 위반 여부:

## Contract Check
- REQ/AC/TC:
- API/UI 문서:

## Test Check
- 로컬 테스트:
- CI 결과:
- 누락 테스트:

## Findings
- P0:
- P1:
- P2:
- P3:

## Required Fixes
- 수정 필요 항목:
REPORT
