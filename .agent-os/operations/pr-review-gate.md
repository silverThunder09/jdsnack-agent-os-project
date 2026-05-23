# PR Review Gate

## 목적

PR Review Gate는 PR을 바로 머지하지 않고, 변경 범위에 맞는 서브 에이전트가 리뷰 결정을 남기도록 강제하는 절차입니다.

목표는 자동 AI 리뷰 봇을 만드는 것이 아니라 **Codex/서브 에이전트가 놓치면 안 되는 검증 기준을 표준화**하는 것입니다.

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

## 담당 에이전트 매핑

| 변경 범위 | 필수 리뷰 에이전트 |
|---|---|
| `.agent-os/specs/**`, API/UI 계약 | `Spec Steward`, `QA Reviewer` |
| `backend/**` | `Backend Engineer`, `QA Reviewer` |
| `frontend/**` | `Frontend Engineer`, `QA Reviewer` |
| `.github/**`, CI/CD, Docker | `DevOps Steward`, `Release Captain` |
| 외부 API, 비밀값, 로그 정책 | `Security Reviewer`, `QA Reviewer` |

여러 범위가 섞이면 필수 리뷰 에이전트도 합쳐집니다.

## 위험도 기준

- `Light`: 기본적으로 Review Gate 대상이 아닙니다.
- `Standard`: 필요 시 실행할 수 있지만 기본 강제 대상은 아닙니다.
- `High-risk`: 반드시 실행합니다.

## 리뷰 절차

1. PR 변경 파일을 확인합니다.
2. 필수 리뷰 에이전트를 결정합니다.
3. PR 본문의 필수 섹션을 확인합니다.
4. CI 상태를 확인합니다.
5. [agent-review-report-template.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/agent-review-report-template.md) 형식으로 리뷰 결과를 작성합니다.
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
- 필수 리뷰 에이전트 목록 출력
- PR 본문 필수 섹션 누락 확인
- PR 범위 위반 후보 탐지
- CI 상태 요약
- 리뷰 리포트 템플릿 출력

스크립트는 의미 기반 코드 리뷰를 대신하지 않습니다. 의미 기반 판단은 담당 에이전트가 수행합니다.

## 범위 위반 후보

아래 조합은 스크립트가 경고합니다.

- 기능 코드와 `.github/**` 변경이 같은 PR에 있음
- 기능 코드와 운영 문서 변경이 같은 PR에 있음
- `backend/**`와 `frontend/**`가 같은 PR에 있음
- API/UI 계약 문서 변경 없이 구현 계약이 바뀐 것으로 보임

경고는 자동 반려가 아닙니다. 단, 예외 적용 시 PR 본문 `범위 판단`에 이유를 남겨야 합니다.

## 머지 조건

머지 전 아래 조건을 모두 만족해야 합니다.

- `scripts/pr-review-gate.sh <PR_NUMBER>` 실행 완료
- 필수 리뷰 에이전트의 `PASS` 또는 허용 가능한 `COMMENT`
- `REQUEST_CHANGES` 없음
- PR 실패 Issue가 있다면 해결 또는 후속 Issue 연결 완료
- GitHub Actions 통과
- [merge-rules.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/merge-rules.md)의 머지 조건 통과
