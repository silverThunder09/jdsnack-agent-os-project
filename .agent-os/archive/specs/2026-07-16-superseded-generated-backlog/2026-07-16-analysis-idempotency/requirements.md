# 분석 중복 방지와 재분석 요구사항

- 상태: pending
- 제품 범위: Service MVP
- 위험도: High
- 선행 조건: 2026-07-16-analysis-persistence, 2026-07-16-analysis-history
- 관련 technical ADR: adr-004-analysis-record

## 목적

같은 입력으로 인한 중복 AI 호출을 막고, 명시적인 재분석만 새 실행으로 처리합니다.

## 범위

### 포함

- resume·JD·options fingerprint
- idempotency key
- 진행 중 분석 재사용
- 명시적 retry/reanalyze
- 동시 요청 경합 처리

### 제외

- 분산 queue
- Redis lock
- 사용자별 quota

## 요구사항

### REQ-01

- 동일 key와 동일 payload는 한 번만 외부 분석을 생성한다.

### REQ-02

- 재분석은 새 record로 추적하고 기존 결과를 덮어쓰지 않는다.

### REQ-03

- 서버 재시작 후에도 fingerprint 상태가 유지된다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
