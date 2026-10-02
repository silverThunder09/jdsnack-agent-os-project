#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/codex-branch-review.yml"
CLAUDE_SKILL="$ROOT_DIR/.claude/skills/review-loop/SKILL.md"
AGENTS_SKILL="$ROOT_DIR/.agents/skills/review-loop/SKILL.md"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local expected="$1"
    grep -Fq -- "$expected" "$WORKFLOW" \
        || fail "codex branch review workflow에 다음 계약이 없습니다: $expected"
}

assert_not_contains() {
    local unexpected="$1"
    if grep -Fq -- "$unexpected" "$WORKFLOW"; then
        fail "신뢰되지 않은 PR 실행을 허용하는 계약이 있습니다: $unexpected"
    fi
}

assert_contains "  pull_request_target:"
assert_contains "    types: [auto_merge_enabled]"
assert_contains "  workflow_run:"
assert_contains "    workflows: [PR CI Router]"
assert_contains "    types: [completed]"
assert_contains "github.event.workflow_run.name == 'PR CI Router'"
assert_contains "github.event.workflow_run.conclusion == 'success'"
assert_contains "github.event.workflow_run.head_repository.full_name == github.repository"
assert_contains "startsWith(github.event.workflow_run.head_branch, 'codex/')"
assert_contains "  workflow_dispatch:"
assert_contains "      pr_number:"
assert_contains "        required: true"
assert_contains "        type: string"
assert_contains "permissions:"
assert_contains "concurrency:"
assert_contains "  group: jdsnack-review-pr-"
assert_contains "      contents: read"
assert_contains "      checks: read"
assert_contains "      pull-requests: write"
assert_contains "  queue_squash:"
assert_contains "  run_review:"
assert_contains "    needs: [run_review]"
assert_contains "    if: needs.run_review.result == 'success'"
assert_contains "      contents: write"
assert_contains "      pull-requests: write"
assert_contains '      pr_number: ${{ steps.resolve.outputs.pr_number }}'
assert_contains '      base_sha: ${{ steps.resolve.outputs.base_sha }}'
assert_contains '      head_sha: ${{ steps.resolve.outputs.head_sha }}'
assert_contains "uses: actions/upload-artifact@v4"
assert_contains "uses: actions/download-artifact@v4"
assert_contains "scripts/complete-review-approval.ps1"
assert_contains "github.event_name == 'pull_request_target'"
assert_contains "github.event.pull_request.head.repo.full_name == github.repository"
assert_contains "github.event.pull_request.base.repo.full_name == github.repository"
assert_contains "github.event.pull_request.author_association"
assert_contains "uses: actions/checkout@v4"
assert_contains "Check out trusted review base"
assert_contains "ref: \${{ github.event_name == 'pull_request_target' && github.event.pull_request.base.sha || github.event.repository.default_branch }}"
assert_contains "fetch-depth: 0"
assert_contains "Resolve and fetch review target"
assert_contains "git fetch --no-tags origin"
assert_contains "refs/remotes/origin/review-base"
assert_contains "refs/remotes/origin/review-head"
assert_contains "REVIEW_BASE_SHA"
assert_contains "REVIEW_HEAD_SHA"
assert_contains "pullRequest.state -ne 'open'"
assert_contains "pullRequest.base.repo.full_name -ne \$env:REPOSITORY"
assert_contains "pullRequest.head.repo.full_name -ne \$env:REPOSITORY"
assert_contains "Review target SHA is invalid"
assert_not_contains "refs/pull/{0}/head"
assert_contains "shell: powershell"
assert_contains 'Join-Path $env:GITHUB_WORKSPACE'
assert_contains 'Run configured reviewer with Codex fallback'
assert_contains 'Verify GitHub review identity'
assert_contains "gh api user --jq '.login'"
assert_contains 'github.repository_owner'
assert_contains '$actualLogin -ne $expectedLogin'
assert_contains 'throw "Review runner identity mismatch: expected $expectedLogin, got $actualLogin"'
assert_contains 'Run configured reviewer with Codex fallback'
assert_contains 'CLAUDE_BIN: claude'
assert_contains 'CODEX_BIN: codex'
assert_contains 'PR_NUMBER_INPUT: ${{ github.event.pull_request.number || inputs.pr_number ||'
assert_contains 'EVENT_HEAD_SHA: ${{ github.event.pull_request.head.sha || github.event.workflow_run.head_sha ||'
assert_contains 'EVENT_HEAD_REF: ${{ github.event.workflow_run.head_branch ||'
assert_contains 'commits/$headSha/pulls'
assert_contains '$_.head.sha -eq $headSha'
assert_contains '$_.author_association -in @('
assert_contains "'OWNER', 'MEMBER', 'COLLABORATOR'"
assert_contains 'scripts/review-backend-fallback.ps1'
assert_contains '-PullRequestNumber'
assert_contains '-BaseSha'
assert_contains '-HeadSha'
assert_contains '$pullRequestNumber = $env:PR_NUMBER'
assert_contains "-notmatch '^\\d+\$'"
assert_not_contains "\$pullRequestNumber = '\${{ github.event.pull_request.number || inputs.pr_number }}'"
assert_contains 'GH_TOKEN: ${{ github.token }}'
assert_not_contains 'claude --model sonnet --effort medium -p'
FALLBACK_SCRIPT="$ROOT_DIR/scripts/review-backend-fallback.ps1"
[[ -f "$FALLBACK_SCRIPT" ]] || fail "리뷰 backend fallback 스크립트가 없습니다: $FALLBACK_SCRIPT"
[[ -f "$ROOT_DIR/scripts/review-policy.json" ]] || fail "리뷰 정책 파일이 없습니다: scripts/review-policy.json"
[[ -f "$ROOT_DIR/scripts/review-risk.ps1" ]] || fail "결정론적 위험도 계산기가 없습니다: scripts/review-risk.ps1"
[[ -f "$ROOT_DIR/.githooks/pre-push" ]] || fail "pre-push hook이 없습니다: .githooks/pre-push"
[[ -f "$ROOT_DIR/scripts/install-git-hooks.sh" ]] || fail "Git hook 설치 스크립트가 없습니다."
[[ -f "$ROOT_DIR/scripts/pre-push-ai-review.sh" ]] || fail "pre-push AI 리뷰 스크립트가 없습니다."
[[ -f "$ROOT_DIR/scripts/pre-push-ai-review-test.sh" ]] || fail "pre-push AI 리뷰 계약 테스트가 없습니다."
[[ -f "$ROOT_DIR/scripts/pre-push-git-invocation-test.sh" ]] || fail "실제 Git pre-push 진입 계약 테스트가 없습니다."
cmp -s "$ROOT_DIR/.agents/skills/review-loop/SKILL.md" "$ROOT_DIR/.claude/skills/review-loop/SKILL.md" \
  || fail 'Codex와 Claude review-loop skill 내용이 동기화되지 않았습니다.'
grep -Fq -- '현재 primary reviewer는 Codex이므로 Claude 호출 없이 바로 읽기 전용 리뷰를 실행합니다.' "$ROOT_DIR/.agents/skills/review-loop/SKILL.md" \
  || fail 'review-loop skill이 Codex 직접 리뷰 경로를 설명하지 않습니다.'
