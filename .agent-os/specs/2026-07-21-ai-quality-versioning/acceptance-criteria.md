# AI 품질 평가와 prompt/model version 수용 기준

## T1: Prompt/Model Version 기록

### AC-01 (REQ-01)

`diagnosis` 결과가 저장된 모든 `SUCCEEDED` 분석 이력은 내부 저장소에 `diagnosis` 모델명과 프롬프트 버전 값이 비어 있지 않게 기록된다. `match` 결과가 저장된 이력은 동일하게 `match` 모델명과 프롬프트 버전이 기록된다. 한쪽 결과만 존재하는 이력은 존재하는 쪽만 기록된다.

### AC-02 (REQ-02)

`GET /api/analysis-histories` 목록 응답, `GET /api/analysis-histories/{historyId}` 상세 응답, `POST /api/analysis-histories`/`.../file`/`.../retry` 응답 어디에도 모델명·프롬프트 버전 필드가 노출되지 않는다. 프론트엔드 소스에 해당 값을 렌더링하는 코드가 없다.

### AC-03 (REQ-03)

REQ-01 적용 전후로 기존 `analysis_input_snapshot`/`analysis_history` 조회, 생성, 재시도, 삭제 API의 기존 응답 필드와 HTTP 상태 코드가 동일하게 유지된다(회귀 없음).

## T2: 사용자 품질 피드백

### AC-04 (REQ-04)

로그인한 사용자가 본인 소유 `SUCCEEDED` 이력에 `rating=LIKE` 또는 `DISLIKE`(+선택 `comment`)로 피드백을 제출하면 `200`과 저장된 피드백이 반환된다. 동일 이력에 다시 제출하면 새 레코드가 추가되지 않고 기존 피드백이 갱신된다. `comment`가 500자를 초과하면 `400 INVALID_FEEDBACK_INPUT`을 반환한다.

### AC-05 (REQ-05)

피드백을 남긴 이력을 `GET /api/analysis-histories/{historyId}`로 조회하면 응답에 해당 사용자의 `feedback`(`rating`, `comment`, `updatedAt`) 객체가 포함된다. 피드백이 없는 이력은 `feedback: null`을 반환한다.

### AC-06 (REQ-06)

타인 소유 이력에 대한 피드백 제출·조회는 `404 ANALYSIS_HISTORY_NOT_FOUND` 계열로 응답한다. `RUNNING` 또는 `FAILED` 상태 이력에 피드백을 제출하면 `409 ANALYSIS_NOT_COMPLETED`를 반환한다.

### AC-07 (REQ-07)

이력을 삭제하면 연결된 피드백 레코드도 함께 삭제되어 조회되지 않는다. 원본 이력에 피드백을 남긴 뒤 재시도로 새 이력을 만들면, 새 이력의 `GET` 응답은 `feedback: null`이며 원본 이력의 피드백은 그대로 유지된다.
