# Worker 모델 배정

## 목적

Worker의 역할·권한·작업 경계와 모델 배정을 분리합니다.

- 역할과 작업 경계의 정본은 `AGENTS.md`, `CLAUDE.md`, 이 문서입니다.
- provider, 모델명, 역할별 선택 근거의 정본은 루트 [backends.json](../../backends.json)입니다.

모델 교체는 `backends.json`의 해당 역할 한 곳만 수정합니다. 역할 문서에 모델명을 다시 적지 않습니다.

## 역할

| Worker 역할 | 책임 | 배정 키 |
|---|---|---|
| Codex 구현 | 기능 구현, 관련 테스트, 커밋, push | `workers.codex.implementation` |
| Codex 테스트 | 테스트 코드 작성, 실패 결과 분석 | `workers.codex.test-authoring-and-analysis` |
| Claude 문서 계획 | spec·계약·운영 문서 설계 | `workers.claude.documentation-planning` |
| Claude 리뷰 | 독립 리뷰, 변경 범위·품질 판정 | `workers.claude.review` |

## 변경 규칙

- 배정에는 `provider`, `model`, `reason`을 모두 둡니다.
- 모델명 변경은 `backends.json`만 수정하고, 역할·권한 변경은 이 문서와 `AGENTS.md` 또는 `CLAUDE.md`를 함께 수정합니다.
- 빌드·lint·test·E2E 명령 실행 자체에는 모델 배정을 적용하지 않습니다.
