# AI 진단·JD 매칭 결과 저장 요구사항

- 상태: pending
- 제품 범위: Service MVP
- 위험도: High
- 선행 조건: 2026-07-16-user-resume-persistence, 2026-07-16-saramin-jd-persistence
- 관련 technical ADR: adr-004-analysis-record

## 목적

현재 동기식 AI 진단·JD 매칭 결과를 사용자·이력서·JD와 연결해 저장합니다.

## 범위

### 포함

- diagnosis 결과 저장
- JD match 결과 저장
- provider·model·prompt version 메타데이터
- 성공·실패·부분 결과 상태
- 기존 fixture/stub/ai-local 경계 유지

### 제외

- 비동기 worker
- AI 품질 자동 평가
- 비용 제한

## 요구사항

### REQ-01

- 분석 기록은 사용자 소유 이력서·JD만 참조한다.

### REQ-02

- AI 결과 원문과 정규화된 응답 계약을 구분해 저장한다.

### REQ-03

- 외부 AI 실패는 실패 상태와 재시도 가능한 오류로 저장한다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
