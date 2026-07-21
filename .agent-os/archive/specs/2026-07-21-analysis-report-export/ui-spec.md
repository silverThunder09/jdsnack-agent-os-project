# 분석 결과 리포트 내보내기 UI 계약

## 입력

- 분석 내역 상세(`AnalysisHistoryView`의 `history-detail`) 영역에 내보내기 진입점을 추가한다.
- 진입점은 `AnalysisResultView`의 기존 `내보내기` 버튼과 동일한 라벨·상호작용 패턴을 재사용한다.

## 상태

- `SUCCEEDED`: 내보내기 진입점이 활성화되고, 클릭 시 Markdown 파일이 다운로드된다.
- `RUNNING`: `내보내기` 버튼을 비활성화하고 `분석이 완료된 이력만 내보낼 수 있습니다.`를 안내한다.
- `FAILED`: `내보내기` 버튼을 비활성화하고 `분석이 완료된 이력만 내보낼 수 있습니다.`를 안내하며 빈 파일을 만들지 않는다.
- `SUCCEEDED`이지만 저장 결과가 없으면 버튼을 비활성화하고 `저장된 분석 결과가 없어 내보낼 수 없습니다.`를 안내한다.

## 내보내기 파일

- 파일명은 이력 식별자와 생성일을 포함한다(예: `jdsnack-분석결과-{historyId}-{YYYYMMDD}.md`). content type은 `text/markdown`이다.
- Markdown 본문은 이력에 저장된 `diagnosis`·`match` 결과만 섹션으로 포함하며, 없는 옵션 섹션은 생략한다.

## 접근성·회귀

- 비활성·안내 상태는 시각 정보만으로 구분하지 않는다(`aria-disabled` 또는 텍스트 안내 병행).
- 기존 `AnalysisResultView` 실시간 내보내기 흐름을 변경하지 않는다.
