[CmdletBinding()]
param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$checkPolicyPath = Join-Path $Workspace 'scripts/pr-check-policy.ps1'
if (-not (Test-Path -LiteralPath $checkPolicyPath -PathType Leaf)) {
    throw "Conditional PR check policy not found: $checkPolicyPath"
}
. $checkPolicyPath
$sourcePath = Join-Path $Workspace 'scripts/review-backend-fallback.ps1'
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Fallback script not found: $sourcePath"
}

$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $sourcePath,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw "Fallback script parse failed: $sourcePath"
}
$fallbackSource = Get-Content -LiteralPath $sourcePath -Raw
if (-not $fallbackSource.Contains('. $prCheckPolicyPath') -or
    -not $fallbackSource.Contains('Test-SuccessfulConditionalPrCheckSkip')) {
    throw 'Fallback script does not load and use the shared conditional PR check policy.'
}

$functionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Test-StructuredReviewSummary'
    }, $true)
if ($null -eq $functionAst) {
    throw 'Test-StructuredReviewSummary function was not found.'
}
. ([scriptblock]::Create($functionAst.Extent.Text))
foreach ($functionName in @('Resolve-ToolPath', 'Invoke-Tool', 'Read-ToolOutput', 'Get-StructuredField', 'Get-ExactlyOneStructuredMatch', 'Test-KoreanReviewText', 'Test-StructuredFindings', 'Get-StructuredReviewResult', 'Get-ClaudeFallbackReason', 'Get-ConfiguredCodexReviewSettings', 'Get-BlockingRequiredChecks', 'Get-PrGateFailure', 'Get-PaginatedJsonItems')) {
    $dependencyAst = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $functionName
        }, $true)
    if ($null -eq $dependencyAst) {
        throw "$functionName function was not found."
    }
    . ([scriptblock]::Create($dependencyAst.Extent.Text))
}

$paginatedComments = @(Get-PaginatedJsonItems -Json '[[{"id":101,"body":"first"}],[{"id":202,"body":"second"}]]')
if ($paginatedComments.Count -ne 2 -or
    [int]$paginatedComments[0].id -ne 101 -or
    [int]$paginatedComments[1].id -ne 202) {
    throw 'Paginated PR comments were not flattened into individual comments.'
}
$invalidCommentsRejected = $false
try {
    Get-PaginatedJsonItems -Json '{not-json}' | Out-Null
} catch {
    $invalidCommentsRejected = $_.Exception.Message -match 'invalid JSON'
}
if (-not $invalidCommentsRejected) {
    throw 'Invalid paginated PR comment JSON was not rejected.'
}

$pendingReviewChecks = @(
    [pscustomobject]@{ name = 'review'; bucket = 'pending' }
    [pscustomobject]@{ name = 'Codex Branch Review / run_review'; bucket = 'pending' }
    [pscustomobject]@{ name = 'Validate PR contract'; bucket = 'pass' }
    [pscustomobject]@{ name = 'PR CI Gate'; bucket = 'pass' }
)
$validPrGateChecks = @(
    [pscustomobject]@{ name = 'Validate PR contract'; bucket = 'pass' }
    [pscustomobject]@{ name = 'PR CI Gate'; bucket = 'pass' }
)
if (-not [string]::IsNullOrWhiteSpace((Get-PrGateFailure -Checks $validPrGateChecks))) {
    throw 'Exact passing PR gates were rejected before reviewer execution.'
}
$caseVariantPrGateFailure = Get-PrGateFailure -Checks @(
    [pscustomobject]@{ name = 'validate PR contract'; bucket = 'pass' }
    [pscustomobject]@{ name = 'PR CI Gate'; bucket = 'pass' }
)
if ($caseVariantPrGateFailure -notmatch 'Expected exactly one ''Validate PR contract'' check, found 0') {
    throw 'A case-mismatched PR gate name was accepted before reviewer execution.'
}
$uppercasePrGateFailure = Get-PrGateFailure -Checks @(
    [pscustomobject]@{ name = 'Validate PR contract'; bucket = 'PASS' }
    [pscustomobject]@{ name = 'PR CI Gate'; bucket = 'pass' }
)
if ($uppercasePrGateFailure -notmatch 'PR gate ''Validate PR contract'' is not passing') {
    throw 'A non-canonical uppercase PASS bucket was accepted before reviewer execution.'
}
$preReviewBlockingChecks = @(Get-BlockingRequiredChecks -Checks $pendingReviewChecks -CurrentJob 'run_review' -AllowReviewCheckPending)
if ($preReviewBlockingChecks.Count -ne 0) {
    throw 'A pending PR-head review check blocked the reviewer job before it could publish its result.'
}
$skippedCurrentReviewJob = @($pendingReviewChecks | ForEach-Object {
        if ($_.name -eq 'Codex Branch Review / run_review') { [pscustomobject]@{ name = $_.name; bucket = 'skipping' } }
        else { $_ }
    })
