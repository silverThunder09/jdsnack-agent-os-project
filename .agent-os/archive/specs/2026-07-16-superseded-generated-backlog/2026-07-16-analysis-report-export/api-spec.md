# 분석 결과 리포트 내보내기 API 명세

## 계약

GET /api/analyses/{id}/export?format=markdown를 정의합니다. 응답은 attachment 파일이며 허용 format 외에는 validation 오류를 반환합니다.

## 공통 규칙

- 인증이 필요한 endpoint는 현재 사용자 소유권을 검증합니다.
- 성공·실패 응답은 기존 `ApiResponse<T>` 규칙과 표준 error code를 따릅니다.
- secret, 원문 민감 데이터, 내부 stack trace를 응답하지 않습니다.
- 기존 endpoint 변경 시 하위 호환 또는 명시적 migration을 acceptance criteria에 포함합니다.
