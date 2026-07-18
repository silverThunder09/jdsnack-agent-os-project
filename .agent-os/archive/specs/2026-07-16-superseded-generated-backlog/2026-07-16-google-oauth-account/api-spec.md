# Google OAuth 계정과 세션 API 명세

## 계약

GET /api/auth/google, GET /api/auth/callback, POST /api/auth/logout, GET /api/auth/me를 정의합니다. callback은 provider subject를 내부 userId로 매핑하고 실패 시 표준 오류를 반환합니다.

## 공통 규칙

- 인증이 필요한 endpoint는 현재 사용자 소유권을 검증합니다.
- 성공·실패 응답은 기존 `ApiResponse<T>` 규칙과 표준 error code를 따릅니다.
- secret, 원문 민감 데이터, 내부 stack trace를 응답하지 않습니다.
- 기존 endpoint 변경 시 하위 호환 또는 명시적 migration을 acceptance criteria에 포함합니다.
