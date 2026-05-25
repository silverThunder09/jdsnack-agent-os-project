# 사람인 JD 수집 안정화 수용 기준

## `AC-01` 정상 사람인 본문 추출

- 사람인 정상 채용공고 fixture에서 실제 JD 본문을 추출한다.
- `jdText`에는 직무 내용 또는 자격 요건이 포함된다.
- `sourceSite`는 `saramin`이다.

## `AC-02` AI매치/추천 노이즈보다 공고 본문 우선

- 사람인 HTML에 AI매치 소개나 추천 문구가 함께 있어도 채용공고 본문을 우선 추출한다.
- `recruit_detail`, `jv_cont`, `wrap_jv_cont`, `dt/dd` 계열 본문 후보를 우선 검토한다.

## `AC-03` 가짜 성공 차단

- 개인정보/푸터/약관/고객센터 문구만 있는 fixture는 `JD_FETCH_UNSUPPORTED_SOURCE`를 반환한다.
- AI매치 소개만 있는 fixture는 `JD_FETCH_UNSUPPORTED_SOURCE`를 반환한다.
- 사람인 오류 또는 Bad Request 페이지는 `JD_FETCH_UNSUPPORTED_SOURCE`를 반환한다.

## `AC-04` 빈약한 본문 구분

- 본문 후보는 있으나 길이나 JD 신호가 부족하면 `JD_FETCH_EMPTY_CONTENT`를 반환한다.
- HTTP 실패, 타임아웃, 너무 큰 응답은 `JD_FETCH_FAILED`를 반환한다.

## `AC-05` 구현 범위 준수

- 브라우저 렌더링, 로그인 우회, anti-bot 우회는 구현하지 않는다.
- 잡코리아, 원티드, 기타 채용 플랫폼 자동 수집은 이번 범위에서 제외한다.
