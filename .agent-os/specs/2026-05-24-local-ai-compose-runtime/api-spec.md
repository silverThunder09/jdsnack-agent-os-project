# 로컬 AI Compose 런타임 계약

## Runtime Contract

`docker compose up --build`는 백엔드를 `ai-local` 모드로 실행한다.

```yaml
JDSNACK_DIAGNOSIS_MODE: ${JDSNACK_DIAGNOSIS_MODE:-ai-local}
```

CI smoke는 외부 키 없이 안정적으로 검증하기 위해 `JDSNACK_DIAGNOSIS_MODE=fixture`로 override한다.

## Environment Contract

루트 `.env`에서 아래 값을 사용할 수 있다.

```env
GEMINI_API_KEY=replace-with-local-secret
GEMINI_MODEL=gemini-2.5-flash
```

## Public API 영향

- 새 API는 추가하지 않는다.
- 기존 `POST /api/diagnose`, `POST /api/diagnose/file`, `POST /api/match/preview`가 `ai-local` provider를 사용한다.
- 키가 없으면 기존 Gemini 오류 계약을 따른다.