grep -Fq -- 'PASS와 score 4 이상이면 review report를 artifact로 넘깁니다.' "$ROOT_DIR/.agents/skills/review-loop/SKILL.md" \
  || fail 'review-loop skill이 PASS 점수와 report artifact 조건을 설명하지 않습니다.'
[[ -f "$ROOT_DIR/scripts/pre-push-empty-diff-test.sh" ]] || fail "빈 branch diff pre-push 계약 테스트가 없습니다."
grep -Fq -- 'bash "$ROOT_DIR/scripts/pre-push-git-invocation-test.sh"' "$ROOT_DIR/scripts/workflow-ci-test.sh" \
  || fail 'workflow CI가 실제 Git pre-push 진입 계약 테스트를 실행하지 않습니다.'
grep -Fq -- 'bash "$ROOT_DIR/scripts/pre-push-empty-diff-test.sh"' "$ROOT_DIR/scripts/workflow-ci-test.sh" \
  || fail 'workflow CI가 빈 branch diff pre-push 계약을 실행하지 않습니다.'
grep -Fq -- 'branch diff가 비어 있어 리뷰할 변경이 없습니다.' "$ROOT_DIR/scripts/pre-push-ai-review.sh" \
  || fail 'pre-push가 빈 branch diff를 reviewer 호출 전에 차단하지 않습니다.'
grep -Fq -- 'bash "$ROOT_DIR/scripts/pre-push-ai-review-test.sh"' "$ROOT_DIR/scripts/workflow-ci-test.sh" \
  || fail 'workflow CI가 실행 권한과 무관하게 pre-push 계약 테스트를 Bash로 실행해야 합니다.'
grep -Fq -- 'Git passes the destination remote name and its location as arguments 1 and 2.' "$ROOT_DIR/.githooks/pre-push" \
  || fail 'pre-push hook의 remote name과 destination URL 인자 계약이 명시되지 않았습니다.'
[[ -f "$ROOT_DIR/.agent-os/operations/review-routing.md" ]] || fail "리뷰 라우팅 문서가 없습니다."
[[ -f "$ROOT_DIR/.agent-os/operations/branch-protection-provisioning.md" ]] || fail "branch protection provisioning 문서가 없습니다."
grep -Fq -- 'scripts/review-policy.json' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 전문 라우팅 정책을 읽지 않습니다.'
grep -Fq -- 'push_remote="${1-}"' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 hook destination remote를 읽지 않습니다.'
grep -Fq -- 'push_remote" != "origin"' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 origin 이외 destination remote를 차단하지 않습니다.'
grep -Fq -- 'normalize_github_repository_url' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 GitHub repository identity를 정규화하지 않습니다.'
grep -Fq -- 'remote get-url --all --push origin' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 origin push URL을 검증하지 않습니다.'
grep -Fq -- 'remote get-url --all origin' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 origin fetch URL을 검증하지 않습니다.'
grep -Fq -- 'push destination과 origin fetch/push URL은 같은 GitHub repository여야 합니다.' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 destination과 origin repository identity 결합을 강제하지 않습니다.'
grep -Fq -- 'refs/heads/*' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 branch ref 이외의 push를 차단하지 않습니다.'
grep -Fq -- 'symbolic-ref --quiet HEAD' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 현재 checkout branch ref를 확인하지 않습니다.'
grep -Fq -- 'push local ref가 현재 checkout 브랜치와 달라' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 source ref와 현재 checkout branch를 결합하지 않습니다.'
grep -Fq -- 'push destination ref가 현재 checkout 브랜치와 달라' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 destination ref와 리뷰 대상 branch를 결합하지 않습니다.'
grep -Fq -- 'push_remote_shas+=("$remote_sha")' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 remote의 기존 tip SHA를 보존하지 않습니다.'
grep -Fq -- 'cat-file -e "$remote_head_sha^{commit}"' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 기존 remote tip을 commit으로 검증하지 않습니다.'
grep -Fq -- 'merge-base --is-ancestor "$remote_head_sha" "$reviewed_ref"' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 non-fast-forward push를 차단하지 않습니다.'
grep -Fq -- 'PASS[[:space:]]+' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push rubric이 PASS 이외 상태를 거부하지 않습니다.'
for scalar_field in decision score risk; do
  grep -Fq -- "has_exactly_one_key_value_field $scalar_field" "$ROOT_DIR/scripts/pre-push-ai-review.sh" \
    || fail "pre-push 리뷰가 malformed duplicate $scalar_field 헤더를 거부하지 않습니다."
done
grep -Fq -- 'git stash push로 보관한 뒤 재시도' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push dirty checkout remediation 안내가 없습니다.'
grep -Fq -- 'git stash push' "$ROOT_DIR/.agent-os/standards/git-hooks.md" || fail 'git-hooks 문서에 dirty checkout 전환 절차가 없습니다.'
grep -Fq -- 'git stash push로 보관한 뒤 재시도' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push dirty checkout remediation 안내가 없습니다.'
grep -Fq -- 'git stash push' "$ROOT_DIR/.agent-os/standards/git-hooks.md" || fail 'git-hooks 문서에 dirty checkout 전환 절차가 없습니다.'
grep -Fq -- 'for tool in env git grep tail sed head awk cmp rm chmod mktemp stat jq codex' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 reviewer 실행에 필요한 host 도구를 확인하지 않습니다.'
grep -Fq -- 'git_bash_path="$(command -v bash || true)"' "$ROOT_DIR/scripts/install-git-hooks.sh" \
  || fail 'Git hook 설치가 pre-push에서 사용할 Git Bash 실행 경로를 명시적으로 확인하지 않습니다.'
grep -Fq -- 'git config --local jdsnack.hookBash "$git_bash_path"' "$ROOT_DIR/scripts/install-git-hooks.sh" \
  || fail 'Git hook 설치가 검증한 Bash 실행 경로를 로컬 설정에 고정하지 않습니다.'
grep -Fq -- 'for required_tool in dirname env git grep tail sed head awk cmp rm chmod mktemp stat jq codex cat; do' "$ROOT_DIR/scripts/install-git-hooks.sh" \
  || fail 'Git hook 설치가 pre-push 실행에 필요한 전체 host 도구를 확인하지 않습니다.'
grep -Fq -- 'git_bash_path="$(git config --local --get jdsnack.hookBash || true)"' "$ROOT_DIR/.githooks/pre-push" \
  || fail 'pre-push hook이 설치 시 검증된 Git Bash 경로를 읽지 않습니다.'
grep -Fq -- 'exec "$git_bash_path" "$repo_root/scripts/pre-push-ai-review.sh" "$@"' "$ROOT_DIR/.githooks/pre-push" \
  || fail 'pre-push hook이 PATH 탐색 대신 검증된 Git Bash 실행 파일을 호출하지 않습니다.'
grep -Fq -- 'for candidate in python3 python; do' "$ROOT_DIR/scripts/install-git-hooks.sh" \
  || fail 'Git hook 설치가 pre-commit readiness용 Python을 확인하지 않습니다.'
grep -Fq -- 'PowerShell-only fallback runtime was not selected when pwsh was unavailable.' "$ROOT_DIR/scripts/review-risk-test.ps1" \
  || fail '위험도 계약 테스트가 powershell.exe 대체 실행기를 검증하지 않습니다.'
