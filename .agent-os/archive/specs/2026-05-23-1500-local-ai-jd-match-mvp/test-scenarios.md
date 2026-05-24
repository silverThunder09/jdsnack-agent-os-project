# 테스트 시나리오

- `TC-01` `ai-local` 모드의 유효한 JD 비교 요청은 `200`과 JD 매칭 결과를 반환한다.
- `TC-02` `stub` 모드의 유효한 JD 비교 요청은 기존 규칙 기반 결과를 반환한다.
- `TC-03` JD가 비어 있으면 `EMPTY_JD`를 반환한다.
- `TC-04` Gemini API 키가 없으면 `GEMINI_API_KEY_MISSING`을 반환한다.
- `TC-05` Gemini 응답 형식이 깨지면 `GEMINI_API_RESPONSE_INVALID`를 반환한다.
- `TC-06` 프론트는 Gemini 실패 시 `JD AI 매칭을 완료하지 못했습니다`를 보여준다.
