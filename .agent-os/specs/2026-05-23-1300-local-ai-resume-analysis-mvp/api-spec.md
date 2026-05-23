# API 명세서

## `POST /api/diagnose`

- 요청:

```json
{
  "resumeText": "string"
}
```

- `ai-local` 성공 응답:

```json
{
  "success": true,
  "data": {
    "score": 84,
    "summary": "백엔드 중심 역량은 분명하지만 성과 수치가 더 보강되면 좋습니다.",
    "strengths": ["Spring Boot API 설계 경험이 잘 드러납니다."],
    "improvements": ["프로젝트 결과를 수치로 보강해 주세요."],
    "sourceText": "string"
  },
  "timestamp": "string"
}
```

## `POST /api/diagnose/file`

- 입력 파일: `PDF`, `DOCX`
- 추출 텍스트를 기준으로 같은 응답 구조를 반환한다.

## 에러 코드

- `EMPTY_RESUME`
- `TEXT_TOO_SHORT`
- `TEXT_TOO_LONG`
- `UNSUPPORTED_FILE_TYPE`
- `FILE_TEXT_EXTRACTION_FAILED`
- `GEMINI_API_KEY_MISSING`
- `GEMINI_API_REQUEST_FAILED`
- `GEMINI_API_RESPONSE_INVALID`

## 모드

- `stub`
- `fixture`
- `ai-local`
