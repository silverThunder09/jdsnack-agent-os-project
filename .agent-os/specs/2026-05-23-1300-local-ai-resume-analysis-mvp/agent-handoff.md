# Agent Handoff

## Feature

- 기능명: 로컬 전용 Gemini 이력서 분석 MVP

## Current Phase

- Backend / Frontend

## Source Documents

- `.agent-os/specs/2026-05-23-1300-local-ai-resume-analysis-mvp/requirements.md`
- `.agent-os/specs/2026-05-23-1300-local-ai-resume-analysis-mvp/acceptance-criteria.md`
- `.agent-os/specs/2026-05-23-1300-local-ai-resume-analysis-mvp/api-spec.md`
- `.agent-os/specs/2026-05-23-1300-local-ai-resume-analysis-mvp/test-scenarios.md`
- `.agent-os/specs/2026-05-23-1300-local-ai-resume-analysis-mvp/traceability.md`

## Changed Files

- `backend/src/test/java/com/jdsnack/diagnose/DiagnoseAiLocalModeControllerTest.java`
- `frontend/src/components/ResultPanel.tsx`
- `frontend/src/App.css`
- `frontend/src/App.test.tsx`

## Decisions Made

- `ai-local` 성공 응답의 `sourceText`는 프론트 결과 패널에서 확인 가능하게 둡니다.
- Gemini 실패는 `GEMINI_API_KEY_MISSING`, `GEMINI_API_REQUEST_FAILED`, `GEMINI_API_RESPONSE_INVALID`로 분리 유지합니다.
- `stub`, `fixture`, `ai-local` 모드는 모두 같은 진단 흐름 UI에서 처리합니다.

## Change Requests

- `QA Reviewer`: `ai-local` 모드에서 키 누락, 요청 실패, 응답 파싱 실패 시나리오를 실제 실행 기준으로 다시 확인해주세요.
- `DevOps Steward`: 로컬 AI 모드 실행 가이드를 CI 대상이 아닌 수동 운영 문서로 정리해주세요.

## Open Questions

- 없음

## Risks

- 실제 Gemini 실호출 검증은 `GEMINI_API_KEY`가 준비된 로컬 환경에서만 가능합니다.
- 기본 런타임 모드는 여전히 `stub`이므로, `ai-local` 테스트 시 실행 인자를 명시해야 합니다.

## Next Agent

- QA Reviewer
