# 사용자 이력서 저장과 버전 요구사항

- 상태: pending
- 제품 범위: Service MVP
- 위험도: Standard
- 선행 조건: 2026-07-16-google-oauth-account
- 관련 technical ADR: adr-001-postgresql

## 목적

로그인한 사용자가 텍스트·PDF·DOCX 이력서를 저장하고 최신 버전과 과거 버전을 구분합니다.

## 범위

### 포함

- 이력서 원문 저장
- 텍스트·파일 입력 정규화
- 사용자별 이력서 소유권
- 최신 버전 조회·교체
- 파일 메타데이터

### 제외

- 분석 결과 생성
- 공개 이력서 공유
- 삭제·내보내기(후속 spec)

## 요구사항

### REQ-01

- 이력서는 반드시 내부 userId에 귀속된다.

### REQ-02

- 저장 시 내용·sourceType·createdAt·version을 기록한다.

### REQ-03

- 다른 사용자의 id를 사용한 조회·수정은 존재 여부를 노출하지 않고 거부한다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