$preReviewBlockingChecks = @(Get-BlockingRequiredChecks -Checks $skippedCurrentReviewJob -CurrentJob 'run_review' -AllowReviewCheckPending)
if ($preReviewBlockingChecks.Count -ne 1 -or $preReviewBlockingChecks[0].name -ne 'Codex Branch Review / run_review') {
    throw 'A skipped current reviewer job was ignored instead of blocking review approval.'
}
$obsoleteReviewJobAlias = @($pendingReviewChecks + [pscustomobject]@{ name = 'Codex Branch Review / review'; bucket = 'pending' })
$preReviewBlockingChecks = @(Get-BlockingRequiredChecks -Checks $obsoleteReviewJobAlias -CurrentJob 'run_review' -AllowReviewCheckPending)
if ($preReviewBlockingChecks.Count -ne 1 -or $preReviewBlockingChecks[0].name -ne 'Codex Branch Review / review') {
    throw 'An obsolete review-job alias was exempted from pre-review checks.'
}
$skippedOptionalChecks = @($pendingReviewChecks + @(
        [pscustomobject]@{ name = 'Test and build backend'; bucket = 'skipping' }
        [pscustomobject]@{ name = 'Test and build frontend'; bucket = 'skipping' }
        [pscustomobject]@{ name = 'Validate Agent OS docs'; bucket = 'skipping' }
        [pscustomobject]@{ name = 'Build backend container'; bucket = 'skipping' }
        [pscustomobject]@{ name = 'Run compose smoke test'; bucket = 'skipping' }
        [pscustomobject]@{ name = 'Verify Flyway migrations on PostgreSQL'; bucket = 'skipping' }
        [pscustomobject]@{ name = 'Workflow CI'; bucket = 'skipping' }
    ))
$preReviewBlockingChecks = @(Get-BlockingRequiredChecks -Checks $skippedOptionalChecks -CurrentJob 'run_review' -AllowReviewCheckPending)
if ($preReviewBlockingChecks.Count -ne 0) {
    throw 'Conditionally skipped path-selected jobs blocked review despite passing PR contract and CI gates.'
}
$unrelatedFailureChecks = @($pendingReviewChecks + [pscustomobject]@{ name = 'Backend tests'; bucket = 'fail' })
$preReviewBlockingChecks = @(Get-BlockingRequiredChecks -Checks $unrelatedFailureChecks -CurrentJob 'run_review' -AllowReviewCheckPending)
if ($preReviewBlockingChecks.Count -ne 1 -or $preReviewBlockingChecks[0].name -ne 'Backend tests') {
    throw 'Allowing the not-yet-published review check also bypassed an unrelated required failure.'
}
$skippedReviewCheck = @($pendingReviewChecks | ForEach-Object {
        if ($_.name -eq 'review') { [pscustomobject]@{ name = $_.name; bucket = 'skipping' } }
        else { $_ }
    })