[[ -f "$ROOT_DIR/scripts/secure-review-temp-acl-contract-test.ps1" ]] \
  || fail '임시 ACL 재분석 지점 계약 테스트가 없습니다.'
[[ -f "$ROOT_DIR/scripts/review-path-safety.ps1" ]] \
  || fail '공유 경로 안전성 검증기가 없습니다.'
grep -Fq -- "(Join-Path \$PSScriptRoot 'review-path-safety.ps1')" "$ROOT_DIR/scripts/secure-review-temp-acl.ps1" \
  || fail '임시 ACL 적용기가 경로 안전성 검증기를 로드하지 않습니다.'
grep -Fq -- 'Assert-NoReparsePointsInPath -Path $fullPath' "$ROOT_DIR/scripts/secure-review-temp-acl.ps1" \
  || fail '임시 ACL 적용기가 DACL 적용 전후 재분석 지점을 재검증하지 않습니다.'
grep -Fq -- '재분석 지점' "$ROOT_DIR/scripts/review-path-safety.ps1" \
  || fail '경로 안전성 검증기가 재분석 지점을 거부하지 않습니다.'
grep -Fq -- "검증해 절대 경로로 로컬 Git 설정(\`jdsnack.hookBash\`)에 저장" "$ROOT_DIR/.agent-os/standards/git-hooks.md" \
  || fail 'git-hooks 문서가 설치 시 검증하는 도구 의존성을 설명하지 않습니다.'
grep -Fq -- 'powershell.exe' "$ROOT_DIR/scripts/install-git-hooks.sh" || fail 'Git hook 설치가 PowerShell 사전조건을 확인하지 않습니다.'
grep -Fq -- 'required_file' "$ROOT_DIR/scripts/install-git-hooks.sh" || fail 'Git hook 설치가 downstream 파일 의존성을 확인하지 않습니다.'
grep -Fq -- 'scripts/check-ai-readiness.py' "$ROOT_DIR/scripts/install-git-hooks.sh" || fail 'Git hook 설치가 readiness 스크립트 의존성을 확인하지 않습니다.'
grep -Fq -- 'scripts/review-policy.json' "$ROOT_DIR/scripts/install-git-hooks.sh" || fail 'Git hook 설치가 review policy 의존성을 확인하지 않습니다.'
grep -Fq -- 'if ! codex exec' "$ROOT_DIR/scripts/install-git-hooks.sh" || fail 'Git hook 설치가 Codex exec 호환성을 확인하지 않습니다.'
install_prereq_line="$(grep -nF -- 'git_bash_path="$(command -v bash || true)"' "$ROOT_DIR/scripts/install-git-hooks.sh" | head -n 1 | cut -d: -f1)"
install_chmod_line="$(grep -nF -- 'chmod +x "$repo_root/$hooks_path/$hook"' "$ROOT_DIR/scripts/install-git-hooks.sh" | head -n 1 | cut -d: -f1)"
[[ -n "$install_prereq_line" && -n "$install_chmod_line" && "$install_prereq_line" -lt "$install_chmod_line" ]] \
    || fail 'Git hook 설치가 사전조건 검증 전에 tracked hook을 변경합니다.'
install_exec_line="$(grep -nF -- 'if ! codex exec' "$ROOT_DIR/scripts/install-git-hooks.sh" | head -n 1 | cut -d: -f1)"
[[ -n "$install_exec_line" && "$install_exec_line" -lt "$install_chmod_line" ]] \
    || fail 'Git hook 설치가 Codex exec 호환성 확인 전에 tracked hook을 변경합니다.'
grep -Fq -- 'Specialized review routing labels and path rules' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰 프롬프트에 전문 라우팅 지침이 없습니다.'
grep -Fq -- '--sandbox read-only' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 read-only sandbox를 강제하지 않습니다.'
if grep -Fq -- 'sandbox_workspace_write.network_access=false' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || grep -Fq -- 'sandbox_workspace_write.network_access=false' "$ROOT_DIR/scripts/install-git-hooks.sh"; then
    fail 'read-only reviewer에 workspace-write 전용 network 설정을 전달하면 안 됩니다.'
fi
grep -Fq -- 'read_only_sandbox_seen' "$ROOT_DIR/scripts/pre-push-ai-review-test.sh" || fail 'pre-push 계약 테스트가 read-only sandbox 인자를 검증하지 않습니다.'
grep -Fq -- '--disable shell_tool' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 shell tool을 비활성화하지 않습니다.'
grep -Fq -- 'risk_score:' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 결정론 위험도 점수를 검증하지 않습니다.'
grep -Fq -- 'has_structured_body' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 구조화된 findings/summary를 검증하지 않습니다.'
grep -Fq -- 'extract_single_field()' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 scalar 구조화 필드를 단일 값으로 검증하지 않습니다.'
grep -Fq -- 'has_single_field_header()' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 구조화 field header 중복을 검증하지 않습니다.'
grep -Fq -- 'has_blocking_finding' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 blocker/major findings를 검증하지 않습니다.'
grep -Fq -- 'has_valid_findings' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 finding 심각도 형식을 검증하지 않습니다.'
grep -Fq -- 'has_auditable_review_summary' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 rubric 근거와 score rationale을 검증하지 않습니다.'
grep -Fq -- 'score rationale:' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰 프롬프트에 score rationale 계약이 없습니다.'
grep -Fq -- 'blocker/major 또는 P0/P1' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 P0/P1 차단 결과를 알리지 않습니다.'
grep -Fq -- 'expected_risk_score' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 host 계산 점수를 보존하지 않습니다.'
grep -Fq -- 'risk_band_for_score' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 위험 점수와 위험도 구간 매핑을 검증하지 않습니다.'
grep -Fq -- 'reported_risk_score' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 보고 점수 불일치를 차단하지 않습니다.'
grep -Fq -- 'reported_review_labels' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 보고 라벨 불일치를 차단하지 않습니다.'
grep -Fq -- '여러 ref가 한 번에 push되어' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 다중 ref push를 차단하지 않습니다.'
grep -Fq -- '현재 checkout의 HEAD와' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 push head와 local HEAD를 고정하지 않습니다.'
grep -Fq -- '삭제 ref만 있는 push는' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 삭제 ref 전용 push를 fail-closed 처리하지 않습니다.'
grep -Fq -- 'tracked checkout 상태가 다릅니다' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 push 대상과 dirty checkout의 불일치를 차단하지 않습니다.'
grep -Fq -- 'Codex 리뷰 전에 staged·working-tree 변경' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 Codex reviewer 전에 dirty checkout을 차단하지 않습니다.'
grep -Fq -- 'scripts/pre-push-ai-review.sh" "$@"' "$ROOT_DIR/.githooks/pre-push" || fail 'pre-push hook이 Git hook 인자를 리뷰 스크립트에 전달하지 않습니다.'
grep -Fq -- 'forbidden_tool in git gh bash pwsh powershell.exe python python3 node' "$ROOT_DIR/scripts/pre-push-ai-review-test.sh" || fail 'pre-push 격리 fixture가 ambient 실행 파일 차단을 검증하지 않습니다.'
grep -Fq -- 'set_fixture_windows_runtime()' "$ROOT_DIR/scripts/pre-push-ai-review-test.sh" \
  || fail 'pre-push Linux workflow fixture가 격리 Codex runtime의 SystemRoot/WINDIR를 제공하지 않습니다.'
