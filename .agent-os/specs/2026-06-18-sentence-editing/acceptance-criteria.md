# 문장 첨삭(맞춤 첨삭, 문장 단위) 수용 기준

## `AC-01` 신규 엔드포인트와 응답 계약

- `POST /api/sentence/preview`가 추가되고, 요청 본문은 매칭과 동일한 형태(`resumeSource{type,value}`, `jdText`, `jdUrl`)를 받는다.
- 응답은 `ApiResponse<SentencePreviewResponse>` 형태이며 `edits` 단일 필드(`SentenceEdit` 배열)를 포함한다.
- `edits`는 항상 존재한다(항목이 없으면 빈 리스트). null이 아니다.
- 각 `SentenceEdit`은 `original`/`improved`/`reason` 세 문자열 필드를 가진다.
- `edits` 항목 수가 상한(`api-spec.md`에 명시된 8건)을 넘지 않는다.

## `AC-02` stub/fixture 모드 첨삭 산출

- `stub`/`fixture` 모드에서 외부 호출 없이 `edits`가 반환된다(필드 존재 보장, null 아님).
- 동일 입력에 대해 결과가 결정적이다(같은 이력서·JD → 같은 `edits`).
- 상한(8건)을 넘지 않는다.

## `AC-03` ai-local(Gemini) 모드 첨삭 산출

- `ai-local` 모드에서 Gemini 프롬프트 스키마에 `edits` 배열이 포함되고, 응답에서 `edits`(각 항목 `original`/`improved`/`reason`)로 파싱된다.
- Gemini 응답에서 `edits`가 누락/비배열이면 `api-spec.md`의 관대 처리 정책대로 빈 리스트로 채우고 성공 응답을 유지한다.
- Gemini 호출 실패·응답 비-JSON 등 기존 결함은 기존 `GEMINI_API_REQUEST_FAILED`/`GEMINI_API_RESPONSE_INVALID` 정책과 일관되게 처리된다.

## `AC-04` 검증·에러 정책 재사용

- 이력서/JD 길이(50~10,000자)·JD URL 검증이 매칭과 동일하게 적용되고, 위반 시 기존 `ErrorCode`(`EMPTY_RESUME`/`TEXT_TOO_SHORT`/`TEXT_TOO_LONG`/`EMPTY_JD`/`JD_TEXT_TOO_SHORT`/`JD_TEXT_TOO_LONG`/`INVALID_JD_URL`)로 반환된다.
- `ai-local` 모드에서 API 키 누락 시 `GEMINI_API_KEY_MISSING`으로 반환된다.
- 새 에러 코드·새 응답 래퍼 변경은 없다(`ApiResponse<T>` 그대로).

## `AC-05` 프론트 sentence 옵션 해금 + 패널

- 분석 옵션 목록에서 `문장 첨삭`(sentence) 항목이 선택 가능하고 "준비중" 태그가 표시되지 않는다. **[개정 2026-06-19] 옵션 라벨은 `문장 첨삭`이다(이전 `맞춤 첨삭`에서 변경; 결과 패널 제목·내보내기 섹션명과 일치).**
- `sentence`를 선택해 제출하면 결과 화면에 문장 첨삭 패널(문장별 Before→After 카드 + 사유)이 표시되고, `ComingSoonPanel`이 표시되지 않는다.
- `sentence`를 선택하지 않으면 문장 첨삭 패널이 표시되지 않는다.
- 문장 첨삭 패널은 신규 호출(`previewSentence`) 응답(`SentencePreviewResult`)의 `edits`에서 값을 가져온다.

## `AC-06` 독립 호출 정합

- `sentence`가 선택되면 신규 호출(`previewSentence`)이 수행되어 첨삭 데이터를 받는다. 이 호출은 매칭(`previewMatch`)과 독립적이다(둘 다 선택 시 각각 호출).
- `edits`가 비어 있는 경우(0건)에도 패널은 빈 상태 문구로 깨지지 않고 표시된다.
- 로딩/에러 상태는 기존 `AnalysisPanel`/result status 패턴과 동일하게 표시된다.

## `AC-07` 통합 검증 게이트·기존 흐름 보존

- `sentence` 옵션 선택 시에도 직전 spec들의 통합 검증 게이트를 통과한 뒤에만 분석이 실행된다(이력서 선택 + JD 50~10,000자 + 분석 항목 1개 이상).
- 기존 패널(JD 적합도·키워드)·진단→분석 순서·기존 에러 처리(키 누락·Gemini 실패 등)가 유지된다.
- 응답은 기존 `ApiResponse<T>` 래퍼·`ErrorCode` 체계를 그대로 따른다(새 엔드포인트는 추가, 새 에러 코드는 없음).
- 내보내기 마크다운(`buildResultMarkdown`)에 `sentence` 선택 시 문장 첨삭 섹션이 포함되고, 빈 `edits`에서도 안전하게 렌더된다.
- 문장 첨삭 패널은 명확한 label/role과 좁은 폭 레이아웃 기준(접근성·반응형)을 따른다.
- **[개정 2026-06-19] 사이드바 잠금 메뉴(`AppShell.tsx` lockedItems)에 `맞춤 첨삭` 항목이 더 이상 존재하지 않는다(live 기능을 🔒준비중으로 중복 노출하던 항목 제거). 다른 잠금 항목은 그대로 유지된다.**
