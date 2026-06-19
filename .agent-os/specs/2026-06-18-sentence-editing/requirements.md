# 문장 첨삭(맞춤 첨삭, 문장 단위) 요구사항

사용자가 업로드한 이력서를 입력한 JD에 **맞춰 개선한 버전**으로 받아본다. 산출물은 **문장별 Before→After + 개선 사유**(`edits: [{ original, improved, reason }]`)이다. 키워드 매칭처럼 기존 매칭 응답에 얹지 않고, LLM 부하가 크고 단독 호출되어야 하므로 **신규 전용 엔드포인트** `POST /api/sentence/preview`로 분리한다. 모든 모드(`stub`/`fixture`/`ai-local`)가 동일한 응답 스키마를 반환하며, 검증·에러 정책은 매칭(`/api/match/preview`)과 동일하게 재사용한다.

## 배경 (현재 화면·코드)

- JD 적합도 매칭은 `POST /api/match/preview`(`backend/src/main/java/com/jdsnack/match/MatchPreviewController.java`)로 제공되며, 요청은 `MatchPreviewRequest`(`resumeSource{type,value}`, `jdText`, `jdUrl`), 응답은 `ApiResponse<MatchPreviewResponse>` 형태다.
- 모드 분기는 `MatchPreviewService`가 담당한다(`stub`/`fixture`는 `buildPreview`, `ai-local`만 `GeminiMatchPreviewProvider`로 분기). 요청 검증(`validateRequest`)·`ErrorCode` 체계·`stripJsonFence`/`toStringList` 헬퍼가 이미 존재한다.
- 프론트 분석 옵션 `sentence`는 현재 `enabled: false`("준비중", `frontend/src/App.tsx` 약 44행)이고, 결과 화면 `submittedOptions.sentence` 자리에는 `ComingSoonPanel`만 있다.
- 사이드바에는 `맞춤 첨삭` 잠금 메뉴가 있다(`frontend/src/components/AppShell.tsx` 약 13행 `lockedItems`). **[개정 2026-06-19] 이 잠금 메뉴가 가리키던 기능이 본 spec의 문장 첨삭이며, live 기능이 🔒준비중으로 중복 노출되는 결함이라 제거 대상으로 재분류한다(REQ-04 참조).**

## 용어 정의 (문장 첨삭)

- **edit(첨삭 항목)**: 이력서의 한 문장(또는 한 문장 단위 구절)에 대한 개선 제안. `{ original, improved, reason }`로 구성된다.
  - **original**: 이력서 원문 문장.
  - **improved**: JD에 맞춰 개선한 문장.
  - **reason**: 왜 그렇게 고쳤는지에 대한 한국어 개선 사유.
- **edits**: 첨삭 항목의 배열. 항상 존재하며(없으면 빈 리스트), 항목 수에 상한을 둔다(아래 `REQ-01` 참조).

## `REQ-01` 신규 전용 엔드포인트와 응답 계약

- 신규 엔드포인트 `POST /api/sentence/preview`를 추가한다. 요청 본문은 매칭과 동일(`MatchPreviewRequest`와 같은 형태: `resumeSource{type,value}`, `jdText`, `jdUrl`)이며, 별도 요청 DTO `SentencePreviewRequest`로 정의한다.
- 응답은 `ApiResponse<SentencePreviewResponse>` 형태이며, `SentencePreviewResponse`는 `List<SentenceEdit> edits` 단일 필드를 갖는다. `SentenceEdit`은 `original`/`improved`/`reason`(각 문자열)으로 구성된다.
- `edits`는 항상 존재한다(없으면 빈 리스트, null 아님). 항목 수에는 상한을 둔다(확정: **최대 8건**, `api-spec.md` 참조).

## `REQ-02` 모드 전체 동일 계약 (stub / fixture / ai-local)

- 세 모드 모두 동일한 `edits` 스키마를 반환한다(필드 존재 보장).
- `stub`/`fixture`: 결정적인 고정/모의 첨삭 항목을 반환한다(외부 호출 없음). 동일 입력에 대해 결정적 결과를 보장한다.
- `ai-local`(Gemini): 매칭의 `GeminiMatchPreviewProvider.prompt()` 구조를 복제하되 출력 스키마를 `{"edits":[{"original","improved","reason"}]}` JSON-only·한국어로 둔다. `stripJsonFence`/JSON 파싱 헬퍼를 재사용한다.

## `REQ-03` 검증·에러 정책 재사용