grep -Fq -- 'test_windows_root="${SystemRoot:-${WINDIR:-$fixture_root}}"' "$ROOT_DIR/scripts/pre-push-ai-review-test.sh" \
  || fail 'pre-push test fixture가 host runtime root가 없을 때 임시 경로를 선택하지 않습니다.'
grep -Fq -- 'reviewer_bin_dir="$tmp_dir/reviewer-bin"' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push reviewer 전용 실행 디렉터리가 없습니다.'
grep -Fq -- 'review_path="$reviewer_bin_dir"' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push reviewer PATH가 전용 실행 디렉터리로 제한되지 않습니다.'
grep -Fq -- 'reviewer_entry="$codex_bin"' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 Codex 실행 파일의 설치 경로를 보존하지 않습니다.'
grep -Fq -- 'runtime_dependency="${0%/*}/codex-runtime.sh"' "$ROOT_DIR/scripts/pre-push-ai-review-test.sh" || fail 'pre-push fixture가 Codex sibling runtime 의존성을 검증하지 않습니다.'
grep -Fq -- 'reviewer_entry="$codex_bin"' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 Codex 실행 파일의 설치 경로를 보존하지 않습니다.'
grep -Fq -- 'review_env_args=(' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push reviewer가 허용 환경변수를 명시적으로 구성하지 않습니다.'
grep -Fq -- '"CODEX_HOME=$codex_home_arg"' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push reviewer가 전용 CODEX_HOME을 고정하지 않습니다.'
grep -Fq -- 'codex_home_dir="$codex_auth_home_root/review-fallback"' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 사용자 설정과 분리된 reviewer 인증 홈을 사용하지 않습니다.'
if grep -Fq -- 'codex_auth_source="$HOME/.codex/auth.json"' "$ROOT_DIR/scripts/pre-push-ai-review.sh"; then
    fail 'pre-push가 명시적 CODEX_HOME/CODEX_AUTH_FILE 없이 기본 사용자 auth를 암묵적으로 복사합니다.'
fi
grep -Fq -- 'set CODEX_HOME or CODEX_AUTH_FILE once to seed' "$ROOT_DIR/scripts/pre-push-ai-review.sh" \
  || fail 'pre-push가 reviewer sidecar 최초 seed 경로를 명시적으로 요구하지 않습니다.'
grep -Fq -- '명시적 인증 seed 없이 Codex reviewer 인증 홈을 만들거나 실행했습니다.' "$ROOT_DIR/scripts/pre-push-ai-review-test.sh" \
  || fail 'pre-push 계약 테스트가 암묵적 사용자 인증 seed를 차단하지 않습니다.'
grep -Fq -- 'codex_auth_lock_dir="$codex_home_dir/.review-lock"' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 동시 reviewer 인증 갱신을 직렬화하지 않습니다.'
grep -Fq -- "codex_auth_link_count=" "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 reviewer 인증 파일의 hard link를 차단하지 않습니다.'
grep -Fq -- 'current_source_ref_sha=' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push가 리뷰 후 push source ref를 재검증하지 않습니다.'
if grep -Fq -- 'sync_refreshed_codex_auth' "$ROOT_DIR/scripts/pre-push-ai-review.sh"; then
    fail 'pre-push가 갱신 토큰을 사용자 원본 인증 파일에 되쓰는 경로를 유지합니다.'
fi
grep -Fq -- '"TMPDIR=$codex_tmp_dir"' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push reviewer가 임시 디렉터리 기반 환경을 고정하지 않습니다.'
grep -Fq -- 'windows_root=' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push reviewer가 Windows 런타임 루트를 확인하지 않습니다.'
grep -Fq -- 'SystemRoot=$windows_root' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push reviewer가 SystemRoot를 격리 환경에 전달하지 않습니다.'
grep -Fq -- 'WINDIR=$windows_root' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push reviewer가 WINDIR를 격리 환경에 전달하지 않습니다.'
grep -Fq -- 'summary_line_count' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push reviewer가 review_summary 전체 줄 수를 고정하지 않습니다.'
grep -Fq -- 'match_count' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push reviewer가 rubric·결론 중복을 차단하지 않습니다.'
grep -Fq -- 'for tool in env git grep tail sed head awk cmp rm' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push hook이 reviewer 이후 필요한 host 도구 경로를 고정하지 않습니다.'
grep -Fq -- 'require_host_tool cat' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push hook이 status 보고용 cat 경로를 고정하지 않습니다.'
grep -Fq -- '"$git_bin" diff' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push hook이 reviewer 이후 Git을 절대 경로로 호출하지 않습니다.'
grep -Fq -- '"$env_bin" -i "${review_env_args[@]}" "$reviewer_entry" "$@"' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push hook이 제한된 PATH에서 전용 Codex runtime을 실행하지 않습니다.'
grep -Fq -- 'run_reviewer exec' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push hook이 전용 reviewer 실행 경계를 사용하지 않습니다.'
grep -Fq -- '--strict-config' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push hook이 reviewer config를 엄격 모드로 검증하지 않습니다.'
clean_checkout_line="$(grep -nF -- 'Codex 리뷰 전에 staged·working-tree 변경' "$ROOT_DIR/scripts/pre-push-ai-review.sh" | head -n 1 | cut -d: -f1)"
review_runtime_line="$(grep -nF -- 'run_reviewer exec' "$ROOT_DIR/scripts/pre-push-ai-review.sh" | head -n 1 | cut -d: -f1)"
[[ -n "$clean_checkout_line" && -n "$review_runtime_line" && "$clean_checkout_line" -lt "$review_runtime_line" ]] \
    || fail 'pre-push reviewer가 dirty checkout을 사전 차단하기 전에 실행됩니다.'
if grep -Fq -- 'clear_review_environment' "$ROOT_DIR/scripts/pre-push-ai-review.sh"; then
    fail 'pre-push reviewer가 denylist 환경 정리에 의존합니다.'
fi
if grep -Fq -- 'for helper in cat grep cygpath' "$ROOT_DIR/scripts/pre-push-ai-review.sh"; then
    fail 'pre-push reviewer PATH가 host 도구 디렉터리로 확장됩니다.'
fi
if grep -Fq -- 'for name in CODEX_HOME' "$ROOT_DIR/scripts/pre-push-ai-review.sh"; then
    fail 'pre-push reviewer가 사용자 CODEX_HOME 경로를 전달합니다.'
fi
grep -Fq -- 'required_pull_request_reviews' "$ROOT_DIR/.agent-os/operations/branch-protection-provisioning.md" || fail 'branch protection 문서가 required_pull_request_reviews를 설명하지 않습니다.'
grep -Fq -- 'branches/$BASE_BRANCH/protection' "$ROOT_DIR/.agent-os/operations/branch-protection-provisioning.md" || fail 'branch protection 문서가 live protection endpoint를 검증하지 않습니다.'
if grep -Fq -- 'PATH|HOME|USERPROFILE|HOMEDRIVE|HOMEPATH|TEMP' "$ROOT_DIR/scripts/pre-push-ai-review.sh"; then
    fail 'pre-push reviewer가 사용자 home/config 환경을 보존합니다.'
