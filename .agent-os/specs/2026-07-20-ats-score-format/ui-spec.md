# ATS 점수·포맷 진단 UI 계약

## 대상 화면·파일

- 분석 옵션 목록: `frontend/src/features/analysis/analysisUtils.ts`의 `ANALYSIS_OPTIONS`(`ats` 항목, 현재 `enabled: false`).
- 결과 화면 패널: `frontend/src/features/analysis/AnalysisResultView.tsx`의 `submittedOptions.ats` 분기(현재 `ComingSoonPanel`을 렌더).
- 패널 컴포넌트: `frontend/src/features/analysis/AnalysisPanels.tsx`(`AnalysisPanel`/`SummaryCard`/`KeywordList` 재사용, `ComingSoonPanel`은 ATS에서는 더 이상 사용 안 함).
- 타입: `frontend/src/types/diagnosis.ts`.
- 서비스·훅: `frontend/src/services/`의 API 호출 계층과 기존 `useMatchPreview`/문장 preview 훅 패턴.

## 옵션 해금

- `ANALYSIS_OPTIONS`의 `ats` 항목을 `enabled: true`로 변경한다. 현재 `enabled: false`라 "준비중" 태그가 붙고 선택이 막혀 있다.
- `ats` 라벨/설명은 기존 문구(`ATS 분석` / `ATS 통과 가능성과 포맷, 키워드 최적화 여부를 분석합니다.`)를 유지한다.
- `DEFAULT_OPTIONS.ats`는 이미 `true`이므로 기본 선택 상태는 그대로 둔다(저장된 입력 복원 로직과의 정합 확인).
- 이 옵션이 마지막 "준비중" 옵션이므로 해금 후 결과 화면에는 `ComingSoonPanel`을 렌더하는 분기가 남지 않는다.

## 결과 패널 (ATS 진단)

- `submittedOptions.ats`가 true일 때, 현재 `ComingSoonPanel`(`AnalysisResultView.tsx`) 대신 **ATS 진단 패널**을 렌더한다. 기존 `AnalysisPanel`(badge/title/description/result/successContent) 구조를 그대로 재사용해 로딩·에러·빈 상태를 일관되게 처리한다.
- 종합 점수: `jdMatch`의 `SummaryCard` 패턴을 참고해 `atsScore`·`summary`를 점수 카드로 표시한다.
- `successContent` 구성 — 세 섹션을 기존 `detail-list-grid`·`detail-card` 스타일로 표시한다:
  - **파싱 안전성**: `parsingWarnings`를 리스트로. 빈 배열이면 "파싱 위험 요소가 없습니다." 등 안전 문구.
  - **구조 진단**: `presentSections`/`missingSections`/`sectionOrderWarnings`를 구분해 표시.
  - **키워드 최적화**: `jdKeywordsCovered`/`jdKeywordsMissing`를 `KeywordList`(빈 상태 문구 내장)로 표시.
- 데이터 출처: 새 ATS 결과 상태(`previewResult`와 별개의 ATS 전용 result state). ATS는 매칭·문장과 독립 엔드포인트이므로 문장 첨삭(`sentenceResult`)과 동일하게 **자체 result state**를 갖는다.
- 로딩/에러/빈 상태: 기존 `AnalysisPanel`/`ResultState`(`idle | loading | success | not-enabled | error`) 패턴을 공유한다.

## 타입·서비스 매핑

- `frontend/src/types/diagnosis.ts`에 `AtsPreviewResult`(`atsScore: number`, `summary: string`, `parsingWarnings: string[]`, `presentSections: string[]`, `missingSections: string[]`, `sectionOrderWarnings: string[]`, `jdKeywordsCovered: string[]`, `jdKeywordsMissing: string[]`)와 요청 타입을 추가한다. 요청 타입은 기존 `MatchPreviewRequest` 형태를 재사용/참조한다.
- `services/` 계층에 `previewAts`(문장 첨삭의 `previewSentence` 패턴)를 추가해 `POST /api/ats/preview`를 호출하고 응답의 목록 필드를 방어적으로(빈 배열 기본값) 매핑한다.
- 컴포넌트는 서비스 계층을 통해서만 데이터를 받는다(직접 fetch 금지, 기존 경계 유지). `ApiErrorCode` 유니온은 새 코드가 없으므로 확장하지 않는다.

## ATS 호출 트리거

- `ats`는 매칭·문장과 독립된 단독 엔드포인트 호출이다. 분석 실행 시 `submittedOptions.ats`가 true이면 `previewAts`를 1회 호출한다(문장 첨삭이 `sentence` 선택 시 독립 호출되는 것과 동일).
- `ats`만 선택 시: ATS 패널만 표시되고 JD 적합도·키워드·문장 패널은 표시되지 않는다.
- 내보내기/인쇄 버튼 노출 조건(`AnalysisResultView.tsx`의 결과 액션 분기)에 ATS 성공 케이스를 포함해, ATS 단독 사용자도 결과를 내보낼 수 있게 한다(성공한 분석이 하나라도 있으면 노출).

## 내보내기 마크다운

- `analysisUtils.ts`의 `buildResultMarkdown`에 `ats` 선택 시 ATS 섹션을 추가한다: 종합 점수·요약, 파싱 안전성, 구조 진단, 키워드 최적화. 빈 분류는 기존 `list()` 헬퍼처럼 "(없음)"으로 안전 처리한다.

## 접근성·반응형

- ATS 패널의 각 섹션은 명확한 제목(예: `파싱 안전성`/`구조 진단`/`키워드 최적화`)을 가진다.
- 리스트·칩은 좁은 폭에서 줄바꿈되며 겹치지 않는다.
- 빈 상태 문구는 시각적으로 섹션과 연결되고 스크린리더로 읽힌다.

## 마이그레이션 메모

- ATS 진단 임계값·상한·점수 산출은 백엔드 책임이므로 프론트에서 새로 정의하지 않는다.
- 결과 화면의 다른 패널(JD 적합도·키워드·문장 첨삭)과 셸은 변경하지 않는다. `ats` 분기와 ATS 호출 트리거, 내보내기 섹션만 손댄다.
- T1에서 `ats` 옵션 해금과 파싱 안전성 섹션까지 표시하고, T2(구조)·T3(키워드)에서 패널 섹션과 내보내기 항목을 하위호환으로 확장한다.
