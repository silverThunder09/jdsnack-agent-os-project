# 사람인 JD 이미지 OCR 폴백 추적성

| Requirement | Acceptance Criteria | Test Cases | Contract |
| --- | --- | --- | --- |
| `REQ-01` 텍스트 추출 실패 시에만 동작하는 OCR 폴백 훅 | `AC-01`, `AC-02` | `TC-01`, `TC-02` | `api-spec.md` |
| `REQ-02` JD 이미지 탐지 | `AC-03` | `TC-02`, `TC-03` | `api-spec.md` |
| `REQ-03` SSRF 보안 | `AC-04` | `TC-04`, `TC-05` | `api-spec.md` |
| `REQ-04` OCR 추상화(테스트 가능성) | `AC-05` | `TC-06` | `api-spec.md` |
| `REQ-05` GEMINI_API_KEY 의존·graceful fallback | `AC-06` | `TC-07`, `TC-08` | `api-spec.md` |
| `REQ-06` 응답 계약(fetchMode image-ocr) | `AC-07` | `TC-09` | `api-spec.md` |
| `REQ-07` 프론트 무변경 | `AC-07` | `TC-09` | `ui-spec.md` |

> 변경 이력: [2026-06-20] 신규 활성 spec 작성. 매핑 끊김 없음. (식별자 토큰은 변경 이력 줄에 두지 않음 — CI awk 파싱 보호.)
