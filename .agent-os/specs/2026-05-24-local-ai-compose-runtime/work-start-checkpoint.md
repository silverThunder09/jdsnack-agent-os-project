# 로컬 AI Compose 런타임 작업 시작 체크포인트

## 작업 등급

- `High-risk`
- 이유: `.env`, Gemini 런타임 모드, compose 실행 기준에 영향을 준다.

## 변경 허용

- `compose.yaml`
- `.env.example`
- `README.md`
- `AGENTS.md`
- `.agent-os/specs/2026-05-24-local-ai-compose-runtime/**`
- `.agent-os/standards/index.yml`

## 변경 금지

- `.env` 읽기 또는 수정
- Gemini 프롬프트 변경
- 백엔드 provider 로직 변경
- 프론트 결과 UI 변경

## 검증

- `docker compose config --no-interpolate`
- `.env` 미추적 확인
- PR CI 전체 확인
