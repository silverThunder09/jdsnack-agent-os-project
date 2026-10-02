# PR Review Gate

## 목적

PR Review Gate는 PR을 바로 머지하지 않고, 변경 범위와 위험도에 맞는 자체 리뷰 결정을 남기도록 강제하는 절차입니다.

목표는 자동 AI 리뷰 봇을 만드는 것이 아니라 **기획 스레드에서 놓치면 안 되는 검증 기준을 표준화**하는 것입니다.

## 실행 주체

- PR 리뷰어는 `scripts/review-policy.json`의 `primaryReviewer`가 정합니다. 현재 Codex가 바로 실행되며, Claude가 primary일 때 실행 불가 또는 구조화 결과 누락·오류는 Codex read-only reviewer로 넘깁니다.
- 리뷰어는 PR diff와 기준만 읽고 결과를 반환합니다. 구현 파일을 수정하지 않으며, GitHub의 별도 approval job이 현재 head와 필수 check를 다시 확인한 뒤 자동 병합을 큐에 넣습니다.
- 자동 배포 검증은 사용자가 별도 지시한 경우에만 코덱스가 수행합니다.

## 후속 이슈 점검

`리뷰 후속: <branch>` 이슈는 사용자가 확인·닫기를 지시하지 않아도, 관련 PR이 머지될 때마다 클로드가 먼저 해당 이슈의 각 항목이 실제로 해소됐는지 재확인하고 닫습니다. 코드 변경으로 해소되지 않는 미래 리스크 트래킹용 이슈(예: 스키마 제약 부재처럼 지금은 관례로만 안전한 항목)는 닫지 않고 열어 둡니다. 새 PR·새 `codex/*` push도 사용자 지시 전에 먼저 확인합니다.

## 실행 시점

`High-risk` PR 생성 후, 머지 전 반드시 실행합니다.

```sh
bash scripts/pr-contract-test.sh <PR_NUMBER>
./scripts/pr-review-gate.sh <PR_NUMBER>
```

## 리뷰 결정

리뷰 결과는 아래 셋 중 하나만 사용합니다.

- `PASS`: 머지 가능
- `COMMENT`: 머지는 가능하지만 후속 개선 필요
- `REQUEST_CHANGES`: 머지 금지, 실패 Issue 생성 후 수정 필요

`NEEDS_HUMAN`은 자동 루프의 중단 사유입니다. 자동 병합 후보는 안전하고 완결된 리뷰에서 `PASS`와 4점 이상을 받아야 합니다. 위험도는 라벨만 정하며 위험도 구간별 사람 승인 조건은 없습니다. GitHub branch protection에 실제 설정된 승인 수가 있으면 그대로 존중합니다. 점수 미달·모호한 결과·서비스 장애는 자동 병합하지 않습니다.

`REQUEST_CHANGES`가 하나라도 있으면 PR은 머지할 수 없습니다.

리뷰 workflow는 저장소 소유자와 일치하는 runner의 사전 인증 `gh` 계정을 사용합니다. 기본 브랜치 보호 규칙은 `review`·`PR CI Gate`·`Validate PR contract`와 모든 설정된 필수 check를 요구합니다. approval job은 branch protection의 실제 승인 수만 추가로 적용하며, 현재 저장소 정책상 위험도별 사람 승인 수는 0입니다. `REQUEST_CHANGES`는 한 번 제출하며, `NEEDS_HUMAN`은 항상 중단합니다.

## 변경 범위별 확인 기준

| 변경 범위 | 기본 확인 |
|---|---|
| `.agent-os/specs/**`, API/UI 계약 | active spec, `REQ/AC/TC`, traceability |
| `backend/**` | 백엔드 테스트, API 계약, 에러 처리 |
| `frontend/**` | 프론트 테스트, UI 상태, 사용자 복구 흐름 |
| `.github/**`, CI/CD, Docker | workflow, script, 운영 문서 |
| 외부 API, 비밀값, 로그 정책 | secret 노출, 로그 정책, 실패 처리 |
| PR/머지/릴리즈 판단 | PR 규칙, 머지 규칙, release checklist |