fi
jq -e '
    .version == 1
    and .primaryReviewer == "codex"
    and .dryRun == false
    and .riskScore.weights.security == 30
    and .riskScore.weights.apiDbEnvironment == 20
    and .riskScore.weights.sizeScope == 15
    and .riskScore.weights.testGap == 15
    and .riskScore.weights.migration == 20
    and (.reviewRouting as $routing | (["Security", "Performance", "Test Coverage", "Architecture"] | all(.[]; ($routing[.] | type) == "array")))
' "$ROOT_DIR/scripts/review-policy.json" >/dev/null || fail 'review-policy.json의 위험도/라우팅 정책이 올바르지 않습니다.'
for fallback_contract in \
    "--model', 'sonnet" \
    "--effort', 'medium" \
    "'codex'" \
    "'exec'" \
    "'--ephemeral'" \
    'Get-ConfiguredCodexReviewSettings' \
    'Get-ExactlyOneStructuredMatch' \
    'failed\s+to\s+authenticate' \
    'oauth\s+session\s+expired' \
    "'backends.json'" \
    "'review-fallback'" \
    "'--config', ('model_reasoning_effort=\"{0}\"' -f \$codexReviewEffort)" \
    "'--sandbox', 'read-only'" \
    "'--ignore-user-config'" \
    "'--config', 'web_search=\"disabled\"'" \
    "'--disable', 'shell_tool'" \
    "'--disable', 'apps'" \
    "'--disable', 'remote_plugin'" \
    "'--disable', 'multi_agent'" \
    "'--disable', 'memories'" \
    "'--disable', 'hooks'" \
    "'--disable', 'goals'" \
    "'--disable', 'browser_use'" \
    "'--disable', 'browser_use_external'" \
    "'--disable', 'browser_use_full_cdp_access'" \
    "'--disable', 'computer_use'" \
    "'--disable', 'plugins'" \
    "'--disable', 'skill_search'" \
    "'--disable', 'skill_mcp_dependency_install'" \
    "'--disable', 'code_mode_host'" \
    "'--disable', 'auth_elicitation'" \
    "'--skip-git-repo-check'" \
    '$null | & $ToolPath @ToolArguments' \
    'ConvertFrom-Json' \
    'Set-Location -LiteralPath $WorkingDirectory' \
    'Wait-Job -Job $job -Timeout $TimeoutSeconds' \
    'timed out after' \
    'decision: PASS | COMMENT | REQUEST_CHANGES | NEEDS_HUMAN' \
    'score: 0-5' \
    'risk: Light | Standard | High-risk' \
    'Stop-NeedsHuman' \
    'Get-RequiredCheckFailure' \
    '(-not $currentJobCheck) -and (-not $deferredReviewCheck) -and $_.bucket -ne' \
    '--required --json name,state,bucket' \
    "'--restricted'" \
    "'--tools', ''" \
    "'--permission-mode', 'plan'" \
    "'--permission-prompts', 'none'" \
    'primaryReviewer' \
    'needs-human' \
    'High-risk' \
    'Configured primary reviewer is Codex; skipping Claude and starting the read-only review' \
    "\$codexFallbackReason = if (\$claudeFallbackReason -eq 'configured-primary') { 'none' } else { \$claudeFallbackReason }" \
    'Risk must not change the review score or merge decision.' \
    'claude-invalid-structured-result' \
    'BaseSha' \
    'HeadSha' \
    '$ReviewBaseSha' \
    '$ReviewHeadSha' \
    '$diffRange' \
    'codex-review-evidence-' \
    'jdsnack-codex-review-' \
    '$workspaceFullPath' \
    '$inheritedInstructions' \
    'ClearEnvironmentVariables' \
    'ErrorOutputPath' \
    '$claudeErrorOutput' \
    '1> $OutputFile 2> $ErrorOutputFile' \
    'The PR diff and review criteria below are the only review evidence' \
    'Do not ask for or use any tools, shell, git, gh, web, or repository access' \
    'Get-Content -LiteralPath $reviewInputs.DiffPath -Raw' \
    "'--output-last-message'" \
    'Remove-Item -LiteralPath $reviewInputs.EvidenceDirectory' \
    'Get-StructuredField' \
    'Get-StructuredReviewResult' \
    'Test-StructuredFindings' \
    'Test-StructuredReviewSummary' \
    'Get-ClaudeFallbackReason' \
    'FindingsContractValid' \
    'ReviewSummaryContractValid' \
    'HasStructuredBody' \
    'hasFindings' \
    'hasReviewSummary' \
    'Write-ReviewReport' \
    'RiskAssessment' \
    'Assert-FixedReviewPolicy' \
    'function Get-BlockingRequiredChecks' \
    'AllowReviewCheckPending' \
    "\$CurrentJob -ceq 'run_review' -and" \
    "Get-RequiredCheckFailure -AllowReviewCheckPending" \
    'risk score:' \
    'risk band:' \
    'review labels:' \
    'Publish-ReviewLabels' \
    'Publish-PassComment' \
    'ghPath pr comment' \
    'ghPath label create' \
    'Could not create or update review label' \
    'reviewed base SHA:' \
    'decision: $($Result.DecisionLabel)' \
    '$($Result.Findings)' \
    'review-routing.md' \
    'Complete-ReviewDecision' \
    '-ProcessExitCode $claudeExitCode' \
    'DecisionLabel' \
    'ScoreLabel' \
    'RiskLabel' \
    'detailed runner output is intentionally omitted from the GitHub comment' \
    "'Validate PR contract'" \
    "'PR CI Gate'" \
    'ReviewSubmissionAttempted' \
    'Complete-ReviewDecision' \
    'Claude invocation failed:'; do
    grep -Fq -- "$fallback_contract" "$FALLBACK_SCRIPT" \
        || fail "Codex review fallback 스크립트에 다음 계약이 없습니다: $fallback_contract"
done
fallback_classifier_line="$(grep -nF -- 'function Get-ClaudeFallbackReason' "$FALLBACK_SCRIPT" | cut -d: -f1)"
structured_result_line="$(grep -nF -- '$claudeHasStructuredResult = $claudeResult.DecisionMatch.Success -and $claudeResult.ScoreMatch.Success -and $claudeResult.RiskMatch.Success -and $claudeResult.HasStructuredBody -and $claudeResult.FindingsContractValid -and $claudeResult.ReviewSummaryContractValid' "$FALLBACK_SCRIPT" | cut -d: -f1)"
claude_success_line="$(grep -nF -- '$claudeReviewSucceeded = ($claudeExitCode -eq 0) -and $claudeHasStructuredResult' "$FALLBACK_SCRIPT" | cut -d: -f1)"
primary_reviewer_line="$(grep -nF -- "if (\$reviewInputs.RiskAssessment.primaryReviewer -eq 'claude')" "$FALLBACK_SCRIPT" | cut -d: -f1)"
direct_codex_line="$(grep -nF -- 'Configured primary reviewer is Codex; skipping Claude and starting the read-only review' "$FALLBACK_SCRIPT" | cut -d: -f1)"
fallback_reason_line="$(grep -nF -- '-HasStructuredResult $claudeHasStructuredResult' "$FALLBACK_SCRIPT" | cut -d: -f1)"
codex_fallback_route_line="$(grep -nF -- 'Claude did not produce a usable structured review' "$FALLBACK_SCRIPT" | cut -d: -f1)"
[[ -n "$fallback_classifier_line" && -n "$structured_result_line" && -n "$claude_success_line" && -n "$primary_reviewer_line" && -n "$direct_codex_line" && -n "$fallback_reason_line" && -n "$codex_fallback_route_line" \
    && "$fallback_classifier_line" -lt "$primary_reviewer_line" \
    && "$primary_reviewer_line" -lt "$structured_result_line" \
    && "$structured_result_line" -lt "$claude_success_line" \
    && "$claude_success_line" -lt "$fallback_reason_line" ]] \
    || fail 'Codex must be the direct configured reviewer, and Claude missing/invalid results must route to Codex.'