$preReviewBlockingChecks = @(Get-BlockingRequiredChecks -Checks $skippedReviewCheck -CurrentJob 'run_review' -AllowReviewCheckPending)
if ($preReviewBlockingChecks.Count -ne 1 -or $preReviewBlockingChecks[0].name -ne 'review') {
    throw 'A skipped required review check was treated as a successful review.'
}
$skippedPrGate = @($pendingReviewChecks | ForEach-Object {
        if ($_.name -eq 'PR CI Gate') { [pscustomobject]@{ name = $_.name; bucket = 'skipping' } }
        else { $_ }
    })
$preReviewBlockingChecks = @(Get-BlockingRequiredChecks -Checks $skippedPrGate -CurrentJob 'run_review' -AllowReviewCheckPending)
if ($preReviewBlockingChecks.Count -ne 1 -or $preReviewBlockingChecks[0].name -ne 'PR CI Gate') {
    throw 'A skipped PR CI Gate was treated as a successful gate.'
}
$unknownSkippedCheck = @($pendingReviewChecks + [pscustomobject]@{ name = 'Unrecognized required check'; bucket = 'skipping' })
$preReviewBlockingChecks = @(Get-BlockingRequiredChecks -Checks $unknownSkippedCheck -CurrentJob 'run_review' -AllowReviewCheckPending)
if ($preReviewBlockingChecks.Count -ne 1 -or $preReviewBlockingChecks[0].name -ne 'Unrecognized required check') {
    throw 'An unrecognized skipped required check was treated as successful.'
}
$skippedCanonicalReview = @($pendingReviewChecks + [pscustomobject]@{ name = 'review'; bucket = 'skipping' })
$preReviewBlockingChecks = @(Get-BlockingRequiredChecks -Checks $skippedCanonicalReview -CurrentJob 'run_review' -AllowReviewCheckPending)
if ($preReviewBlockingChecks.Count -ne 1 -or $preReviewBlockingChecks[0].name -ne 'review') {
    throw 'A skipped canonical review check was treated as successful.'
}
$allowedConditionalPrChecks = @(
    'Validate Agent OS docs'
    'Test and build backend'
    'Verify Flyway migrations on PostgreSQL'
    'Test and build frontend'
    'Build backend container'
    'Run compose smoke test'
    'Workflow CI'
)
foreach ($checkName in $allowedConditionalPrChecks) {
    if (-not (Test-SuccessfulConditionalPrCheckSkip -CheckName $checkName -Bucket 'skipping')) {
        throw "Path-selected PR check '$checkName' was not recognized as conditionally skippable."
    }
}
foreach ($checkName in @('Validate PR contract', 'PR CI Gate', 'review', 'Unrecognized required check', 'test and build backend')) {
    if (Test-SuccessfulConditionalPrCheckSkip -CheckName $checkName -Bucket 'skipping') {
        throw "Non-optional PR check '$checkName' was recognized as conditionally skippable."
    }
}
$uppercasePassingCheck = @([pscustomobject]@{ name = 'Unrecognized required check'; bucket = 'PASS' })
$preReviewBlockingChecks = @(Get-BlockingRequiredChecks -Checks $uppercasePassingCheck -CurrentJob 'run_review')
if ($preReviewBlockingChecks.Count -ne 1) {
    throw 'A non-canonical uppercase PASS bucket was accepted as a successful required check.'
}
$withoutReviewExemption = @(Get-BlockingRequiredChecks -Checks $pendingReviewChecks -CurrentJob 'run_review')
if ($withoutReviewExemption.Count -ne 1 -or $withoutReviewExemption[0].name -ne 'review') {
    throw 'A non-review gate was able to ignore a pending required review check.'
}

$modelFixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('jdsnack-review-model-contract-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $modelFixtureRoot -Force | Out-Null
try {
    $modelFixture = @{
        workers = @{
            codex = @{
                'review-fallback' = @{
                    model = 'gpt-6-luna'
                    effort = 'max'
                }
            }
        }
    }
    $modelFixture | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $modelFixtureRoot 'backends.json') -Encoding utf8
    $configuredModel = Get-ConfiguredCodexReviewSettings -ReviewWorkspace $modelFixtureRoot
    if ($configuredModel.Model -ne 'gpt-6-luna' -or $configuredModel.Effort -ne 'max') {
        throw 'The configured Codex reviewer model and effort were not preserved.'
    }
    $modelFixture.workers.codex.'review-fallback'.effort = 'unsupported'
    $modelFixture | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $modelFixtureRoot 'backends.json') -Encoding utf8
    $unsupportedEffortRejected = $false
    try {
        Get-ConfiguredCodexReviewSettings -ReviewWorkspace $modelFixtureRoot | Out-Null
    } catch {
        $unsupportedEffortRejected = $_.Exception.Message -match 'unsupported'
    }
    if (-not $unsupportedEffortRejected) {
        throw 'An unsupported Codex reviewer effort was accepted.'
    }
} finally {
    Remove-Item -LiteralPath $modelFixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$validSummary = @(
    '- correctness: PASS — 세 링크 경로가 각 문서 위치와 일치합니다.'
    '- contract: PASS — 변경이 보관 요구사항 문서의 링크 수정으로 제한됩니다.'
    '- tests: PASS — 문서 링크 검증과 diff 검사가 통과했습니다.'
    '- security: PASS — 보안 동작과 설정에 영향이 없습니다.'
    '- maintainability: PASS — 관련 문서로 이동하는 경로가 명확합니다.'
    '- score rationale: 5/5 — 변경 범위가 명확하고 추가 문제가 없습니다.'
    '- conclusion: 수정된 링크는 대상 문서를 가리키며 변경이 안전합니다.'
)
if (-not (Test-StructuredReviewSummary -Summary ($validSummary -join [Environment]::NewLine) -Score 5)) {
    throw 'A valid seven-line review summary was rejected.'
}
$unbulletedSummary = @($validSummary | ForEach-Object { ([string]$_) -replace '^\s*-\s*', '' })
if (-not (Test-StructuredReviewSummary -Summary ($unbulletedSummary -join [Environment]::NewLine) -Score 5)) {
    throw 'A valid seven-line review summary without bullet prefixes was rejected.'
}
$noSpaceBulletSummary = @($validSummary | ForEach-Object { ([string]$_) -replace '^\s*-\s+', '-' })
if (Test-StructuredReviewSummary -Summary ($noSpaceBulletSummary -join [Environment]::NewLine) -Score 5) {
    throw 'A malformed review summary with a hyphen directly attached to its field name was accepted.'
}

foreach ($severity in @('P2', 'P3')) {
    $finding = "- $severity — 경미한 발견사항은 리뷰 요약에도 반영해야 합니다."
    if (Test-StructuredReviewSummary -Summary ($validSummary -join [Environment]::NewLine) -Score 5 -Findings $finding) {
        throw "A $severity finding was accepted without a matching summary reference."
    }

    $referencedSummary = @($validSummary)
    $referencedSummary[6] = "- conclusion: $severity 발견사항을 유지하고 검토 근거를 기록했습니다."
    if (-not (Test-StructuredReviewSummary -Summary ($referencedSummary -join [Environment]::NewLine) -Score 5 -Findings $finding)) {
        throw "A $severity finding referenced in the conclusion was rejected."
    }
}

foreach ($nonPassStatus in @('OK', 'SATISFIED')) {
    $weakerRubricSummary = @($validSummary)
    $weakerRubricSummary[0] = $weakerRubricSummary[0].Replace(': PASS ', ": $nonPassStatus ")
    if (Test-StructuredReviewSummary -Summary ($weakerRubricSummary -join [Environment]::NewLine) -Score 5) {
        throw "A rubric line using $nonPassStatus instead of PASS was accepted."
    }
}

$duplicateRubric = @($validSummary[0..4] + $validSummary[0] + $validSummary[5..6])
if (Test-StructuredReviewSummary -Summary ($duplicateRubric -join [Environment]::NewLine) -Score 5) {
    throw 'A duplicate rubric line was accepted.'
}

$duplicateConclusion = @($validSummary[0..5] + $validSummary[6] + $validSummary[6])
if (Test-StructuredReviewSummary -Summary ($duplicateConclusion -join [Environment]::NewLine) -Score 5) {
    throw 'A duplicate conclusion line was accepted.'
}

$extraLine = @($validSummary + '- unrelated extra evidence must be rejected.')
if (Test-StructuredReviewSummary -Summary ($extraLine -join [Environment]::NewLine) -Score 5) {
    throw 'An extra summary line was accepted.'
}
$englishOnlySummary = @($validSummary)
$englishOnlySummary[0] = '- correctness: PASS — all three links reach their intended documents.'
if (Test-StructuredReviewSummary -Summary ($englishOnlySummary -join [Environment]::NewLine) -Score 5) {
    throw 'An English-only review explanation was accepted.'
}
$garbledSummary = @($validSummary)
$garbledSummary[0] = '- correctness: PASS — 寃쎈맂 링크 경로는 정상입니다.'
if (Test-StructuredReviewSummary -Summary ($garbledSummary -join [Environment]::NewLine) -Score 5) {
    throw 'A mixed CJK and Hangul review explanation was accepted.'
}

$validReview = @(
    'decision: PASS'
    'score: 5/5'
    'risk: Light'
    'findings:'
    '- none'
    'review_summary:'
    $validSummary
) -join [Environment]::NewLine
$validResult = Get-StructuredReviewResult -Text $validReview -ReviewerBackend 'claude' -FallbackReason 'none'
if (-not $validResult.FindingsContractValid -or -not $validResult.ReviewSummaryContractValid) {
    throw "A valid structured review result did not preserve both contract-valid flags (decision=$($validResult.DecisionMatch.Success), score=$($validResult.ScoreMatch.Success), risk=$($validResult.RiskMatch.Success), findings=$($validResult.FindingsContractValid), summary=$($validResult.ReviewSummaryContractValid))."
}
$splitDecisionReview = $validReview.Replace('decision: PASS', "decision:`nPASS")
$splitDecisionResult = Get-StructuredReviewResult -Text $splitDecisionReview -ReviewerBackend 'claude' -FallbackReason 'none'
if ($splitDecisionResult.DecisionMatch.Success) {
    throw 'A decision value split onto another line was accepted as a valid scalar field.'
}
$conflictingDecisionReview = $validReview.Replace('decision: PASS', "decision: MAYBE`ndecision: PASS")
$conflictingDecisionResult = Get-StructuredReviewResult -Text $conflictingDecisionReview -ReviewerBackend 'claude' -FallbackReason 'none'
if ($conflictingDecisionResult.DecisionMatch.Success) {
    throw 'Conflicting decision headers were accepted as a valid structured result.'
}
$unreferencedFindingReview = $validReview.Replace('- none', '- P2 — 보관 요구사항 문서의 링크 한 곳이 여전히 잘못된 경로를 가리킵니다.')
$unreferencedFindingResult = Get-StructuredReviewResult -Text $unreferencedFindingReview -ReviewerBackend 'claude' -FallbackReason 'none'
if (-not $unreferencedFindingResult.FindingsContractValid -or $unreferencedFindingResult.ReviewSummaryContractValid) {
    throw 'A P2 finding without a summary reference was not isolated as a summary contract failure.'
}
$malformedFindingsReview = $validReview.Replace('- none', '- informational finding')
$malformedFindingsResult = Get-StructuredReviewResult -Text $malformedFindingsReview -ReviewerBackend 'claude' -FallbackReason 'none'
if ($malformedFindingsResult.FindingsContractValid) {
    throw 'Malformed findings were marked contract-valid.'
}
$malformedSummaryReview = $validReview.Replace('- conclusion: 수정된 링크는 대상 문서를 가리키며 변경이 안전합니다.', '- conclusion: 수정된 링크는 대상 문서를 가리키며 변경이 안전합니다.' + [Environment]::NewLine + '- conclusion: 중복 결론')
$malformedSummaryResult = Get-StructuredReviewResult -Text $malformedSummaryReview -ReviewerBackend 'claude' -FallbackReason 'none'
if ($malformedSummaryResult.ReviewSummaryContractValid) {
    throw 'Malformed review_summary was marked contract-valid.'
}

if ((Get-ClaudeFallbackReason -Output 'ERROR: Claude subscription access is disabled.') -ne 'claude-subscription') {
    throw 'A Claude subscription outage was not classified for fallback.'
}
if ((Get-ClaudeFallbackReason -Output 'ERROR: Authentication failed because the credential expired.') -ne 'claude-auth') {
    throw 'A Claude authentication outage was not classified for fallback.'
}
if ((Get-ClaudeFallbackReason -Output 'JDSNACK RUNNER: tool timed out after 120 seconds (claude).' -ExitCode 124) -ne 'claude-unavailable') {
    throw 'A Claude execution outage was not classified for fallback.'
}
if ((Get-ClaudeFallbackReason -Output 'JDSNACK RUNNER: tool unavailable on PATH (claude).' -ExitCode 127) -ne 'claude-unavailable') {
    throw 'An unavailable Claude executable was not classified for fallback.'
}
if ((Get-ClaudeFallbackReason -Output 'review output mentions a timeout' -ExitCode 124) -ne 'claude-execution-failed') {
    throw 'An unclassified Claude process failure did not route to the Codex reviewer.'
}
if ((Get-ClaudeFallbackReason -Output 'review output mentions an unavailable executable' -ExitCode 127) -ne 'claude-execution-failed') {
    throw 'An unclassified Claude process failure did not route to the Codex reviewer.'
}
if ((Get-ClaudeFallbackReason -Output 'API ERROR: Claude rate limit exceeded.') -ne 'claude-quota') {
    throw 'An explicit Claude quota error was not classified for fallback.'
}
if ((Get-ClaudeFallbackReason -Output 'Claude exited with an internal review error.' -ExitCode 1) -ne 'claude-execution-failed') {
    throw 'An unclassified Claude runner failure was not routed to Codex fallback.'
}
if ((Get-ClaudeFallbackReason -Output '' -ExitCode 0 -HasStructuredResult $false) -ne 'claude-invalid-structured-result') {
    throw 'A missing Claude result was not routed to Codex fallback.'
}
$malformedReviewWithAvailabilityPhrase = "decision: NEEDS_HUMAN`nscore: 1/5`nrisk: Standard`nfindings:`n- P2 — the review timed out in a quoted example.`nreview_summary:`nnot a valid summary"
if ((Get-ClaudeFallbackReason -Output $malformedReviewWithAvailabilityPhrase -ExitCode 0 -HasStructuredResult $false) -ne 'claude-invalid-structured-result') {
    throw 'Malformed Claude output mentioning a timeout was not routed as an invalid result.'
}
$ioTempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('jdsnack-tool-stream-contract-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $ioTempRoot -Force | Out-Null
$ioFixturePath = Join-Path $ioTempRoot 'native-stream-fixture.ps1'
$ioOutputPath = Join-Path $ioTempRoot 'native-stream.stdout.log'
$ioErrorPath = Join-Path $ioTempRoot 'native-stream.stderr.log'
$utf8ReviewPath = Join-Path $ioTempRoot 'review-no-bom.md'
try {
$utf8ReviewText = "review_summary:`n- correctness: PASS — 한글 검토 결과가 UTF-8로 유지됩니다."
[System.IO.File]::WriteAllText($utf8ReviewPath, $utf8ReviewText, [System.Text.UTF8Encoding]::new($false))
$decodedReviewText = Read-ToolOutput -Path $utf8ReviewPath
if ($decodedReviewText -cne $utf8ReviewText) {
    throw 'UTF-8 reviewer output without a BOM was not read without character corruption.'
}
@'
[System.Console]::Out.WriteLine('review text mentions a timeout, but is standard output')
[System.Console]::Error.WriteLine('ERROR: Claude subscription access is disabled.')
'@ | Set-Content -LiteralPath $ioFixturePath -Encoding utf8
$ioExitCode = Invoke-Tool -Name 'pwsh' -Arguments @('-NoProfile', '-File', $ioFixturePath) -OutputPath $ioOutputPath -TimeoutSeconds 30 -ErrorOutputPath $ioErrorPath
$ioStandardOutput = Get-Content -LiteralPath $ioOutputPath -Raw
$ioStandardError = Get-Content -LiteralPath $ioErrorPath -Raw
if ($ioExitCode -ne 0 -or
    $ioStandardOutput -notmatch 'standard output' -or
    $ioStandardError -notmatch 'ERROR: Claude subscription access is disabled' -or
    $ioStandardError -match 'standard output') {
    throw "Invoke-Tool did not preserve separate stdout/stderr for fallback classification (exit=$ioExitCode, stdout=$ioStandardOutput, stderr=$ioStandardError)."
}
} finally {
    Remove-Item -LiteralPath $ioTempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$passCommentFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-ExistingPassComment'
    }, $true)
if ($null -eq $passCommentFunctionAst) {
    throw 'Get-ExistingPassComment function was not found.'
}
. ([scriptblock]::Create($passCommentFunctionAst.Extent.Text))
$publishPassCommentFunctionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Publish-PassComment'
    }, $true)
