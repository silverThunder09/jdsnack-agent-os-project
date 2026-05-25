# Agent Handoff

## Feature

- 기능명: 사람인 JD 수집 안정화

## Current Phase

- Spec

## Source Documents

- `requirements.md`
- `acceptance-criteria.md`
- `api-spec.md`
- `test-scenarios.md`
- `traceability.md`
- `plan.md`

## Changed Files

- `.agent-os/specs/2026-05-24-saramin-jd-scraping-stabilization/**`
- `.agent-os/archive/specs/2026-05-24-custom-agent-toml/**`
- `AGENTS.md`
- `.agent-os/standards/index.yml`
- `README.md`

## Decisions Made

- `POST /api/jd/fetch` 계약은 유지한다.
- 사람인 정적 HTML 수집만 이번 안정화 대상으로 둔다.
- `200 OK`는 HTTP 성공이 아니라 JD 본문 품질 통과를 의미한다.
- 개인정보/푸터/AI매치/오류 페이지는 가짜 성공으로 보고 실패 처리한다.
- 개발 검증은 실제 외부 사이트가 아니라 HTML fixture를 기준으로 한다.

## Change Requests

- `Backend Engineer`: 기존 `JdHtmlExtractor`에서 사람인 selector와 노이즈 차단 로직을 스펙 기준으로 안정화한다.
- `Backend Engineer`: 사람인 정상, AI매치 노이즈, `dd` 본문, 개인정보/푸터, 오류 페이지, 짧은 본문 fixture 테스트를 확인한다.

## Open Questions

- 없음

## Risks

- 실제 사람인 HTML은 언제든 바뀔 수 있으므로 fixture 기준 통과와 실시간 링크 성공이 항상 같지는 않을 수 있다.
- anti-bot 또는 로그인 필요 페이지는 이번 범위에서 제외되어 자동 수집 실패로 안내해야 한다.

## Next Agent

- `Backend Engineer`
