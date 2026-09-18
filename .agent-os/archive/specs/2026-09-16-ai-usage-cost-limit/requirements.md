## 요구사항

- REQ-01: 인증 user/date별 `Asia/Seoul` 일일 quota를 기본 20건으로 원자 예약하고 `JDSNACK_AI_USAGE_DAILY_LIMIT`으로 설정한다.
- REQ-02: 같은 user/key 재요청은 history를 재사용하며 quota/provider를 재실행하지 않고, 다른 user와 격리한다.
- REQ-03: quota 초과는 실행 전에 HTTP 429 `AI_QUOTA_EXCEEDED`와 `retryAfter/limit/remaining/resetAt`을 반환한다.
- REQ-04: 텍스트 50~10,000자와 PDF/DOCX 10 MiB 이하만 허용하며 validation 실패는 quota를 소비하지 않는다.
- REQ-05: 분석·매칭 Gemini timeout 기본값 10/30초와 설정 override를 유지하고 실행 metadata를 남긴다.

Redis·결제·가격표·비인증 preview·외부 Gemini 실호출 테스트는 범위에서 제외하며 Controller → Service → Repository/External API 경계를 지킨다.
