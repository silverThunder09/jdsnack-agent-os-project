# JD 링크 수집 안정화 MVP 수용 기준

## `AC-01` 사람인 정적 HTML 본문 추출

- 사람인 정적 HTML fixture에서 JD 본문이 추출되어야 한다.
- 응답에는 `jdText`, `sourceUrl`, `title`, `fetchMode`, `sourceSite`가 포함되어야 한다.
- `sourceSite`는 `saramin`으로 식별되어야 한다.

## `AC-02` 본문 품질 미달 실패

- 개인정보, 채용절차, 푸터, 추천공고 문구만 있는 HTML은 성공하면 안 된다.
- 이 경우 `422 JD_FETCH_UNSUPPORTED_SOURCE`를 반환해야 한다.

## `AC-03` 빈 본문 실패

- HTML은 가져왔지만 추출 가능한 JD 본문이 없거나 너무 짧으면 `422 JD_FETCH_EMPTY_CONTENT`를 반환해야 한다.

## `AC-04` 안전하지 않은 URL 차단

- 잘못된 URL, 미지원 스킴, localhost, private IP, metadata IP는 거부해야 한다.
- 외부 fetch 실패, timeout, 응답 크기 초과는 `502 JD_FETCH_FAILED`로 처리한다.

## `AC-05` 로그 안전성

- API Key, 요청 헤더, JD 원문 전체, 외부 응답 원문 전체를 로그에 출력하지 않아야 한다.
