# PR 자동 운영 루프

## 목적

JDSnack의 변경은 직접 `main`에 푸시하지 않습니다.
모든 변경은 현재 기획 스레드에서 범위, 위험도, 검증 결과를 정리한 뒤 PR로 반영합니다.

주제가 바뀌면 새 세션을 시작합니다.

## Codex 자동 구현 루프

Codex 자동화 프롬프트는 짧게 유지합니다.

```text
JDSnack 기능 구현 해줘.
기능 구현 해줘.
기능 만들어줘.
루프 확인해줘.
변경요청 있으면 반영해줘.
```

세부 규칙은 저장소 문서를 기준으로 따릅니다.

- Codex 담당: Spec 문서 계획, 구현, 테스트, 커밋, origin push.
- Claude 담당: 명시적으로 선택된 리뷰 backend 또는 사용자 승인 폴백. trusted approval job이 검증 완료 뒤 Squash auto-merge를 큐에 넣습니다.
- 모델 정책은 [Worker 모델 배정](worker-backends.md), `scripts/review-policy.json`의 기본 리뷰어, 루트 [backends.json](../../backends.json)을 따릅니다. 현재 기본 PR reviewer는 Codex이며 Claude를 기본으로 설정한 경우 실행 불가·구조화 결과 오류 시 Codex read-only 리뷰로 전환합니다. 빌드·lint·test·E2E 명령 실행 자체에는 모델을 지정하지 않습니다.
- 구현 대상은 `index.yml`의 `active_specs`(최대 1개) 안에서 준비된 티켓 하나입니다. 다음 후보의 시작 조건을 기다릴 때는 active Spec을 비워 둡니다. 자율 dispatcher는 활성 Spec의 `plan.md`가 있어야 티켓을 선택할 수 있으며, 누락은 `needs-human`입니다.
- 티켓 브랜치는 `codex/<active-spec-slug>-<ticket-id>`로 만들고, 티켓별 구현·테스트·PR·리뷰·머지를 독립적으로 수행합니다.
- **티켓 전진(원자적)**: 티켓 PR에는 코드뿐 아니라 `plan.md`의 티켓 상태와 관련 traceability·테스트 결과 갱신을 포함합니다. 머지 후 active Spec은 유지한 채 다음 준비 티켓을 claim합니다.
- **Feature 완료**: 마지막 티켓과 전체 수용 기준이 통과한 PR을 main에 반영하면 `autonomous-loop.yml`이 완료 Spec을 archive하고 `active_specs`를 비운 뒤 `spec-queue.json`의 첫 eligible 후보를 자동 승격합니다. Windows self-hosted runner에서는 checkout 직후 추적된 `.sh` 파일 목록을 NUL 구분으로 읽어 PowerShell로 LF로 정규화하고, PowerShell이 Windows 경로 구분자를 정규화하고 `wsl.exe wslpath`로 runner 경로를 변환한 뒤 Bash coordinator를 호출합니다. 이 워크플로의 `main` push trigger는 `.agent-os/standards/index.yml`, `.agent-os/product/spec-queue.json`, `.agent-os/specs/**/plan.md` 변경 경로로 한정해 Feature 티켓 진행과 큐 상태 변경만 확인합니다. 자동 판정 가능한 후보가 없을 때는 정책대로 `needs-human`으로 중단합니다.
- **Spec 순환**: Codex가 자동 승격된 후보의 문서 필수 세트와 traceability를 생성·검증한 뒤 Spec promotion PR을 만들고, 통과하면 T1을 Codex에 디스패치합니다. 한 시점에 active Spec은 하나만 유지합니다.
- 변경요청(`리뷰 반려: <branch>` 또는 `리뷰 후속: <branch>` 이슈)이 있으면 같은 `codex/*` 브랜치에서 반영합니다.
- **PR 리뷰-머지 루프는 GitHub 이벤트로 기동합니다.** [.github/workflows/codex-branch-review.yml](../../.github/workflows/codex-branch-review.yml)은 `PR CI Router` 성공 이벤트 뒤에 리뷰를 시작하고 trusted base만 checkout하며 PR head는 실행하지 않습니다. 현재 설정된 Codex가 PR diff와 검토 기준만 받아 저장소 밖의 빈 작업공간에서 도구 없이 리뷰합니다. Claude가 기본 reviewer일 때 실행 불가·누락·형식 오류는 Codex로 넘기며, Codex의 실행 실패나 잘못된 결과는 `needs-human`으로 중단합니다. PASS와 4점 이상, Validate PR contract, PR CI Gate, 현재 head의 모든 branch-required check를 확인합니다. 위험도는 라벨만 정하며 사람 승인 수를 추가하지 않습니다. approval job은 최신 base/head SHA, review check, 필수 check, 미해결 변경요청 부재를 다시 확인한 뒤 Squash auto-merge를 큐에 넣습니다. 경로 라우터가 생략한 체크는 PR CI Gate가 통과했을 때 허용합니다.
- 리뷰 결과는 [review-routing.md](review-routing.md)의 고정 위험도 산식과 Security·Performance·Test Coverage·Architecture 라벨을 사용합니다. PASS는 요약·점수·위험도·head SHA를 PR 코멘트로 공개하고 라벨을 붙입니다. `dryRun=false`이며 모든 위험도에서 PASS 4점 이상과 현재 필수 게이트 통과 시 동일하게 auto-merge를 허용합니다. GitHub branch protection에 실제 설정된 승인과 check-provider 조건은 그대로 존중합니다.
- Windows self-hosted runner에서는 Git Bash의 `C:\...` 임시 스크립트 경로 변환 문제가 생길 수 있으므로 review step은 Windows PowerShell로 실행하고, Claude 절차 파일과 fallback script는 trusted base의 `$GITHUB_WORKSPACE`에서 해석합니다. PR head는 파일로 checkout하지 않고 검증된 base/head SHA의 diff만 evidence로 전달합니다. PR Review는 runner에 로그인된 `gh` 계정을 사용하며, workflow가 `gh api user`와 `github.repository_owner` 일치를 먼저 확인합니다. Actions 기본 `github.token`을 `GH_TOKEN`으로 주입하지 않습니다.
- Windows self-hosted runner의 PR feedback detector는 PowerShell에서 `jq.exe`를 찾아 `GITHUB_PATH`에 추가한 뒤 공백이 없는 8.3 절대 경로 `C:\PROGRA~1\Git\bin\bash.exe`로 Git Bash를 명시적으로 실행합니다. Git Bash가 runner의 Chocolatey 경로를 자동 상속하지 않을 수 있기 때문입니다. `.gitattributes`의 `*.sh text eol=lf`를 적용합니다. autonomous loop는 `JQ_BIN`·`GH_BIN`·`PYTHON_BIN`·`CODEX_BIN`으로 런타임 의존성을 주입할 수 있으며, 누락 시 구조화된 `needs_human` 결과를 출력합니다.
- autonomous loop의 Windows PowerShell 단계는 설치된 `gh.exe`와 `codex.exe`를 `wslpath`로 변환해 각각 `GH_BIN`·`CODEX_BIN`으로 WSL에 전달합니다. `CODEX_BIN`이 Windows 실행 파일이면 coordinator가 `.git` 디렉터리를 가진 standalone clone을 만들고 `--cd` worktree 경로도 Windows 형식으로 변환해 Windows Codex가 WSL worktree 메타데이터에 의존하지 않게 합니다. 따라서 WSL PATH에 두 CLI가 없어도 Codex 기반 Spec promotion PR 흐름을 실행할 수 있습니다.
- 반려 감지는 [pr-feedback-detector.sh](../../scripts/pr-feedback-detector.sh)가 GitHub 이벤트로 깨워진 workflow에서 한 번 실행될 때 수행합니다. 감지기는 polling loop를 내장하지 않으며 `no_action`, `actionable`, `needs_human` JSON과 종료 코드를 내보냅니다.
- `.github/workflows/pr-feedback-detector.yml`은 반려 Issue 생성·수정, Issue/PR 댓글, PR 리뷰, required CI 완료 이벤트에만 실행됩니다. 로컬 `jdsnack` self-hosted runner가 안전한 후보를 격리 worktree에 전달해 Codex의 수정·테스트·커밋·푸시를 수행합니다.
- PR CI는 `.github/workflows/pr-ci-router.yml`이 변경 경로를 먼저 분류한 뒤 필요한 Backend/Frontend/Container/Docs/Workflow job만 조건부 실행합니다. backend/frontend 코드도 각 테스트와 함께 컨테이너 빌드·health·Compose smoke를 실행하며, Dockerfile·Compose·smoke 변경도 같은 runtime 검증을 선택합니다. 기존 개별 workflow는 `main` push와 수동 실행을 담당하며, PR에서는 Router가 기존 job 이름을 유지해 required check를 제공합니다.
- Codex worktree는 `scripts/create-codex-worktree.sh`로 최신 `origin/main`에서 생성합니다. `scripts/publish-codex-branch.sh`는 publish 직전에 `origin/main`이 feature HEAD의 조상인지 확인하므로 main이 전진한 stale 브랜치는 push하지 않고 재base를 요구합니다.
- PR이 실제로 머지된 뒤에는 [머지 상태를 먼저 확인](https://cli.github.com/manual/gh_pr_view)하고 primary checkout에서 `bash scripts/sync-main-checkout.sh`를 실행합니다. 이 스크립트는 `origin/main`을 fetch한 뒤 변경 없는 `main`에서만 fast-forward하며, feature branch·dirty worktree·local ahead/diverged 상태에서는 pull·reset·checkout을 수행하지 않고 중단합니다. 동기화 후 `git rev-parse HEAD`와 `origin/main`이 같은지 확인합니다.
- 반려 Issue 이벤트는 해당 이슈의 `codex/*` 브랜치만 dispatcher에 전달합니다. Codex는 커밋까지만 수행하고 dispatcher가 publish와 원격 SHA를 검증합니다. push·검증 실패는 workflow 성공으로 숨기지 않고 `needs_human`으로 종료합니다.
- `.github/workflows/autonomous-loop.yml`은 5분 폴링 대신 main 반영, 승인된 제품 Issue, workflow dispatch 이벤트에서 큐 선택·Spec 승격·Codex T1 디스패치를 수행합니다. 리뷰 반려 Issue는 기존 `pr-feedback-detector`가 담당하고 자율 루프가 중복 처리하지 않습니다.
- Codex push 자체는 workflow 트리거가 아니므로 동일 이벤트의 무한 재실행을 만들지 않습니다. PR 생성·머지는 수행하지 않습니다.
- 반려 자동 복구 루프는 PR 생성·갱신 뒤 CI 실패, 리뷰 `REQUEST_CHANGES`, 또는 반려 Issue가 확인되면 최신 로그·리뷰·Issue를 읽고 실패 원인을 재현합니다. CI 실패와 다른 피드백이 함께 있으면 CI를 먼저 수정하고, CI 통과 뒤 다음 이벤트에서 리뷰·Issue 피드백을 처리합니다. 원래 수용 기준과 업무 검증 범위를 보존한 채 같은 브랜치에서 수정하고, 관련 테스트와 전체 회귀 테스트를 실행한 뒤 Conventional Commit으로 커밋·푸시하고 PR 상태를 다시 확인합니다. 테스트를 삭제하거나 assertion을 약화해 통과시키지 않습니다.
- 자동 루프는 동일 PR에서 최대 3회 리뷰 시도까지 반복합니다. 같은 실패가 반복되거나 configured reviewer를 실행할 수 없거나, Codex 결과가 유효하지 않거나, 외부 자격 증명·서비스 복구가 필요하면 `needs-human`으로 기록하고 담당자에게 중단 지점과 필요한 조치를 보고합니다. 일반 구현 PR은 리뷰-머지 실행기가, `automation/spec-*` promotion PR은 자율 루프가 각각 게이트 통과 후 머지합니다. Codex 리뷰어는 읽기 전용이며 보호 규칙을 우회하지 않습니다.
- 문서 없는 API/UI 계약 변경은 하지 않습니다.
- 작업 범위 밖 파일은 스테이징하지 않습니다.
- 할 일이 없으면 수정하지 않고 대기합니다.
- 기획 스레드에서 문맥을 요약해 이어갑니다. 새 세션은 사용자가 요청한 경우에만 생성하며, 별도 작업 스레드를 자동으로 만들지 않습니다.
- 프로젝트 자동화의 실행 정본은 GitHub 이벤트 workflow입니다. 로컬 예약 자동화 이름이나 target thread가 존재한다고 가정하지 않습니다.

## 제품 신호 대기와 실행 오류

- `no_candidate_start_condition_satisfied`는 큐를 정상적으로 확인했지만 제품 판단이 필요한 대기 상태입니다. 구조화 결과는 `needs_human`을 유지하고 Spec 승격·Codex 디스패치·완료 기록을 수행하지 않습니다.
- 이 사유만 coordinator가 종료 코드 0으로 반환합니다. GitHub notice와 step summary에 중단 사유·재개 방법을 남기고 기존 needs-human 알림을 best-effort로 호출합니다. CI 성공은 다음 Feature의 구현 완료를 뜻하지 않습니다.
- 잘못된 큐·runtime 상태, 활성 Feature에 준비 티켓이 없는 상태, 런타임 의존성 누락 등 나머지 `needs_human`은 종료 코드 20으로 계속 실패합니다.
- Windows runner는 `GITHUB_STEP_SUMMARY/p`를 WSL에 전달해 summary 파일 경로를 변환합니다. 승인된 제품 신호 Issue 또는 조건 충족 후 수동 실행으로 큐를 다시 판단합니다.

## 실행 호스트 중단과 재개

Codex 루프는 실행 호스트가 살아 있을 때만 진행됩니다.

- self-hosted runner 호스트가 잠자기 또는 종료 상태이면 Codex 구현과 리뷰 호출이 진행되지 않습니다. GitHub 이벤트와 runner의 가용성을 확인한 뒤 재개합니다.
- 잠자기·종료 자체를 작업 실패로 기록하거나 재시도 횟수로 계산하지 않습니다.
- 호스트가 깨어나거나 다시 시작되면 오케스트레이터가 영속적인 `run-state`를 먼저 읽습니다.
- `run-state`의 `spec_id`, 브랜치, 현재 단계, 마지막 완료 단계와 외부 리소스 상태를 확인한 뒤 중단된 지점에서 재개합니다.
- `run-state`가 없는 작업을 임의로 새로 시작하지 않습니다. 큐와 브랜치·PR 상태를 조정한 뒤 작업을 claim합니다.
- 이미 완료된 spec, 단계, 리뷰 시도는 다시 실행하지 않습니다. 구현·PR·리뷰 호출에는 `run_id + spec_id + stage + attempt` 기반 멱등성 키를 사용합니다.
- 외부 호출 직전과 결과 반영 직후에 상태를 저장합니다. 호출 결과가 불확실하면 재호출 전에 GitHub PR·커밋·CI 상태를 조회합니다.

`run-state`의 최소 필드는 다음과 같습니다.

```yaml
run_id: RUN-...
spec_id: SPEC-...
ticket_id: T1-... | legacy-spec
branch: codex/<spec-slug>-<ticket-id>
phase: claim | implement | test | review | fix | pr | merge | advance
attempt: 0
last_completed_step: ...
status: running | interrupted | blocked | completed
active_backend: codex | claude-fallback
fallback_reason: codex-auth | codex-quota | null
fallback_since: <ISO8601> | null
fallback_approved: true | false
updated_at: ...
lock: ...
```

`run-state`의 구체적인 저장소와 복구 스크립트는 오케스트레이터 구현 spec에서 정합니다. 단, 실행 프로세스의 메모리나 일시적인 작업 디렉터리만을 유일한 상태 저장소로 사용하지 않습니다.

## 필수 테스트 의존성 차단

현재 spec의 `acceptance-criteria.md` 또는 `test-scenarios.md`가 DB·Redis·외부 서비스를 필수로 요구하면, 실행 전에 해당 의존성의 준비 상태를 확인합니다.

- 필수 의존성이 하나라도 없으면 현재 spec 전체를 즉시 중단합니다.
- 이 상태에서는 구현 완료 처리, 테스트 통과 처리, 리뷰, PR 생성·갱신, 다음 spec 진행을 하지 않습니다.
- 일부 의존성 없는 테스트를 실행하더라도 이는 진단 결과일 뿐, 현재 spec의 완료 근거가 아닙니다.
- `run-state`에는 아래 정보를 기록합니다.

```yaml
status: blocked
blocked_reason: dependency_unavailable
required_services:
  - postgresql
resume_phase: test
```

- 의존성 복구 확인과 재시도는 코드 수정·리뷰 재시도 횟수에 포함하지 않습니다.
- Docker daemon이 준비된 경우 승인된 코드 변경의 완료 검증으로 Compose 재빌드·재실행을 수행합니다. Docker Desktop daemon이 중단돼 필수 의존성이 준비되지 않은 경우에는 차단 상태와 복구 방법을 알립니다.
- 의존성이 복구되면 저장된 `resume_phase`부터 테스트를 다시 실행합니다. 복구 전 테스트 결과는 최종 통과 근거로 재사용하지 않습니다.
- 필수 의존성이 복구되지 않으면 자동화 루프는 현재 spec에서 멈추며, 다음 spec으로 넘어가지 않습니다.

## 시작 판단

작업 시작 시 먼저 이 PR의 위험도(`Light` / `Standard` / `High-risk`)를 결정합니다. 분류 기준·예시·필수 검증의 정본은 [pr-rules.md](pr-rules.md)의 "PR 위험도 기준"입니다.

## Technical ADR gate

- active spec이 참조하는 technical ADR이 `proposed`이면 구현을 시작하지 않고 `blocked: adr_pending_approval`로 기록합니다.
- `accepted` ADR만 구현 계약으로 사용할 수 있습니다. 승인된 ADR 본문은 수정하지 않고 superseding ADR로 변경합니다.
- High-risk ADR은 사용자 명시 승인 전까지 자동 루프가 해당 spec을 claim하지 않습니다.
- ADR 승인과 코드 구현은 별도 상태로 관리합니다. ADR이 승인되어도 spec의 테스트·의존성·브랜치 gate를 다시 통과해야 합니다.

## `Light` 흐름

1. 작업 브랜치를 생성합니다.
2. [work-start-checkpoint.md](work-start-checkpoint.md)에 `Light`로 기록합니다.
3. 변경을 구현합니다.
4. 관련 테스트 또는 관련 CI만 확인합니다.
5. 커밋합니다.
6. PR을 생성합니다.
7. 작성자 확인, configured reviewer의 PASS 4점 이상과 필수 게이트를 통과하면 trusted approval job이 자동 병합을 큐에 넣습니다.

## `Standard` 흐름

1. 작업 브랜치를 생성합니다.
2. 체크포인트에 `Standard`로 기록합니다.
3. 관련 문서를 확인하고 구현합니다.
4. 관련 로컬 테스트를 통과시킵니다.
5. 현재 기획 스레드에서 변경 범위와 테스트 결과를 확인합니다.
6. 커밋 후 PR을 생성합니다.
7. configured reviewer의 PASS 4점 이상과 필수 게이트를 통과하면 trusted approval job이 자동 병합을 큐에 넣습니다.

## `High-risk` 흐름

1. 작업 브랜치를 생성합니다.
2. 체크포인트 기준으로 위험도, 범위와 테스트 계획을 먼저 고정합니다.
3. 변경을 구현하고 로컬 테스트를 통과시킵니다.
4. 테스트 통과 후 커밋합니다.
5. `scripts/pr-review-gate.sh <PR_NUMBER>`로 자체 리뷰 게이트를 실행합니다.
6. 자체 리뷰 결과를 `PASS`, `COMMENT`, `REQUEST_CHANGES` 중 하나로 기록합니다.
7. PR 검사 또는 리뷰가 실패하면 GitHub Issue를 생성합니다.
8. Issue를 기준으로 같은 브랜치에서 수정합니다.
9. 다시 테스트하고 자체 리뷰를 반복합니다.
10. PASS 4점 이상과 필수 게이트가 통과하면 trusted approval job이 Squash auto-merge를 큐에 넣습니다. 위험도만으로 사람 승인을 추가하지 않습니다.
11. `main`에 반영되면 GitHub Actions가 최종 워크플로우를 실행합니다.

## 변경 범위별 확인 기준

변경 범위별 확인 기준의 정본은 [pr-review-gate.md](pr-review-gate.md)의 표입니다.

## PR 생성 조건

PR 생성 전 검증 기준의 정본은 [pr-rules.md](pr-rules.md)의 "PR 전 필수 검증 기준"입니다.

PR 생성 전 제목·커밋·본문·기능/운영 범위를 준비하고, PR 생성 후 `bash scripts/pr-contract-test.sh <PR_NUMBER>`로 원격 PR 계약을 검증합니다. High-risk PR은 이 계약 검증 뒤 `scripts/pr-review-gate.sh <PR_NUMBER>`를 실행합니다. reviewer는 구조화 결과를 반환하고, PASS는 별도 approval job에 전달합니다. 반려·중단 결과의 정식 제출은 [리뷰 실행 규칙](review-backend-fallback.md)을 따릅니다.

## PR 실패 처리

PR 실패는 숨기지 않고 Issue로 남깁니다. 실패 Issue의 형식·라벨·기록 항목·수정 절차의 정본은 [pr-rules.md](pr-rules.md)의 "PR 실패 처리"입니다. `High-risk` PR은 Issue 생성 후 같은 브랜치에서 수정하고 다시 테스트 후 커밋합니다.

## 머지 조건

머지 전 필수 조건·금지 조건의 정본은 [merge-rules.md](merge-rules.md)입니다. `High-risk`는 추가로 자체 리뷰 게이트([pr-review-gate.md](pr-review-gate.md))를 통과해야 합니다.

## main 반영 후

`main`에 최종 반영되면 아래 워크플로우가 실행됩니다.

- 문서 하네스 검증
- 백엔드 CI
- 프론트엔드 CI
- 컨테이너 빌드와 `/api/health` 검증
