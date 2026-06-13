# 변경 이력

## 2026-05-25

- 리포트 UX 개선을 적용해 이력서 분석과 JD 매칭 결과 화면의 정보 구조를 정리
- 커밋/PR 제목 규칙을 Conventional Commits 형식 중심으로 복원
- 프로젝트 용어집과 탐색 제외 규칙을 추가해 에이전트 탐색 비용을 축소
- 단일 기획 스레드 운영과 주제별 세션 교체 기준을 문서화
- 사람인 JD 수집 안정화 스펙과 fixture 검증 기준을 추가
- 로컬 `ai-local` compose 런타임 기준을 정리
- 오래된 spec 보관과 빌드 산출물 탐색 제외 기준을 강화

## 2026-05-24

- JD 링크 수집 API 흐름을 추가하고 서비스 wiring을 보정
- Jsoup 기반 HTML 본문 후보 추출 점수화를 개선
- 사람인 링크 수집에서 오류 페이지, 홍보성 문구, 본문 없는 성공을 실패로 처리
- JD 링크 수집 안정화 계획을 문서화
- 로컬 전용 Gemini 이력서 분석 모드와 JD 매칭 흐름을 추가
- 브라우저 기반 업로드와 JD 미리보기 스모크 테스트를 추가

## 2026-05-23

- JD 입력 MVP 설계를 추가하고 `POST /api/match/preview` 계약을 고정
- JD 미리보기 결과 응답 구조를 추가
- 1.5차 fixture 런타임 문서 정합성을 보정
- 분리 컨테이너 런타임과 스모크 테스트 운영 흐름을 정리
- PR 위험도별 Light / Standard / High-risk 흐름을 문서화
- 로컬 Gemini 실호출 검증을 `googleTest` 경로로 분리

## 2026-05-22

- PR 자동 운영 루프, PR 실패 Issue 템플릿, PR 템플릿 추가
- 백엔드 CI와 컨테이너 빌드 GitHub Actions 추가
- 컨테이너 workflow에 실행 및 `/api/health` 검증 조건 추가
- `backend/Dockerfile` 기반 컨테이너 흐름 추가
- health API 추적 매핑과 경계값 테스트 문서화
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
- 초기 운영 문서 추가
