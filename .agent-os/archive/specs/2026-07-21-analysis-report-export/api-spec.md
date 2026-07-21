# 분석 결과 리포트 내보내기 API 계약

## 계약

이 기능은 신규 서버 API를 추가하지 않는다. 기존 `GET /api/analysis-histories/{historyId}` 응답을 그대로 사용해 클라이언트에서 Markdown을 생성한다. 해당 endpoint의 계약 정본은 `.agent-os/archive/specs/2026-07-18-service-mvp/api-spec.md`(소유권 검증, 404 `ANALYSIS_HISTORY_NOT_FOUND`, 응답 스키마)이며, 본 문서는 이를 재서술하지 않는다.

## 공통 규칙

- 인증이 필요한 endpoint는 기존 세션 기반 소유권 검증을 그대로 따른다.
- secret, 원문 민감 데이터, 내부 stack trace를 응답하지 않는다.
- 기존 endpoint의 요청·응답 스키마를 변경하지 않는다.

## 클라이언트 처리 경계

- `AnalysisHistoryDetail.result.diagnosis`, `AnalysisHistoryDetail.result.match`가 있는 항목만 Markdown 섹션으로 변환한다.
- `status`가 `SUCCEEDED`가 아니면 Markdown을 생성하지 않는다.
- 변환 함수는 `buildAnalysisHistoryMarkdown(history)`이며, `sourceText`와 저장되지 않은 ATS·문장 첨삭 결과는 포함하지 않는다.
- 다운로드 Blob의 content type은 `text/markdown`이며, 파일명은 `jdsnack-분석결과-{historyId}-{YYYYMMDD}.md` 형식이다.
- `result`가 없거나 `diagnosis`·`match`가 모두 없으면 빈 성공 리포트를 만들지 않는다.
