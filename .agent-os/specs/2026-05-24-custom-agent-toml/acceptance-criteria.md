# 커스텀 에이전트 TOML 전환 수용 기준

## `AC-01` TOML 에이전트 존재

- `.codex/agents/`에 7개 에이전트 TOML이 존재해야 한다.
- 각 TOML은 `name`, `description`, `instructions`를 포함해야 한다.

## `AC-02` 중복 MD 프롬프트 제거

- `.agent-os/agents/*.md`는 더 이상 남아 있지 않아야 한다.
- 역할 운영 표준은 `.agent-os/standards/sub-agent-operations.md`에 남긴다.

## `AC-03` AGENTS 최신화

- `AGENTS.md`는 `.codex/agents/`를 실제 커스텀 에이전트 위치로 안내해야 한다.
- `.agent-os/agents/`를 서브 에이전트 프롬프트 위치로 안내하지 않아야 한다.
