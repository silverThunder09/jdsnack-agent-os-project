# 테스트 시나리오

> 기능: JDSnack — JD 입력 MVP

## `TC-01` 정상 JD 텍스트 입력

- 대응 AC: `AC-01`, `AC-07`
- 절차:
  - 사용자가 JD 텍스트를 입력한다
  - JD 링크는 비운다
- 기대 결과:
  - 검증 통과
  - 다음 비교 단계로 이어질 수 있는 상태가 된다

## `TC-02` 빈 JD 입력

- 대응 AC: `AC-03`
- 절차:
  - JD 텍스트 없이 진행한다
- 기대 결과:
  - `EMPTY_JD` 오류로 처리된다

## `TC-03` 너무 짧은 JD 입력

- 대응 AC: `AC-03`
- 절차:
  - 핵심 자격요건이 드러나지 않을 정도의 짧은 JD 텍스트를 입력한다
- 기대 결과:
  - `JD_TEXT_TOO_SHORT` 오류로 처리된다

## `TC-04` 잘못된 JD 링크 형식

- 대응 AC: `AC-02`, `AC-04`
- 절차:
  - JD 텍스트는 정상 입력한다
  - URL 형식이 아닌 JD 링크를 입력한다
- 기대 결과:
  - `INVALID_JD_URL` 오류로 처리된다

## `TC-05` JD 링크 없이 텍스트만 입력

- 대응 AC: `AC-02`
- 절차:
  - JD 텍스트만 입력한다
  - JD 링크는 입력하지 않는다
- 기대 결과:
  - 흐름이 정상 진행된다

## `TC-06` 비교 API 요청/응답 계약 확인

- 대응 AC: `AC-05`, `AC-06`
- 절차:
  - `POST /api/match/preview` 문서를 확인한다
- 기대 결과:
  - `resumeSource`, `jdText`, `jdUrl` 요청 구조가 존재한다
  - 응답에 `matchingScore`, `summary`, `strengths`, `gaps`, `suggestions`가 정의되어 있다

## `TC-07` 유효한 JD 비교 미리보기 요청

- 대응 AC: `AC-05`, `AC-06`, `AC-07`
- 절차:
  - 유효한 이력서 소스와 JD 텍스트를 함께 보낸다
- 기대 결과:
  - 요청 형식 검증은 통과한다
  - `matchingScore`, `summary`, `strengths`, `gaps`, `suggestions`가 포함된 응답이 반환된다

## `TC-08` 브라우저 JD 비교 smoke

- 대응 AC: `AC-05`, `AC-06`, `AC-07`
- 절차:
  - 브라우저에서 fixture 분석 성공 상태를 만든다
  - JD 텍스트를 입력한다
  - `JD 비교 미리보기`를 실행한다
- 기대 결과:
  - JD 결과 카드가 렌더링된다
  - `matchingScore`와 결과 요약이 보인다
