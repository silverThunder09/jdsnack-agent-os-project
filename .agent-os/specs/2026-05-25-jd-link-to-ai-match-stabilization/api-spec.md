# JD 링크 to AI 매칭 안정화 API 명세

## 유지 API

이번 spec은 새 API를 추가하지 않고 기존 API 흐름을 연결한다.

- `POST /api/jd/fetch`
- `POST /api/match/preview`
- `POST /api/diagnose`
- `POST /api/diagnose/file`

## `POST /api/jd/fetch`

JD URL에서 본문을 수집한다. 성공 시 프론트는 `data.jdText`를 JD textarea에 반영한다.

### Success Data

```json
{
  "jdText": "string",
  "sourceUrl": "string",
  "title": "string",
  "fetchMode": "static-html",
  "sourceSite": "saramin"
}
```

### Failure Behavior

- 실패 시 프론트는 기존 JD textarea 값을 보존한다.
- 실패 안내는 사용자가 직접 JD 본문을 붙여넣도록 유도한다.

## `POST /api/match/preview`

준비된 이력서와 JD 본문으로 매칭 리포트를 요청한다.

### Request

```json
{
  "resumeSource": {
    "type": "TEXT | FILE",
    "value": "string"
  },
  "jdText": "string",
  "jdUrl": "string"
}
```

### Success Data

```json
{
  "matchingScore": 76,
  "summary": "string",
  "strengths": ["string"],
  "gaps": ["string"],
  "suggestions": ["string"]
}
```

## 계약 원칙

- `jdUrl`은 출처와 수집 시도 정보를 유지하기 위한 선택값이다.
- 실제 비교 기준은 `jdText`다.
- `ai-local`, `fixture`, `stub` 모드별 내부 provider 차이는 API 계약에 노출하지 않는다.