- 요청 검증은 매칭과 동일하게 재사용한다: 이력서/JD 길이 50~10,000자, JD URL 검증. `ErrorCode`(`EMPTY_RESUME`/`TEXT_TOO_SHORT`/`TEXT_TOO_LONG`/`EMPTY_JD`/`JD_TEXT_TOO_SHORT`/`JD_TEXT_TOO_LONG`/`INVALID_JD_URL`/`GEMINI_API_KEY_MISSING`/`GEMINI_API_REQUEST_FAILED`/`GEMINI_API_RESPONSE_INVALID`)를 그대로 사용한다. **새 에러 코드는 추가하지 않는다.**
- Gemini 응답에서 `edits` 누락/비배열은 **관대 처리**(빈 리스트로 채우고 성공 유지)한다. 그 외 응답 자체가 JSON으로 파싱 불가하거나 필수 구조가 깨진 경우는 기존 `GEMINI_API_RESPONSE_INVALID` 정책과 일관되게 처리한다(`api-spec.md`에서 확정).

## `REQ-04` 프론트 sentence 옵션 해금 + 결과 패널

- `ANALYSIS_OPTIONS`의 `sentence` 항목을 `enabled: true`로 바꿔 선택 가능하게 한다("준비중" 태그 제거, `frontend/src/App.tsx` 약 44행). **[개정 2026-06-19] 옵션 라벨은 `문장 첨삭`으로 한다(이전 `맞춤 첨삭`에서 변경; 결과 패널 제목·내보내기 섹션명과 일치, `ui-spec.md` 결정 참조).**
- **[개정 2026-06-19] 사이드바 `맞춤 첨삭` 잠금 메뉴를 제거한다**(`frontend/src/components/AppShell.tsx` `lockedItems`에서 `'맞춤 첨삭'` 한 줄 제거). live인 문장 첨삭을 🔒준비중으로 중복·거짓 노출하던 항목이며, 별도 전용 화면 계획은 없다(`ui-spec.md` 결정 참조).
- `sentence` 옵션이 제출에 포함되면, 결과 화면의 `submittedOptions.sentence` 자리에 `ComingSoonPanel` 대신 **문장 첨삭 패널**(문장별 Before→After 카드 + 사유)을 표시한다.
- 문장 첨삭은 신규 엔드포인트에 의존하므로, `sentence`가 선택되면 신규 호출(`previewSentence`)이 수행되도록 한다. 매칭(`previewMatch`)과는 **독립된 호출**이다(LLM 부하 분리).
- 프론트 타입(`frontend/src/types/diagnosis.ts`)에 `SentenceEdit`/`SentencePreviewResult{edits}`를 추가하고, 서비스(`frontend/src/services/api.ts`)에 `previewSentence()`를, 훅(`frontend/src/hooks/useSentencePreview.ts`)을 `useMatchPreview` 미러로 추가한다.

## `REQ-05` 통합 검증 게이트와의 정합

- 직전 spec들의 통합 검증 게이트를 따른다: `sentence` 옵션을 선택해도 이력서(파일/텍스트 선택)·JD(최소/최대 길이)·분석 항목(1개 이상) 검증을 통과한 뒤에만 분석이 실행된다.
- 빈 결과(`edits` 0건)에도 패널은 빈 상태 문구로 깨지지 않고 표시된다.
- 내보내기(`buildResultMarkdown`, `frontend/src/App.tsx` 약 99~142행)에 문장 첨삭 섹션을 더한다(`sentence` 선택 시). 빈 분류는 안전 처리한다.

## 범위 밖

- 매칭/키워드 응답에 문장 첨삭을 얹는 방식. 문장 첨삭은 신규 전용 엔드포인트로만 제공한다(LLM 부하 분리가 확정 결정).
- 검증 임계값(JD/이력서 50/10,000) 변경, `ApiResponse<T>` 래퍼·`ErrorCode` 체계 변경, 새 에러 코드 추가.
- 다국어 첨삭, 배치/대량 처리, 첨삭 결과 저장·이력 관리 등 speculative 확장.
- ATS 등 다른 "준비중" 옵션 해금, 문장 분리·문장 단위 추출 알고리즘 고도화.
- 사이드바 `맞춤 첨삭` 잠금 메뉴를 **다른 화면으로 재구현**하는 것(잠금 메뉴는 제거만 하고, 별도 전용 화면은 만들지 않는다 — REQ-04·`ui-spec.md` 결정 참조).

> 변경 이력: [2026-06-19] 사이드바 `맞춤 첨삭` 잠금 메뉴 "해제"는 본래 범위 밖이었으나, 머지 후 중복/거짓 노출 결함이 확인되어 REQ-04로 이동(제거 확정). 옵션 라벨도 `맞춤 첨삭`→`문장 첨삭`으로 개정.
