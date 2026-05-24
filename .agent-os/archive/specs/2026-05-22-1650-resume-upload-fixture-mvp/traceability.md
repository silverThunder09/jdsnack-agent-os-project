# 추적 매핑표

| 요구사항 | 수용 기준 | 테스트 시나리오 | 계약 / 설계 문서 |
|---|---|---|---|
| `REQ-01` 다중 입력 방식 | `AC-01`, `AC-02`, `AC-03` | `TC-01`, `TC-02`, `TC-03` | `ui-spec.md` |
| `REQ-01` 다중 입력 방식 | `AC-01`, `AC-02`, `AC-03` | `TC-01`, `TC-02`, `TC-03` | `api-spec.md` |
| `REQ-02` 파일 텍스트 추출 | `AC-02`, `AC-03`, `AC-04` | `TC-02`, `TC-03`, `TC-04`, `TC-05` | `api-spec.md` |
| `REQ-03` fixture 분석 결과 반환 | `AC-01`, `AC-02`, `AC-03`, `AC-05` | `TC-01`, `TC-02`, `TC-03`, `TC-06` | `api-spec.md`, `fixture-data-model.md` |
| `REQ-04` 결과 화면 검증 | `AC-05` | `TC-01`, `TC-02`, `TC-03` | `ui-spec.md` |
| `REQ-05` 운영 모드 분리 | `AC-06`, `AC-07` | `TC-07` | `architecture.md` |
| `REQ-04` 결과 화면 검증 | `AC-05` | `TC-08`, `TC-09` | `frontend/e2e/upload-and-jd-preview.spec.ts` |

## 사용 규칙

- fixture 결과 구조가 바뀌면 `api-spec.md`, `fixture-data-model.md`, `ui-spec.md`, `traceability.md`를 함께 갱신한다.
- 업로드 방식이 늘어나면 `REQ`, `AC`, `TC`를 같은 번호 체계로 추가한다.
