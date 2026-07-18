# PostgreSQL을 서비스 영속 저장소로 사용

```yaml
id: adr-001-postgresql
status: proposed
risk: High
author: Codex
approved_by:
related_specs: 2026-07-16-postgresql-foundation, 2026-07-16-user-resume-persistence
```

## Context

현재 런타임은 H2와 LocalStorage 중심이며 OAuth 사용자, 이력서, JD, AI 분석 결과를 장기 보존해야 합니다.

## Decision

서비스 운영 저장소 후보로 PostgreSQL을 사용합니다. 테스트는 H2 또는 fixture를 유지하고, migration·운영 DB 연결·복구 정책은 별도 구현 스펙에서 고정합니다.

## Alternatives considered

- MySQL: 전통적 CRUD에는 적합하지만 JSON·향후 vector 확장 요구를 별도 검토해야 합니다.
- NoSQL: 현재 관계형 사용자·이력서·JD·분석 소유권 모델에 비해 일관성 경계가 불필요하게 커집니다.
- H2 유지: 서비스 재시작 시 데이터가 사라져 MVP 사용자 흐름을 충족하지 못합니다.

## Consequences

- PostgreSQL Compose와 운영 연결이 필요합니다.
- schema migration과 backup/restore runbook이 필요합니다.
- DB 연결 실패는 readiness 실패와 spec blocked로 처리합니다.

## Approval rule

- High 위험 ADR은 사용자 명시 승인이 있기 전까지 구현을 시작하지 않습니다.
- 이 문서는 현재 technical decision 초안이며, 승인 후 본문을 직접 수정하지 않고 superseding ADR로 변경합니다.
