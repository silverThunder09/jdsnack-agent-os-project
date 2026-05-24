# 커스텀 에이전트 TOML 전환 계획

## Summary

문서 역할 프롬프트였던 `.agent-os/agents/*.md`를 제거하고, 실제 Codex 프로젝트 커스텀 에이전트인 `.codex/agents/*.toml`로 전환한다.

## 변경 범위

- `.codex/agents/*.toml` 추가
- `.agent-os/agents/*.md` 제거
- `AGENTS.md`, `README.md`, `sub-agent-operations.md` 참조 최신화
- 활성 spec 최신화

## 제외 범위

- 백엔드/프론트 구현 변경
- PR Review Gate 자동 에이전트 실행화
- 외부 플러그인 설치
