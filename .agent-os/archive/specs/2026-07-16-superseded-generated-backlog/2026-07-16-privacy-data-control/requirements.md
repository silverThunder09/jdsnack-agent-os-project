# 사용자 데이터 삭제와 초기화 요구사항

- 상태: pending
- 제품 범위: Service MVP
- 위험도: High
- 선행 조건: 2026-07-16-analysis-history
- 관련 technical ADR: adr-004-analysis-record

## 목적

사용자가 저장된 이력서·JD·분석 결과를 삭제하고 계정 데이터를 초기화할 수 있게 합니다.

## 범위

### 포함

- 개별 이력서·JD·분석 삭제
- 계정 전체 데이터 삭제
- 삭제 cascade 정책
- 삭제 완료 확인
- 외부 AI로 재전송하지 않는 삭제 흐름

### 제외

- 법률 문서 자동 생성
- 데이터 복구 UI
- 공유 데이터 삭제

## 요구사항

### REQ-01

- 삭제 권한은 사용자 소유권으로 검증한다.

### REQ-02

- 계정 전체 삭제는 참조 관계를 안전하게 처리한다.

### REQ-03

- 삭제된 id의 존재 여부를 타 사용자에게 노출하지 않는다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
