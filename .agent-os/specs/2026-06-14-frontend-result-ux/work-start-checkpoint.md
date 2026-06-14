# Work Start Checkpoint

## 작업 유형

- Standard

## 목표

- "새로운 분석 시작" 페이지에 결과 내보내기(다운로드/인쇄)와 입력 자동저장·복원을 추가하기 위한 요구사항·UI 계약·검증 기준을 고정한다. Codex 토큰 부재 시 Claude가 직접 구현.

## 읽을 문서

- `AGENTS.md`, `CLAUDE.md`
- `.agent-os/specs/2026-06-14-frontend-result-ux/requirements.md`
- `.agent-os/specs/2026-06-14-frontend-result-ux/acceptance-criteria.md`
- `.agent-os/specs/2026-06-14-frontend-result-ux/test-scenarios.md`
- `.agent-os/specs/2026-06-14-frontend-result-ux/traceability.md`
- `.agent-os/specs/2026-06-14-frontend-result-ux/ui-spec.md`
- `.agent-os/specs/2026-06-14-frontend-result-ux/api-spec.md`

## 변경 허용

- 문서 PR: `.agent-os/specs/**`, `.agent-os/archive/specs/**`, `.agent-os/standards/index.yml`, `AGENTS.md`
- 구현 PR: `frontend/**`

## 변경 금지

- 백엔드 API 계약 변경, Gemini 응답 계약 변경
- 결과 복사·다크모드 등 범위 밖 기능
- 이력서 파일·추출 본문의 로컬 저장, 비밀키 프론트 저장, `.env` 읽기/수정

## 검증

- 문서 PR: Agent OS 문서 인덱스 검증, traceability 매핑 확인
- 구현 PR: `cd frontend && npm run lint`, `npm test`, `npm run build`, `npm run test:e2e`. `fixture` 모드 수동 확인.
