# 백엔드 아키텍처

## 핵심 요약

백엔드는 “주문을 받는 창구(Controller)”와 “실제 일을 처리하는 작업실(Service)”를 나누는 구조입니다.  
공식적으로는 **레이어드 아키텍처**이며, 핵심 경계는 `Controller -> Service -> Repository/External API`입니다.

## 레이어

- `controller`
  - HTTP 요청/응답 처리
  - 요청 검증
  - 공통 응답 래퍼 반환
- `service`
  - 입력·소유권·업무 규칙 처리
  - Gemini·JD fetch 등 외부 provider 조합
- `dto`
  - 요청/응답 스키마
  - 경계 데이터 전달용 record
- `exception`
  - 사용자 친화적 예외 응답
- `config`
  - 웹 설정, 환경별 정책

## 하네스 규칙

- Controller는 Service만 의존합니다.
- Service는 Controller를 의존하지 않습니다.
- DTO는 Controller 또는 퍼사드 경계에서만 사용합니다.
- 외부 AI와 JD URL 수집은 Service/provider 경계에서 검증·파싱합니다.
- Controller는 Service만 의존하고 Entity를 직접 응답하지 않습니다.
- 구조 변경 시 [코딩 표준](../../.agent-os/standards/coding-standards.md)을 함께 갱신합니다.

## Persistence and migrations

- 운영 저장소는 ADR-019에 따라 PostgreSQL이며, 접속 정보는 `postgres` 프로파일 환경변수로 주입합니다.
- H2 테스트와 PostgreSQL 운영은 `backend/src/main/resources/db/migration/`의 같은 Flyway migration을 사용합니다.
- `spring.sql.init`의 매 부팅 초기화는 사용하지 않으며, 적용된 migration은 수정하지 않고 새 버전 파일을 추가합니다.
- 실제 PostgreSQL 연결·최초 migration·재기동 멱등성은 `PostgresMigrationTest`와 PR CI의 PostgreSQL 서비스로 확인합니다.

## Common changes and gotchas

- 새 보호 API는 authentication filter, Controller test, API spec을 함께 갱신합니다.
- 외부 URL 수집은 SSRF 방어와 fixture/mock HTTP test를 유지합니다.
- Gemini/OAuth 비밀값과 provider token은 서버에만 두고 예외 메시지에도 노출하지 않습니다.

## 관련 문서

- API 계약: [분석 결과 리포트 내보내기 API spec](../../.agent-os/archive/specs/2026-07-21-analysis-report-export/api-spec.md)
- 테스트 기준: [테스트 표준](../../.agent-os/standards/testing-standards.md)
- 모듈 진입점: [backend README](../../backend/README.md)
