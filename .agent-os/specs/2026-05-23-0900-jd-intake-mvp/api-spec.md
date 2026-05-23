# API 명세서

> 프로젝트: JDSnack — JD 입력 MVP
> 핵심 결정: 이번 단계는 비교 API 구현이 아니라 요청 계약 초안을 고정하는 문서 작업이다.

## 1. 입력 모델

JD 입력 화면은 아래 필드를 기준으로 설계한다.

```json
{
  "jdText": "string",
  "jdUrl": "string"
}
```

규칙:

- `jdText`는 필수다.
- `jdUrl`은 선택이다.
- `jdUrl`이 있어도 서버는 링크 내용을 직접 수집하지 않는다.

## 2. 검증 규칙

| HTTP 상태 코드 | 에러 코드 | 설명 |
|---|---|---|
| `400` | `EMPTY_JD` | JD 텍스트가 비어 있음 |
| `400` | `JD_TEXT_TOO_SHORT` | JD 텍스트가 최소 길이보다 짧음 |
| `400` | `JD_TEXT_TOO_LONG` | JD 텍스트가 최대 길이를 초과함 |
| `400` | `INVALID_JD_URL` | JD 링크 형식이 올바르지 않음 |

길이 수치는 이번 단계에서 구현으로 고정하지 않고, 2차 MVP 구현 시 validation 문서와 함께 확정한다. 다만 빈 값, 너무 짧음, 너무 김은 별도 에러 코드로 분리해야 한다.

## 3. `POST /api/match/preview`

### 3.1 개요

| 항목 | 값 |
|---|---|
| 엔드포인트 | `POST /api/match/preview` |
| 설명 | 이력서-JD 비교 분석 단계에서 사용할 요청 계약 초안 |
| 구현 상태 | 문서 초안만 고정, 실제 API 미구현 |
| 인증 | 없음 |

### 3.2 Request 초안

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

필드 의미:

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `resumeSource.type` | `TEXT \| FILE` | 예 | 이력서가 직접 입력인지 파일 업로드 기반인지 표시 |
| `resumeSource.value` | `string` | 예 | 비교에 사용할 이력서 텍스트 본문 |
| `jdText` | `string` | 예 | 사용자가 붙여넣은 JD 본문 |
| `jdUrl` | `string` | 아니오 | 사용자가 남긴 JD 출처 링크 |

해석 규칙:

- `resumeSource.value`는 원시 파일 바이너리가 아니라 비교에 사용할 텍스트 본문이다.
- 파일 업로드 이력서는 1.5차 MVP에서 이미 추출된 텍스트를 다음 단계에 넘기는 것으로 해석한다.
- `jdUrl`은 저장 또는 표시용 메타데이터이며, 본문 수집의 근거가 아니다.

### 3.3 Response 예약 필드

이번 단계에서는 실제 응답 계약을 구현하지 않는다. 다만 2차 MVP를 위해 아래 필드를 예약한다.

```json
{
  "matchingScore": 0,
  "summary": "string",
  "strengths": ["string"],
  "gaps": ["string"],
  "suggestions": ["string"]
}
```

## 4. 범위 밖

- 실제 `POST /api/match/preview` 구현
- JD 링크 HTML 수집
- 외부 AI 비교 분석 호출
- 점수 계산 로직
