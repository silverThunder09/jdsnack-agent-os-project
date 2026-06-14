# Work Start Checkpoint

## 작업 유형

- Standard

## 목표

- 이력서 기반 모의 면접 질문 생성 기능의 요구사항·계약·검증 기준을 문서로 고정하고, 이후 Codex 구현의 진입점을 만든다.

## 읽을 문서

- `AGENTS.md`
- `.agent-os/specs/2026-06-13-resume-mock-interview-questions/requirements.md`
- `.agent-os/specs/2026-06-13-resume-mock-interview-questions/acceptance-criteria.md`
- `.agent-os/specs/2026-06-13-resume-mock-interview-questions/test-scenarios.md`
- `.agent-os/specs/2026-06-13-resume-mock-interview-questions/traceability.md`
- `.agent-os/specs/2026-06-13-resume-mock-interview-questions/api-spec.md`
- `.agent-os/specs/2026-06-13-resume-mock-interview-questions/ui-spec.md`

## 변경 허용

- 이번 문서 PR: `.agent-os/specs/**`, `.agent-os/archive/specs/**`, `.agent-os/standards/index.yml`, `AGENTS.md`
- 구현 PR(Codex): `backend/**`, `frontend/**`

## 변경 금지

- 기존 `diagnose`/`match`/`jd/fetch` API 계약 변경
- 새 외부 사이트 수집 또는 브라우저 렌더링 수집 확장
- `.env` 읽기 또는 수정

## 검증

- 문서 PR: Agent OS 문서 인덱스 검증, traceability 매핑 확인
- 구현 PR: `cd backend && ./gradlew test bootJar`, `cd frontend && npm test -- --run`, `cd frontend && npm run build`