if ($null -eq $publishPassCommentFunctionAst) {
    throw 'Publish-PassComment function was not found.'
}
. ([scriptblock]::Create($publishPassCommentFunctionAst.Extent.Text))

$passCommentTempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('jdsnack-pass-comment-contract-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $passCommentTempRoot -Force | Out-Null
try {
    $script:fallbackRoot = $passCommentTempRoot
    $script:Repository = 'silverThunder09/jdsnack-agent-os-project'
    $script:PullRequestNumber = 220
    $script:passCommentFakeGhPath = Join-Path $passCommentTempRoot 'gh.ps1'
    $passCommentLog = Join-Path $passCommentTempRoot 'gh-commands.log'
    $passCommentFixture = Join-Path $passCommentTempRoot 'comments.json'
    @'
$arguments = @($args | ForEach-Object { [string]$_ })
Add-Content -LiteralPath $env:JDSNACK_PASS_GH_LOG -Value ($arguments -join '|')
if ($arguments.Count -ge 2 -and $arguments[0] -eq 'api' -and $arguments[1] -eq 'user') {
    Write-Output $env:JDSNACK_PASS_GH_LOGIN
    $global:LASTEXITCODE = 0
    return
}
if ($arguments.Count -gt 0 -and $arguments[-1] -match '^repos/.+/issues/\d+/comments$') {
    Get-Content -LiteralPath $env:JDSNACK_PASS_GH_COMMENTS -Raw
    $global:LASTEXITCODE = 0
    return
}
$global:LASTEXITCODE = 0
'@ | Set-Content -LiteralPath $script:passCommentFakeGhPath -Encoding utf8
    function Resolve-ToolPath {
        param([string]$Name)
        if ($Name -eq 'gh') {
            return $script:passCommentFakeGhPath
        }
        return $null
    }
    $env:JDSNACK_PASS_GH_LOG = $passCommentLog
    $env:JDSNACK_PASS_GH_LOGIN = 'silverThunder09'
    $env:JDSNACK_PASS_GH_COMMENTS = $passCommentFixture

    $headSha = 'abcdef0123456789'
    $riskAssessment = [pscustomobject]@{
        componentScores = [pscustomobject]@{ security = 10; performance = 10 }
        riskScore = 20
        riskBand = 'Light'
        reviewLabels = @('Security')
        autoMergePolicy = 'allowed-after-passing-review-and-required-checks'
        dryRun = $false
    }
    $reviewInputs = [pscustomobject]@{ RiskAssessment = $riskAssessment }
    $reviewResult = [pscustomobject]@{
        ReviewerBackend = 'claude'
        FallbackReason = 'none'
        DecisionLabel = 'PASS'
        ScoreLabel = '5/5'
        ReviewSummary = 'All required review checks passed.'
        Findings = '- none'
    }

    $matchingMarker = "<!-- jdsnack-review-result head:$headSha -->`n## JDSnack 리뷰 PASS"
    @(
        [pscustomobject]@{ id = 120; user = [pscustomobject]@{ login = 'another-user' }; body = $matchingMarker },
        [pscustomobject]@{ id = 121; user = [pscustomobject]@{ login = 'silverThunder09' }; body = '<!-- jdsnack-review-result head:older-head -->' },
        [pscustomobject]@{ id = 130; user = [pscustomobject]@{ login = 'silverThunder09' }; body = $matchingMarker },
        [pscustomobject]@{ id = 131; user = [pscustomobject]@{ login = 'silverThunder09' }; body = $matchingMarker }
    ) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $passCommentFixture -Encoding utf8
    Publish-PassComment -Result $reviewResult -ReviewInputs $reviewInputs -BaseSha 'base-sha' -HeadSha $headSha
    $updateCommands = @(Get-Content -LiteralPath $passCommentLog)
    if (-not ($updateCommands | Where-Object { $_ -match 'api\|-X\|PATCH\|repos/silverThunder09/jdsnack-agent-os-project/issues/comments/131\|-F\|body=@' })) {
        throw 'A same-author PASS comment for the current head was not updated in place.'
    }
    if ($updateCommands | Where-Object { $_ -match '^pr\|comment\|' }) {
        throw 'An existing PASS comment generated a duplicate comment instead of an update.'
    }

    Clear-Content -LiteralPath $passCommentLog
    @(
        [pscustomobject]@{ id = 140; user = [pscustomobject]@{ login = 'another-user' }; body = $matchingMarker },
        [pscustomobject]@{ id = 141; user = [pscustomobject]@{ login = 'silverThunder09' }; body = '<!-- jdsnack-review-result head:older-head -->' }
    ) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $passCommentFixture -Encoding utf8
    Publish-PassComment -Result $reviewResult -ReviewInputs $reviewInputs -BaseSha 'base-sha' -HeadSha $headSha
    $createCommands = @(Get-Content -LiteralPath $passCommentLog)
    if (-not ($createCommands | Where-Object { $_ -match '^pr\|comment\|220\|' })) {
        throw 'A new head without an owned PASS comment did not create a comment.'
    }
    if ($createCommands | Where-Object { $_ -match '\|-X\|PATCH\|' }) {
        throw 'A comment from another author or an older head was overwritten.'
    }
} finally {
    Remove-Item -LiteralPath $passCommentTempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:JDSNACK_PASS_GH_LOG -ErrorAction SilentlyContinue
    Remove-Item Env:JDSNACK_PASS_GH_LOGIN -ErrorAction SilentlyContinue
    Remove-Item Env:JDSNACK_PASS_GH_COMMENTS -ErrorAction SilentlyContinue
}

Write-Output 'Review backend fallback contract tests passed'
