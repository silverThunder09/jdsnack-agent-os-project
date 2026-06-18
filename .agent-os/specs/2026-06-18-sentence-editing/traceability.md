# 문장 첨삭(맞춤 첨삭, 문장 단위) 추적성

| Requirement | Acceptance Criteria | Test Cases | Contract |
| --- | --- | --- | --- |
| `REQ-01` 신규 전용 엔드포인트와 응답 계약 | `AC-01` | `TC-01`, `TC-02` | `api-spec.md` |
| `REQ-02` 모드 전체 동일 계약(stub/fixture/ai-local) | `AC-02`, `AC-03` | `TC-01`, `TC-02`, `TC-03`, `TC-04` | `api-spec.md` |
| `REQ-03` 검증·에러 정책 재사용 | `AC-04` | `TC-05` | `api-spec.md` |
| `REQ-04` 프론트 sentence 옵션 해금 + 결과 패널 | `AC-05`, `AC-06` | `TC-06`, `TC-07`, `TC-08` | `ui-spec.md` |
| `REQ-05` 통합 검증 게이트와의 정합 | `AC-07` | `TC-09` | `ui-spec.md`, `api-spec.md` |
