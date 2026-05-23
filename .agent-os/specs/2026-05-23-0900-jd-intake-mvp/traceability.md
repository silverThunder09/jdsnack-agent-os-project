# 추적 매핑표

| 요구사항 | 수용 기준 | 테스트 시나리오 | 계약 / 설계 문서 |
|---|---|---|---|
| `REQ-01` JD 텍스트 입력 | `AC-01`, `AC-03` | `TC-01`, `TC-02`, `TC-03` | `ui-spec.md`, `api-spec.md` |
| `REQ-02` JD 링크 선택 입력 | `AC-02`, `AC-04` | `TC-04`, `TC-05` | `ui-spec.md`, `api-spec.md` |
| `REQ-03` JD 입력 검증 | `AC-03`, `AC-04` | `TC-02`, `TC-03`, `TC-04` | `api-spec.md` |
| `REQ-04` 비교 API 응답 구조 제공 | `AC-05`, `AC-06` | `TC-06`, `TC-07` | `api-spec.md` |
| `REQ-05` 화면 흐름 연결 | `AC-07` | `TC-01`, `TC-05`, `TC-07` | `ui-spec.md`, `plan.md` |

## 사용 규칙

- JD 입력 필드가 바뀌면 `requirements.md`, `acceptance-criteria.md`, `api-spec.md`, `ui-spec.md`, `traceability.md`를 함께 갱신한다.
- 링크 자동 수집을 도입하면 새 `REQ`, `AC`, `TC`를 추가하고 이번 MVP 범위와 분리한다.
