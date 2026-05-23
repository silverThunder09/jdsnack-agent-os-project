# JD 링크 수집 안정화 MVP API 명세

## `POST /api/jd/fetch`

### 요청

```json
{
  "jdUrl": "https://www.saramin.co.kr/..."
}
```

### 성공 응답

```json
{
  "success": true,
  "data": {
    "jdText": "추출된 JD 본문",
    "sourceUrl": "원본 URL",
    "title": "공고 제목",
    "fetchMode": "static-html",
    "sourceSite": "saramin"
  },
  "error": null,
  "timestamp": "string"
}
```

### 오류 응답

| HTTP | Code | 의미 |
| --- | --- | --- |
| `400` | `INVALID_JD_URL` | URL 형식, 스킴, 내부망 주소 오류 |
| `422` | `JD_FETCH_EMPTY_CONTENT` | HTML은 가져왔지만 JD 본문이 비어 있거나 너무 짧음 |
| `422` | `JD_FETCH_UNSUPPORTED_SOURCE` | 지원 대상이 아니거나 본문 품질이 기준 미달 |
| `502` | `JD_FETCH_FAILED` | 네트워크, timeout, redirect, 응답 크기 문제 |

## 계약 원칙

- 성공 응답은 JD 본문으로 볼 수 있는 텍스트가 있을 때만 반환한다.
- 개인정보/채용절차/푸터성 문구만 추출되면 실패로 처리한다.
- 실제 외부 사이트 호출은 기본 CI 검증에 넣지 않고 fixture 또는 mock HTML로 검증한다.
