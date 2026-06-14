# Work Start Checkpoint

## 작업 유형

- Standard

## 목표

- 대시보드 화면을 목업 기반 SaaS 셸로 재설계하기 위한 요구사항·UI 계약·검증 기준을 문서로 고정하고, Codex 구현의 진입점을 만든다.

## 읽을 문서

- `AGENTS.md`
- `.agent-os/specs/2026-06-14-frontend-saas-shell-redesign/requirements.md`
- `.agent-os/specs/2026-06-14-frontend-saas-shell-redesign/acceptance-criteria.md`
- `.agent-os/specs/2026-06-14-frontend-saas-shell-redesign/test-scenarios.md`
- `.agent-os/specs/2026-06-14-frontend-saas-shell-redesign/traceability.md`
- `.agent-os/specs/2026-06-14-frontend-saas-shell-redesign/ui-spec.md`

## 변경 허용

- 이번 문서 PR: `.agent-os/specs/**`, `.agent-os/archive/specs/**`, `.agent-os/standards/index.yml`, `AGENTS.md`
- 구현 PR(Codex): `frontend/**`

## 변경 금지

- 백엔드 API 계약 변경, Gemini 응답 계약 변경
- ATS·키워드 구조화·첨삭·키워드 사전·템플릿·요금제 등 신규 기능
- 인증/프로필/내역 기능 신규 추가
- 제품명 변경, `.env` 읽기 또는 수정

## 검증

- 문서 PR: Agent OS 문서 인덱스 검증, traceability 매핑 확인
- 구현 PR: `cd frontend && npm run lint`, `npm test`, `npm run build`, `npm run test:e2e`. `fixture` 모드 수동 확인.
