# ATS 점수·포맷 진단 API 계약

## 공통

- 경로는 인증된 내부 세션을 요구한다.
- 성공·실패 응답은 기존 `ApiResponse<T>` 래퍼를 사용한다.
- ATS는 외부 AI 호출 없이 서버에서 계산한다.

## `POST /api/ats/preview`

요청:

```json
{
  "resumeSource": {
    "type": "TEXT",
    "value": "이력서 추출 텍스트"
  },
  "jdText": "채용공고 본문",
  "jdUrl": "https://example.com/jobs/1"
}
```

`resumeSource.type`은 `TEXT` 또는 `FILE`이다. `value`는 원본 파일이 아니라 서버에서 추출된 텍스트다. 이력서와 JD는 각각 50자 이상 10,000자 이하여야 한다. `jdUrl`은 선택값이며 입력되면 `http` 또는 `https`만 허용한다.

성공 응답:

```json
{
  "success": true,
  "data": {
    "atsScore": 78,
    "summary": "핵심 키워드와 기본 섹션은 확인되지만 성과 근거를 더 보강할 필요가 있습니다.",
    "strengths": ["연락처 단서가 확인됩니다."],
    "risks": ["JD의 핵심 키워드 일부가 이력서에 없습니다."],
    "suggestions": ["누락 키워드가 드러나는 프로젝트 성과를 추가해 보세요."],
    "matchedKeywords": ["java"],
    "missingKeywords": ["kubernetes"],
    "formatChecks": [
      { "label": "연락처 단서", "passed": true, "message": "이메일 또는 전화번호 단서가 확인됩니다." }
    ]
  }
}
```

## 오류

| 상황 | 코드 |
|---|---|
| 세션 없음 | `AUTHENTICATION_REQUIRED` |
| 이력서 없음·길이 오류 | `EMPTY_RESUME`, `TEXT_TOO_SHORT`, `TEXT_TOO_LONG` |
| JD 없음·길이 오류 | `EMPTY_JD`, `JD_TEXT_TOO_SHORT`, `JD_TEXT_TOO_LONG` |
| JD URL 오류 | `INVALID_JD_URL` |
