# PR 자동 운영 루프

## 목적

JDSnack의 변경은 직접 `main`에 푸시하지 않습니다.
모든 변경은 **작업 브랜치 -> 커밋 -> 담당 에이전트 검사 -> PR -> 실패 이슈화 -> 수정 루프 -> main 머지** 순서로 처리합니다.

## 기본 흐름

1. 작업 브랜치를 생성합니다.
   - 기본 형식: `codex/<scope>-<short-description>`
2. [work-start-checkpoint.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/work-start-checkpoint.md) 기준으로 범위와 테스트 계획을 먼저 고정합니다.
3. 변경을 구현하고 로컬 테스트를 통과시킵니다.
4. 테스트 통과 후 커밋합니다.
5. 변경 범위에 맞는 담당 에이전트가 검사합니다.
6. 담당 에이전트가 `PASS`를 주면 PR을 생성합니다.
7. PR 본문은 `.github/pull_request_template.md`와 `pr-rules.md`를 따릅니다.
8. `scripts/pr-review-gate.sh <PR_NUMBER>`로 자체 리뷰 게이트를 실행합니다.
9. 담당 에이전트가 `PASS`, `COMMENT`, `REQUEST_CHANGES` 중 하나로 리뷰합니다.
10. PR 검사 또는 리뷰가 실패하면 GitHub Issue를 생성합니다.
11. Issue를 기준으로 같은 브랜치에서 수정합니다.
12. 다시 테스트하고 담당 에이전트 검사를 받습니다.
13. PR이 통과하면 `Squash and merge`로 `main`에 합칩니다.
14. `main`에 반영되면 GitHub Actions가 최종 워크플로우를 실행합니다.

## 담당 에이전트 매핑

| 변경 범위 | 필수 검사 에이전트 |
|---|---|
| 요구사항, API/UI 계약 | `Spec Steward`, `QA Reviewer` |
| `backend/**` | `Backend Engineer`, `QA Reviewer` |
| `frontend/**` | `Frontend Engineer`, `QA Reviewer` |
| `.github/**`, CI/CD, Docker | `DevOps Steward`, `Release Captain` |
| 외부 AI, 비밀값, 로그 정책 | `Security Reviewer`, `QA Reviewer` |

## PR 생성 조건

- 커밋이 존재해야 합니다.
- PR의 주 목적이 한 문장으로 설명되어야 합니다.
- 변경 파일이 `pr-rules.md`의 `PR 범위 경계`를 통과해야 합니다.
- CI, 운영, 템플릿, 광범위 문서 정리는 기능 PR과 분리해야 합니다.
- 관련 문서와 테스트가 갱신되어야 합니다.
- 담당 에이전트가 `PASS`를 줘야 합니다.
- 로컬에서 가능한 검증을 통과해야 합니다.
- PR 본문에 `REQ`, `AC`, `TC`, 변경 문서, 검증 결과가 연결되어야 합니다.

## 자체 리뷰 게이트

PR 생성 후에는 [pr-review-gate.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/pr-review-gate.md)를 따릅니다.

```sh
./scripts/pr-review-gate.sh <PR_NUMBER>
```

자체 리뷰 결과:

- `PASS`: 머지 가능
- `COMMENT`: 머지는 가능하지만 후속 개선 필요
- `REQUEST_CHANGES`: 머지 금지, 실패 Issue 생성 후 수정 필요

## PR 실패 처리

PR 실패는 숨기지 않고 Issue로 남깁니다.

Issue에는 아래 내용을 기록합니다.

- 실패 유형
- 실패한 PR 링크
- 실패한 체크 이름
- 실패 로그 핵심
- 관련 `REQ`, `AC`, `TC`
- 담당 에이전트
- 수정 계획

Issue 생성 후에는 같은 브랜치에서 수정하고 다시 테스트 후 커밋합니다.

## 머지 조건

- GitHub Actions 통과
- 담당 에이전트 최종 `PASS`
- 자체 리뷰 게이트 통과
- PR 범위 경계 통과
- PR 리뷰 승인
- 머지 금지 조건 없음
- `release-checklist.md` 또는 `cd-checklist.md`에 걸리는 배포 영향 확인

## main 반영 후

`main`에 최종 반영되면 아래 워크플로우가 실행됩니다.

- 문서 하네스 검증
- 백엔드 CI
- 컨테이너 빌드와 `/api/health` 검증

배포 자동화는 컨테이너 빌드가 안정화된 뒤 별도 워크플로우로 승격합니다.
