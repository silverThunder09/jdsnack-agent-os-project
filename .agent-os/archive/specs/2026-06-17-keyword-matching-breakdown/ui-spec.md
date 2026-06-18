# 키워드 매칭 구조화 / 키워드 분석 옵션 해금 UI 명세

## 대상 화면

- 입력 화면(`frontend/src/App.tsx`)의 분석 옵션 목록(`ANALYSIS_OPTIONS`, 약 22~57행).
- 결과 화면(`frontend/src/App.tsx` `renderResultView`, 약 705~775행)의 `preview-grid` 내 `submittedOptions.keyword` 분기(약 770~772행).

## 옵션 해금

- `ANALYSIS_OPTIONS`의 `keyword` 항목을 `enabled: true`로 변경한다. 현재 `enabled: false`라 "준비중" 태그(`option-tag--soon`, 약 625행)가 붙고 선택이 막혀 있다.
- `keyword` 라벨/설명은 기존 문구(`키워드 분석` / `주요 키워드 누락 여부와 활용도를 분석합니다.`)를 유지한다.
- `DEFAULT_OPTIONS.keyword`는 이미 `true`이므로 기본 선택 상태는 그대로 둔다(저장된 입력 복원 로직과의 정합 확인).

## 결과 패널 (키워드 브레이크다운)

- `submittedOptions.keyword`가 true일 때, 현재 `ComingSoonPanel`(약 770~772행) 대신 **키워드 브레이크다운 패널**을 렌더한다.
- 패널 구성: 세 섹션(매칭 / 부분 / 누락)을 칩/리스트 형태로 표시. 기존 `detail-card`·`detail-list-grid` 스타일 패턴(JD 적합도 패널, 약 748~761행)을 재사용해 시각적 일관성을 유지한다.
- 데이터 출처: `previewResult.matchPreview`(`MatchPreviewResult`)의 새 필드 `matchedKeywords`/`partialKeywords`/`missingKeywords`.
- 빈 상태: 특정 분류가 빈 배열이면 해당 섹션에 빈 상태 문구(예: "해당 키워드가 없습니다.")를 표시하고 레이아웃을 깨지 않는다.
- 로딩/에러: 매칭 호출이 진행 중이거나 실패하면 기존 `AnalysisPanel`/`previewResult.status` 패턴과 동일하게 로딩·에러 상태를 표시한다(키워드 패널도 동일 result 상태를 공유).

## 타입·서비스 매핑

- `frontend/src/types/diagnosis.ts`의 `MatchPreviewResult`에 `matchedKeywords: string[]`, `partialKeywords: string[]`, `missingKeywords: string[]`를 추가한다.
- `frontend/src/services/api.ts`의 `previewMatch`가 백엔드 응답의 새 필드를 그대로 매핑한다(서버 응답이 빈 배열을 보장하므로 기본값 처리는 방어적으로 둔다).
- 컴포넌트는 서비스 계층(`previewMatch`)을 통해서만 데이터를 받는다(직접 fetch 금지, 기존 경계 유지).

## 매칭 호출 트리거 (keyword 정합)

- 현행 `handleStartAnalysis`(약 415~451행)는 `options.jdMatch`일 때만 `submitFile` → `submitPreview`를 호출한다.
- 변경: `options.jdMatch || options.keyword`일 때 매칭 호출을 수행한다(키워드 패널이 매칭 응답에 의존하므로).
- **표시 분기(권장 동작)**:
  - JD 적합도 점수 카드(`summary-grid`, 약 729~738행)·JD 적합도 상세 패널(`AnalysisPanel`, 약 741~764행)은 `submittedOptions.jdMatch`일 때만 표시(현행 유지).
  - 키워드 브레이크다운 패널은 `submittedOptions.keyword`일 때 표시.
  - 따라서 `keyword`만 선택 시: 매칭 호출은 1회 발생하지만 화면에는 키워드 패널만 보이고 점수/강점/gap/제안 패널은 보이지 않는다.
- 내보내기/인쇄 버튼 노출 조건(`submittedOptions.jdMatch && previewResult.status === 'success'`, 약 713행)을 키워드 단독 케이스에서 어떻게 다룰지는 열린 질문으로 남긴다(권장: 현행 조건 유지, 키워드 단독이면 미노출).

## 접근성·반응형

- 키워드 패널의 각 섹션은 명확한 제목(예: `매칭 키워드`/`부분 매칭`/`누락 키워드`)을 가진다.
- 칩/리스트는 좁은 폭에서 줄바꿈되며 겹치지 않는다.
- 빈 상태 문구는 시각적으로 섹션과 연결되고 스크린리더로 읽힌다.

## 마이그레이션 메모

- 키워드 추출 임계값/상한은 백엔드가 책임지므로 프론트에서 새로 정의하지 않는다.
- 결과 화면의 다른 패널(ATS/문장 첨삭의 `ComingSoonPanel`)과 셸·기존 JD 적합도 패널은 변경하지 않는다. `keyword` 분기와 매칭 트리거 조건만 손댄다.
- `buildResultMarkdown`(내보내기, 약 99~119행)에 키워드 섹션을 더할지는 선택 사항으로 두되, 더한다면 빈 분류 처리에 주의한다(열린 질문).
