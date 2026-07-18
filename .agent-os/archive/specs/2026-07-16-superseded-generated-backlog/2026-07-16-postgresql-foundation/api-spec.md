# PostgreSQL 서비스 기반과 마이그레이션 API 명세

## 계약

GET /api/health 응답에 애플리케이션 상태와 DB readiness를 구분해 표현합니다. 기존 health 소비자가 깨지지 않도록 기존 필드는 유지합니다.

## 공통 규칙

- 인증이 필요한 endpoint는 현재 사용자 소유권을 검증합니다.
- 성공·실패 응답은 기존 `ApiResponse<T>` 규칙과 표준 error code를 따릅니다.
- secret, 원문 민감 데이터, 내부 stack trace를 응답하지 않습니다.
- 기존 endpoint 변경 시 하위 호환 또는 명시적 migration을 acceptance criteria에 포함합니다.
