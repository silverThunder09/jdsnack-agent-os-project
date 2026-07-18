# CI 체크리스트

## 목적

아직 백엔드와 프론트엔드 코드가 완성되지 않았더라도, CI가 무엇을 검증해야 하는지 먼저 문서 계약으로 고정합니다.

현재 CI 목표는 **문서 계약, 1.5차 MVP fixture 흐름, 빌드 가능성**을 자동으로 확인하는 것입니다.

## 현재 단계

- 상태: 문서 하네스 CI v1
- `.github/workflows/docs-harness.yml`에서 문서 계약을 먼저 자동 검증합니다.
- `.github/workflows/backend-ci.yml`에서 백엔드 테스트와 `bootJar` 빌드를 검증합니다.
- `.github/workflows/frontend-ci.yml`에서 프론트엔드 린트, 테스트, 빌드를 검증합니다.
- `.github/workflows/container.yml`에서 compose 기반 스모크 테스트를 함께 검증합니다.
- compose 기반 통합 검증은 `fixture` 모드 기준으로 텍스트/PDF/DOCX 흐름을 확인합니다.
- 보호 브랜치 required check와 충돌하지 않도록 백엔드/프론트 CI는 경로 필터 없이 항상 실행합니다.

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
- 모든 `REQ`, `AC`, `TC`가 `traceability.md`에 빠짐없이 연결
- 각 traceability 행에 계약/설계 문서 경로 포함
- `standards/index.yml`의 경로가 실제 파일과 일치
- 1차 MVP 문서에 구버전 인증 키 입력 흐름이 남아 있지 않음

현재 워크플로우:

- `.github/workflows/docs-harness.yml`
- `.github/workflows/backend-ci.yml`
- PR 운영 스크립트 변경 시 `scripts/pr-feedback-detector-test.sh`로 반려·CI 오류·선택적 체크 필터·환경 실패 경계를 검증합니다.

### 2. 백엔드 CI

도입 시점:

- `backend/`에 Spring Boot 프로젝트가 생성된 뒤

검증 대상:

- 컴파일
- 단위 테스트
- `GET /api/health`
- `POST /api/diagnose` 입력 검증
- `stub` 모드 정상 입력 시 `501 AI_ANALYSIS_NOT_ENABLED`
- `fixture` 모드 정상 입력 시 fixture 결과
- 정확히 50자와 정확히 10,000자 경계값 검증
- `resumeText` 누락, `null`, 공백 문자만 있는 입력 검증
- `POST /api/diagnose/file` 업로드 검증과 fixture 오류 코드 검증

대표 명령 후보:

```sh
cd backend
gradle test
gradle bootJar
```

### 3. 프론트엔드 CI

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
- 현재는 1.5차 MVP fixture 기준 시나리오를 적용한다.

검증 대상:

- 프론트 루트 페이지 응답
- `/api/health` 정상 응답
- `/api/health` 응답에 `status=UP`, `service=JDSnack`, `version=1.0.0` 포함
- 빈 입력 요청 시 `EMPTY_RESUME`
- 50자 미만 요청 시 `TEXT_TOO_SHORT`
- 10,000자 초과 요청 시 `TEXT_TOO_LONG`
- 정상 길이 텍스트 요청 시 fixture 결과
- PDF 업로드 fixture 결과
- DOCX 업로드 fixture 결과
- TXT 업로드 `UNSUPPORTED_FILE_TYPE`
- 깨진 PDF 업로드 `FILE_TEXT_EXTRACTION_FAILED`
- fixture 없음 업로드 `FIXTURE_NOT_FOUND`

현재 실행 기준:

- [browser-smoke-checks.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/browser-smoke-checks.md)
- [scripts/smoke-test.sh](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/scripts/smoke-test.sh)

## PR 필수 기준

- 문서만 변경한 PR은 문서 하네스 검증을 통과해야 합니다.
- 백엔드 변경 PR은 백엔드 CI 기준을 통과해야 합니다.
- 프론트엔드 변경 PR은 프론트엔드 CI 기준을 통과해야 합니다.
- API/UI 계약 변경 PR은 관련 spec 문서와 테스트 시나리오가 함께 갱신되어야 합니다.

## 실패 처리

- CI 실패는 코드 버그와 같은 급으로 봅니다.
- 실패를 우회해야 하면 PR 본문에 이유와 후속 조치를 남깁니다.
- 같은 실패가 2회 이상 반복되면 `standards/` 또는 Git 훅 규칙으로 승격합니다.
