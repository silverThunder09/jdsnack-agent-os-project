# 분석 이력 목록과 상세 조회 요구사항

- 상태: pending
- 제품 범위: Service MVP
- 위험도: Standard
- 선행 조건: 2026-07-16-analysis-persistence
- 관련 technical ADR: adr-004-analysis-record

## 목적

사용자가 과거 분석을 목록·상세로 다시 확인해 분석 결과를 재사용합니다.

## 범위

### 포함

- analysis history 목록
- resume·JD 요약 표시
- 상세 결과 조회
- 페이지네이션 또는 cursor
- 삭제된 원본의 안전한 표시

### 제외

- 재분석 실행
- 공유 링크
- 고급 검색·정렬

## 요구사항

### REQ-01

- 목록과 상세는 userId로 강제 격리한다.

### REQ-02

- 최신 분석부터 안정적인 순서로 반환한다.

### REQ-03

- 결과가 실패한 기록도 이력에서 확인할 수 있다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
