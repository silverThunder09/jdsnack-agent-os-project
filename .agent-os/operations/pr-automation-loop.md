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

- Codex 담당: 구현, 테스트, 커밋, origin push.
- Claude 담당: 문서 계획, 리뷰, PR, merge.
- 모델 정책은 [Worker 모델 배정](worker-backends.md)과 루트 [backends.json](../../backends.json)을 따릅니다. 빌드·lint·test·E2E 명령 실행 자체에는 모델을 지정하지 않습니다. 리뷰·판정은 Codex가 아니라 Claude `code-reviewer`가 담당합니다.
- 구현 대상은 `index.yml`의 `active_specs`(정확히 1개) 안에서 준비된 티켓 하나입니다. `plan.md`가 없는 레거시 active Spec은 Spec 전체를 한 작업으로 취급합니다.
- 티켓 브랜치는 `codex/<active-spec-slug>-<ticket-id>`로 만들고, 티켓별 구현·테스트·PR·리뷰·머지를 독립적으로 수행합니다.
- **티켓 전진(원자적)**: 티켓 PR에는 코드뿐 아니라 `plan.md`의 티켓 상태와 관련 traceability·테스트 결과 갱신을 포함합니다. 머지 후 active Spec은 유지한 채 다음 준비 티켓을 claim합니다.
- **Feature 완료**: 마지막 티켓과 전체 수용 기준이 통과한 PR을 main에 반영하면 `autonomous-loop.yml`이 완료 Spec을 archive하고 `active_specs`를 비운 뒤 `spec-queue.json`의 첫 eligible 후보를 자동 승격합니다. 자동 판정 가능한 후보가 없을 때만 `needs-human`으로 중단합니다.
- **Spec 순환**: 자동 승격된 후보는 문서 필수 세트와 traceability를 생성·검증한 뒤 Spec promotion PR을 만들고, 통과하면 T1을 Codex에 디스패치합니다. 한 시점에 active Spec은 하나만 유지합니다.
- 변경요청(`리뷰 반려: <branch>` 또는 `리뷰 후속: <branch>` 이슈)이 있으면 같은 `codex/*` 브랜치에서 반영합니다.
- **클로드 리뷰-머지 루프도 GitHub 이벤트로 기동합니다.** [`.github/workflows/codex-branch-review.yml`](../../.github/workflows/codex-branch-review.yml)이 `codex/**` 브랜치 push마다 로컬 `jdsnack` self-hosted runner에서 클로드 리뷰-머지 절차(`jdsnack-review-merge-loop` SKILL.md)를 즉시 1회 기동합니다. 기존 5분 폴링 감지기(`~/.claude/scripts/jdsnack-codex-watch.sh`)는 push 이벤트가 유실될 때를 대비한 백업 용도로만 유지하며, 정상 상황에서는 이 workflow가 먼저 처리합니다.
- 반려 감지는 [pr-feedback-detector.sh](../../scripts/pr-feedback-detector.sh)가 GitHub 이벤트로 깨워진 workflow에서 한 번 실행될 때 수행합니다. 감지기는 polling loop를 내장하지 않으며 `no_action`, `actionable`, `needs_human` JSON과 종료 코드를 내보냅니다.
- `.github/workflows/pr-feedback-detector.yml`은 반려 Issue 생성·수정, Issue/PR 댓글, PR 리뷰, required CI 완료 이벤트에만 실행됩니다. 로컬 `jdsnack` self-hosted runner가 안전한 후보를 격리 worktree에 전달해 Codex의 수정·테스트·커밋·푸시를 수행합니다.
- Codex worktree는 `scripts/create-codex-worktree.sh`로 최신 `origin/main`에서 생성합니다. `scripts/publish-codex-branch.sh`는 publish 직전에 `origin/main`이 feature HEAD의 조상인지 확인하므로 main이 전진한 stale 브랜치는 push하지 않고 재base를 요구합니다.
- 반려 Issue 이벤트는 해당 이슈의 `codex/*` 브랜치만 dispatcher에 전달합니다. Codex는 커밋까지만 수행하고 dispatcher가 publish와 원격 SHA를 검증합니다. push·검증 실패는 workflow 성공으로 숨기지 않고 `needs_human`으로 종료합니다.
- `.github/workflows/autonomous-loop.yml`은 5분 폴링 대신 main 반영, 승인된 제품 Issue, workflow dispatch 이벤트에서 큐 선택·Spec 승격·Codex T1 디스패치를 수행합니다. 리뷰 반려 Issue는 기존 `pr-feedback-detector`가 담당하고 자율 루프가 중복 처리하지 않습니다.
- Codex push 자체는 workflow 트리거가 아니므로 동일 이벤트의 무한 재실행을 만들지 않습니다. PR 생성·머지는 수행하지 않습니다.
- 반려 자동 복구 루프는 PR 생성·갱신 뒤 CI 실패, 리뷰 `REQUEST_CHANGES`, 또는 반려 Issue가 확인되면 최신 로그·리뷰·Issue를 읽고 실패 원인을 재현합니다. 원래 수용 기준과 업무 검증 범위를 보존한 채 같은 브랜치에서 수정하고, 관련 테스트와 전체 회귀 테스트를 실행한 뒤 Conventional Commit으로 커밋·푸시하고 PR 상태를 다시 확인합니다. 테스트를 삭제하거나 assertion을 약화해 통과시키지 않습니다.
- 자동 루프는 동일 PR에서 최대 3회 리뷰 시도까지 반복합니다. 같은 실패가 반복되거나 외부 승인·비밀값·서비스 복구가 필요하면 `needs-human`으로 기록하고 담당자에게 중단 지점과 필요한 조치를 보고합니다. 일반 구현 PR은 리뷰-머지 실행기가, `automation/spec-*` promotion PR은 자율 루프가 각각 게이트 통과 후 머지합니다. 코덱스는 직접 머지하지 않습니다.
- 문서 없는 API/UI 계약 변경은 하지 않습니다.
- 작업 범위 밖 파일은 스테이징하지 않습니다.
- 할 일이 없으면 수정하지 않고 대기합니다.
- 컨텍스트가 70% 이상이면 `fork_thread`가 아니라 `create_thread`로 새 세션을 만들고 요약만 전달합니다.
- 새 세션을 만들면 `jdsnack-5` 자동화 target도 새 세션으로 옮깁니다.

