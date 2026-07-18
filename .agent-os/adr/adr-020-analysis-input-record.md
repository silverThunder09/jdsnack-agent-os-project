# 분석 입력 스냅샷을 사용자 소유 Analysis Record로 저장

```yaml
id: adr-020-analysis-input-record
status: accepted
risk: High
author: Codex
approved_by: user (2026-07-19)
supersedes: adr-017-analysis-record
related_specs: 2026-07-18-service-mvp
```

## Decision

분석 제출은 인증된 사용자 소유의 입력 스냅샷으로 저장합니다. 스냅샷에는 제출 당시 정규화된 이력서 텍스트, JD 본문, JD 입력 유형, 출처 URL과 수집 메타데이터를 보존합니다. PDF/DOCX 원본 바이트는 텍스트 추출 후 폐기하며 저장하지 않습니다.

분석 결과와 상태는 후속 T3에서 같은 Analysis Record에 연결합니다. 입력 저장은 분석 실패와 무관하게 트랜잭션 경계 안에서 수행할 수 있어야 하며, 사용자 소유권은 모든 조회·변경·삭제 경계에서 검증합니다.

## Consequences

- 재시도는 저장된 입력 스냅샷을 사용하고 JD URL을 다시 호출하지 않습니다.
- 삭제 시 입력 스냅샷과 이후 연결된 JD·결과를 함께 영구 삭제합니다.
- API 응답은 전용 DTO를 사용하며 저장 Entity를 직접 노출하지 않습니다.

## Approval

기존 [ADR-017 Analysis Record](adr-017-analysis-record.md)의 제안을 사용자 승인에 따라 superseding 결정으로 확정합니다.
