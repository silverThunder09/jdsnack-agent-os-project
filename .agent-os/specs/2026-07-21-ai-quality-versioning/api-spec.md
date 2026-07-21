# AI 품질 평가와 prompt/model version API 계약

## 공통

- 보호 API는 기존 내부 세션 인증 경계를 그대로 사용한다(정본: `.agent-os/archive/specs/2026-07-18-service-mvp/api-spec.md`).
- 성공 응답은 기존 `ApiResponse<T>` 래퍼를 사용한다.
- 타인 소유 이력에 대한 접근은 기존과 동일하게 `ANALYSIS_HISTORY_NOT_FOUND` 계열로 처리해 존재 여부를 숨긴다.

## T1: Prompt/Model Version (내부 전용, 공개 계약 없음)

- 새 공개 API 엔드포인트를 추가하지 않는다.
- `analysis_history` 테이블에 다음 내부 컬럼을 추가한다(제안 이름, 최종 컬럼명은 구현 티켓에서 확정 가능하나 의미는 유지):
  - `diagnosis_model_name`, `diagnosis_prompt_version` (nullable, `diagnosis_json`이 채워질 때 함께 기록)
  - `match_model_name`, `match_prompt_version` (nullable, `match_json`이 채워질 때 함께 기록)
- 이 컬럼들은 `AnalysisHistoryResponse` 등 기존 응답 DTO에 매핑하지 않는다(REQ-02, AC-02).
- 모델명은 각 Gemini provider(`GeminiDiagnosisProvider`, `GeminiMatchPreviewProvider`)가 실제 호출에 사용한 값(`GEMINI_MODEL` 환경변수 또는 `DEFAULT_MODEL`)을 그대로 사용한다. 프롬프트 버전은 각 provider가 소유한 버전 상수(예: `"diagnosis-v1"`)를 사용한다.

## T2: 사용자 품질 피드백

### `POST /api/analysis-histories/{historyId}/feedback`

요청:

```json
{
  "rating": "LIKE",
  "comment": "핵심 개선점이 명확했어요."
}
```

`rating`은 `LIKE` 또는 `DISLIKE`(필수)이다. `comment`는 선택값이며 최대 500자다. 기존 피드백이 있으면 upsert(갱신)한다.

성공 응답:

```json
{
  "success": true,
  "data": {
    "historyId": "history-uuid",
    "rating": "LIKE",
    "comment": "핵심 개선점이 명확했어요.",
    "updatedAt": "2026-07-21T12:00:00Z"
  }
}
```

### `GET /api/analysis-histories/{historyId}` (기존 응답에 필드 추가)

기존 응답(`.agent-os/archive/specs/2026-07-18-service-mvp/api-spec.md` 66-78행)에 `feedback` 필드를 추가한다. 기존 필드는 변경하지 않는다.

```json
{
  "data": {
    "id": "history-uuid",
    "status": "SUCCEEDED",
    "createdAt": "2026-07-18T12:00:00Z",
    "result": { "diagnosis": {}, "match": {} },
    "feedback": {
      "rating": "LIKE",
      "comment": "핵심 개선점이 명확했어요.",
      "updatedAt": "2026-07-21T12:00:00Z"
    }
  }
}
```

피드백이 없으면 `"feedback": null`을 반환한다. `GET /api/analysis-histories` 목록 응답은 요약 목적이므로 `feedback`을 포함하지 않는다(기존 계약 유지).

### `DELETE /api/analysis-histories/{historyId}` (기존 계약 확장)

기존과 동일하게 `204 No Content`를 반환하며, 연결된 피드백도 같은 트랜잭션 경계에서 함께 삭제한다(응답 스키마 변경 없음).

## 오류

| 상황 | HTTP | 코드 |
|---|---:|---|
| 세션 없음 | 401 | `AUTHENTICATION_REQUIRED` |
| 이력 없음/타인 소유 | 404 | `ANALYSIS_HISTORY_NOT_FOUND` |
| `RUNNING`/`FAILED` 이력에 피드백 제출 | 409 | `ANALYSIS_NOT_COMPLETED` |
| `rating` 누락·잘못된 값, `comment` 500자 초과 | 400 | `INVALID_FEEDBACK_INPUT` |
