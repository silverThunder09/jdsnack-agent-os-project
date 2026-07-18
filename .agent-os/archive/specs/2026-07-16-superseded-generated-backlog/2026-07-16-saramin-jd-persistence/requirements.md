# 사람인 JD 수집 결과 저장 요구사항

- 상태: pending
- 제품 범위: Service MVP
- 위험도: Standard
- 선행 조건: 2026-07-16-canonical-jd-intake
- 관련 technical ADR: adr-003-jd-source-adapter

## 목적

현재 사람인 HTML·이미지 OCR 수집 경로를 canonical JD와 연결해 로그인 사용자가 재사용할 수 있게 합니다.

## 범위

### 포함

- 사람인 fetch와 canonical JD 연결
- static-html·image-ocr fetchMode 보존
- 원본 URL·제목·수집 시각 저장
- 수집 실패의 기존 오류 보존

### 제외

- JobKorea·RocketPunch
- 주기적 재수집
- 크롤링 우회·로그인 필요 공고

## 요구사항

### REQ-01

- 사람인 외 source는 이 endpoint에서 허용하지 않는다.

### REQ-02

- 현재 active OCR spec의 SSRF·크기·타임아웃 기준을 그대로 적용한다.

### REQ-03

- 수집 성공과 DB 저장이 모두 성공해야 사용자에게 성공을 표시한다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
