# 분석 결과 리포트 내보내기 요구사항

- 상태: pending
- 제품 범위: Post MVP
- 위험도: Standard
- 선행 조건: 2026-07-16-analysis-history
- 관련 technical ADR: adr-004-analysis-record

## 목적

사용자가 자신의 분석 결과를 사람이 읽을 수 있는 Markdown 또는 PDF 파일로 내보냅니다.

## 범위

### 포함

- 분석 결과 Markdown export
- 파일명·content type
- 민감정보 포함 경고
- 사용자 권한 검증

### 제외

- 공유 URL
- 자동 이메일 발송
- 문서 편집기

## 요구사항

### REQ-01

- 내보내기는 현재 사용자 소유 분석만 허용한다.

### REQ-02

- 화면 표시용 데이터와 export 데이터의 필드 매핑을 고정한다.

### REQ-03

- export 생성 실패 시 부분 파일을 성공으로 표시하지 않는다.

## 구현 경계

- 백엔드는 Controller → Service → Repository/External API 경계를 지킵니다.
- 외부 OAuth·JD source·Gemini는 인터페이스 또는 fake 경계로 테스트합니다.
- API·UI 계약은 각각 `api-spec.md`와 `ui-spec.md`를 기준으로 합니다.
- 본 spec의 모든 acceptance criteria는 대응 test scenario와 traceability를 가져야 합니다.
