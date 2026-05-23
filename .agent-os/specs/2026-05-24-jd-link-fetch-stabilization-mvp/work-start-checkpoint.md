# JD 링크 수집 안정화 MVP 작업 시작 체크포인트

## 작업 등급

- `High-risk`
- 이유: 외부 URL fetch, HTML 파싱, SSRF 방지, 로그 안전성 영향이 있다.

## 시작 전 확인

- `requirements.md`
- `acceptance-criteria.md`
- `api-spec.md`
- `test-scenarios.md`
- `traceability.md`

## 변경 허용

- JD 링크 수집 관련 문서
- `backend/src/main/java/com/jdsnack/jd/`
- `backend/src/test/java/com/jdsnack/jd/`

## 변경 금지

- Gemini API Key 처리
- JD AI 매칭 응답 구조
- 이력서 분석 API 계약
- 배포/CI 스크립트 대규모 변경

## 완료 조건

- 사람인 성공 fixture가 존재한다.
- 개인정보/푸터 오탐 방지 테스트가 존재한다.
- 안전하지 않은 URL 차단 테스트가 존재한다.
- 문서와 구현의 오류 코드가 일치한다.
