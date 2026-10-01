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
assert_not_contains 'GH_TOKEN: ${{ github.token }}'
assert_not_contains 'claude --model sonnet --effort medium -p'
FALLBACK_SCRIPT="$ROOT_DIR/scripts/review-backend-fallback.ps1"
[[ -f "$FALLBACK_SCRIPT" ]] || fail "리뷰 backend fallback 스크립트가 없습니다: $FALLBACK_SCRIPT"
[[ -f "$ROOT_DIR/scripts/review-policy.json" ]] || fail "리뷰 정책 파일이 없습니다: scripts/review-policy.json"
[[ -f "$ROOT_DIR/scripts/review-risk.ps1" ]] || fail "결정론적 위험도 계산기가 없습니다: scripts/review-risk.ps1"
[[ -f "$ROOT_DIR/.githooks/pre-push" ]] || fail "pre-push hook이 없습니다: .githooks/pre-push"
[[ -f "$ROOT_DIR/scripts/pre-push-ai-review.sh" ]] || fail "pre-push AI 리뷰 스크립트가 없습니다."
[[ -f "$ROOT_DIR/scripts/pre-push-ai-review-test.sh" ]] || fail "pre-push AI 리뷰 계약 테스트가 없습니다."
[[ -f "$ROOT_DIR/.agent-os/operations/review-routing.md" ]] || fail "리뷰 라우팅 문서가 없습니다."
grep -Fq -- 'scripts/review-policy.json' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 전문 라우팅 정책을 읽지 않습니다.'
grep -Fq -- 'Specialized review routing labels and path rules' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰 프롬프트에 전문 라우팅 지침이 없습니다.'
grep -Fq -- '--sandbox read-only' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 read-only sandbox를 강제하지 않습니다.'
grep -Fq -- '--disable shell_tool' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 shell tool을 비활성화하지 않습니다.'
grep -Fq -- 'risk_score:' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 결정론 위험도 점수를 검증하지 않습니다.'
grep -Fq -- 'has_structured_body' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 구조화된 findings/summary를 검증하지 않습니다.'
grep -Fq -- '여러 ref가 한 번에 push되어' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 다중 ref push를 차단하지 않습니다.'
grep -Fq -- 'staged/working-tree diff가 다릅니다' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 push 대상과 dirty checkout의 불일치를 차단하지 않습니다.'
grep -Fq -- 'clear_review_environment' "$ROOT_DIR/scripts/pre-push-ai-review.sh" || fail 'pre-push 리뷰가 Codex 환경 변수를 정리하지 않습니다.'
jq -e '
    .version == 1
    and .dryRun == true
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
    'RiskAssessment' \
    'Assert-FixedReviewPolicy' \
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
    'dry-run' \
    'risk does not match deterministic risk band' \
    'Complete-ReviewDecision' \
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
availability_check_line="$(grep -nF -- '$claudeAvailabilitySignal = [regex]::IsMatch($claudeOutput, $availabilityPattern)' "$FALLBACK_SCRIPT" | cut -d: -f1)"
structured_result_line="$(grep -nF -- '$claudeHasStructuredResult = $claudeResult.DecisionMatch.Success -and $claudeResult.ScoreMatch.Success -and $claudeResult.RiskMatch.Success' "$FALLBACK_SCRIPT" | cut -d: -f1)"
unavailable_route_line="$(grep -nF -- '$claudeReviewUnavailable = $claudeExitCode -ne 0 -or -not $claudeHasStructuredResult' "$FALLBACK_SCRIPT" | cut -d: -f1)"
claude_success_route_line="$(grep -nF -- 'if (-not $claudeReviewUnavailable) {' "$FALLBACK_SCRIPT" | cut -d: -f1)"
codex_fallback_route_line="$(grep -nF -- 'Claude could not provide a valid structured review' "$FALLBACK_SCRIPT" | cut -d: -f1)"
[[ -n "$availability_check_line" && -n "$structured_result_line" && -n "$unavailable_route_line" && -n "$claude_success_route_line" && -n "$codex_fallback_route_line" \
    && "$availability_check_line" -lt "$structured_result_line" \
    && "$structured_result_line" -lt "$unavailable_route_line" \
    && "$unavailable_route_line" -lt "$claude_success_route_line" \
    && "$claude_success_route_line" -lt "$codex_fallback_route_line" ]] \
    || fail 'A Claude invocation failure or malformed structured result must route review to Codex.'
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
    'The review report must include deterministic risk score, risk band, and dry-run state.' \
    'review-risk.ps1' \
    'Get-HumanApprovalSummary' \
    'minimumApprovals' \
    'autoMergePolicy' \
    'dry-run is enabled, so no merge command was executed.' \
    "'skipping'" \
    ' --auto' \
    'ConvertFrom-Json -InputObject $checksEnvelopeJson' \
    '$checks = @($checksEnvelope.checks)' \
    'return ,$checks'; do
    grep -Fq -- "$approval_contract" "$APPROVAL_SCRIPT" \
        || fail "분리된 승인 게이트에 다음 계약이 없습니다: $approval_contract"
done
if grep -Fq -- '--admin' "$APPROVAL_SCRIPT"; then
    fail '분리된 승인 게이트는 관리자 우회 머지를 포함하면 안 됩니다.'
fi
if ! grep -Fq -- 'pr merge' "$APPROVAL_SCRIPT"; then
    fail '드라이런 이후 정책을 해제했을 때만 사용하는 병합 경로가 없습니다.'
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
