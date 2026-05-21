# 추적 매핑표

| 요구사항 | 수용 기준 | 테스트 시나리오 | 계약 / 설계 문서 |
|---|---|---|---|
| `REQ-01` 이력서 텍스트 입력 | `AC-01`, `AC-06` | `TC-01` | `api-spec.md`, `ui-spec.md` |
| `REQ-02` 입력 검증 | `AC-02`, `AC-03`, `AC-04` | `TC-02`, `TC-03`, `TC-04` | `api-spec.md`, `ui-spec.md` |
| `REQ-03` AI 미연동 안내 | `AC-01`, `AC-06` | `TC-01` | `api-spec.md`, `ui-spec.md`, `architecture.md` |
| `REQ-04` 단순한 운영 구조 | `AC-05`, `AC-07` | `TC-05`, `TC-06` | `architecture.md`, `plan.md`, `standards.md` |

## 사용 규칙

- 요구사항이 바뀌면 이 표를 먼저 갱신합니다.
- 테스트가 추가되면 대응하는 `REQ`와 `AC`를 연결합니다.
- 2차 MVP에서 Gemini 연동을 추가할 때는 `REQ`, `AC`, `TC`를 새로 추가합니다.
