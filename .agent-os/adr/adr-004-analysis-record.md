# AI 분석을 사용자 소유 Analysis Record로 저장

```yaml
id: adr-004-analysis-record
status: proposed
risk: High
author: Codex
approved_by:
related_specs: 2026-07-16-analysis-persistence, 2026-07-16-analysis-history, 2026-07-16-analysis-idempotency, 2026-07-16-analysis-report-export
```

## Context

현재 진단·JD 매칭은 요청 시 결과를 반환하는 preview 중심이라 새로고침·재방문·재시도·비용 추적이 어렵습니다.

## Decision

분석 실행과 분석 결과를 Analysis Record로 분리하고, userId·resumeVersion·jdId·provider/model/prompt metadata·status·result를 저장합니다. 원본 입력과 정규화 결과를 모두 추적하되 API 응답은 정규화 계약을 사용합니다.

## Alternatives considered

- 결과만 저장: 재현성과 prompt/model 추적이 약합니다.
- 입력만 저장: 과거 결과 재조회가 불가능합니다.
- 모든 AI 응답을 공개 원문으로 반환: provider 내부 정보와 민감정보 노출 위험이 있습니다.

## Consequences

- 소유권 필터가 모든 조회·수정·삭제에 적용됩니다.
- schema validation 실패는 성공 record가 될 수 없습니다.
- 분석 삭제·export·retry 정책이 함께 필요합니다.

## Approval rule

- High 위험 ADR은 사용자 명시 승인이 있기 전까지 구현을 시작하지 않습니다.
- 이 문서는 현재 technical decision 초안이며, 승인 후 본문을 직접 수정하지 않고 superseding ADR로 변경합니다.