grep -Fq -- 'Malformed Claude output mentioning a timeout was not routed as an invalid result.' "$ROOT_DIR/scripts/review-backend-fallback-contract-test.ps1" \
    || fail 'malformed Claude review output fallback 회귀 테스트가 없습니다.'
grep -Fq -- 'Invoke-Tool did not preserve separate stdout/stderr for fallback classification' "$ROOT_DIR/scripts/review-backend-fallback-contract-test.ps1" \
    || fail 'Claude CLI 표준 출력과 오류 출력 분리 계약 테스트가 없습니다.'
grep -Fq -- "return 'claude-invalid-structured-result'" "$FALLBACK_SCRIPT" \
    || fail 'Malformed or missing Claude structured output must route to Codex fallback.'
for check_json_parse in \
    'ConvertFrom-Json -InputObject $checksEnvelopeJson' \
    '$checks = @($checksEnvelope.checks)' \
    'ConvertFrom-Json -InputObject $allChecksEnvelopeJson' \
    '$allChecks = @($allChecksEnvelope.checks)'; do
    grep -Fq -- "$check_json_parse" "$FALLBACK_SCRIPT" \
        || fail "Codex review fallback must parse check JSON as an explicit input object: $check_json_parse"
done
if grep -Fq -- '$checksJson | ConvertFrom-Json' "$FALLBACK_SCRIPT" || grep -Fq -- '$allChecksJson | ConvertFrom-Json' "$FALLBACK_SCRIPT"; then
    fail 'PR check JSON arrays must not be piped into ConvertFrom-Json on Windows PowerShell.'
fi
pre_review_gate_line="$(grep -nF -- '$preReviewCheckFailure = Get-RequiredCheckFailure' "$FALLBACK_SCRIPT" | cut -d: -f1)"
reviewer_start_line="$(grep -nF -- '$claudeBin = ' "$FALLBACK_SCRIPT" | cut -d: -f1)"
[[ -n "$pre_review_gate_line" && -n "$reviewer_start_line" && "$pre_review_gate_line" -lt "$reviewer_start_line" ]] \
    || fail 'Codex/Claude review must not start before required CI and PR gates pass.'
if grep -Fq -- '--ignore-rules' "$FALLBACK_SCRIPT"; then
    fail 'Codex fallback must not bypass repository rules.'
fi
if grep -Fq -- "(Join-Path \$ReviewWorkspace 'AGENTS.md')" "$FALLBACK_SCRIPT" || grep -Fq -- '## $contextPath' "$FALLBACK_SCRIPT"; then
    fail 'Codex review evidence must not include inherited repository instructions or local file paths.'
fi
if grep -Fq -- '--approve' "$FALLBACK_SCRIPT" || grep -Fq -- 'ghPath pr merge' "$FALLBACK_SCRIPT"; then
    fail 'The review job must defer approval and merge to the dependent approval job.'
fi
if [[ "$(grep -Fc -- "Submit-Review '--request-changes'" "$FALLBACK_SCRIPT")" -ne 1 ]]; then
    fail 'REQUEST_CHANGES must have exactly one GitHub review submission site.'
fi
if grep -Fq -- "-replace '\s+' ' '" "$FALLBACK_SCRIPT" || grep -Fq -- 'MaximumCharacters = 2000' "$FALLBACK_SCRIPT"; then
    fail 'Structured findings must retain all lines and content.'
fi
grep -Fq -- '$summaryLines.Count -ne 7' "$FALLBACK_SCRIPT" || fail 'review_summary는 정확히 7개의 구조화 줄만 허용해야 합니다.'
grep -Fq -- '$rubricMatches.Count -ne 1' "$FALLBACK_SCRIPT" || fail 'review_summary rubric 중복을 차단하지 않습니다.'
grep -Fq -- '):\s+PASS\s+.{10,}$' "$FALLBACK_SCRIPT" || fail 'review_summary rubric은 PASS만 허용해야 합니다.'
grep -Fq -- '$conclusionMatches.Count -ne 1' "$FALLBACK_SCRIPT" || fail 'review_summary conclusion 중복을 차단하지 않습니다.'
grep -Fq -- '-Findings $findings' "$FALLBACK_SCRIPT" || fail 'review_summary 검증에 구조화 findings가 전달되지 않습니다.'
grep -Fq -- 'When findings contain P2 or P3 items, mention every present severity in the score rationale or conclusion.' "$FALLBACK_SCRIPT" || fail 'review prompt가 P2/P3 finding의 summary 참조를 요구하지 않습니다.'
grep -Fq -- 'A P2 finding without a summary reference was not isolated as a summary contract failure.' "$ROOT_DIR/scripts/review-backend-fallback-contract-test.ps1" || fail 'P2 finding과 summary 불일치 회귀 테스트가 없습니다.'
grep -Fq -- "api --paginate --slurp --jq 'flatten'" "$FALLBACK_SCRIPT" || fail 'PASS 댓글 중복 방지를 위해 모든 PR 댓글을 조회하지 않습니다.'
grep -Fq -- 'Get-ExistingPassComment -Comments $existingComments -Login $reviewLogin -HeadSha $HeadSha' "$FALLBACK_SCRIPT" || fail 'PASS 댓글 조회가 작성자와 현재 head SHA에 결합되지 않습니다.'
grep -Fq -- 'api -X PATCH "repos/$Repository/issues/comments/$($existingComment.id)" -F "body=@$commentPath"' "$FALLBACK_SCRIPT" || fail '기존 PASS 댓글을 갱신하는 경로가 없습니다.'
grep -Fq -- 'same-author PASS comment for the current head was not updated in place.' "$ROOT_DIR/scripts/review-backend-fallback-contract-test.ps1" || fail '동일 head의 PASS 댓글 갱신 회귀 테스트가 없습니다.'
grep -Fq -- '$claudeResult.FindingsContractValid' "$FALLBACK_SCRIPT" || fail 'Claude 구조화 findings 계약이 fallback 판단에 반영되지 않습니다.'
grep -Fq -- '$claudeResult.ReviewSummaryContractValid' "$FALLBACK_SCRIPT" || fail 'Claude 구조화 summary 계약이 fallback 판단에 반영되지 않습니다.'
APPROVAL_SCRIPT="$ROOT_DIR/scripts/complete-review-approval.ps1"
[[ -f "$APPROVAL_SCRIPT" ]] || fail "분리된 승인 게이트 스크립트가 없습니다: $APPROVAL_SCRIPT"
for approval_regression in \
    'paginated-changes-requested' \
    'same-timestamp-conflict' \
    'stale-current-head' \
    'case-variant-same-user'; do
    grep -Fq -- "'$approval_regression'" "$ROOT_DIR/scripts/complete-review-approval-contract-test.ps1" \
        || fail "승인 계약 회귀 테스트가 누락되었습니다: $approval_regression"
