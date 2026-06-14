# 새로운 분석 시작 페이지 재구성 API 명세

## 변경 없음

이번 spec은 **프론트 화면 재구성**이며 새 API를 추가하거나 기존 API 계약을 바꾸지 않는다. 아래 기존 엔드포인트를 그대로 호출한다.

- `POST /api/diagnose` · `POST /api/diagnose/file` — 이력서 진단 및 업로드 본문 추출(score, summary, strengths, improvements, sourceText)
- `POST /api/jd/fetch` — JD URL 본문 수집(jdText 등)
- `POST /api/match/preview` — 이력서↔JD 매칭(matchingScore, summary, strengths, gaps, suggestions)
- `POST /api/interview/preview` — 모의 면접 질문(questions[{question, category, keypoints}], strategy, summary)

## 계약 원칙

- 요청/응답 필드, 에러 코드, `ApiResponse<T>` 래퍼를 변경하지 않는다.
- `stub`/`fixture`/`ai-local` 모드 동작과 분기 결과를 화면 변경이 침해하지 않는다.
- 이력서 업로드 지원 형식은 백엔드 지원(PDF·DOCX) 기준이다(TXT 등 미지원 형식은 노출하지 않는다).

## 동작 매핑 (목업 옵션 → 기존 기능)

- `JD 적합도` 실행: 업로드 이력서를 `POST /api/diagnose/file`로 본문 추출(`sourceText`) → `POST /api/match/preview`로 JD와 매칭. 결과 = 매칭 응답.
- `ATS 분석`·`문장 첨삭`·`키워드 분석`: 대응 백엔드가 없어 호출하지 않으며 결과 화면에서 "준비중"으로 표시한다.
- 모의 면접: 기존 `POST /api/interview/preview` 흐름을 그대로 유지한다.
- 새 통합 분석 엔드포인트는 만들지 않는다(클라이언트에서 기존 호출을 조합).
