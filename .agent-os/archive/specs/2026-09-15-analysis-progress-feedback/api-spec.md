# 분석 진행 상태 피드백 인터페이스 계약

## 서버 계약

이번 기능은 서버의 진행률을 새로 제공하지 않는다. 다음 기존 요청을 그대로 사용한다.

| UI 실행 그룹 | 기존 요청 | 실행 조건 |
|---|---|---|
| 이력서 진단 | `POST /api/diagnose` 또는 `POST /api/diagnose/file` | 항상 |
| JD 적합도·키워드 | `POST /api/match/preview` | `jdMatch` 또는 `keyword` 선택 |
| ATS | `POST /api/ats/preview` | `ats` 선택 |
| 문장 첨삭 | `POST /api/sentence/preview` | `sentence` 선택 |
| 결과 저장 | `POST /api/analysis-histories` 또는 `/file` | 기존 저장 흐름 |

새 endpoint, polling, SSE/WebSocket, 응답 필드 추가는 이번 스펙에 포함하지 않는다. 서버 응답의 성공·실패와 기존 `ApiError`를 프론트 진행 상태로 매핑한다.

## 프론트 내부 인터페이스

진행 상태를 계산하는 모듈은 다음 개념을 외부에 제공한다. 실제 타입명은 구현 시 기존 타입 체계에 맞춰 조정할 수 있지만 의미와 상태 전이는 유지한다.

```text
TaskKey = resume | match | ats | sentence | history
TaskStatus = pending | running | succeeded | failed | skipped
RunStatus = idle | running | succeeded | partial-failure | failed

AnalysisProgressState {
  runId: string
  status: RunStatus
  currentStage: preparing | analyzing | saving | terminal
  tasks: Record<TaskKey, {
    status: TaskStatus
    message?: string
    errorCode?: string
  }>
}
```

불변 규칙:

- `match`는 `jdMatch`와 `keyword`가 모두 선택되어도 한 번만 실행한다.
- `succeeded`는 해당 요청이 실제 성공 응답을 받은 경우에만 설정한다.
- 선택된 task가 `running` 또는 `pending`인 동안 `RunStatus`는 `running`이다.
- 모든 선택 task와 `history`가 성공하면 `succeeded`다.
- 하나 이상 실패하고 하나 이상 성공하면 `partial-failure`다.
- 이력서 진단 실패로 후속 task를 실행하지 못하면 해당 task는 `skipped`, 전체는 `failed`다.
- 새 `runId`가 시작되면 이전 run의 이벤트는 무시한다.

## 오류·저장 정책

기존 API 오류 코드를 새 서버 오류 코드로 변환하지 않는다. 진행 영역에는 사용자가 다음 행동을 알 수 있는 문구를 표시하고, 상세 기술 오류는 기존 결과 카드 정책을 따른다. 이력 저장 실패는 분석 결과 자체와 구분해 `결과는 준비되었지만 분석 내역 저장에 실패했습니다`로 안내한다.
