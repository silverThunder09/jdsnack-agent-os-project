# 모의 면접 질문 생성 API 명세

## 신규 API

이번 spec은 이력서 기반 모의 면접 질문 생성을 위한 신규 엔드포인트 하나를 추가한다. 기존 `diagnose`/`match` 계약은 변경하지 않는다.

- `POST /api/interview/preview`

## `POST /api/interview/preview`

준비된 이력서(선택적으로 직무·JD 맥락)로 예상 면접 질문 목록을 생성한다.

### Request

```json
{
  "resumeSource": {
    "type": "TEXT | FILE",
    "value": "string"
  },
  "jobTitle": "string (optional)",
  "jdText": "string (optional)"
}
```

- `resumeSource.value`는 텍스트 이력서 본문 또는 PDF/DOCX 분석 결과 `sourceText`다.
- `jobTitle`, `jdText`는 선택값이며 질문 맥락 구체화에만 쓰인다.

### Success Data

```json
{
  "questions": [
    {
      "question": "string",
      "category": "experience | technical | behavioral",
      "keypoints": "string"
    }
  ],
  "strategy": "string",
  "summary": "string"
}
```

### Failure Behavior

- 빈/짧은/긴 이력서는 입력 검증 에러로 막고, 사용자 입력은 보존한다.
- Gemini 호출 실패는 재시도 가능한 외부 호출 실패 에러로 안내한다.
- 키 누락은 설정 실패 안내로 처리한다(보안 실패 아님).

### 에러 코드

- 재사용: `EMPTY_RESUME`, `TEXT_TOO_SHORT`, `TEXT_TOO_LONG`, `GEMINI_API_KEY_MISSING`, `GEMINI_API_REQUEST_FAILED`, `GEMINI_API_RESPONSE_INVALID`
- 신규: `MOCK_INTERVIEW_NOT_ENABLED`(stub 모드 준비중), `INTERVIEW_QUESTION_GENERATION_FAILED`(질문 생성 실패)

## 계약 원칙

- 응답은 `ApiResponse<T>` 래퍼(`success`, `data`, `error`, `timestamp`)를 따른다.
- `ai-local`, `fixture`, `stub` 모드별 내부 provider 차이는 API 계약에 노출하지 않는다.
- 질문 카테고리는 `experience`, `technical`, `behavioral` 세 값으로 고정한다.
