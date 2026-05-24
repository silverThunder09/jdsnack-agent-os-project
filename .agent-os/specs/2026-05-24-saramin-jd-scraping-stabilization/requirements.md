# 사람인 JD 수집 안정화 요구사항

## `REQ-01` 사람인 JD 본문 성공 기준 고정

- `POST /api/jd/fetch`는 사람인 채용공고 링크에서 실제 JD 본문을 추출해야 한다.
- 성공한 `jdText`에는 직무 내용, 자격 요건, 우대 사항, 기술 스택, 업무 환경 중 의미 있는 JD 신호가 포함되어야 한다.
- 개인정보 안내문, 푸터, 약관, 고객센터 문구, AI매치 홍보문은 JD 본문 성공으로 보지 않는다.

## `REQ-02` 가짜 성공 방지

- 사람인 링크 호출이 `200 OK`여도 `jdText`가 공고 본문이 아니면 실패로 판단해야 한다.
- 개인정보/푸터/약관/고객센터 문구만 추출되면 `JD_FETCH_UNSUPPORTED_SOURCE`로 처리한다.
- AI매치 소개 또는 추천/광고 문구만 추출되면 `JD_FETCH_UNSUPPORTED_SOURCE`로 처리한다.
- 사람인 오류, 차단, Bad Request 페이지는 `JD_FETCH_UNSUPPORTED_SOURCE`로 처리한다.

## `REQ-03` 기존 API 계약 유지

- 기존 `POST /api/jd/fetch` 엔드포인트와 요청/응답 구조를 유지한다.
- 성공 응답은 `jdText`, `sourceUrl`, `title`, `fetchMode`, `sourceSite`를 유지한다.
- 사람인 URL의 `sourceSite`는 `saramin`이어야 한다.

## `REQ-04` 구현 범위 제한

- 개발 쓰레드는 기존 `JdHtmlExtractor`와 `JdFetchService`를 개선 대상으로 삼는다.
- Jsoup 기반 정적 HTML 파싱을 유지한다.
- 브라우저 렌더링, 로그인 우회, anti-bot 우회, 잡코리아/원티드 확장은 이번 범위에서 제외한다.

## `REQ-05` fixture 기반 검증 기준

- 실제 외부 사이트 실시간 응답은 불안정하므로 개발 검증은 HTML fixture를 기준으로 한다.
- 사람인 정상 본문, AI매치 노이즈, `dd` 중심 본문, 개인정보/푸터, 오류 페이지, 짧은 본문 fixture를 구분한다.
