# Flyway로 H2·PostgreSQL 스키마 마이그레이션 관리

```yaml
id: adr-022-flyway-schema-migrations
status: accepted
risk: High
author: Codex
decision_scope: Issue #175 implementation (2026-09-15)
related_adrs:
  - adr-019-postgresql-service-storage
```

## Context

ADR-019는 운영 영속 저장소를 PostgreSQL로 정했지만, 기존 애플리케이션은 `schema.sql`과 `data.sql`을 매 부팅 실행하는 방식이었습니다. 이 방식은 인메모리 H2 테스트에는 편하지만 영속 PostgreSQL의 스키마 이력·재기동·변경 순서를 관리하지 못합니다. Windows에서는 SQL 초기화 파일의 기본 인코딩 차이로 한글 fixture가 깨지는 회귀도 드러났습니다.

## Decision

Flyway를 애플리케이션의 스키마 마이그레이션 도구로 사용합니다. H2와 PostgreSQL은 `backend/src/main/resources/db/migration/`의 같은 migration 집합을 실행하고, Spring SQL 초기화(`spring.sql.init`)는 사용하지 않습니다.

- `V1__baseline.sql`은 현재 저장 모델의 최초 스키마를 만듭니다.
- `V2__fixture_seed.sql`은 로컬·CI fixture를 추가합니다.
- 이미 적용된 migration은 수정하지 않고 다음 버전의 migration을 추가합니다.
- PostgreSQL 접속 정보는 `postgres` 프로파일의 환경변수로만 주입합니다.
- 기존에 수동으로 만들어진 운영 DB를 Flyway 이력으로 전환하는 작업과 backup/restore는 별도 운영 작업으로 둡니다. 자동 `baseline-on-migrate`로 불완전한 스키마를 승인하지 않습니다.

## Alternatives considered

- Liquibase: 변경 집합과 XML/YAML/SQL 관리가 현재 JDBC·SQL 중심 코드보다 무겁습니다.
- PostgreSQL 프로파일에만 Flyway 적용: H2용 SQL 초기화를 남겨 두어 스키마 정의가 이중화되고, 테스트와 운영의 migration 경로가 달라집니다.
- 수동 `psql` 실행: 애플리케이션 기동 시 migration 이력과 재적용 안전성을 보장하지 못합니다.

## Consequences

- 애플리케이션 기동 시 `flyway_schema_history`가 적용 이력을 보존하고, 재기동은 이미 적용된 migration을 중복 실행하지 않습니다.
- H2 테스트와 실제 PostgreSQL CI가 같은 SQL을 사용하므로 DBMS별 문법 회귀를 줄일 수 있습니다.
- 초기 schema/data 파일은 versioned migration으로 이동했으며, 앞으로 스키마 변경은 `V3__...` 이상의 새 파일로 관리합니다.
- 최초 운영 DB가 이미 존재하는 경우에는 별도 점검·baseline·데이터 전환 계획이 필요합니다.

## Verification

- `SchemaPortabilityTest`: migration SQL의 PostgreSQL/H2 공통 타입·문법 가드
- `PostgresMigrationTest`: 실제 PostgreSQL 프로파일에서 최초 적용, seed, `flyway.migrate()` 재호출과 중복 없는 이력 검증
