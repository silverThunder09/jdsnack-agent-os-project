# 수용 기준

## `AC-01` ai-local 모드 선택

- `jdsnack.diagnosis.mode=ai-local`일 때 Gemini provider가 선택되어야 한다.

## `AC-02` 텍스트 AI 분석 성공

- 유효한 이력서 텍스트 요청은 `200` AI 분석 결과를 반환해야 한다.
- 응답은 `score`, `summary`, `strengths`, `improvements`, `sourceText`를 포함해야 한다.

## `AC-03` 파일 AI 분석 성공

- 유효한 PDF/DOCX 업로드 요청은 `200` AI 분석 결과를 반환해야 한다.

## `AC-04` Gemini 실패 처리

- API key 누락은 `GEMINI_API_KEY_MISSING`으로 처리해야 한다.
- 호출 실패는 `GEMINI_API_REQUEST_FAILED`로 처리해야 한다.
- 응답 파싱 실패는 `GEMINI_API_RESPONSE_INVALID`로 처리해야 한다.

## `AC-05` 기존 모드 유지

- `stub`는 기존 준비중 응답을 유지해야 한다.
- `fixture`는 기존 정적 결과 응답을 유지해야 한다.

## `AC-06` 사용자 키 입력 UI 금지

- 프론트에 Gemini 키 설정 UI를 추가하지 않아야 한다.
