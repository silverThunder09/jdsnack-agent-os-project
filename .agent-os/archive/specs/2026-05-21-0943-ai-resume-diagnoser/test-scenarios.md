# 테스트 시나리오

> 기능: JDSnack 1차 MVP — 입력 검증과 준비중 안내

## `TC-01` 정상 입력 요청

- 대응 AC: `AC-01`, `AC-06`
- 절차:
  - 50자 이상 10,000자 이하의 이력서 텍스트 입력
  - 진단 버튼 클릭
- 기대 결과:
  - `501 Not Implemented`
  - `AI_ANALYSIS_NOT_ENABLED`
  - 준비중 안내 메시지 표시

## `TC-02` 최소 경계값 정상 입력

- 대응 AC: `AC-01`
- 절차:
  - 정확히 50자의 이력서 텍스트 입력
  - 진단 버튼 클릭
- 기대 결과:
  - `501 Not Implemented`
  - `AI_ANALYSIS_NOT_ENABLED`

## `TC-03` 최대 경계값 정상 입력

- 대응 AC: `AC-01`
- 절차:
  - 정확히 10,000자의 이력서 텍스트 입력
  - 진단 버튼 클릭
- 기대 결과:
  - `501 Not Implemented`
  - `AI_ANALYSIS_NOT_ENABLED`

## `TC-04` 빈 입력 요청

- 대응 AC: `AC-02`
- 절차:
  - 입력 없이 요청
- 기대 결과:
  - `400 EMPTY_RESUME`
  - 사용자 안내 메시지 표시

## `TC-05` 누락/null/공백 입력 요청

- 대응 AC: `AC-02`
- 절차:
  - `resumeText` 필드 누락 요청
  - `resumeText=null` 요청
  - 공백 문자만 있는 입력 요청
- 기대 결과:
  - 모두 `400 EMPTY_RESUME`
  - 사용자 안내 메시지 표시

## `TC-06` 너무 짧은 입력

- 대응 AC: `AC-03`
- 절차:
  - 50자 미만 텍스트 입력
- 기대 결과:
  - `400 TEXT_TOO_SHORT`
  - 길이 기준 메시지 표시

## `TC-07` 너무 긴 입력

- 대응 AC: `AC-04`
- 절차:
  - 10,000자 초과 텍스트 입력
- 기대 결과:
  - `400 TEXT_TOO_LONG`
  - 최대 길이 기준 메시지 표시

## `TC-08` 인증 정보 UI 제거 확인

- 대응 AC: `AC-05`
- 절차:
  - 페이지 최초 접속
  - 헤더와 모달 영역 확인
- 기대 결과:
  - 인증 정보 입력 모달이 표시되지 않음
  - 인증 정보 설정 버튼이 없음
  - 인증 정보 관련 LocalStorage 접근이 없음

## `TC-09` 문서 계약 동기화 검토

- 대응 AC: `AC-07`
- 절차:
  - API/UI/요구사항 변경 시 관련 문서 갱신 여부 확인
- 기대 결과:
  - 누락 문서 없이 변경 세트가 완성됨

## `TC-10` 상태 확인 API

- 대응 AC: `AC-08`
- 절차:
  - `GET /api/health` 요청
- 기대 결과:
  - `200 OK`
  - `status=UP`
  - `service=JDSnack`
  - `version=1.0.0`

## `TC-12` 루트 경로 기본 응답

- 대응 AC: `AC-09`
- 절차:
  - 브라우저 또는 HTTP 클라이언트로 `GET /` 요청
- 기대 결과:
  - `200 OK`
  - `service=JDSnack`
  - `status=RUNNING`
  - `healthPath=/api/health`
  - `diagnosePath=/api/diagnose`

## `TC-13` 미등록 경로 404 응답

- 대응 AC: `AC-09`
- 절차:
  - 등록되지 않은 경로로 요청
- 기대 결과:
  - `404 NOT_FOUND`
  - `error.code=NOT_FOUND`

## `TC-11` 프론트 네트워크 오류 안내

- 대응 AC: `AC-06`
- 절차:
  - 네트워크 오류 상황에서 진단 요청
- 기대 결과:
  - `네트워크 연결을 확인해주세요.` 메시지 표시
  - 오류 메시지가 접근성 기준에 맞게 노출됨
