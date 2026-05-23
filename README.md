# JDSnack Agent OS

JDSnack은 개발자 이력서와 JD를 AI로 분석해 개선 피드백과 매칭 인사이트를 제공하는 것을 목표로 하는 웹 서비스 프로젝트입니다.

현재 구현은 세 단계로 나뉩니다. 1차 MVP는 no-key 서비스 뼈대, 1.5차 MVP는 fixture 기반 업로드 분석, 2차 MVP는 로컬 전용 `ai-local` Gemini 이력서 분석 단계입니다.

이 저장소는 서비스 코드와 문서 하네스를 함께 관리합니다. 쉽게 말하면, `backend/`와 `frontend/`가 실제 제품을 만들고, `.agent-os/`와 `docs/`가 그 제품을 어떻게 만들지 정해주는 설계도 역할을 합니다.

## 저장소 구조

```text
jdsnack-agent-os/
├── AGENTS.md
├── agent.md
├── README.md
├── .agent-os/
│   ├── product/
│   ├── specs/
│   ├── standards/
│   ├── operations/
│   └── agents/
├── docs/
│   ├── api/
│   ├── erd/
│   ├── architecture/
│   └── troubleshooting/
├── backend/
├── frontend/
└── scripts/
```

## 핵심 문서

- 에이전트 진입 지도: `AGENTS.md`
- 호환용 포인터: `agent.md`
- 제품 목적: `.agent-os/product/mission.md`
- 로드맵: `.agent-os/product/roadmap.md`
- 기술 스택: `.agent-os/product/tech-stack.md`
- 1차 MVP 기본 계약: `.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/`
- 1.5차 MVP 업로드 + fixture 확장: `.agent-os/specs/2026-05-22-1650-resume-upload-fixture-mvp/`
- 다음 설계 단계: `.agent-os/specs/2026-05-23-0900-jd-intake-mvp/`
- 2차 MVP AI 이력서 분석: `.agent-os/specs/2026-05-23-1300-local-ai-resume-analysis-mvp/`
- API 상세 문서: `.agent-os/specs/2026-05-22-1650-resume-upload-fixture-mvp/api-spec.md`
- ERD 상세 문서: `.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/erd.md`
- 아키텍처 상세 문서: `docs/architecture/`
- CI 기준 문서: `.agent-os/operations/ci-checklist.md`
- CD 기준 문서: `.agent-os/operations/cd-checklist.md`
- PR 자동 운영 루프: `.agent-os/operations/pr-automation-loop.md`
- 컨테이너 워크플로우: `.agent-os/operations/container-workflow.md`
- 문서 하네스 워크플로우: `.github/workflows/docs-harness.yml`
- 백엔드 CI 워크플로우: `.github/workflows/backend-ci.yml`
- 컨테이너 워크플로우: `.github/workflows/container.yml`

## 1차 MVP 구현 범위

- 이력서 텍스트 입력
- 입력 길이 검증
- AI 분석 준비중 안내
- `GET /api/health`
- `POST /api/diagnose`
- Spring Boot 백엔드와 React 프론트엔드 기반 서비스 구성

## 1.5차 MVP 구현 범위

- 텍스트 입력 fixture 분석
- PDF 업로드 후 텍스트 추출 + fixture 분석
- DOCX 업로드 후 텍스트 추출 + fixture 분석
- `POST /api/diagnose/file`
- H2 fixture 매핑 조회
- 점수, 요약, 강점, 개선 포인트 결과 카드 렌더링
- `googleTest` 로컬 실호출 검증 경로 분리

## 2차 MVP 구현 범위

- `ai-local` 모드 기반 실제 Gemini 이력서 분석
- 텍스트 입력 AI 분석
- PDF/DOCX 업로드 AI 분석
- 점수, 요약, 강점, 개선 포인트 AI 결과 카드
- 구조화된 JSON 응답 파싱

1차 MVP에서 하지 않는 것:

- 사용자 인증 키 입력 UI
- 서버 외부 AI 비밀값 설정
- 서버 Gemini 호출
- AI 점수/피드백 생성
- JD 매칭

## 작업 원칙

1. 문서를 먼저 확인합니다.
2. 요구사항, 수용 기준, 테스트 시나리오를 맞춥니다.
3. API/UI 계약을 기준으로 구현합니다.
4. 구현 후 문서와 테스트가 같은 말을 하는지 확인합니다.

## 다음 구현 우선순위

1. JD AI 매칭 계약 설계
2. 브라우저 기반 업로드 스모크 자동화
3. 분리 컨테이너 운영용 reverse proxy / ingress 설정 문서화
4. 운영 배포용 Gemini 보안/재시도 정책 확장

## 로컬 통합 실행

루트 디렉토리에서 아래 명령으로 프론트와 백엔드를 같이 띄울 수 있습니다.

```bash
docker compose up --build
```

접속 주소:

- 프론트: `http://localhost:5173`
- 백엔드 루트: `http://localhost:8080`
- 백엔드 헬스체크: `http://localhost:8080/api/health`
