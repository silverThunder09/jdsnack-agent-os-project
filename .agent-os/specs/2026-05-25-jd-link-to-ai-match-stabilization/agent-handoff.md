# Agent Handoff

## Feature

- 기능명: JD 링크 to AI 매칭 안정화

## Current Phase

- Backend

## Source Documents

- `requirements.md`
- `acceptance-criteria.md`
- `api-spec.md`
- `test-scenarios.md`
- `traceability.md`
- `plan.md`

## Changed Files

- `backend/src/main/java/com/jdsnack/jd/JdFetchService.java`
- `backend/src/test/java/com/jdsnack/jd/JdFetchServiceTest.java`
- `.agent-os/specs/2026-05-25-jd-link-to-ai-match-stabilization/agent-handoff.md`

## Decisions Made

- 기존 `POST /api/jd/fetch` 계약은 유지한다.
- 사람인 relay view 정적 페이지가 개인정보/AI매치/푸터성 내용만 반환하면 `view-ajax` fallback을 먼저 시도한다.
- `view-ajax`에 상세 iframe이 없거나 JD 본문을 추출하지 못하면 `rec_idx` 기반 `view-detail` 직접 조회를 추가 시도한다.
- 직접 상세 조회도 실패하면 기존 fallback 실패 원인을 유지한다.

## Change Requests

- `QA Reviewer`: 사람인 실제 링크에서 JD 본문 자동 채움과 실패 시 직접 입력 복구 흐름을 확인한다.
- `Frontend Engineer`: 실패 메시지는 기존처럼 `JD 본문을 직접 붙여넣어 주세요.` 기준을 유지한다.

## Open Questions

- 없음

## Risks

- 사람인 HTML 구조가 다시 변경되면 fixture 기준은 통과해도 실제 링크 성공률은 변동될 수 있다.
- 브라우저 렌더링, 로그인 우회, anti-bot 우회는 이번 범위에 포함하지 않는다.
- 실제 외부 사이트 네트워크 상태는 로컬/CI 환경에 따라 다를 수 있다.

## Next Agent

- `QA Reviewer`
