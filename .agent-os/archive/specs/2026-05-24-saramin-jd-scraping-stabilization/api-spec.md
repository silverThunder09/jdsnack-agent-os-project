# 사람인 JD 수집 안정화 API 명세

## `POST /api/jd/fetch`

사람인 채용공고 URL에서 JD 본문을 추출해 JD 입력 textarea에 넣을 수 있는 평문으로 반환한다.

### Request

```json
{
  "jdUrl": "https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=53864907"
}
```

### Success Response

```json
{
  "success": true,
  "data": {
    "jdText": "Java/JSP 기반 웹 서비스를 개발합니다. Spring Framework와 MySQL 경험이 필요합니다.",
    "sourceUrl": "https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=53864907",
    "title": "Java 신입/경력 개발자 모집",
    "fetchMode": "static-html",
    "sourceSite": "saramin"
  },
  "error": null,
  "timestamp": "2026-05-24T00:00:00+09:00"
}
```

### Error Contract

| Code | Status | 기준 |
| --- | --- | --- |
| `INVALID_JD_URL` | `400` | URL 형식이 잘못되었거나 unsafe host |
| `JD_FETCH_UNSUPPORTED_SOURCE` | `422` | 지원하지 않는 host, 사람인 오류/차단 페이지, 개인정보/AI매치/푸터만 추출 |
| `JD_FETCH_EMPTY_CONTENT` | `422` | 본문 후보는 있으나 길이 또는 JD 신호가 부족 |
| `JD_FETCH_FAILED` | `502` | HTTP 실패, 타임아웃, 너무 큰 응답, 네트워크 오류 |

### Success Quality Rule

`200 OK`는 HTTP 수집 성공이 아니라 **JD 본문 품질 통과**를 의미한다. `jdText`가 개인정보 안내문, 추천 문구, 공통 푸터, AI매치 소개문이면 성공 응답을 반환하지 않는다.
