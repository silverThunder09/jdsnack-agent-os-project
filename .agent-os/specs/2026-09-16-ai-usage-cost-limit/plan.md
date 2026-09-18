- 구현 상태: `completed`

### T1. 백엔드 quota·idempotency·오류 계약

- 상태: `completed`
- 범위: 사용자별 일일 quota 예약, ledger, idempotency, 429 metadata, 입력·파일 검증, Gemini timeout, migration
- 완료 PR: #205

### T2. 프론트 quota 오류 안내

- 상태: `completed`
- 범위: `AI_QUOTA_EXCEEDED` metadata 해석, idempotency header 전달, quota 초과 안내와 재사용 가능 시각 표시
- 완료 조건: AC-02·AC-03과 TC-08을 포함한 frontend lint·test·build 통과
- 검증: lint 통과, Vitest 58/58 통과, production build 통과, AI readiness 통과
