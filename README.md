# JDSnack

JDSnack은 개발자 이력서와 채용공고(JD)를 비교해 이력서 개선 포인트와 JD 매칭 인사이트를 제공하는 웹 서비스입니다.

현재 프로젝트는 **이력서 입력/업로드, JD 링크 수집, 로컬 Gemini 기반 AI 매칭, 결과 리포트 UI**를 하나의 서비스 흐름으로 안정화하는 단계입니다. `.agent-os/`는 이 흐름을 일관되게 개발하기 위한 문서 하네스입니다.

## 현재 할 수 있는 것

- 이력서 텍스트 입력
- PDF/DOCX 이력서 업로드와 텍스트 추출
- JD 텍스트 직접 입력
- JD URL 기반 본문 수집 시도
- fixture/stub 모드 기반 안전한 로컬 검증
- `ai-local` 모드 기반 Gemini 이력서 분석과 JD 매칭
- 분석 결과와 매칭 결과를 카드형 UI로 표시

## 주요 API

- `GET /api/health`: 백엔드 상태 확인
- `POST /api/diagnose`: 이력서 텍스트 분석
- `POST /api/diagnose/file`: PDF/DOCX 업로드 분석
- `POST /api/jd/fetch`: JD URL에서 본문 수집
- `POST /api/match/preview`: 이력서와 JD 매칭 미리보기

## 기술 스택

- Frontend: React, TypeScript, Vite
- Backend: Spring Boot, Java, Gradle
- AI: Gemini API, 로컬 `ai-local` 모드
- Test/Fixture: H2, JUnit, Vitest, Playwright
- Runtime: Docker Compose 분리 컨테이너
- Docs Harness: `.agent-os/`, `AGENTS.md`, 커스텀 Codex agents

## 저장소 구조

```text
jdsnack-agent-os/
├── AGENTS.md
├── README.md
├── CHANGELOG.md
├── .agent-os/
│   ├── product/
│   ├── specs/
│   ├── archive/
│   ├── standards/
│   └── operations/
├── .codex/
│   └── agents/
├── docs/
│   └── architecture/
├── backend/
├── frontend/
└── scripts/
```

## 핵심 문서

- 작업 진입 지도: `AGENTS.md`
- 제품 목적: `.agent-os/product/mission.md`
- 로드맵: `.agent-os/product/roadmap.md`
- 기술 스택: `.agent-os/product/tech-stack.md`
- 용어집: `.agent-os/product/glossary.md`
- 활성 기능 명세: `.agent-os/specs/`
- 보관 기능 명세: `.agent-os/archive/specs/`
- 커스텀 에이전트: `.codex/agents/*.toml`
- 아키텍처 문서: `docs/architecture/`
- 변경 이력: `CHANGELOG.md`

## 로컬 실행

루트 디렉토리에서 프론트와 백엔드를 함께 실행합니다.

```bash
docker compose up --build
```

접속 주소:

- 프론트: `http://localhost:5173`
- 백엔드 루트: `http://localhost:8080`
- 헬스체크: `http://localhost:8080/api/health`

`ai-local` 모드에서 실제 Gemini 호출을 확인하려면 루트 `.env`에 `GEMINI_API_KEY`가 필요합니다. `.env`는 로컬 전용이며 커밋하지 않습니다.

## 개발 원칙

1. `AGENTS.md`에서 현재 활성 문서와 금지 규칙을 확인합니다.
2. 기능 변경은 `REQ -> AC -> TC -> API/UI -> 구현/테스트` 순서로 맞춥니다.
3. API/UI 계약 변경은 관련 spec 문서와 함께 수정합니다.
4. 커밋과 PR 제목은 Conventional Commits 형식을 따릅니다.
5. 완료 후 테스트 결과와 handoff를 남깁니다.
