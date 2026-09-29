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
assert_contains "    types: [opened, synchronize, reopened, auto_merge_enabled]"
assert_contains "  workflow_dispatch:"
assert_contains "      pr_number:"
assert_contains "        required: true"
assert_contains "        type: string"
assert_contains "permissions:"
assert_contains "concurrency:"
assert_contains "  group: jdsnack-review-pr-"
assert_contains "      contents: read"
assert_contains "      pull-requests: write"
assert_contains "  queue_squash:"
assert_contains "    needs: [review]"
assert_contains "    if: needs.review.result == 'success'"
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
assert_contains "'.claude/skills/review-loop/SKILL.md'"
assert_contains 'Test-Path -LiteralPath $skillPath -PathType Leaf'
assert_contains 'Verify GitHub review identity'
assert_contains "gh api user --jq '.login'"
assert_contains 'github.repository_owner'
assert_contains '$actualLogin -ne $expectedLogin'
assert_contains 'throw "Review runner identity mismatch: expected $expectedLogin, got $actualLogin"'
assert_contains 'Run Claude review loop with Codex fallback'
assert_contains 'CLAUDE_BIN: claude'
assert_contains 'CODEX_BIN: codex'
assert_contains 'PR_NUMBER_INPUT: ${{ github.event.pull_request.number || inputs.pr_number }}'
assert_contains 'scripts/review-backend-fallback.ps1'
assert_contains '-PullRequestNumber'
assert_contains '-BaseSha'
assert_contains '-HeadSha'
assert_contains '$pullRequestNumber = $env:PR_NUMBER'
assert_contains "-notmatch '^\\d+\$'"
assert_not_contains "\$pullRequestNumber = '\${{ github.event.pull_request.number || inputs.pr_number }}'"
assert_not_contains 'GH_TOKEN: ${{ github.token }}'
assert_not_contains 'claude --model sonnet --effort medium -p'
FALLBACK_SCRIPT="$ROOT_DIR/scripts/review-backend-fallback.ps1"
[[ -f "$FALLBACK_SCRIPT" ]] || fail "리뷰 backend fallback 스크립트가 없습니다: $FALLBACK_SCRIPT"
for fallback_contract in \
    "--model', 'sonnet" \
    "--effort', 'medium" \
    "'codex'" \
    "'exec'" \
    "'--ephemeral'" \
    'Get-ConfiguredCodexReviewModel' \
    'failed\s+to\s+authenticate' \
    'oauth\s+session\s+expired' \
    "'backends.json'" \
    "'review-fallback'" \
    "'--config', 'model_reasoning_effort=\"medium\"'" \
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
    '--required --json name,state,bucket' \
    "'--restricted'" \
    "'--tools', ''" \
    "'--permission-mode', 'plan'" \
    "'--permission-prompts', 'none'" \
    'HighRisk' \
    '[bool]$ReviewInputs.HighRisk' \
    'needs-human' \
    'High-risk' \
    'Get-OwnerAutoMergeSignoff' \
    'current-head Squash auto-merge confirmation' \
    'Score concrete findings independently from risk; a High-risk label alone does not lower the score.' \
    'Do not use NEEDS_HUMAN solely because a change is High-risk' \
    'Any NEEDS_HUMAN result remains blocked even when owner confirmation exists.' \
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
    'The PR diff and review criteria below are the only review evidence' \
    'Do not ask for or use any tools, shell, git, gh, web, or repository access' \
    'Get-Content -LiteralPath $reviewInputs.DiffPath -Raw' \
    "'--output-last-message'" \
    'Remove-Item -LiteralPath $reviewInputs.EvidenceDirectory' \
    'Get-StructuredField' \
    'Get-StructuredReviewResult' \
    'Write-ReviewReport' \
    'Complete-ReviewDecision' \
    'DecisionLabel' \
    'ScoreLabel' \
    'RiskLabel' \
    'detailed runner output is intentionally omitted from the GitHub comment' \
    "'Validate PR contract'" \
    "'PR CI Gate'" \
    'ReviewSubmissionAttempted' \
    'Complete-ReviewDecision'; do
    grep -Fq -- "$fallback_contract" "$FALLBACK_SCRIPT" \
        || fail "Codex review fallback 스크립트에 다음 계약이 없습니다: $fallback_contract"
