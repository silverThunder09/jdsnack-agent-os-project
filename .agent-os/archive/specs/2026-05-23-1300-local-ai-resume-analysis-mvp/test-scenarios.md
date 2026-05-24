# 테스트 시나리오

## `TC-01` 텍스트 AI 분석 성공

- 유효한 이력서 텍스트 입력
- 기대 결과: `200`, 점수/요약/강점/개선 포인트 반환

## `TC-02` 파일 AI 분석 성공

- 유효한 PDF 또는 DOCX 업로드
- 기대 결과: `200`, 점수/요약/강점/개선 포인트 반환

## `TC-03` API key 누락

- `ai-local` 모드에서 키 없이 실행
- 기대 결과: `GEMINI_API_KEY_MISSING`

## `TC-04` Gemini 호출 실패

- 외부 호출 실패 또는 비정상 상태 코드
- 기대 결과: `GEMINI_API_REQUEST_FAILED`

## `TC-05` Gemini 응답 파싱 실패

- JSON이 아니거나 필수 필드 누락
- 기대 결과: `GEMINI_API_RESPONSE_INVALID`

## `TC-06` 기존 모드 회귀 없음

- `stub`와 `fixture` 요청 확인
- 기대 결과: 기존 응답 유지
