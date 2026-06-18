# 문장 첨삭(맞춤 첨삭, 문장 단위) UI 명세

## 대상 화면

- 입력 화면(`frontend/src/App.tsx`)의 분석 옵션 목록(`ANALYSIS_OPTIONS`, 약 22~57행) 중 `sentence` 항목(약 44행).
- 결과 화면(`frontend/src/App.tsx`)의 `submittedOptions.sentence` 분기(약 806~808행, 현재 `ComingSoonPanel`).
- 내보내기 마크다운(`buildResultMarkdown`, 약 99~142행).

## 옵션 해금

- `ANALYSIS_OPTIONS`의 `sentence` 항목을 `enabled: true`로 변경한다(약 44행). 현재 `enabled: false`라 "준비중" 태그(`option-tag--soon`)가 붙고 선택이 막혀 있다.
- `sentence` 라벨/설명은 기존 문구(`맞춤 첨삭` 계열)를 유지한다.
- `DEFAULT_OPTIONS.sentence`는 이미 `true`이므로(약 75행) 기본 선택 상태는 그대로 두되, 저장된 입력 복원 로직과의 정합을 확인한다.

## 결과 패널 (문장 첨삭)

- `submittedOptions.sentence`가 true일 때, 현재 `ComingSoonPanel`(약 806~808행) 대신 **문장 첨삭 패널**을 렌더한다. 패널 배지는 "Sentence Edit"로 둔다.
- 패널 구성: `edits` 각 항목을 **문장별 카드**로 표시한다(원문 → 개선문 → 사유 순). 키워드 패널의 `detail-card`/`successContent` 패턴을 차용해 시각적 일관성을 유지한다.
  - 카드 1개 = 한 `SentenceEdit`. `original`(Before)·`improved`(After)·`reason`(사유)을 명확한 라벨과 함께 표시한다.
- 데이터 출처: 신규 호출(`previewSentence`) 응답(`SentencePreviewResult`)의 `edits`.
- 빈 상태: `edits`가 빈 배열이면 빈 상태 문구(예: "첨삭할 문장이 없습니다.")를 표시하고 레이아웃을 깨지 않는다.
- 로딩/에러: 신규 호출이 진행 중이거나 실패하면 기존 `AnalysisPanel`/result status 패턴과 동일하게 로딩·에러 상태를 표시한다(문장 첨삭 패널은 자신의 result 상태를 공유).

## 타입·서비스·훅 매핑

- `frontend/src/types/diagnosis.ts`에 `SentenceEdit { original: string; improved: string; reason: string }`와 `SentencePreviewResult { edits: SentenceEdit[] }`를 추가한다.
- `frontend/src/services/api.ts`에 `previewSentence()`를 추가한다. 매칭의 `previewMatch`(약 154~214행)의 배열 안전처리(빈 배열 방어, 응답 매핑) 패턴을 복제하되 엔드포인트만 `/api/sentence/preview`로, 매핑 필드만 `edits`로 둔다.
- `frontend/src/hooks/useSentencePreview.ts`를 `useMatchPreview` 미러로 추가한다(상태·트리거·에러 처리 동일 구조).
- 컴포넌트는 서비스 계층(`previewSentence`)을 통해서만 데이터를 받는다(직접 fetch 금지, 기존 경계 유지).

## 호출 트리거 (sentence 정합)

- `sentence`가 선택되면 신규 호출(`previewSentence`)을 수행한다. 이 호출은 매칭(`previewMatch`)과 **독립적**이다(LLM 부하 분리가 확정 결정).
- **표시 분기**:
  - JD 적합도/키워드 패널은 각각 `submittedOptions.jdMatch`/`submittedOptions.keyword`일 때만 표시(현행 유지).
  - 문장 첨삭 패널은 `submittedOptions.sentence`일 때 표시.
  - `sentence`만 선택 시: `previewSentence`만 호출되고 문장 첨삭 패널만 보인다.
- 내보내기/인쇄 버튼 노출 조건은 기존 패턴을 따르되, 문장 첨삭 단독 성공 결과도 내보낼 수 있도록 `sentence` 성공 결과를 포함한다(직전 키워드 spec의 "성공 결과가 있으면 노출" 기조와 일관).

## 사이드바 잠금 메뉴 결정

- 사이드바 `맞춤 첨삭` 잠금 메뉴(`frontend/src/components/AppShell.tsx` 약 13행 `lockedItems`)는 **유지한다(해제하지 않음)**.
- 근거: 사이드바 `맞춤 첨삭`은 분석 옵션 `sentence`와는 **별개 메뉴**(독립 화면/내비게이션)이며, 본 spec은 분석 옵션 `sentence`의 해금만 다룬다. 별도 화면을 구현하지 않으므로 잠금 메뉴를 풀 명확한 근거가 없다. ("없는 기능은 구현하지 말 것" 기조에 따라 surgical하게 분석 옵션만 해금.)

## 접근성·반응형

- 각 문장 카드는 Before/After/사유에 대한 명확한 라벨(예: `원문`/`개선문`/`개선 사유`)을 가진다.
- 카드와 텍스트는 좁은 폭에서 줄바꿈되며 겹치지 않는다.
- 빈 상태 문구는 시각적으로 패널과 연결되고 스크린리더로 읽힌다.

## 마이그레이션 메모

- 첨삭 항목 상한(8)은 백엔드가 책임지므로 프론트에서 새로 정의하지 않는다.
- 결과 화면의 다른 패널(JD 적합도·키워드·ATS의 `ComingSoonPanel`)과 셸은 변경하지 않는다. `sentence` 분기와 신규 호출 트리거만 손댄다.
- `buildResultMarkdown`(약 99~142행)에 `sentence` 선택 시 문장 첨삭 섹션(문장별 Before→After + 사유)을 더한다. 빈 `edits`는 "없음" 등으로 안전 처리한다.
