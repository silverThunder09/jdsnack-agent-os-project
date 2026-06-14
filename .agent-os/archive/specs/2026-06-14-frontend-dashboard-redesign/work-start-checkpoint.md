# Work Start Checkpoint

## 작업 유형

- Standard

## 목표

- 3단계 위저드 화면을 대시보드형으로 전면 재설계하기 위한 요구사항·UI 계약·검증 기준을 문서로 고정하고, Codex 구현의 진입점을 만든다.

## 읽을 문서

- `AGENTS.md`
- `.agent-os/specs/2026-06-14-frontend-dashboard-redesign/requirements.md`
- `.agent-os/specs/2026-06-14-frontend-dashboard-redesign/acceptance-criteria.md`
- `.agent-os/specs/2026-06-14-frontend-dashboard-redesign/test-scenarios.md`
- `.agent-os/specs/2026-06-14-frontend-dashboard-redesign/traceability.md`
- `.agent-os/specs/2026-06-14-frontend-dashboard-redesign/ui-spec.md`

## 변경 허용

- 이번 문서 PR: `.agent-os/specs/**`, `.agent-os/archive/specs/**`, `.agent-os/standards/index.yml`, `AGENTS.md`
- 구현 PR(Codex): `frontend/**`

## 변경 금지

- 백엔드 API 계약 변경, Gemini 응답 계약 변경
- diagnose/match 기능 통합 등 기능 재정의
- 인증/프로필 기능 신규 추가
- `.env` 읽기 또는 수정

## 검증

- 문서 PR: Agent OS 문서 인덱스 검증, traceability 매핑 확인
- 구현 PR: `cd frontend && npm run lint`, `npm test -- --run`, `npm run build`. `fixture` 모드 수동 확인.
