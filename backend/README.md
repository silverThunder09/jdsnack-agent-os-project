# Backend

## Purpose

Spring Boot API가 인증·입력 검증·AI 분석·JD 수집을 서버 경계에서 처리합니다. Controller는 HTTP 계약만, Service는 업무 규칙과 외부 API 조합만 담당합니다.

## Key files

- `src/main/java/com/jdsnack/auth/AuthController.java`: 세션·Google OAuth 경계
- `src/main/java/com/jdsnack/diagnose/DiagnoseService.java`: 이력서 진단 조합
- `src/main/java/com/jdsnack/jd/JdFetchService.java`: JD URL 수집과 사람인 fallback
- `src/main/java/com/jdsnack/common/GlobalExceptionHandler.java`: 공통 오류 응답
- `src/test/java/com/jdsnack/jd/JdFetchServiceTest.java`: 외부 HTTP 없이 JD 수집 회귀 검증

## Patterns

- API 추가는 `Controller -> Service -> Repository/External API` 순서로 추가하고 DTO/record로 응답을 반환합니다.
- 외부 Gemini·JD URL 호출은 provider 또는 adapter 경계에 두고 테스트에서는 fixture/mock을 사용합니다.
- 보호 API 변경은 인증 필터와 controller test를 함께 확인합니다.

## Gotchas

- 브라우저·프론트 코드에 OAuth secret이나 Gemini key를 노출하지 않습니다.
- 사람인 수집 회귀는 실 URL이 아니라 `src/test/resources/jd/fixtures/`와 mock `HttpClient`로 검증합니다.
- Entity를 API 응답으로 직접 반환하지 않습니다.

## Dependencies

- 프론트 계약: [`../frontend/src/services/api.ts`](../frontend/src/services/api.ts)
- API 규격: [`../.agent-os/specs/2026-07-20-ats-score-format/api-spec.md`](../.agent-os/specs/2026-07-20-ats-score-format/api-spec.md)
- 아키텍처: [`../docs/architecture/backend-architecture.md`](../docs/architecture/backend-architecture.md)

## Commands

```bash
./gradlew test
./gradlew bootJar
```
