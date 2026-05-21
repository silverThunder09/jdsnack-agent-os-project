# JDSnack Agent OS

JDSnack은 개발자 이력서와 JD를 AI로 분석해 개선 피드백과 매칭 인사이트를 제공하는 것을 목표로 하는 웹 서비스 프로젝트입니다.

1차 MVP는 사용자 인증 키 입력도, 서버 Gemini 연동도 없는 no-key 서비스 뼈대입니다. 먼저 이력서 입력, 입력 검증, 준비중 안내, 백엔드/프론트 기본 구조를 완성하고, 실제 AI/JD 분석은 2차 MVP 이후에 붙입니다.

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
- 현재 활성 기능: `.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/`
- API 상세 문서: `.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/api-spec.md`
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

1. `backend/`에 Spring Boot 프로젝트 생성
2. `frontend/`에 React + Vite 프로젝트 생성
3. `POST /api/diagnose` 입력 검증 구현
4. 준비중 안내 UI 구현
5. 2차 MVP에서 서버 기반 AI 분석 연동
