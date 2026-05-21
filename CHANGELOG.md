# 변경 이력

## 2026-05-22

- PR 자동 운영 루프, PR 실패 Issue 템플릿, PR 템플릿 추가
- 백엔드 CI와 컨테이너 빌드 GitHub Actions 추가
- 컨테이너 workflow에 실행 및 `/api/health` 검증 조건 추가
- `backend/Dockerfile` 기반 컨테이너 흐름 추가
- 서브 에이전트 리뷰 결과를 반영해 health API 추적 매핑과 경계값 테스트 문서화
- 문서 하네스 CI를 `REQ/AC/TC` 완전 매핑 검사로 강화
- 문서 하네스 GitHub Actions 워크플로우 추가
- 문서형 CI/CD v0 기준 추가
- `ci-checklist.md`, `cd-checklist.md`를 운영 문서로 등록
- PR/머지/완료정의/배포/릴리즈 문서에 CI/CD 확인 기준 연결

## 2026-05-21

- 1차 MVP에서 사용자 인증 정보 입력과 서버 외부 AI 연동 제거
- `POST /api/diagnose` 정상 입력 응답을 `501 AI_ANALYSIS_NOT_ENABLED`로 재설계
- API/UI/아키텍처/테스트 문서를 입력 검증과 준비중 안내 중심으로 재정리
- 중복 상세 문서 복사본 정리
- 오래된 `initial-setup` 스펙 제거
- API/ERD 원본 문서를 활성 기능 명세 경로로 통일
- `jdsnack-agent-os-main.zip` 참고본을 기준으로 상세 문서 복원
- 제품 문서, 기능 명세, 표준, 운영 문서를 `.agent-os/` 아래로 재배치
- API, ERD, 아키텍처 상세 문서를 `docs/` 아래로 복사
- 루트 `README.md`, `AGENTS.md`, `config.yml`을 현재 저장소 구조에 맞게 갱신
- `DevOps Steward` 에이전트 문서 추가
