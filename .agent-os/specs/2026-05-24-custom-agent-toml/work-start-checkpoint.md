# 커스텀 에이전트 TOML 전환 작업 시작 체크포인트

## 작업 등급

- `Standard`
- 이유: 구현 코드는 바꾸지 않지만 에이전트 운영 기준과 진입 문서를 바꾼다.

## 변경 허용

- `.codex/agents/**`
- `.agent-os/agents/**`
- `.agent-os/specs/**`
- `.agent-os/standards/sub-agent-operations.md`
- `.agent-os/standards/index.yml`
- `AGENTS.md`
- `README.md`

## 변경 금지

- backend/**
- frontend/**
- .env
- compose.yaml

## 완료 조건

- TOML 에이전트 7개가 존재한다.
- 구 MD 프롬프트가 제거된다.
- AGENTS.md가 실제 TOML 위치를 안내한다.
