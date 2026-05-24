# 수용 기준

- `AC-01` `ai-local` 모드에서 유효한 JD 비교 요청은 `200`과 JD 매칭 결과를 반환해야 한다.
- `AC-02` 응답에는 `matchingScore`, `summary`, `strengths`, `gaps`, `suggestions`가 모두 포함되어야 한다.
- `AC-03` `stub` 또는 `fixture` 모드에서는 기존 규칙 기반 JD 미리보기가 계속 동작해야 한다.
- `AC-04` `GEMINI_API_KEY_MISSING`은 `503`, `GEMINI_API_REQUEST_FAILED`와 `GEMINI_API_RESPONSE_INVALID`는 `502`로 반환해야 한다.
- `AC-05` 프론트는 Gemini 실패 시 `JD AI 매칭을 완료하지 못했습니다` 제목으로 오류를 보여줘야 한다.
