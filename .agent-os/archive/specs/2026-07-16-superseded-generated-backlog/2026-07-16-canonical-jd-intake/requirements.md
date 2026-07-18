# 표준 JD 모델과 입력 계약 요구사항

- 상태: pending
- 제품 범위: Service MVP
- 위험도: Standard
- 선행 조건: 2026-07-16-user-resume-persistence
- 관련 technical ADR: adr-003-jd-source-adapter

## 목적

직접 입력·URL 수집 결과를 출처와 원문 provenance를 보존하는 표준 JD 모델로 통합합니다.

## 범위

### 포함

- JD text·URL 저장 모델
- sourceSite·fetchMode·sourceUrl provenance
- 직접 입력과 URL 입력의 공통 계약
- 정규화·최소 길이 검증

### 제외

- JobKorea·RocketPunch 구현
- 추가 OCR
- AI 매칭 실행

## 요구사항

### REQ-01

- 모든 JD는 canonical id와 소유 userId를 가진다.

### REQ-02

- 수집 방식과 원본 URL을 결과에 보존한다.

### REQ-03

- JD 본문이 검증 기준보다 짧으면 저장하지 않는다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