## 실행 호스트 중단과 재개

Codex 루프는 실행 호스트가 살아 있을 때만 진행됩니다.

- Mac이 잠자기 또는 종료 상태이면 Codex 구현, `cron`·`launchd` 감지, Claude 리뷰 호출을 중단합니다.
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
- 로컬에서는 Docker Desktop 또는 Compose를 사용자 동의 없이 자동으로 시작하지 않습니다.
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
7. 작성자 확인과 CI 통과 후 머지합니다.

## `Standard` 흐름

1. 작업 브랜치를 생성합니다.
2. 체크포인트에 `Standard`로 기록합니다.
3. 관련 문서를 확인하고 구현합니다.
4. 관련 로컬 테스트를 통과시킵니다.
5. 현재 기획 스레드에서 변경 범위와 테스트 결과를 확인합니다.
6. 커밋 후 PR을 생성합니다.
7. 관련 CI가 통과하면 머지합니다.

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
10. PR이 통과하면 `Squash and merge`로 `main`에 합칩니다.
11. `main`에 반영되면 GitHub Actions가 최종 워크플로우를 실행합니다.

## 변경 범위별 확인 기준

변경 범위별 확인 기준의 정본은 [pr-review-gate.md](pr-review-gate.md)의 표입니다.

## PR 생성 조건

PR 생성 전 검증 기준의 정본은 [pr-rules.md](pr-rules.md)의 "PR 전 필수 검증 기준"입니다.

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
