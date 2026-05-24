# 요구사항

## 목표

`POST /api/match/preview`가 `ai-local` 모드에서 규칙 기반 미리보기가 아니라 실제 Gemini 기반 JD 매칭 결과를 반환해야 한다.

## 요구사항

- `REQ-01` `ai-local` 모드에서는 JD 비교 요청 시 Gemini 기반 결과를 반환해야 한다.
- `REQ-02` 응답 필드는 기존 계약인 `matchingScore`, `summary`, `strengths`, `gaps`, `suggestions`를 유지해야 한다.
- `REQ-03` `stub` 또는 `fixture` 모드에서는 기존 규칙 기반 JD 미리보기를 유지해야 한다.
- `REQ-04` Gemini 연동 실패는 `GEMINI_API_KEY_MISSING`, `GEMINI_API_REQUEST_FAILED`, `GEMINI_API_RESPONSE_INVALID`로 구분해야 한다.
- `REQ-05` 프론트는 JD AI 매칭 실패와 일반 JD 입력 검증 실패를 구분해 보여줘야 한다.

## 범위 밖

- JD 링크 HTML 수집
- 운영 배포 환경의 JD AI 매칭
- JD 저장용 영속 DB 확장
