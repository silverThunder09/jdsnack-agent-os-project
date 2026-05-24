# 커스텀 에이전트 TOML 전환 요구사항

## `REQ-01` 실제 Codex 커스텀 에이전트 정의

- 프로젝트는 `.codex/agents/*.toml` 파일로 커스텀 에이전트를 정의해야 한다.
- 기존 `.agent-os/agents/*.md` 역할 문서는 중복이므로 제거해야 한다.

## `REQ-02` 역할과 책임 최신화

- 각 에이전트는 책임, 허용 변경, 금지 변경, 검토 기준을 명확히 가져야 한다.
- 역할 기준은 현재 프로젝트 상태와 최신 활성 spec 운영 방식에 맞아야 한다.

## `REQ-03` 진입 문서 최신화

- `AGENTS.md`는 커스텀 에이전트 위치를 `.codex/agents/`로 안내해야 한다.
- 활성 spec은 항상 최신 기획 1개만 유지한다.

## `REQ-04` 쓰레드별 중복 호출 방지

- 계획 쓰레드는 기본적으로 `Spec Steward`만 호출해야 한다.
- 개발 쓰레드는 변경 대상에 따라 `Backend Engineer` 또는 `Frontend Engineer` 중 하나를 기본 호출해야 한다.
- 검증 쓰레드는 기본적으로 `QA Reviewer`만 호출해야 한다.
- `Security Reviewer`, `DevOps Steward`, `Release Captain`은 해당 위험이 실제로 있을 때만 조건부로 호출해야 한다.
- handoff가 있으면 다음 쓰레드는 handoff를 먼저 읽고 같은 검토를 반복하지 않아야 한다.
