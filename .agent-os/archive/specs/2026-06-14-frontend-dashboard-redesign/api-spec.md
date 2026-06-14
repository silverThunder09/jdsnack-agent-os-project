# 프론트 대시보드 전면 재설계 API 명세

## 변경 없음

이번 spec은 **프론트 화면 재설계**이며 새 API를 추가하거나 기존 API 계약을 바꾸지 않는다. 대시보드는 아래 기존 엔드포인트를 그대로 호출한다.

- `POST /api/diagnose` · `POST /api/diagnose/file` — 이력서 진단(score, summary, strengths, improvements)
- `POST /api/jd/fetch` — JD URL 본문 수집(jdText 등)
- `POST /api/match/preview` — 이력서↔JD 매칭(matchingScore, summary, strengths, gaps, suggestions)
- `POST /api/interview/preview` — 모의 면접 질문(questions[{question, category, keypoints}], strategy, summary)

## 계약 원칙

- 요청/응답 필드, 에러 코드, `ApiResponse<T>` 래퍼를 변경하지 않는다.
- `stub`/`fixture`/`ai-local` 모드 동작과 그 분기 결과를 화면 구조 변경이 침해하지 않는다.
- resume source(`TEXT`/`FILE` + value)를 진단·매칭·면접 호출에 동일하게 전달한다.
- 계약 변경이 필요해지면 이 spec 범위 밖 변경으로 분리한다.
