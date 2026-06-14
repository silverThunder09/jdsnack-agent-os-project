# 프론트 SaaS 셸 재설계 API 명세

## 변경 없음

이번 spec은 **프론트 비주얼/UX 재설계**이며 새 API를 추가하거나 기존 API 계약을 바꾸지 않는다. 셸은 아래 기존 엔드포인트를 그대로 호출한다.

- `POST /api/diagnose` · `POST /api/diagnose/file` — 이력서 진단(score, summary, strengths, improvements)
- `POST /api/jd/fetch` — JD URL 본문 수집(jdText 등)
- `POST /api/match/preview` — 이력서↔JD 매칭(matchingScore, summary, strengths, gaps, suggestions)
- `POST /api/interview/preview` — 모의 면접 질문(questions[{question, category, keypoints}], strategy, summary)

## 계약 원칙

- 요청/응답 필드, 에러 코드, `ApiResponse<T>` 래퍼를 변경하지 않는다.
- `stub`/`fixture`/`ai-local` 모드 동작과 그 분기 결과를 셸 구조 변경이 침해하지 않는다.
- resume source(`TEXT`/`FILE` + value)를 진단·매칭·면접 호출에 동일하게 전달한다.
- `분석 시작`은 클라이언트에서 진단·매칭 호출을 함께 트리거할 뿐, 새 통합 엔드포인트를 만들지 않는다.

## 데이터 매핑 (목업 지표 → 기존 응답)

- 이력서 진단 점수 카드 ← `diagnose.score`
- JD 적합도 카드 ← `match.matchingScore`
- 상세 프리뷰 ← `diagnose.strengths/improvements`, `match.strengths/gaps/suggestions`
- AI 코멘트 ← `diagnose.summary` 또는 `match.summary`
- 목업의 ATS 점수·누락 키워드 구조화·첨삭 제안은 대응 응답이 없어 화면에 노출하지 않는다.
