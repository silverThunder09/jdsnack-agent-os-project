# 장시간 분석은 선택적 비동기 Worker로 분리

```yaml
id: adr-018-analysis-worker
status: proposed
risk: High
author: Codex
approved_by:
related_specs: 2026-07-16-analysis-worker
```

## Context

Gemini 호출과 향후 여러 source 처리는 HTTP timeout과 사용자 대기 시간을 초과할 수 있습니다. 다만 초기 서비스 MVP에서 Redis·worker를 선제 도입하면 운영 복잡도가 커집니다.

## Decision

동기 저장 경로를 먼저 완성하고, 필요성이 검증된 뒤 analysis job을 DB 상태와 Redis lease 기반 worker로 분리합니다. 필수 의존성이 없으면 전체 job을 blocked로 처리하고, run-state로 중단 후 재개합니다.

## Alternatives considered

- 항상 동기 처리: 구현은 단순하지만 timeout·재시도·재개가 취약합니다.
- 처음부터 worker: 확장성은 좋지만 MVP에 운영 의존성이 추가됩니다.
- 외부 managed queue만 사용: 운영 부담은 줄지만 로컬·CI 재현성이 낮아집니다.

## Consequences

- job 상태·lock·backoff·멱등성 정책이 필요합니다.
- Docker/Redis가 꺼지면 성공·PR 진행을 허용하지 않습니다.
- worker 도입 전까지 Redis를 필수 dependency로 추가하지 않습니다.

## Approval rule

- High 위험 ADR은 사용자 명시 승인이 있기 전까지 구현을 시작하지 않습니다.
- 이 문서는 현재 technical decision 초안이며, 승인 후 본문을 직접 수정하지 않고 superseding ADR로 변경합니다.
