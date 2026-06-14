# Work Start Checkpoint

## 작업 유형

- Standard

## 목표

- 목업 "새로운 분석 시작"대로 home을 3단계 입력 페이지 + 결과 화면으로 재구성하기 위한 요구사항·UI 계약·검증 기준을 고정하고, 구현 진입점을 만든다. Codex 토큰 부재 시 Claude가 직접 구현한다.

## 읽을 문서

- `AGENTS.md`, `CLAUDE.md`
- `.agent-os/specs/2026-06-14-frontend-analysis-start-page/requirements.md`
- `.agent-os/specs/2026-06-14-frontend-analysis-start-page/acceptance-criteria.md`
- `.agent-os/specs/2026-06-14-frontend-analysis-start-page/test-scenarios.md`
- `.agent-os/specs/2026-06-14-frontend-analysis-start-page/traceability.md`
- `.agent-os/specs/2026-06-14-frontend-analysis-start-page/ui-spec.md`
- `.agent-os/specs/2026-06-14-frontend-analysis-start-page/api-spec.md`

## 변경 허용

- 문서 PR: `.agent-os/specs/**`, `.agent-os/archive/specs/**`, `.agent-os/standards/index.yml`, `AGENTS.md`, `CLAUDE.md`
- 구현 PR: `frontend/**`

## 변경 금지

- 백엔드 API 계약 변경, Gemini 응답 계약 변경
- ATS·문장 첨삭·키워드 분석 등 미지원 기능의 실제 구현
- 인증/프로필/내역/요금제 기능 신규 추가, 제품명 변경, `.env` 읽기/수정

## 검증

- 문서 PR: Agent OS 문서 인덱스 검증, traceability 매핑 확인
- 구현 PR: `cd frontend && npm run lint`, `npm test`, `npm run build`, `npm run test:e2e`. `fixture` 모드 수동 확인.
