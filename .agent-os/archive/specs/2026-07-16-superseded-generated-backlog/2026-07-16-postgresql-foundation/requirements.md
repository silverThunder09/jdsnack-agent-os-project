# PostgreSQL 서비스 기반과 마이그레이션 요구사항

- 상태: pending
- 제품 범위: Service MVP
- 위험도: High
- 선행 조건: 현재 활성 사람인 OCR spec 완료
- 관련 technical ADR: adr-001-postgresql

## 목적

H2 메모리 DB와 LocalStorage 중심의 현재 구조를 서비스용 PostgreSQL 영속 기반으로 전환합니다.

## 범위

### 포함

- PostgreSQL 로컬 Compose 서비스와 환경변수 연결
- 마이그레이션 도구와 초기 스키마 실행
- DB readiness를 health 계약에 반영
- 기존 fixture 테스트의 H2 격리 유지

### 제외

- OAuth·사용자 기능
- 분석 도메인 전체 저장
- Redis 도입
- 운영 Managed DB 배포

## 요구사항

### REQ-01

- 서비스가 PostgreSQL에 연결되지 않으면 readiness를 통과시키지 않는다.

### REQ-02

- 스키마 변경은 재실행 가능한 migration으로 관리한다.

### REQ-03

- 테스트는 외부 PostgreSQL 없이 기존 H2/fixture 경계로 실행할 수 있다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
