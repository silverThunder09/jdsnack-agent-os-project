# Backend

이 디렉토리에는 JDSnack Spring Boot 백엔드 프로젝트를 생성합니다.

1차 MVP 범위:

- `GET /api/health`
- `POST /api/diagnose`
- 이력서 입력 검증
- 검증 성공 시 `501 AI_ANALYSIS_NOT_ENABLED` 반환
- 예외 처리 및 검증

2차 MVP 이후:

- 서버 환경변수 기반 외부 AI 연동
- 이력서/JD 분석 서비스
