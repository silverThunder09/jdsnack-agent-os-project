# PR 자동 운영 루프

## 목적

JDSnack의 변경은 직접 `main`에 푸시하지 않습니다.  
모든 변경은 **작업 브랜치 -> 커밋 -> 담당 에이전트 검사 -> PR -> 실패 이슈화 -> 수정 루프 -> main 머지** 순서로 처리합니다.

## 기본 흐름

1. 작업 브랜치를 생성합니다.
   - 기본 형식: `codex/<scope>-<short-description>`
2. 변경을 구현하고 커밋합니다.
3. 변경 범위에 맞는 담당 에이전트가 검사합니다.
4. 담당 에이전트가 `PASS`를 주면 PR을 생성합니다.
5. PR 본문은 `.github/pull_request_template.md`와 `pr-rules.md`를 따릅니다.
6. PR 검사 또는 리뷰가 실패하면 GitHub Issue를 생성합니다.
7. Issue를 기준으로 같은 브랜치에서 수정합니다.
8. 다시 테스트하고 담당 에이전트 검사를 받습니다.
9. PR이 통과하면 `Squash and merge`로 `main`에 합칩니다.
10. `main`에 반영되면 GitHub Actions가 최종 워크플로우를 실행합니다.

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
- 관련 문서와 테스트가 갱신되어야 합니다.
- 담당 에이전트가 `PASS`를 줘야 합니다.
- 로컬에서 가능한 검증을 통과해야 합니다.
- PR 본문에 `REQ`, `AC`, `TC`, 변경 문서, 검증 결과가 연결되어야 합니다.

## PR 실패 처리

PR 실패는 숨기지 않고 Issue로 남깁니다.

Issue에는 아래 내용을 기록합니다.

- 실패한 PR 링크
- 실패한 체크 이름
- 실패 로그 핵심
- 관련 `REQ`, `AC`, `TC`
- 담당 에이전트
- 수정 계획

Issue 생성 후에는 같은 브랜치에서 수정하고 다시 커밋합니다.

## 머지 조건

- GitHub Actions 통과
- 담당 에이전트 최종 `PASS`
- PR 리뷰 승인
- 머지 금지 조건 없음
- `release-checklist.md` 또는 `cd-checklist.md`에 걸리는 배포 영향 확인

## main 반영 후

`main`에 최종 반영되면 아래 워크플로우가 실행됩니다.

- 문서 하네스 검증
- 백엔드 CI
- 컨테이너 빌드 검증

배포 자동화는 컨테이너 빌드가 안정화된 뒤 별도 워크플로우로 승격합니다.

