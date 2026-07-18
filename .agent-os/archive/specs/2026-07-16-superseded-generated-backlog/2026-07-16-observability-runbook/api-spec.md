# 분석·수집 운영 관측성과 장애 대응 API 명세

## 계약

공개 응답 body는 변경하지 않고 correlation id를 응답 헤더에 포함합니다. 내부 상태와 로그 필드를 표준화합니다.

## 공통 규칙

- 인증이 필요한 endpoint는 현재 사용자 소유권을 검증합니다.
- 성공·실패 응답은 기존 `ApiResponse<T>` 규칙과 표준 error code를 따릅니다.
- secret, 원문 민감 데이터, 내부 stack trace를 응답하지 않습니다.
- 기존 endpoint 변경 시 하위 호환 또는 명시적 migration을 acceptance criteria에 포함합니다.
