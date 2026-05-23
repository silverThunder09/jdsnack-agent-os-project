# Agent Handoff

## Feature

- 기능명: 로컬 전용 Gemini JD 매칭 MVP

## Current Phase

- Backend / Frontend / QA

## Source Documents

- `.agent-os/specs/2026-05-23-1500-local-ai-jd-match-mvp/requirements.md`
- `.agent-os/specs/2026-05-23-1500-local-ai-jd-match-mvp/acceptance-criteria.md`
- `.agent-os/specs/2026-05-23-1500-local-ai-jd-match-mvp/api-spec.md`
- `.agent-os/specs/2026-05-23-1500-local-ai-jd-match-mvp/test-scenarios.md`
- `.agent-os/specs/2026-05-23-1500-local-ai-jd-match-mvp/traceability.md`

## Changed Files

- `backend/src/main/java/com/jdsnack/match/GeminiMatchPreviewProvider.java`
- `backend/src/main/java/com/jdsnack/match/MatchPreviewService.java`
- `backend/src/test/java/com/jdsnack/match/MatchPreviewAiLocalModeControllerTest.java`
- `frontend/src/hooks/useMatchPreview.ts`
- `frontend/src/App.tsx`

## Decisions Made

- JD 매칭도 `ai-local`에서만 실제 Gemini 응답을 사용한다.
- `stub`와 `fixture`는 기존 규칙 기반 JD 미리보기를 유지한다.
- 프론트는 Gemini 실패를 일반 입력 검증 실패와 다른 제목으로 노출한다.

## Change Requests

- `QA Reviewer`: `ai-local` JD 매칭 성공/실패와 규칙 기반 fallback 회귀를 다시 확인해주세요.
- `Security Reviewer`: JD 매칭용 Gemini 프롬프트와 응답 로그가 민감 정보를 과출력하지 않는지 확인해주세요.

## Open Questions

- 없음

## Risks

- 실제 Gemini JD 매칭 smoke는 `GEMINI_API_KEY`가 준비된 로컬 환경에서만 검증 가능하다.

## Next Agent

- QA Reviewer
