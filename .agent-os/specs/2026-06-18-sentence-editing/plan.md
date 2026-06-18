# 문장 첨삭(맞춤 첨삭, 문장 단위) 계획

## Summary

사용자가 업로드한 이력서를 입력한 JD에 맞춰 개선한 버전(문장별 Before→After + 사유, `edits: [{ original, improved, reason }]`)으로 받아본다. 키워드처럼 매칭 응답에 얹지 않고 LLM 부하 분리를 위해 신규 전용 엔드포인트 `POST /api/sentence/preview`로 분리한다. 요청 형태·검증·`ErrorCode`·`ApiResponse<T>` 래퍼는 매칭과 동일하게 재사용하고, 새 에러 코드는 추가하지 않는다. `stub`/`fixture`/`ai-local` 모두 동일 스키마를 반환하며 `ai-local`만 Gemini를 호출한다. 프론트 `sentence` 옵션을 해금하고 결과 화면에 문장 첨삭 패널을 추가한다. 구현은 Codex가 담당.

## 변경 범위

- 문서: 새 active spec 추가, 직전 `2026-06-17-keyword-matching-breakdown` spec archive 이동, `.agent-os/index.yml`(또는 `standards/index.yml`)·`AGENTS.md` 활성 spec 포인터 갱신(이 문서 PR).
- 구현(백엔드, 신규 패키지 `com.jdsnack.sentence`):
  - `SentencePreviewController` — `POST /api/sentence/preview`.
  - `SentencePreviewService` — 모드 분기(`stub`/`fixture`는 결정적 산출, `ai-local`만 Gemini), 요청 검증은 매칭 `validateRequest` 정책 재사용.
  - DTO: `SentencePreviewRequest`(매칭 요청과 동형), `SentencePreviewResponse(List<SentenceEdit> edits)`, `SentenceEdit(original, improved, reason)`.
  - Provider 3종: `StubSentencePreviewProvider`/`FixtureSentencePreviewProvider`/`GeminiSentencePreviewProvider`. Gemini 프롬프트는 `com.jdsnack.match.GeminiMatchPreviewProvider.prompt()`(약 105~145행) 구조를 복제하되 출력 스키마를 `{"edits":[{"original","improved","reason"}]}` JSON-only·한국어로. `stripJsonFence` 재사용.
- 구현(프론트):
  - `frontend/src/types/diagnosis.ts`에 `SentenceEdit`/`SentencePreviewResult{edits}` 추가.
  - `frontend/src/services/api.ts`에 `previewSentence()` 추가(`previewMatch` 약 154~214행의 배열 안전처리 복제, 엔드포인트만 변경).
  - `frontend/src/hooks/useSentencePreview.ts`를 `useMatchPreview` 미러로 추가.
  - `frontend/src/App.tsx`: `ANALYSIS_OPTIONS.sentence`의 `enabled:false→true`(약 44행), 결과뷰 `submittedOptions.sentence` 분기를 `ComingSoonPanel`→문장 첨삭 패널(배지 "Sentence Edit", 문장별 Before→After 카드)로 교체(약 806~808행), `buildResultMarkdown`(약 99~142행)에 문장 첨삭 섹션 추가.

## 구현 지침

- 신규 엔드포인트는 매칭과 동일 계약·검증·에러 코드를 재사용한다(새 에러 코드 금지). `edits`는 항상 존재(빈 배열)·상한 8건.
- `stub`/`fixture`는 외부 호출 없이 결정적 `edits`를 반환한다(같은 입력 → 같은 결과).
- Gemini `edits` 필드는 관대 처리(누락/비배열 시 빈 리스트, 성공 유지). 비-JSON·호출 실패는 기존 `GEMINI_API_RESPONSE_INVALID`/`GEMINI_API_REQUEST_FAILED` 정책을 따른다.
- 문장 첨삭 패널은 키워드 패널의 `detail-card`/`successContent` 패턴을 차용하고, 서비스 계층(`previewSentence`)을 통해서만 데이터를 받는다.
- 사이드바 `맞춤 첨삭` 잠금 메뉴는 유지(별개 메뉴, `ui-spec.md` 결정).
- 직전 spec들의 통합 검증 게이트를 깨지 않는다(`sentence` 선택 시에도 게이트 통과 후 실행).
- 검증: 프론트 `npm run lint`/`npm test`/`npm run build`/`npm run test:e2e`, 백엔드 `./gradlew test`. 백엔드 미러 테스트(`GeminiSentencePreviewProviderTest`/`SentencePreviewControllerTest`/`SentencePreviewFixtureModeControllerTest`/`SentencePreviewAiLocalModeControllerTest`)와 프론트 sentence 옵션 해금·패널 표시 테스트(`App.test.tsx`)·e2e를 추가한다.

## 제외 범위

- 매칭/키워드 응답에 문장 첨삭을 얹는 방식. 신규 전용 엔드포인트로만 제공(LLM 부하 분리 확정).
- 새 ErrorCode, `ApiResponse<T>` 래퍼 변경, 검증 임계값(50/10,000) 변경.
- 다국어 첨삭, 배치/대량 처리, 첨삭 결과 저장·이력 등 speculative 확장.
- 사이드바 `맞춤 첨삭` 잠금 메뉴 해제, ATS 등 다른 "준비중" 옵션 해금, 문장 분리 알고리즘 고도화.

## 컨테이너 운영 기준

- 로컬 개발/검증은 `compose.local.yaml`(또는 `npm run dev` + 백엔드 로컬) 기준. `ai-local` 모드 검증은 `gemini-local-test-policy.md`를 따른다. 배포 영향 없음.

## 결정 사항 (확정 — 메인 세션 확정, Codex는 이대로 구현)

- **엔드포인트 분리**: 신규 전용 `POST /api/sentence/preview`로 **확정**. 매칭/키워드에 얹지 않음(LLM 부하 크고 단독 호출).
- **응답 형태**: `edits: [{ original, improved, reason }]` **확정**. 문장별 Before→After + 사유.
- **항목 수 상한**: `edits` **최대 8건** 확정(초과 시 앞에서부터 8건).
- **Gemini edits 검증**: **관대 처리 확정** — 누락/비배열이면 빈 리스트로 채우고 성공 유지. 비-JSON·호출 실패만 기존 `GEMINI_API_RESPONSE_INVALID`/`GEMINI_API_REQUEST_FAILED`.
- **검증/에러 정책**: 매칭과 **동일 재사용 확정**(50~10,000자, URL 검증, 기존 `ErrorCode`). 새 에러 코드 없음.
- **모드 동작**: `stub`/`fixture`는 결정적 산출(외부 호출 없음), `ai-local`만 Gemini 호출. 모든 모드 동일 스키마.
- **프론트 호출**: `sentence` 선택 시 `previewSentence`를 매칭과 **독립 호출**.
- **사이드바 잠금 메뉴**: `맞춤 첨삭` 잠금 **유지 확정**(별개 메뉴, 분석 옵션과 다름).
- **내보내기 마크다운**: `buildResultMarkdown`에 문장 첨삭 섹션 **추가**(sentence 선택 시). 빈 `edits` 안전 처리.
