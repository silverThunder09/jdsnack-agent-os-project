# 비동기 분석 worker와 재개 상태 요구사항

- 상태: pending
- 제품 범위: Post MVP
- 위험도: High
- 선행 조건: 2026-07-16-analysis-persistence, 2026-07-16-rate-limit-cost-control, 2026-07-16-observability-runbook
- 관련 technical ADR: adr-005-analysis-worker

## 목적

Gemini 분석 시간이 길어질 때 HTTP 요청과 실행을 분리하고, worker 중단 후 run-state 기반으로 재개합니다.

## 범위

### 포함

- analysis job 상태
- worker lease·lock
- 재시도와 backoff
- DB·Redis 필수 의존성 차단
- run-state와 resume_phase
- 완료 결과 멱등성

### 제외

- Codex 구현 루프 자체
- 무제한 자동 재시도
- 분산 multi-region worker
- 사용자에게 provider secret 노출

## 요구사항

### REQ-01

- 필수 DB·Redis가 없으면 job을 생성하지 않고 전체 spec을 blocked로 기록한다.

### REQ-02

- worker 중단 후 이미 완료된 job을 다시 외부 호출하지 않는다.

### REQ-03

- 재시도 횟수는 코드 리뷰 재시도와 별도로 관리한다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
