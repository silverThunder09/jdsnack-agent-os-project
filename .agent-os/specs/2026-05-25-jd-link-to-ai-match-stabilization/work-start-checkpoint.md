# Work Start Checkpoint

## 작업 유형

- Standard

## 목표

- JD 링크 수집 성공/실패 흐름이 AI 매칭 리포트까지 끊기지 않도록 문서 기준을 고정한다.

## 읽을 문서

- `AGENTS.md`
- `.agent-os/specs/2026-05-25-jd-link-to-ai-match-stabilization/requirements.md`
- `.agent-os/specs/2026-05-25-jd-link-to-ai-match-stabilization/acceptance-criteria.md`
- `.agent-os/specs/2026-05-25-jd-link-to-ai-match-stabilization/test-scenarios.md`
- `.agent-os/specs/2026-05-25-jd-link-to-ai-match-stabilization/traceability.md`
- `.agent-os/specs/2026-05-25-jd-link-to-ai-match-stabilization/api-spec.md`
- `.agent-os/specs/2026-05-25-jd-link-to-ai-match-stabilization/ui-spec.md`

## 변경 허용

- 이번 문서 PR: `.agent-os/specs/**`, `AGENTS.md`, `.agent-os/standards/index.yml`, `README.md`
- 개발 쓰레드: 관련 `frontend/**`, 필요 시 `backend/**`

## 변경 금지

- 새 API 추가
- Gemini 응답 계약 변경
- 잡코리아/원티드/로그인 필요 페이지 수집 확장
- `.env` 읽기 또는 수정

## 검증

- 문서 PR: Agent OS 문서 인덱스 검증, traceability 매핑 확인
- 개발 PR: `cd frontend && npm test -- --run`, `cd frontend && npm run build`
- 필요 시 백엔드 영향이 있으면 `cd backend && ./gradlew test bootJar`
