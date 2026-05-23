# JD 링크 수집 안정화 MVP 추적성

| Requirement | Acceptance Criteria | Test Cases | Contract |
| --- | --- | --- | --- |
| `REQ-01` 사람인 JD 본문 추출 | `AC-01` | `TC-01` | `api-spec.md` |
| `REQ-02` 잘못된 성공 반환 방지 | `AC-02`, `AC-03` | `TC-02`, `TC-03` | `api-spec.md` |
| `REQ-03` 안전한 외부 URL 수집 | `AC-04`, `AC-05` | `TC-04`, `TC-05`, `TC-06` | `api-spec.md` |

## 연결 문서

- 기존 JD 입력 spec: `.agent-os/specs/2026-05-23-0900-jd-intake-mvp/`
- JD 매칭 spec: `.agent-os/specs/2026-05-23-1500-local-ai-jd-match-mvp/`
- 백엔드 구현 대상: `backend/src/main/java/com/jdsnack/jd/`