## 위험도 기준

- `Light`: 0~30점, 위험도 라벨입니다.
- `Standard`: 31~60점, 위험도 라벨입니다.
- `High-risk`: 61~100점, 위험도 라벨입니다. 위험 구간만으로 추가 승인을 요구하지 않습니다.
- `dryRun=false`; PASS 4점 이상과 현재 head의 모든 필수 게이트가 통과하면 Squash auto-merge를 큐에 넣습니다.

점수 항목과 경로 조건은 [review-routing.md](review-routing.md)와 `scripts/review-policy.json`에 고정합니다. `Security` 30점, `API/DB/환경변수` 20점, `PR 크기·범위` 15점, `테스트 공백` 15점, `마이그레이션` 20점으로 총 100점입니다.

## 리뷰 절차

1. PR 변경 파일을 확인합니다.
2. 필요한 확인 범위를 결정합니다.
3. PR 본문의 필수 섹션을 확인합니다.
4. CI 상태를 확인합니다.
5. `PASS`면 요약·점수·위험도·head SHA를 PR 코멘트로 공개하고 전문 라벨을 붙입니다.
6. approval job이 최신 base/head SHA, 현재 `review` check, PR 계약·CI Gate·branch-required check, branch protection이 실제 요구하는 승인만 재확인한 뒤 Squash auto-merge를 큐에 넣습니다.
7. `REQUEST_CHANGES`면 GitHub PR에 request changes를 남기고 실패 Issue를 생성합니다.

대표 명령:

```sh
gh pr review <PR_NUMBER> --request-changes --body-file <review-report.md>
gh pr review <PR_NUMBER> --comment --body-file <review-report.md>
```

## 스크립트 책임

`scripts/pr-review-gate.sh`는 아래를 수행합니다.

- PR 변경 파일 조회
- PR 제목·커밋 summary·본문·기능/운영 범위·API/UI 계약 문서 동반 여부 결정론 검증
- 필수 확인 범위 출력
- PR 본문 필수 섹션 누락 확인
- PR 범위 위반 후보 탐지
- CI 상태 요약

스크립트는 의미 기반 코드 리뷰를 대신하지 않습니다. 의미 기반 판단은 현재 기획 스레드에서 수행합니다.

## 범위 위반 후보

아래 조합은 `pr-contract-test.sh`가 기본적으로 실패 처리합니다.

- 기능 코드와 `.github/**` 변경이 같은 PR에 있음
- 기능 코드와 운영 문서 변경이 같은 PR에 있음
- `backend/**`와 `frontend/**`가 같은 PR에 있음
- `backend/**`의 Controller/API 구현 변경에 `api-spec.md`가 없음
- `frontend/src/components/**`, `hooks/**`, `pages/**`, `routes/**`, `services/**` 변경에 `ui-spec.md` 또는 `test-scenarios.md`가 없음

위 조합은 `pr-contract-test.sh`가 결정론적으로 실패 처리합니다. 같은 기능의 backend/frontend를 묶거나 하네스 최소 수정을 포함하는 허용 예외는 PR 본문에 `예외 적용 여부: 있음`과 구체적인 `같은 PR에 포함한 이유:`를 함께 적은 경우에만 경고로 남깁니다.

CI/운영/자동화와 기능 코드를 섞는 경우에는 PR 본문의 명시된 예외 사유가 없으면 자동 반려합니다.

## 머지 조건

머지 전 게이트 고유 조건은 아래 셋입니다. 그 외 공통 머지 조건(CI·실패 Issue 등)의 정본은 [merge-rules.md](merge-rules.md)입니다.

- `scripts/pr-review-gate.sh <PR_NUMBER>` 실행 완료
- 자체 리뷰 결과 `PASS` 또는 허용 가능한 `COMMENT`
- `REQUEST_CHANGES` 없음
