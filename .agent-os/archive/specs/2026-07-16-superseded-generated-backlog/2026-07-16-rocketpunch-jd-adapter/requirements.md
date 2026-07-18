# RocketPunch JD source adapter 요구사항

- 상태: pending
- 제품 범위: Post MVP
- 위험도: High
- 선행 조건: 2026-07-16-jobkorea-jd-adapter
- 관련 technical ADR: adr-003-jd-source-adapter

## 목적

동일한 canonical JD 계약과 보안 경계를 사용해 RocketPunch 공고를 수집합니다.

## 범위

### 포함

- RocketPunch host allowlist
- 본문 추출 adapter
- canonical JD provenance
- 실패·empty content 정책
- 기존 source 회귀 보호

### 제외

- 로그인 필요 페이지
- 브라우저 자동화
- 사이트별 우회 로직의 공통화
- 이미지 OCR

## 요구사항

### REQ-01

- RocketPunch adapter는 source-specific selector를 내부에 격리한다.

### REQ-02

- 본문 품질 검증을 통과하지 못하면 저장하지 않는다.

### REQ-03

- 사람인·JobKorea adapter와 독립적으로 실패한다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
