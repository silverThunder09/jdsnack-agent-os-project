# AI 호출량과 비용 제한 요구사항

- 상태: pending
- 제품 범위: Post MVP
- 위험도: High
- 선행 조건: 2026-07-16-analysis-persistence, 2026-07-16-analysis-idempotency
- 관련 technical ADR: adr-004-analysis-record

## 목적

사용자·endpoint·provider별 AI 호출량과 예상 비용을 제한해 오남용과 비용 폭증을 막습니다.

## 범위

### 포함

- 사용자별 일일 호출 제한
- 본문·파일 크기 제한
- provider timeout
- 비용 metadata
- 제한 초과 오류 계약

### 제외

- 결제
- 정교한 과금
- Redis 기반 분산 quota

## 요구사항

### REQ-01

- idempotency 확인이 비용 제한보다 먼저 적용된다.

### REQ-02

- 제한 초과 요청은 외부 AI를 호출하지 않는다.

### REQ-03

- 제한 값과 실제 호출 기록을 감사 가능하게 남긴다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
