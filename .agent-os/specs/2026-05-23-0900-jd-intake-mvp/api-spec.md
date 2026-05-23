# API 명세서

> 프로젝트: JDSnack — JD 입력 MVP
> 핵심 결정: 이번 단계는 AI 연동 전에도 쓸 수 있는 JD 비교 미리보기 계약을 먼저 구현한다.

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
| 설명 | 이력서-JD 비교 미리보기 요청 |
| 구현 상태 | 규칙 기반 미리보기 구현 완료 |
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

### 3.3 Response

현재 구현은 AI 분석이 아니라 키워드 겹침 기준의 규칙 기반 미리보기다.

```json
{
  "matchingScore": 76,
  "summary": "Spring Boot와 테스트 자동화 키워드는 잘 맞지만 배포 경험 근거를 더 드러내면 좋습니다.",
  "strengths": ["Spring Boot 관련 표현이 JD와 겹칩니다."],
  "gaps": ["배포 관련 경험 또는 성과 근거가 이력서에서 약하게 보입니다."],
  "suggestions": ["배포 경험이 있다면 프로젝트 맥락, 사용 기술, 결과를 함께 적어 보세요."]
}
```

응답 의미:

- `matchingScore`: JD 키워드와 이력서 키워드 겹침 정도를 0~100 점수로 표현한 미리보기 값
- `summary`: 현재 이력서와 JD의 맞는 부분과 보완 포인트를 요약
- `strengths`: JD와 맞닿는 이력서 요소
- `gaps`: JD 대비 약하게 보이는 항목
- `suggestions`: 다음 이력서 보완 제안

### 3.4 구현 경계

- 현재 응답은 AI가 만든 분석이 아니다.
- 현재 응답은 키워드 기준 규칙 기반 미리보기다.
- 2차 MVP에서 AI가 들어와도 요청 형식과 응답 필드 구조는 유지한다.

## 4. 범위 밖

- JD 링크 HTML 수집
- 외부 AI 비교 분석 호출
- 정교한 적합도 점수 모델
