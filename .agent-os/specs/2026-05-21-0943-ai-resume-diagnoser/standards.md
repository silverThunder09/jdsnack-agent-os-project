# 기능별 구현 표준

> 적용 범위: `2026-05-21-0943-ai-resume-diagnoser` 1차 MVP

## 1. 핵심 결정

- 1차 MVP는 사용자 인증 정보 입력을 제공하지 않는다.
- 1차 MVP는 서버에서 외부 AI를 호출하지 않는다.
- 유효한 입력은 실제 분석 대신 `AI_ANALYSIS_NOT_ENABLED`로 응답한다.
- 2차 MVP에서 외부 AI 연동을 추가할 때 별도 요구사항과 테스트를 만든다.

## 2. 백엔드 표준

- Controller는 HTTP 요청/응답 처리에 집중한다.
- 입력 검증은 Validation Service 또는 Bean Validation으로 분리한다.
- `POST /api/diagnose`는 빈 입력, 최소 길이, 최대 길이를 구분한다.
- `resumeText` 누락, `null`, 공백 문자만 있는 값은 `EMPTY_RESUME`으로 처리한다.
- 정확히 50자와 정확히 10,000자 입력은 유효한 입력으로 처리한다.
- 검증 통과 시 `501 Not Implemented`와 `AI_ANALYSIS_NOT_ENABLED`를 반환한다.
- 1차 MVP 코드에는 외부 AI 클라이언트, 프롬프트 조립기, AI 응답 파서를 만들지 않는다.

## 3. 프론트엔드 표준

- 컴포넌트에서 직접 `fetch`를 호출하지 않는다.
- API 호출은 `services/api.ts` 같은 서비스 계층을 통해 수행한다.
- 화면 상태는 `idle`, `loading`, `not-enabled`, `error`로 구분한다.
- 인증 정보 입력 UI를 만들지 않는다.
- LocalStorage에는 이력서 입력값만 저장할 수 있다.

## 4. 테스트 표준

- 빈 입력은 `EMPTY_RESUME`으로 검증한다.
- 50자 미만 입력은 `TEXT_TOO_SHORT`로 검증한다.
- 10,000자 초과 입력은 `TEXT_TOO_LONG`으로 검증한다.
- 정상 길이 입력은 `AI_ANALYSIS_NOT_ENABLED`로 검증한다.
- 경계값 50자와 10,000자를 검증한다.
- `GET /api/health`는 `200 OK`, `status=UP`, `service=JDSnack`, `version=1.0.0`을 검증한다.
- 프론트는 준비중 안내를 렌더링해야 한다.

## 5. 2차 MVP 전환 조건

외부 AI 연동을 시작하기 전 아래 문서를 먼저 갱신한다.

- `requirements.md`
- `acceptance-criteria.md`
- `test-scenarios.md`
- `traceability.md`
- `api-spec.md`
- `architecture.md`
