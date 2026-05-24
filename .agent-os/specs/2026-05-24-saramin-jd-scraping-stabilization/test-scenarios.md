# 사람인 JD 수집 안정화 테스트 시나리오

## `TC-01` 정상 사람인 fixture 추출

- 대응 AC: `AC-01`
- 절차:
  - 사람인 정상 채용공고 fixture를 `JdHtmlExtractor`에 입력한다.
- 기대 결과:
  - `jdText`에 직무 내용과 자격 요건이 포함된다.
  - `sourceSite`는 `saramin`이다.

## `TC-02` AI매치 노이즈보다 공고 본문 우선

- 대응 AC: `AC-02`
- 절차:
  - AI매치 소개와 실제 채용공고 본문이 함께 있는 fixture를 입력한다.
- 기대 결과:
  - AI매치 소개문이 아니라 실제 공고 본문이 반환된다.

## `TC-03` `dd` 중심 사람인 본문 추출

- 대응 AC: `AC-02`
- 절차:
  - `dt/dd` 계열에 본문이 있는 사람인 fixture를 입력한다.
- 기대 결과:
  - `dd` 본문에서 업무/자격/우대 정보가 추출된다.

## `TC-04` 개인정보/푸터-only 실패

- 대응 AC: `AC-03`
- 절차:
  - 개인정보, 푸터, 약관, 고객센터 문구만 있는 fixture를 입력한다.
- 기대 결과:
  - `JD_FETCH_UNSUPPORTED_SOURCE`가 반환된다.

## `TC-05` AI매치 소개-only 실패

- 대응 AC: `AC-03`
- 절차:
  - AI매치 소개 또는 추천공고 홍보문만 있는 fixture를 입력한다.
- 기대 결과:
  - `JD_FETCH_UNSUPPORTED_SOURCE`가 반환된다.

## `TC-06` 오류/Bad Request 페이지 실패

- 대응 AC: `AC-03`
- 절차:
  - 사람인 오류 또는 Bad Request fixture를 입력한다.
- 기대 결과:
  - `JD_FETCH_UNSUPPORTED_SOURCE`가 반환된다.

## `TC-07` 빈약한 본문 실패

- 대응 AC: `AC-04`
- 절차:
  - 본문 후보는 있으나 길이와 JD 신호가 부족한 fixture를 입력한다.
- 기대 결과:
  - `JD_FETCH_EMPTY_CONTENT`가 반환된다.

## `TC-08` 범위 제외 확인

- 대응 AC: `AC-05`
- 절차:
  - 개발 변경 범위를 확인한다.
- 기대 결과:
  - 브라우저 렌더링, 로그인 우회, anti-bot 우회, 잡코리아/원티드 수집이 포함되지 않는다.
