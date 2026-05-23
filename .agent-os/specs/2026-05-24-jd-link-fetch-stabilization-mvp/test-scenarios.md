# JD 링크 수집 안정화 MVP 테스트 시나리오

## `TC-01` 사람인 JD 본문 추출 성공

- 대응 AC: `AC-01`
- 절차:
  - 사람인 공고 형태의 정적 HTML fixture를 준비한다.
  - `POST /api/jd/fetch` 수집 흐름으로 검증한다.
- 기대 결과:
  - `200`을 반환한다.
  - `jdText`에 직무, 자격요건, 우대사항 중 하나 이상이 포함된다.
  - 개인정보/푸터 문구가 과도하게 섞이지 않는다.

## `TC-02` 개인정보/푸터 문구 오탐 방지

- 대응 AC: `AC-02`
- 절차:
  - 개인정보 안내, 채용절차 안내, 푸터 문구만 있는 HTML fixture를 입력한다.
- 기대 결과:
  - `422 JD_FETCH_UNSUPPORTED_SOURCE`를 반환한다.
  - 성공 응답으로 처리하지 않는다.

## `TC-03` 빈 본문 실패

- 대응 AC: `AC-03`
- 절차:
  - 본문 후보가 없거나 너무 짧은 HTML fixture를 입력한다.
- 기대 결과:
  - `422 JD_FETCH_EMPTY_CONTENT`를 반환한다.

## `TC-04` 안전하지 않은 URL 차단

- 대응 AC: `AC-04`
- 절차:
  - `file://`, `localhost`, private IP, metadata IP URL을 입력한다.
- 기대 결과:
  - 요청이 거부된다.
  - 내부망으로 fetch하지 않는다.

## `TC-05` 외부 fetch 실패 처리

- 대응 AC: `AC-04`
- 절차:
  - timeout, redirect 초과, 응답 크기 초과 상황을 mock으로 만든다.
- 기대 결과:
  - `502 JD_FETCH_FAILED`를 반환한다.

## `TC-06` 로그 안전성 확인

- 대응 AC: `AC-05`
- 절차:
  - JD fetch 실패/성공 로그를 확인한다.
- 기대 결과:
  - 요청 헤더와 JD 원문 전체가 로그에 출력되지 않는다.
