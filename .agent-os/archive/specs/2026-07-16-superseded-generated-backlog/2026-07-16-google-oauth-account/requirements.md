# Google OAuth 계정과 세션 요구사항

- 상태: pending
- 제품 범위: Service MVP
- 위험도: High
- 선행 조건: 2026-07-16-postgresql-foundation
- 관련 technical ADR: adr-002-oauth-provider

## 목적

사용자가 Google 계정으로 로그인하고, 서버가 애플리케이션 사용자와 세션을 관리하도록 합니다.

## 범위

### 포함

- Google authorization-code 로그인
- provider subject 기반 사용자 upsert
- 서버 세션 또는 승인된 토큰 경계
- 로그인·로그아웃·현재 사용자 API
- OAuth secret 서버 보관

### 제외

- Kakao·Naver 등 추가 공급자
- 비밀번호 로그인
- 프론트 secret 저장
- 관리자 권한

## 요구사항

### REQ-01

- OAuth callback은 state 검증과 redirect allowlist를 통과해야 한다.

### REQ-02

- provider의 email이 바뀌어도 provider subject를 주 식별자로 사용한다.

### REQ-03

- 세션·client secret·provider token은 브라우저 localStorage에 저장하지 않는다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
