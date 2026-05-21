# CI 체크리스트

## 목적

아직 백엔드와 프론트엔드 코드가 완성되지 않았더라도, CI가 무엇을 검증해야 하는지 먼저 문서 계약으로 고정합니다.

1차 MVP의 CI 목표는 **문서 계약, 입력 검증, 빌드 가능성**을 자동으로 확인하는 것입니다.

## 현재 단계

- 상태: 문서형 CI/CD v0
- 실제 GitHub Actions 워크플로우는 `backend/`, `frontend/` 프로젝트 생성 후 추가합니다.
- 이 문서는 이후 `.github/workflows/**`로 승격할 기준 문서입니다.

## 권장 트리거

- PR 생성 또는 갱신
- `main` 브랜치 push
- 수동 실행

## 필수 Job 설계

### 1. 문서 하네스 검증

검증 대상:

- `requirements.md`에 `REQ` 존재
- `acceptance-criteria.md`에 `AC` 존재
- `test-scenarios.md`에 `TC` 존재
- `traceability.md`에 `REQ -> AC -> TC` 매핑 존재
- `standards/index.yml`의 경로가 실제 파일과 일치
- 1차 MVP 문서에 구버전 인증 키 입력 흐름이 남아 있지 않음

대표 검증 방식:

```sh
rg -n "<구버전 인증 키 저장명>|<서버 비밀값 환경변수명>|<구버전 AI 서비스 클래스명>|<구버전 테스트 파일명>" AGENTS.md README.md .agent-os docs backend frontend
```

실제 워크플로우 작성 시 괄호 안의 금지 키워드를 구체화하고, 검색 결과가 없어야 통과합니다.

### 2. 백엔드 CI

도입 시점:

- `backend/`에 Spring Boot 프로젝트가 생성된 뒤

검증 대상:

- 컴파일
- 단위 테스트
- `GET /api/health`
- `POST /api/diagnose` 입력 검증
- 정상 입력 시 `501 AI_ANALYSIS_NOT_ENABLED`

대표 명령 후보:

```sh
cd backend
./gradlew test
./gradlew bootJar
```

### 3. 프론트엔드 CI

도입 시점:

- `frontend/`에 React + Vite 프로젝트가 생성된 뒤

검증 대상:

- 타입 체크
- 린트
- 테스트
- 프로덕션 빌드
- API 호출이 `services` 계층을 통하는지 리뷰

대표 명령 후보:

```sh
cd frontend
npm ci
npm run lint
npm run test
npm run build
```

### 4. 통합 스모크 테스트

도입 시점:

- 백엔드와 프론트엔드가 연결된 뒤

검증 대상:

- `/api/health` 정상 응답
- 빈 입력 요청 시 `EMPTY_RESUME`
- 50자 미만 요청 시 `TEXT_TOO_SHORT`
- 10,000자 초과 요청 시 `TEXT_TOO_LONG`
- 정상 길이 요청 시 `AI_ANALYSIS_NOT_ENABLED`

## PR 필수 기준

- 문서만 변경한 PR은 문서 하네스 검증을 통과해야 합니다.
- 백엔드 변경 PR은 백엔드 CI 기준을 통과해야 합니다.
- 프론트엔드 변경 PR은 프론트엔드 CI 기준을 통과해야 합니다.
- API/UI 계약 변경 PR은 관련 spec 문서와 테스트 시나리오가 함께 갱신되어야 합니다.

## 실패 처리

- CI 실패는 코드 버그와 같은 급으로 봅니다.
- 실패를 우회해야 하면 PR 본문에 이유와 후속 조치를 남깁니다.
- 같은 실패가 2회 이상 반복되면 `standards/` 또는 Git 훅 규칙으로 승격합니다.