done
for approval_contract in \
    'Assert-ReviewedPullRequestIsCurrent' \
    'Assert-FixedApprovalPolicy' \
    'Review policy dryRun must be false to enable score-based auto-merge.' \
    'expectedWeights' \
    'expectedBands' \
    "'Validate PR contract'" \
    "'PR CI Gate'" \
    "'review'" \
    'Required checks are not passing' \
    'The review report must have a PASS result with score 4 or higher.' \
    'The review report must include deterministic risk score, risk band, and labels.' \
    'review-risk.ps1' \
    'Get-CurrentHeadApprovers' \
    'Test-EligibleHumanApprover' \
    'Get-HumanApprovalSummary' \
    'Assert-RequiredChecksMatchBranchProtection' \
    'Get-CanonicalReviewChecks' \
    "[string]\$_.name -ceq 'review'" \
    "reportedBucket -ine 'pass'" \
    'Branch-required check' \
    'Test-ReviewLabelsMatchAssessment' \
    "'review labels'" \
    'Assert-NoUnresolvedChangeRequests' \
    'api' \
    'graphql' \
    'reviews(first: 100, after: $cursor)' \
    'pageInfo { hasNextPage endCursor }' \
    'hasNextPage' \
    'endCursor' \
    'Human review pagination did not provide a deterministic next cursor.' \
    'createdAt' \
    'Human review data is missing a submittedAt and createdAt timestamp' \
    'conflicting states or commits at the same timestamp' \
    'Timestamp = $reviewTimestamp' \
    'CommitOid = [string]$review.commit.oid' \
    'Get-CurrentHeadApprovers -LatestByLogin $eligibleLatestByLogin -ExpectedHeadSha $ExpectedHeadSha' \
    'collaborators/$encodedLogin/permission' \
    "@('admin', 'maintain', 'push', 'write')" \
    '$latest.State -eq '\''APPROVED'\'' -and $latest.CommitOid -eq $ExpectedHeadSha' \
    '$latestChangeRequestEventByLogin[$reviewEvent.Login] = $reviewEvent' \
    'COMMENTED, PENDING, and approvals on stale commits do not resolve it.' \
    'Get-BranchProtectionApprovalRequirement' \
    'required_status_checks' \
    'RequiredCheckContexts' \
    'Branch protection required check set does not match gh pr checks --required' \
    'required_approving_review_count' \
    'effectiveMinimumApprovals' \
    'DismissStaleReviews' \
    'dismiss_stale_reviews' \
    'does not dismiss stale pull request reviews' \
    'ExpectedHeadSha' \
    'commit.oid' \
    'reviewState' \
    "authorAssociation -eq 'MANNEQUIN'" \
    'CONTRIBUTOR' \
    'authorAssociation' \
    'review.id' \
    'review.databaseId' \
    'CompareOrdinal' \
    'ReviewId' \
    'riskMatch.Groups[1].Value -ne [string]$riskAssessment.riskBand' \
    'The normalized review risk label does not match the deterministic label.' \
    'minimumApprovals' \
    'autoMergePolicy' \
    ' --auto' \
    "'--json', 'name,state,bucket,link'" \
    'Test-CurrentRunReviewCheck' \
    "[string]\$Check.state -ine 'SUCCESS'" \
    "[string]\$Check.bucket -ine 'pass'" \
    'ConvertFrom-Json -InputObject $checksEnvelopeJson' \
    '$checks = @($checksEnvelope.checks)' \
    'return ,$checks'; do
    grep -Fq -- "$approval_contract" "$APPROVAL_SCRIPT" \
        || fail "분리된 승인 게이트에 다음 계약이 없습니다: $approval_contract"
done
grep -Fq -- 'REVIEW_JOB_RESULT: ${{ needs.run_review.result }}' "$ROOT_DIR/.github/workflows/codex-branch-review.yml" \
    || fail '승인 job에 상위 review job의 검증된 결과가 전달되지 않습니다.'
grep -Fq -- '-ReviewJobResult $env:REVIEW_JOB_RESULT' "$ROOT_DIR/.github/workflows/codex-branch-review.yml" \
    || fail '승인 게이트가 상위 review job 결과를 사용하지 않습니다.'
grep -Fq -- "State = 'DISMISSED'" "$ROOT_DIR/scripts/complete-review-approval-contract-test.ps1" \
    || fail '승인 계약 테스트가 dismissed review state를 검증하지 않습니다.'
grep -Fq -- "Scenario = 'stale-changes-requested-commented'" "$ROOT_DIR/scripts/complete-review-approval-contract-test.ps1" \
    || fail '승인 계약 테스트가 후속 COMMENTED 뒤에도 stale change request를 차단하지 않습니다.'
grep -Fq -- "Scenario = 'stale-changes-requested-dismissed'" "$ROOT_DIR/scripts/complete-review-approval-contract-test.ps1" \
    || fail '승인 계약 테스트가 change request 명시적 dismissal 해제를 검증하지 않습니다.'
grep -Fq -- 'Get-BranchProtectionApprovalRequirement -BaseBranch' "$ROOT_DIR/scripts/complete-review-approval-contract-test.ps1" \
    || fail '승인 계약 테스트가 branch protection live 검증 경로를 실행하지 않습니다.'
grep -Fq -- 'Assert-FixedApprovalPolicy -ReviewPolicy' "$ROOT_DIR/scripts/complete-review-approval-contract-test.ps1" \
    || fail '승인 계약 테스트가 고정 리뷰 정책 검증 경로를 실행하지 않습니다.'
grep -Fq -- 'JDSNACK_FAKE_REVIEWER_PERMISSION' "$ROOT_DIR/scripts/complete-review-approval-contract-test.ps1" \
    || fail '승인 계약 테스트가 reviewer repository permission 경로를 실행하지 않습니다.'
grep -Fq -- 'JDSNACK_FAKE_STATUS_CHECKS' "$ROOT_DIR/scripts/complete-review-approval-contract-test.ps1" \
    || fail '승인 계약 테스트가 branch protection required check 경로를 실행하지 않습니다.'
grep -Fq -- 'fixture_head_sha=' "$ROOT_DIR/scripts/pre-push-ai-review-test.sh" \
    || fail 'pre-push AI 리뷰 계약 테스트가 fixture HEAD를 명시적으로 검증하지 않습니다.'
if grep -Fq -- "if (\$reviewState -ieq 'DISMISSED')" "$APPROVAL_SCRIPT"; then
    fail 'Dismissed human reviews must remain in latest-state selection so they revoke earlier approvals.'
