# JDSnack

JDSnack은 개발자 이력서와 채용공고(JD)를 비교해 이력서 개선 포인트와 JD 매칭 인사이트를 제공하는 웹 서비스입니다.

현재 프로젝트는 **이력서 입력/업로드, JD 링크 수집, 로컬 Gemini 기반 AI 매칭, 결과 리포트 UI**를 하나의 서비스 흐름으로 안정화하는 단계입니다. `./.agent-os/`는 이 흐름을 일관되게 개발하기 위한 문서 하네스입니다.

## 현재 할 수 있는 것

- 이력서 텍스트 입력 또는 PDF/DOCX 업로드·추출
- JD 직접 입력 또는 URL 수집, fixture/stub 기반 로컬 검증
- `ai-local` Gemini 분석·매칭과 결과 카드 UI

## 주요 API

- 상태: `GET /api/health` · 분석: `POST /api/diagnose`, `/api/diagnose/file`
- JD 수집: `POST /api/jd/fetch` · 매칭 미리보기: `POST /api/match/preview`

## 기술 스택

- Frontend: React, TypeScript, Vite · Backend: Spring Boot, Java, Gradle
- AI: Gemini API, 로컬 `ai-local` · Test: H2, JUnit, Vitest, Playwright
- Runtime: Docker Compose 분리 컨테이너 · Docs: `./.agent-os/`, `AGENTS.md`, `CLAUDE.md`
- Docs Harness: `./.agent-os/`, `AGENTS.md`, `CLAUDE.md`, `.claude/`

## 저장소 구조

```text
jdsnack-agent-os/
├── AGENTS.md
├── CLAUDE.md
├── README.md
├── .agent-os/{product,specs,archive,standards,operations}/
├── .claude/{agents,skills}/
├── docs/architecture/
└── backend/ · frontend/ · scripts/
```

## 핵심 문서

- 진입 지도: `AGENTS.md`(Codex) · `CLAUDE.md`(Claude)
- 제품·기술·용어: `./.agent-os/product/{mission,tech-stack,glossary}.md`
- 활성·보관 spec: `./.agent-os/specs/` · `./.agent-os/archive/specs/`
- 아키텍처: `docs/architecture/` · 결정: `docs/decisions/`
- 핵심 진입 파일: `frontend/src/App.tsx` · `backend/src/main/java/com/jdsnack/jd/JdFetchService.java` · `scripts/check-ai-readiness.py`
- 변경 이력: `git log --oneline` · 제품 검증 이력: `./.agent-os/product/roadmap.md`

## 로컬 실행

루트 디렉토리에서 프론트와 백엔드를 함께 실행합니다. 로컬 개발/검증은 소스에서 이미지를 빌드하는 `compose.local.yaml`을 사용합니다.

```bash
docker compose -f compose.local.yaml up --build
```

접속 주소:

- 프론트 `http://localhost:5173` · 백엔드 `http://localhost:8080` · 헬스 `http://localhost:8080/api/health`

`ai-local` 모드에서 실제 Gemini 호출을 확인하려면 루트 `.env`에 `GEMINI_API_KEY`가 필요합니다. `.env`는 로컬 전용이며 커밋하지 않습니다.

> 주의: `docker compose config` 결과와 `.env` 내용은 secret이 포함될 수 있어 공유하지 않습니다.

## 배포 실행 기준

배포/운영은 registry 이미지를 사용하는 `compose.prod.yaml`을 사용하며 `build:`를 두지 않습니다.

```bash
docker compose -f compose.prod.yaml pull
docker compose -f compose.prod.yaml up -d
```

기본 태그는 `latest`이며 특정 커밋은 `JDSNACK_IMAGE_TAG=<git-sha>`로 지정합니다. `docker compose config` 출력에는 secret이 섞일 수 있으므로 구조만 볼 때 `--no-env-resolution`을 사용합니다.

## 개발 원칙

1. `AGENTS.md`를 먼저 읽고 `REQ -> AC -> TC -> API/UI -> 구현/테스트` 순서를 지킵니다.
2. API/UI 계약은 관련 spec과 함께 수정하고 Conventional Commits를 사용합니다.
3. 문서 계획·PR·리뷰·머지는 Claude, 구현·테스트는 Codex가 담당합니다.
4. 완료 후 테스트 결과와 PR 요약을 남깁니다.
