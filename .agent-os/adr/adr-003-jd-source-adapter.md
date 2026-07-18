# 채용 사이트별 JD 수집을 Source Adapter로 격리

```yaml
id: adr-003-jd-source-adapter
status: proposed
risk: Standard
author: Codex
approved_by:
related_specs: 2026-07-16-canonical-jd-intake, 2026-07-16-saramin-jd-persistence, 2026-07-16-jobkorea-jd-adapter, 2026-07-16-rocketpunch-jd-adapter
```

## Context

사람인·JobKorea·RocketPunch의 HTML 구조와 실패 양상이 다르므로 하나의 거대한 scraper에 조건문을 쌓으면 변경 비용과 SSRF 위험이 커집니다.

## Decision

공통 canonical JD와 provenance 계약을 두고, source별 fetch/extract 로직은 독립 adapter로 둡니다. 공통 경계에는 host allowlist·SSRF·timeout·size·fake-success 검증을 둡니다.

## Alternatives considered

- 단일 scraper: 초기 파일 수는 적지만 source 변경이 전체 경로를 흔듭니다.
- 브라우저 자동화 우선: 동적 페이지 대응은 좋지만 비용·실행 의존성이 큽니다.
- source별 완전 별도 API: UI와 저장 계약이 중복됩니다.

## Consequences

- 첫 source의 실제 차이를 확인한 뒤 공통 abstraction을 최소화합니다.
- 새 source는 별도 vertical spec과 fixture를 가져야 합니다.
- 사이트 약관·robots·접근 정책은 각 source spec에서 확인합니다.

## Approval rule

- High 위험 ADR은 사용자 명시 승인이 있기 전까지 구현을 시작하지 않습니다.
- 이 문서는 현재 technical decision 초안이며, 승인 후 본문을 직접 수정하지 않고 superseding ADR로 변경합니다.
