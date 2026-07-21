# 분석 결과 리포트 내보내기 추적성

| 요구사항 | 수용 기준 | 테스트 | 계약 | 티켓 |
|---|---|---|---|---|
| REQ-01 | AC-01 | TC-01 (`AnalysisHistoryView`) | ui-spec.md | T1 |
| REQ-02 | AC-02 | TC-02 (기존 상세 조회 계약) | api-spec.md | T1 |
| REQ-03 | AC-03 | TC-03 (`analysisUtils.test.ts`) | api-spec.md, ui-spec.md | T1 |
| REQ-04 | AC-04 | TC-04 (`analysisUtils.test.ts`, 다운로드 구현) | ui-spec.md | T1 |
| REQ-05 | AC-05 | TC-05 (`analysisUtils.test.ts`, 상태별 UI) | ui-spec.md | T1 |
| REQ-06 | AC-06 | TC-06 (정적 품질 게이트) | api-spec.md | T1 |

모든 REQ·AC·TC가 최소 한 번 연결되어 있으며, API/UI 계약은 이 spec의 `api-spec.md`·`ui-spec.md`와 정본인 `.agent-os/archive/specs/2026-07-18-service-mvp/api-spec.md`를 기준으로 합니다.
