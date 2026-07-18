# PR Review Gate

## 목적

PR Review Gate는 PR을 바로 머지하지 않고, 변경 범위와 위험도에 맞는 자체 리뷰 결정을 남기도록 강제하는 절차입니다.

목표는 자동 AI 리뷰 봇을 만드는 것이 아니라 **기획 스레드에서 놓치면 안 되는 검증 기준을 표준화**하는 것입니다.

## 실행 주체

- PR Review Gate 실행, 리뷰 결정, approve, request changes, 실패 Issue 판단은 클로드가 담당합니다.
- 코덱스는 리뷰 판단을 대신하지 않고, 클로드가 남긴 리뷰 결과를 기준으로 코드 수정과 테스트만 수행합니다.
- 자동 배포 검증은 사용자가 별도 지시한 경우에만 코덱스가 수행합니다.

## 실행 시점

`High-risk` PR 생성 후, 머지 전 반드시 실행합니다.

```sh
./scripts/pr-review-gate.sh <PR_NUMBER>
```

## 리뷰 결정

리뷰 결과는 아래 셋 중 하나만 사용합니다.

- `PASS`: 머지 가능
- `COMMENT`: 머지는 가능하지만 후속 개선 필요
- `REQUEST_CHANGES`: 머지 금지, 실패 Issue 생성 후 수정 필요

`REQUEST_CHANGES`가 하나라도 있으면 PR은 머지할 수 없습니다.

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

- `Light`: 기본적으로 Review Gate 대상이 아닙니다.
- `Standard`: 필요 시 실행할 수 있지만 기본 강제 대상은 아닙니다.
- `High-risk`: 반드시 실행합니다.

## 리뷰 절차

1. PR 변경 파일을 확인합니다.
2. 필요한 확인 범위를 결정합니다.
3. PR 본문의 필수 섹션을 확인합니다.
4. CI 상태를 확인합니다.
5. PR 본문 또는 코멘트에 리뷰 결과를 작성합니다.
6. `PASS`면 GitHub PR에 approve를 남깁니다.
7. `REQUEST_CHANGES`면 GitHub PR에 request changes를 남기고 실패 Issue를 생성합니다.

대표 명령:

```sh
gh pr review <PR_NUMBER> --approve --body-file <review-report.md>
gh pr review <PR_NUMBER> --request-changes --body-file <review-report.md>
gh pr review <PR_NUMBER> --comment --body-file <review-report.md>
```

## 스크립트 책임

`scripts/pr-review-gate.sh`는 아래를 수행합니다.

- PR 변경 파일 조회
- 필수 확인 범위 출력
- PR 본문 필수 섹션 누락 확인
- PR 범위 위반 후보 탐지
- CI 상태 요약

스크립트는 의미 기반 코드 리뷰를 대신하지 않습니다. 의미 기반 판단은 현재 기획 스레드에서 수행합니다.

## 범위 위반 후보

아래 조합은 스크립트가 경고합니다.

- 기능 코드와 `.github/**` 변경이 같은 PR에 있음
- 기능 코드와 운영 문서 변경이 같은 PR에 있음
- `backend/**`와 `frontend/**`가 같은 PR에 있음
- API/UI 계약 문서 변경 없이 구현 계약이 바뀐 것으로 보임

경고는 자동 반려가 아닙니다. 단, 예외 적용 시 PR 본문 `범위 판단`에 이유를 남겨야 합니다.

## 머지 조건

머지 전 게이트 고유 조건은 아래 셋입니다. 그 외 공통 머지 조건(CI·실패 Issue 등)의 정본은 [merge-rules.md](merge-rules.md)입니다.

- `scripts/pr-review-gate.sh <PR_NUMBER>` 실행 완료
- 자체 리뷰 결과 `PASS` 또는 허용 가능한 `COMMENT`
- `REQUEST_CHANGES` 없음
