# API 명세서

## `POST /api/match/preview`

### 모드별 동작

| 모드 | 동작 |
|---|---|
| `stub` | 규칙 기반 키워드 비교 결과 반환 |
| `fixture` | 규칙 기반 키워드 비교 결과 반환 |
| `ai-local` | Gemini 기반 JD 매칭 결과 반환 |

### 요청

```json
{
  "resumeSource": {
    "type": "TEXT",
    "value": "string"
  },
  "jdText": "string",
  "jdUrl": "https://example.com/jobs/backend"
}
```

### 성공 응답

```json
{
  "matchingScore": 82,
  "summary": "Spring Boot와 테스트 자동화 경험은 잘 맞지만 배포 근거를 조금 더 보강하면 좋습니다.",
  "strengths": ["Spring Boot 경험이 JD 요구사항과 직접 맞닿습니다."],
  "gaps": ["배포 경험을 더 구체적으로 드러내는 편이 좋습니다."],
  "suggestions": ["배포 경험이 있다면 프로젝트 맥락과 결과를 함께 적어 보세요."]
}
```

### Gemini 내부 응답 스키마

```json
{
  "matchingScore": 0,
  "summary": "string",
  "strengths": ["string"],
  "gaps": ["string"],
  "suggestions": ["string"]
}
```

### 오류 코드

| HTTP 상태 | 코드 |
|---|---|
| `400` | `EMPTY_JD` |
| `400` | `JD_TEXT_TOO_SHORT` |
| `400` | `JD_TEXT_TOO_LONG` |
| `400` | `INVALID_JD_URL` |
| `503` | `GEMINI_API_KEY_MISSING` |
| `502` | `GEMINI_API_REQUEST_FAILED` |
| `502` | `GEMINI_API_RESPONSE_INVALID` |
