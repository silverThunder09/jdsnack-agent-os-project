# 분석 결과 리포트 내보내기 요구사항

## 목표

로그인한 사용자가 분석 내역(`AnalysisHistoryView`) 상세에서 과거에 저장된 분석 결과를 Markdown 파일로 내려받을 수 있게 한다. 현재는 방금 실행한 분석 화면(`AnalysisResultView`)에서만 클라이언트 측 `buildResultMarkdown`으로 내보내기가 가능하고, 이력 상세 화면에는 동일 기능이 없다.

## 범위

### 포함

- 분석 내역 상세(`AnalysisHistoryView`)에 Markdown 내보내기 진입점 추가
- 이력에 저장된 결과(`diagnosis`, `match`)만을 대상으로 하는 Markdown 빌드
- 소유자 본인 이력만 내보내기 가능하도록 기존 이력 조회 소유권 경계 재사용
- 상태(`RUNNING`/`FAILED`/`SUCCEEDED`)에 따른 내보내기 가능 여부 안내
- 파일명·content type 규칙

### 제외

- 신규 서버 export API 추가 (기존 `GET /api/analysis-histories/{historyId}` 응답 재사용)
- PDF 내보내기, 공유 URL, 자동 이메일 발송, 문서 편집기
- 이력에 저장되지 않은 옵션(ATS, 문장 첨삭, 모의면접) 결과 포함 — DB 스키마 확장 없이는 재구성할 수 없다
- 분석 이력 데이터 모델·저장 범위 변경

## 요구사항

### REQ-01 이력 상세 내보내기 진입점

로그인한 사용자는 분석 내역 상세 화면에서 선택한 이력을 Markdown 파일로 내려받을 수 있어야 한다.

### REQ-02 소유권 경계 재사용

내보내기는 `AnalysisHistoryService.get`(정본: `.agent-os/archive/specs/2026-07-18-service-mvp/api-spec.md`의 `GET /api/analysis-histories/{historyId}`)이 이미 수행하는 소유권 검증 결과만을 사용하며, 별도의 export 전용 인증·인가 경로를 새로 만들지 않는다.

### REQ-03 저장된 결과만 포함

내보내기 파일은 이력에 저장된 `diagnosis`, `match` 결과만 포함한다. 저장되지 않은 옵션은 섹션 자체를 생략하며 빈 값으로 과장하지 않는다.

### REQ-04 파일명·content type

내보내기 파일명은 이력 식별자와 생성일을 알아볼 수 있어야 하고, content type은 `text/markdown`이어야 한다.

### REQ-05 상태별 내보내기 정책

`RUNNING` 또는 `FAILED` 이력은 내보내기를 제공하지 않거나, 내려받아도 실제 결과가 없음을 명확히 알린다. 빈 내용을 성공한 리포트처럼 보이지 않게 한다.

### REQ-06 비밀정보 경계

내보내기 구현은 브라우저에 secret을 요구하지 않으며 외부 서비스와 통신하지 않는다.
