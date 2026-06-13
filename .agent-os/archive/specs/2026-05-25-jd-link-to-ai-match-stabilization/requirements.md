# JD 링크 to AI 매칭 안정화 요구사항

## `REQ-01` JD 링크 성공 흐름 연결

- 사용자는 JD 링크를 입력해 JD 본문을 불러올 수 있어야 한다.
- `POST /api/jd/fetch` 성공 시 프론트는 반환된 `jdText`를 JD textarea에 자동 반영해야 한다.
- 자동 반영된 JD 본문은 즉시 `JD 비교 미리보기` 요청에 사용할 수 있어야 한다.

## `REQ-02` JD 링크 실패 복구

- JD 링크 수집 실패가 JD 직접 입력과 매칭 요청 흐름을 막으면 안 된다.
- 실패 시 화면은 실패 이유와 복구 행동 하나를 보여준다.
- 기본 복구 행동은 `JD 본문을 직접 붙여넣어 주세요.`로 고정한다.
- 실패 후 사용자가 직접 JD 본문을 입력하면 `POST /api/match/preview`를 호출할 수 있어야 한다.

## `REQ-03` 이력서 입력 경로 유지

- 이력서 텍스트 입력 경로와 PDF/DOCX 업로드 경로를 모두 유지한다.
- 파일 업로드 경로에서는 분석 성공 응답의 `sourceText`를 JD 매칭의 resume source로 사용한다.
- 이력서 분석 실패 상태에서는 JD 매칭 요청을 막고 사용자가 먼저 이력서를 준비하도록 안내한다.

## `REQ-04` 기존 API 계약 유지

- 새 API를 추가하지 않는다.
- 기존 `POST /api/jd/fetch`, `POST /api/match/preview`, `POST /api/diagnose`, `POST /api/diagnose/file` 계약을 유지한다.
- `POST /api/match/preview` 응답은 `matchingScore`, `summary`, `strengths`, `gaps`, `suggestions` 구조를 유지한다.

## `REQ-05` 구현 범위 제한

- 이번 spec은 JD 링크 결과가 AI 매칭 리포트까지 이어지는 사용자 흐름 안정화에 집중한다.
- 잡코리아, 원티드, 로그인 필요 페이지, anti-bot 우회는 범위에서 제외한다.
- Gemini 응답 스키마와 백엔드 AI provider 계약은 변경하지 않는다.
