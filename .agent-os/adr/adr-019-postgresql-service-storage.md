# PostgreSQL을 Service MVP 영속 저장소로 사용

```yaml
id: adr-019-postgresql-service-storage
status: accepted
risk: High
author: Codex
approved_by: user (2026-07-19)
supersedes: adr-014-postgresql
related_specs: 2026-07-18-service-mvp
```

## Decision

Service MVP의 운영 영속 저장소는 PostgreSQL을 사용합니다. 애플리케이션은 `JdbcTemplate` 기반 저장 경계를 사용하고, 로컬 단위 테스트는 H2 또는 fixture로 격리할 수 있습니다. PostgreSQL 연결 정보는 환경 설정으로 주입하며 비밀값을 코드·프론트·테스트에 넣지 않습니다.

T2에서는 PostgreSQL과 H2에서 동작 가능한 저장 계약과 스키마를 추가하고, 운영 DB 전환·migration·backup/restore 절차는 별도 운영 작업으로 다룹니다.

## Consequences

- 사용자 소유 데이터는 메모리나 브라우저 저장소가 아니라 서버 저장소에 둡니다.
- 로컬 테스트가 H2를 사용해도 PostgreSQL 운영 저장소 계약을 대체하는 것으로 보지 않습니다.
- 스키마 변경은 호환 가능한 SQL과 테스트로 검증해야 합니다.

## Approval

기존 [ADR-014 PostgreSQL](adr-014-postgresql.md)의 제안을 사용자 승인에 따라 superseding 결정으로 확정합니다.
