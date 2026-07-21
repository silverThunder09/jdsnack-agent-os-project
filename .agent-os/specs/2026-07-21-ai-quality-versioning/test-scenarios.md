# AI 품질 평가와 prompt/model version 테스트 시나리오

## T1: Prompt/Model Version 기록

### TC-01 (AC-01) 진단·매칭 결과 저장 시 모델/프롬프트 버전 기록

`resumeText`+`jd.text`로 `POST /api/analysis-histories`를 호출해 `diagnosis`, `match`가 모두 `SUCCEEDED`로 저장되는 케이스에서, 내부 저장소(repository 조회 또는 통합 테스트)의 `diagnosis` 모델명·프롬프트 버전과 `match` 모델명·프롬프트 버전이 모두 비어 있지 않음을 검증한다.

### TC-02 (AC-01) 부분 실패 시 부분 기록

Gemini 매칭 호출만 실패하도록 fixture/mock을 구성한 뒤 이력을 생성하고, `diagnosis` 모델/프롬프트 버전은 기록되고 `match` 쪽은 기록되지 않음(또는 null)을 검증한다.

### TC-03 (AC-02) 공개 응답에 미노출

`POST /api/analysis-histories`, `GET /api/analysis-histories`, `GET /api/analysis-histories/{historyId}`, `POST .../retry` 각 응답 JSON을 역직렬화한 뒤 모델명·프롬프트 버전 관련 키가 존재하지 않음을 단언한다. 프론트 `frontend/src/features/analysis/**`에 관련 필드를 사용하는 코드가 없음을 정적 검증(코드 리뷰 또는 grep 기반 lint)한다.

### TC-04 (AC-03) 기존 흐름 회귀 없음

기존 `service-mvp`의 생성/조회/재시도/삭제 통합 테스트(`AnalysisHistoryControllerTest` 등 기존 스위트)가 스키마 변경 후에도 그대로 통과함을 확인한다.

## T2: 사용자 품질 피드백

### TC-05 (AC-04) 피드백 최초 제출

`SUCCEEDED` 이력 소유자가 `rating=LIKE`로 피드백을 제출하면 `200`과 생성된 피드백을 반환하는지 검증한다.

### TC-06 (AC-04) 피드백 갱신(upsert)

같은 이력에 `rating=DISLIKE`, `comment="개선 필요"`로 다시 제출하면 레코드가 하나만 유지되고 값이 갱신됨을 검증한다.

### TC-07 (AC-04) 코멘트 길이 검증

`comment`가 501자인 요청이 `400 INVALID_FEEDBACK_INPUT`을 반환함을 검증한다.

### TC-08 (AC-05) 상세 조회에 피드백 포함

피드백 제출 후 `GET /api/analysis-histories/{historyId}`를 호출해 응답의 `feedback.rating`, `feedback.comment`, `feedback.updatedAt`이 제출 값과 일치함을 검증한다. 피드백이 없는 다른 이력은 `feedback: null`임을 검증한다.

### TC-09 (AC-06) 소유권 경계

사용자 B가 사용자 A 소유 이력에 피드백을 제출·조회하면 `404 ANALYSIS_HISTORY_NOT_FOUND`가 반환됨을 검증한다.

### TC-10 (AC-06) 상태 경계

`RUNNING` 또는 `FAILED` 이력에 피드백을 제출하면 `409 ANALYSIS_NOT_COMPLETED`가 반환됨을 검증한다.

### TC-11 (AC-07) 삭제 시 피드백 연쇄 삭제

피드백이 있는 이력을 `DELETE`한 뒤, 동일 `historyId`로 조회 시 `404`가 반환되고 피드백 레코드도 남아 있지 않음을(재사용 시 동일 ID가 재생성되지 않으므로 간접 검증: 새 이력 생성 후 동일 사용자의 다른 이력 목록에 삭제된 피드백이 노출되지 않음) 검증한다.

### TC-12 (AC-07) 재시도 시 피드백 미상속

원본 이력에 피드백을 남긴 뒤 `POST .../retry`로 새 이력을 생성하고, 새 이력의 `GET` 응답이 `feedback: null`이며 원본 이력의 `GET` 응답은 기존 피드백을 그대로 유지함을 검증한다.

### TC-13 (T1+T2 공통) UI 프론트 피드백 위젯

`frontend/src/features/analysis/AnalysisHistoryView.tsx` 관련 컴포넌트 테스트에서, `SUCCEEDED` 이력 상세에 좋아요/별로 버튼이 노출되고 클릭 시 제출 API가 호출되며, `RUNNING`/`FAILED` 이력에는 버튼이 비활성화되거나 노출되지 않음을 검증한다.

### TC-14 (문서 게이트) 정적 품질 게이트

`python3 scripts/check-ai-readiness.py`가 통과함을 확인한다.
