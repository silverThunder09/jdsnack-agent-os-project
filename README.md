# JDSnack Agent OS

JDSnack은 개발자 이력서와 JD를 AI로 분석해 개선 피드백과 매칭 인사이트를 제공하는 웹 서비스 프로젝트입니다.

이 저장소는 서비스 코드와 문서 하네스를 함께 관리합니다. 쉽게 말하면, `backend/`와 `frontend/`가 실제 제품을 만들고, `.agent-os/`와 `docs/`가 그 제품을 어떻게 만들지 정해주는 설계도 역할을 합니다.

## 저장소 구조

```text
jdsnack-agent-os/
├── AGENTS.md
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

- 제품 목적: `.agent-os/product/mission.md`
- 로드맵: `.agent-os/product/roadmap.md`
- 기술 스택: `.agent-os/product/tech-stack.md`
- 현재 활성 기능: `.agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/`
- API 상세 문서: `docs/api/api-spec.md`
- ERD 상세 문서: `docs/erd/erd.md`
- 아키텍처 상세 문서: `docs/architecture/`

## 현재 구현 범위

- 이력서 텍스트 입력
- JD 텍스트 입력
- AI 기반 이력서/JD 분석
- 점수, 개선 피드백, 요약 리포트 제공
- Spring Boot 백엔드와 React 프론트엔드 기반 서비스 구성

## 작업 원칙

1. 문서를 먼저 확인합니다.
2. 요구사항, 수용 기준, 테스트 시나리오를 맞춥니다.
3. API/UI 계약을 기준으로 구현합니다.
4. 구현 후 문서와 테스트가 같은 말을 하는지 확인합니다.

## 다음 구현 우선순위

1. `backend/`에 Spring Boot 프로젝트 생성
2. `frontend/`에 React + Vite 프로젝트 생성
3. `POST /api/diagnose` 계약 기준 백엔드 구현
4. 이력서/JD 입력 및 결과 리포트 UI 구현
5. Gemini API 연동과 실패 처리 검증
