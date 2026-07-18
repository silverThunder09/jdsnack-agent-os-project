# JobKorea JD source adapter 요구사항

- 상태: pending
- 제품 범위: Post MVP
- 위험도: High
- 선행 조건: 2026-07-16-saramin-jd-persistence, 2026-07-16-observability-runbook
- 관련 technical ADR: adr-003-jd-source-adapter

## 목적

공통 JD source adapter 계약을 사용해 JobKorea 정적 공고를 안전하게 수집·저장합니다.

## 범위

### 포함

- JobKorea host allowlist
- HTML 본문 추출
- canonical JD mapping
- SSRF·timeout·size 제한
- 실패 원인과 provenance

### 제외

- 로그인 필요 공고
- 브라우저 자동화
- 이미지 OCR
- 사이트 약관 우회

## 요구사항

### REQ-01

- 허용된 JobKorea 호스트 외 URL은 요청하지 않는다.

### REQ-02

- 추출 결과는 canonical JD 계약을 만족해야 저장된다.

### REQ-03

- 추출 실패 시 fake success를 반환하지 않는다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
