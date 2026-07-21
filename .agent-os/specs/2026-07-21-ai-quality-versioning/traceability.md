# AI 품질 평가와 prompt/model version 추적성

| 요구사항 | 수용 기준 | 테스트 | 계약 | 티켓 |
|---|---|---|---|---|
| REQ-01 | AC-01 | TC-01, TC-02 | api-spec.md (T1 내부 스키마) | T1 |
| REQ-02 | AC-02 | TC-03 | api-spec.md (T1 내부 스키마), ui-spec.md | T1 |
| REQ-03 | AC-03 | TC-04 | api-spec.md, `.agent-os/archive/specs/2026-07-18-service-mvp/api-spec.md` | T1 |
| REQ-04 | AC-04 | TC-05, TC-06, TC-07 | api-spec.md | T2 |
| REQ-05 | AC-05 | TC-08 | api-spec.md | T2 |
| REQ-06 | AC-06 | TC-09, TC-10 | api-spec.md | T2 |
| REQ-07 | AC-07 | TC-11, TC-12 | api-spec.md, ui-spec.md | T2 |
| (UI 공통) | AC-04, AC-05 | TC-13 | ui-spec.md | T2 |
| (문서 게이트) | 전체 | TC-14 | `.agent-os/ai-readiness.yml` | T1, T2 |

모든 REQ·AC·TC가 최소 한 번 연결되어 있다. 공개 API/UI 계약은 이 spec의 `api-spec.md`·`ui-spec.md`와 정본인 `.agent-os/archive/specs/2026-07-18-service-mvp/api-spec.md`를 기준으로 하며, T1은 내부 저장소 변경만 있어 공개 계약을 추가하지 않는다.
