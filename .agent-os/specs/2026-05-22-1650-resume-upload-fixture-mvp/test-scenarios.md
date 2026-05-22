# 테스트 시나리오

> 기능: JDSnack 1.5차 MVP — 이력서 업로드와 fixture 분석

## `TC-01` 텍스트 입력 fixture 분석

- 대응 AC: `AC-01`, `AC-05`
- 절차:
  - 유효한 이력서 텍스트 입력
  - 진단 요청
- 기대 결과:
  - `200 OK`
  - `score`, `summary`, `strengths`, `improvements` 반환

## `TC-02` PDF 업로드 fixture 분석

- 대응 AC: `AC-02`, `AC-05`
- 절차:
  - 유효한 PDF 파일 업로드
  - 진단 요청
- 기대 결과:
  - 텍스트 추출 성공
  - fixture 결과 반환

## `TC-03` DOCX 업로드 fixture 분석

- 대응 AC: `AC-03`, `AC-05`
- 절차:
  - 유효한 DOCX 파일 업로드
  - 진단 요청
- 기대 결과:
  - 텍스트 추출 성공
  - fixture 결과 반환

## `TC-04` 지원하지 않는 파일 형식

- 대응 AC: `AC-04`
- 절차:
  - PDF/DOCX 외 파일 업로드
- 기대 결과:
  - `400 UNSUPPORTED_FILE_TYPE`

## `TC-05` 파일 텍스트 추출 실패

- 대응 AC: `AC-02`, `AC-03`
- 절차:
  - 손상 파일 또는 텍스트 추출 불가 파일 업로드
- 기대 결과:
  - `400 FILE_TEXT_EXTRACTION_FAILED`

## `TC-06` fixture 결과 없음

- 대응 AC: `AC-05`
- 절차:
  - 텍스트 추출은 성공하지만 fixture 매핑이 없는 입력으로 요청
- 기대 결과:
  - `404 FIXTURE_NOT_FOUND`

## `TC-07` 운영 모드 분리

- 대응 AC: `AC-06`
- 절차:
  - stub 모드와 fixture 모드를 각각 실행
- 기대 결과:
  - stub 모드: `501 AI_ANALYSIS_NOT_ENABLED`
  - fixture 모드: `200 OK` fixture 결과