done
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
APPROVAL_SCRIPT="$ROOT_DIR/scripts/complete-review-approval.ps1"
[[ -f "$APPROVAL_SCRIPT" ]] || fail "분리된 승인 게이트 스크립트가 없습니다: $APPROVAL_SCRIPT"
for approval_contract in \
    'Assert-ReviewedPullRequestIsCurrent' \
    'Get-OwnerAutoMergeSignoff' \
    "'Validate PR contract'" \
    "'PR CI Gate'" \
    "'review'" \
    'Required checks are not passing' \
    'The review report must have a PASS result with score 4 or higher.' \
    "'skipping'" \
    ' --auto'; do
    grep -Fq -- "$approval_contract" "$APPROVAL_SCRIPT" \
        || fail "분리된 승인 게이트에 다음 계약이 없습니다: $approval_contract"
done
if grep -Fq -- '--admin' "$APPROVAL_SCRIPT"; then
    fail '분리된 승인 게이트는 관리자 우회 머지를 포함하면 안 됩니다.'
fi
if grep -Fq -- 'pulls/$PullRequestNumber/reviews' "$APPROVAL_SCRIPT" || grep -Fq -- "event = 'APPROVE'" "$APPROVAL_SCRIPT"; then
    fail '저장소 소유자가 자기 PR에 별도 GitHub APPROVE 리뷰를 제출하도록 요구하지 않습니다.'
fi
OWNER_SIGNOFF_SCRIPT="$ROOT_DIR/scripts/review-owner-signoff.ps1"
[[ -f "$OWNER_SIGNOFF_SCRIPT" ]] || fail "저장소 소유자 확인 스크립트가 없습니다: $OWNER_SIGNOFF_SCRIPT"
for signoff_contract in \
    "--json state,headRefOid,autoMergeRequest" \
    'request.enabledBy.login' \
    'request.mergeMethod' \
    'ExpectedHeadSha' \
    'enabledAt -lt $headCommittedAt' \
    'The repository owner enabled Squash auto-merge after the current head commit.' \
    'disable and re-enable Squash auto-merge'; do
    grep -Fq -- "$signoff_contract" "$OWNER_SIGNOFF_SCRIPT" \
        || fail "저장소 소유자 확인에 다음 계약이 없습니다: $signoff_contract"
done
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
    'PASS와 score 4 이상이면 review report를 artifact로 넘깁니다.' \
    'REQUEST_CHANGES는 GitHub review로 한 번 제출합니다.' \
    'COMMENT, NEEDS_HUMAN, score 4 미만은 정식 comment review를 남기고 자동 승인을 중단합니다.' \
    'High-risk도 같은 리뷰 점수를 요구하며 소유자가 최신 head 이후 Squash auto-merge를 켜야 사람 확인을 통과합니다.' \
    'approval job은 report와 최신 PR이 리뷰한 base/head SHA가 일치하는지' \
    'Validate PR contract, PR CI Gate, review check' \
    '별도 GitHub APPROVE 리뷰 없이 확인한 head의 squash auto-merge를 큐에 넣습니다.' \
    'gh pr view의 state가 MERGED이고 mergedAt이 있을 때만 완료로 보고합니다.' \
    'needs-human으로 멈춥니다.' \
    'autoMergeRequest' \
    '현재 실행 중인 review check는 완료 전에 IN_PROGRESS일 수 있으므로' \
    '최대 3회' \
    'attempt == 3'; do
    grep -Fq -- "$skill_contract" "$CLAUDE_SKILL" \
        || fail "Claude review-loop 스킬에 다음 리뷰·머지 계약이 없습니다: $skill_contract"
done
if grep -Fq -- 'gh pr review <N> --approve' "$CLAUDE_SKILL" || grep -Fq -- 'gh pr merge <N>' "$CLAUDE_SKILL"; then
    fail 'The review skill must defer automatic approval to its gated dependent job.'
fi
assert_not_contains "shell: bash"
assert_not_contains "  push:"
assert_not_contains "github.event_name == 'push'"
assert_not_contains 'Join-Path $env:USERPROFILE'

printf 'Codex branch review workflow contract passed\n'
