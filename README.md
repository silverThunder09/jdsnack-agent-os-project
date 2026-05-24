# JDSnack Agent OS

JDSnack은 개발자 이력서와 JD를 AI로 분석해 개선 피드백과 매칭 인사이트를 제공하는 것을 목표로 하는 웹 서비스 프로젝트입니다.

현재 활성 기획은 사람인 JD 수집 안정화입니다. 과거 MVP 명세는 토큰 낭비를 줄이기 위해 `.agent-os/archive/specs/`에 보관합니다.

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
│   ├── archive/
│   ├── standards/
│   ├── operations/
│   └── archive/
├── .codex/
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
- 프로젝트 용어집: `.agent-os/product/glossary.md`
- 현재 활성 spec: `.agent-os/specs/2026-05-24-saramin-jd-scraping-stabilization/`
- 보관 spec: `.agent-os/archive/specs/`
- 커스텀 에이전트: `.codex/agents/*.toml`
- API 상세 문서: `.agent-os/specs/2026-05-24-saramin-jd-scraping-stabilization/api-spec.md`
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

## 2.5차 MVP 구현 범위

- `ai-local` 모드 기반 실제 Gemini JD 매칭 결과
- `POST /api/match/preview`의 AI 응답 반환
- `matchingScore`, `summary`, `strengths`, `gaps`, `suggestions` 구조 유지
- `stub`/`fixture`에서는 기존 규칙 기반 미리보기 유지

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
5. PR 제목과 본문은 한국어로 작성합니다.

## 다음 구현 우선순위

1. 사람인 JD 수집 안정화: `.agent-os/specs/2026-05-24-saramin-jd-scraping-stabilization/`
2. 분리 컨테이너 운영용 reverse proxy / ingress 설정 문서화
3. 운영 배포용 Gemini 보안/재시도 정책 확장
4. 수동 JD 저장 UX 확장

## 로컬 통합 실행

루트 디렉토리에서 아래 명령으로 프론트와 백엔드를 같이 띄울 수 있습니다.

```bash
docker compose up --build
```

`compose.yaml`의 기본 백엔드 모드는 `ai-local`입니다. 로컬 실사용 전 루트 `.env`에 `GEMINI_API_KEY`를 준비해야 하며, `.env`는 커밋하지 않습니다.

접속 주소:

- 프론트: `http://localhost:5173`
- 백엔드 루트: `http://localhost:8080`
- 백엔드 헬스체크: `http://localhost:8080/api/health`
