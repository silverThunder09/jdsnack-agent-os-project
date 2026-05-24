# 커스텀 에이전트 TOML 계약

## 파일 위치

- 프로젝트용 커스텀 에이전트: `.codex/agents/*.toml`
- 개인용 커스텀 에이전트: `~/.codex/agents/*.toml`

## 최소 TOML 필드

```toml
name = "Agent Name"
description = "Short responsibility summary."
instructions = """
Detailed role instructions.
"""
```

## 에이전트 목록

- `spec-steward.toml`
- `backend-engineer.toml`
- `frontend-engineer.toml`
- `qa-reviewer.toml`
- `security-reviewer.toml`
- `devops-steward.toml`
- `release-captain.toml`