fi
unresolved_changes_line="$(grep -nF -- 'Assert-NoUnresolvedChangeRequests -ApprovalSummary $approvalSummary' "$APPROVAL_SCRIPT" | cut -d: -f1)"
merge_command_line="$(grep -nF -- '& $script:ghPath pr merge $PullRequestNumber --repo $Repository --squash --delete-branch --auto' "$APPROVAL_SCRIPT" | cut -d: -f1)"
[[ -n "$unresolved_changes_line" && -n "$merge_command_line" && "$unresolved_changes_line" -lt "$merge_command_line" ]] \
    || fail 'Unresolved change requests must be rejected before queuing Squash auto-merge.'
RISK_SCRIPT="$ROOT_DIR/scripts/review-risk.ps1"
grep -Fq -- 'expectedScoringPathPatterns' "$RISK_SCRIPT" || fail '위험도 계산기가 source/test scoring path patterns를 고정하지 않습니다.'
grep -Fq -- 'Review policy dryRun must be false to enable score-based auto-merge.' "$RISK_SCRIPT" || fail '위험도 계산기가 dryRun=false 정책을 고정하지 않습니다.'
grep -Fq -- 'scripts/.*-test' "$ROOT_DIR/scripts/review-policy.json" || fail 'PowerShell test path가 위험도 정책에 포함되지 않았습니다.'
grep -Fq -- 'ChangesRequested' "$APPROVAL_SCRIPT" || fail '승인 게이트가 unresolved change request를 차단하지 않습니다.'
PR_GATE_SCRIPT="$ROOT_DIR/scripts/pr-review-gate.sh"
grep -Fq -- 'current_refs_path' "$PR_GATE_SCRIPT" || fail 'PR review gate가 위험도 계산 후 최신 PR SHA를 보관하지 않습니다.'
grep -Fq -- '위험도 계산 중 변경되어' "$PR_GATE_SCRIPT" || fail 'PR review gate가 위험도 계산 중 PR SHA 변경을 차단하지 않습니다.'
approval_summary_line="$(grep -nF -- '$approvalSummary = Get-HumanApprovalSummary' "$APPROVAL_SCRIPT" | head -n 1 | cut -d: -f1)"
[[ -n "$approval_summary_line" ]] \
    || fail '승인 게이트가 미해결 변경요청 및 GitHub branch protection 승인을 검증하지 않습니다.'
if grep -Fq -- '--admin' "$APPROVAL_SCRIPT"; then
    fail '분리된 승인 게이트는 관리자 우회 머지를 포함하면 안 됩니다.'
fi
if ! grep -Fq -- 'pr merge' "$APPROVAL_SCRIPT"; then
    fail 'PASS와 필수 게이트 통과 후 Squash auto-merge를 큐에 넣는 경로가 없습니다.'
fi
if grep -Fq -- 'pulls/$PullRequestNumber/reviews' "$APPROVAL_SCRIPT" || grep -Fq -- "event = 'APPROVE'" "$APPROVAL_SCRIPT"; then
    fail '저장소 소유자가 자기 PR에 별도 GitHub APPROVE 리뷰를 제출하도록 요구하지 않습니다.'
fi
assert_not_contains '--dangerously-skip-permissions'
for unsafe_report_contract in \
    '- decision: $($decisionMatch.Value)' \
    '- score: $($scoreMatch.Value)' \
    '- risk: $($riskMatch.Value)' \
    '- evidence: $($reviewInputs.DiffPath), $($reviewInputs.CriteriaPath)' \
    '## Codex report'; do
    if grep -Fq -- "$unsafe_report_contract" "$FALLBACK_SCRIPT"; then
        fail "Codex 리뷰 댓글에 원시 출력 또는 임시 경로를 포함하는 포맷이 남아 있습니다: $unsafe_report_contract"
    fi
done
if grep -Fq -- '--admin' "$FALLBACK_SCRIPT"; then
    fail 'Codex review fallback은 관리자 우회 머지를 포함하면 안 됩니다.'
fi
[[ -f "$CLAUDE_SKILL" ]] || fail "저장소의 Claude review-loop 스킬 파일이 없습니다: $CLAUDE_SKILL"
[[ -f "$AGENTS_SKILL" ]] || fail "저장소의 .agents review-loop 스킬 파일이 없습니다: $AGENTS_SKILL"
diff -u <(sed 's/\r$//' "$CLAUDE_SKILL") <(sed 's/\r$//' "$AGENTS_SKILL") >/dev/null || fail ".claude와 .agents의 review-loop 스킬이 서로 다릅니다."
for skill_contract in \
    'bash scripts/pr-contract-test.sh <N>' \
    '현재 primary reviewer는 Codex이므로 Claude 호출 없이 바로 읽기 전용 리뷰를 실행합니다.' \
    'PASS와 score 4 이상이면 review report를 artifact로 넘깁니다.' \
    'REQUEST_CHANGES는 GitHub review로 한 번 제출합니다.' \
    'COMMENT, NEEDS_HUMAN, score 4 미만은 정식 comment review를 남기고 자동 병합을 중단합니다.' \
    '위험도는 라벨일 뿐 PASS 기준이나 승인 수를 바꾸지 않습니다.' \
    'approval job은 report와 최신 PR이 리뷰한 base/head SHA, Validate PR contract' \
    'PR head에 게시된 review check' \
    '위험도 구간별 추가 사람 승인은 요구하지 않습니다.' \
    'Squash auto-merge를 큐에 넣습니다.' \
    'gh pr view의 state가 MERGED이고 mergedAt이 있을 때만 완료로 보고합니다.' \
    'needs-human으로 멈춥니다.' \
    '현재 실행의 review check도 GitHub가 SUCCESS/pass로 완료한 경우에만 인정하며' \
    'Codex는 구현·테스트와 현재 기본 PR 리뷰'; do
    grep -Fq -- "$skill_contract" "$CLAUDE_SKILL" \
        || fail "review-loop 스킬에 다음 리뷰·머지 계약이 없습니다: $skill_contract"
done
if grep -Fq -- 'gh pr review <N> --approve' "$CLAUDE_SKILL" || grep -Fq -- 'gh pr merge <N>' "$CLAUDE_SKILL"; then
    fail 'The review skill must defer automatic approval to its gated dependent job.'
fi
assert_not_contains "shell: bash"
assert_not_contains "  push:"
assert_not_contains "github.event_name == 'push'"
assert_not_contains 'Join-Path $env:USERPROFILE'

for review_check_contract in \
    '  publish_review_check:' \
    'needs: [run_review]' \
    'checks: write' \
    'head_sha = $env:REVIEW_HEAD_SHA' \
    'external_id = $externalId' \
    'name = '\''review'\''' \
    'needs: [run_review, publish_review_check]' \
    "if: needs.run_review.result == 'success' && needs.publish_review_check.result == 'success'"; do
    grep -Fq -- "$review_check_contract" "$ROOT_DIR/.github/workflows/codex-branch-review.yml" \
        || fail "PR head review-check publisher contract is missing: $review_check_contract"
done
if grep -Fq -- 'Verify Claude review skill' "$ROOT_DIR/.github/workflows/codex-branch-review.yml"; then
    fail 'Codex-primary workflow must not require the unused Claude review skill.'
fi
if grep -Eq '^  review:$' "$ROOT_DIR/.github/workflows/codex-branch-review.yml"; then
    fail 'The reviewer job must not share the required review check name with the PR-head check publisher.'
fi

printf 'Codex branch review workflow contract passed\n'
