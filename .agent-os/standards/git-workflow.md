# Git 작업 흐름 표준

## 목적

Git 기록을 “작업 일기”가 아니라 **요구사항, 문서, 테스트, 구현이 연결된 변경 기록**으로 남깁니다.

## 브랜치 규칙

브랜치 이름은 아래 형식을 따릅니다.

```text
<type>/<scope>-<short-description>
```

허용 타입:

| 타입 | 용도 | 예시 |
|---|---|---|
| `feat` | 새 기능 | `feat/resume-diagnosis-api` |
| `fix` | 버그 수정 | `fix/gemini-timeout-error` |
| `docs` | 문서 변경 | `docs/codex-harness-rules` |
| `test` | 테스트 추가/수정 | `test/diagnose-validation` |
| `refactor` | 동작 변경 없는 구조 개선 | `refactor/api-response-wrapper` |
| `chore` | 설정/빌드/운영 보조 작업 | `chore/git-hooks` |

## 커밋 메시지 규칙

커밋 메시지는 Conventional Commits를 기본으로 사용합니다.

```text
<type>(<scope>): <summary>
```

예시:

```text
docs(harness): Git 운영 규칙 추가
feat(api): 이력서 진단 엔드포인트 추가
test(api): 입력값 검증 테스트 추가
fix(gemini): 응답 파싱 실패 처리
```

## 커밋 타입

| 타입 | 의미 |
|---|---|
| `feat` | 사용자 관점 기능 추가 |
| `fix` | 버그 수정 |
| `docs` | 문서만 변경 |
| `test` | 테스트 추가/수정 |
| `refactor` | 기능 변화 없는 코드 구조 개선 |
| `style` | 포맷팅, 세미콜론 등 동작 없는 변경 |
| `chore` | 빌드, 설정, 의존성, 잡무 |
| `ci` | CI 설정 변경 |
| `perf` | 성능 개선 |

## 커밋 본문 필수 조건

다음 변경은 커밋 본문에 문서 연결을 남깁니다.

```text
Refs: REQ-01, AC-01, TC-01
Docs: specs/2026-05-21-0943-ai-resume-diagnoser/api-spec.md
```

필수 대상:

- API 변경
- UI 흐름 변경
- 요구사항 변경
- 테스트 기준 변경
- 아키텍처 경계 변경

## 커밋 분리 기준

- 문서만 바뀌면 `docs` 커밋으로 분리합니다.
- 기능 구현과 테스트는 같은 PR에 둘 수 있지만, 커밋은 분리해도 됩니다.
- 리팩토링과 기능 변경은 같은 커밋에 섞지 않습니다.
- 포맷팅만 바뀐 변경은 별도 커밋으로 둡니다.

## 금지

- `wip`, `temp`, `fix stuff`, `update` 같은 의미 없는 커밋 메시지
- 문서 계약 변경 없는 API 변경
- 테스트 시나리오 없는 수용 기준 변경
- 여러 기능을 한 PR에 섞는 변경
