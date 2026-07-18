# AI 응답 품질 평가와 프롬프트 버전 요구사항

- 상태: pending
- 제품 범위: Post MVP
- 위험도: High
- 선행 조건: 2026-07-16-analysis-persistence
- 관련 technical ADR: adr-004-analysis-record

## 목적

Gemini 분석 품질을 fixture·golden dataset·schema 검증으로 반복 평가하고 프롬프트 버전을 추적합니다.

## 범위

### 포함

- golden resume/JD fixtures
- 응답 schema validation
- prompt/model version metadata
- 품질 회귀 명령
- 실호출 테스트와 fixture 테스트 분리

### 제외

- 모델 자동 교체
- 사용자별 맞춤 prompt
- 온라인 A/B 테스트

## 요구사항

### REQ-01

- 구조화 응답이 계약을 벗어나면 성공 결과로 저장하지 않는다.

### REQ-02

- fixture 테스트는 token·network 비용 없이 실행된다.

### REQ-03

- 실호출 검증은 명시적 명령에서만 실행된다.

### REQ-04

- 분석 결과의 prompt/model 버전을 추적할 수 있다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
