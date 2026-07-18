# 분석·수집 운영 관측성과 장애 대응 요구사항

- 상태: pending
- 제품 범위: Post MVP
- 위험도: Standard
- 선행 조건: 2026-07-16-analysis-persistence, 2026-07-16-rate-limit-cost-control
- 관련 technical ADR: adr-004-analysis-record

## 목적

JD 수집·AI 분석·DB 장애를 correlation id와 상태 지표로 추적하고 운영자가 재개 지점을 알 수 있게 합니다.

## 범위

### 포함

- structured log
- request/run correlation id
- 분석 상태·latency·failure metric
- 외부 provider 오류 분류
- incident runbook

### 제외

- 상용 APM 도입
- 분산 tracing 제품 고정
- 자동 장애 복구

## 요구사항

### REQ-01

- 모든 외부 fetch·AI 호출은 correlation id로 연결된다.

### REQ-02

- secret·원문 이력서·JD 본문은 로그에 남기지 않는다.

### REQ-03

- 운영자는 실패 상태와 재개 가능 단계를 확인할 수 있다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
