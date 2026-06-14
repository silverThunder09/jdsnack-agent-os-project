# JDSnack

JDSnack은 개발자 이력서와 채용공고(JD)를 비교해 이력서 개선 포인트와 JD 매칭 인사이트를 제공하는 웹 서비스입니다.

현재는 **이력서·JD를 한 화면에서 입력하면 진단·JD 매칭·모의 면접 질문을 한 번에 받는 SaaS형 단일 화면(대시보드 셸)**까지 구현돼 있습니다. 앞으로는 계정·요금제 같은 외형보다 **분석의 깊이**(키워드 매칭·맞춤 첨삭·ATS)를 먼저 채워 가는 방향입니다. `.agent-os/`는 이 흐름을 일관되게 개발하기 위한 문서 하네스입니다.

## 현재 할 수 있는 것

- 이력서 텍스트 입력
- PDF/DOCX 이력서 업로드와 텍스트 추출
- JD 텍스트 직접 입력
- JD URL 기반 본문 수집 시도
- fixture/stub 모드 기반 안전한 로컬 검증
- `ai-local` 모드 기반 Gemini 이력서 분석과 JD 매칭
- 이력서 기반 모의 면접 질문 생성(카테고리·키포인트·전략)
- 사이드바·히어로·통합 입력의 SaaS형 단일 화면(대시보드 셸)에서 진단·매칭을 한 번에 실행

## 제품 방향 (최종 형태)

> **"JD 맞춤 이력서 분석·개선 단일 화면 도구"** — 풍성한 SaaS 외형을 다 채우기보다, 한 화면에서 이력서·JD를 넣으면 **진단·JD 매칭·키워드·ATS·맞춤 첨삭·면접 질문**을 한 번에 받는 **분석 허브**를 완성형으로 삼습니다.

계정·내역·요금제는 **분석 가치가 검증된 뒤** 얹는 레이어입니다(`ADR-003`: 복잡한 계정보다 분석 핵심 흐름 우선).

### 단계별 진행 방향

분석 깊이 → 결과 보존 → 계정·수익화 순으로 채웁니다. 각 단계는 `.agent-os/specs/`의 활성 spec 1개로 진행하며, 로드맵 정본은 `.agent-os/product/roadmap.md`에서 관리합니다.

- **Phase A — 분석 가치 심화**: 키워드 매칭 구조화(매칭/부분/누락) → 맞춤 첨삭(문장 단위) → ATS 점수·포맷 점검
- **Phase B — 결과 보존**: 분석 내역(경량 → DB) → 이력서 관리
- **Phase C — 계정·수익화**: 인증/계정 → 요금제/결제
- **병렬(출시)**: 분리 컨테이너 EC2 배포·운영 검증(`ADR-004`)

현재 셸의 사이드바에서 잠금(🔒)으로 표시된 메뉴들이 위 단계로 하나씩 실제 기능으로 해금됩니다.

## 주요 API

- `GET /api/health`: 백엔드 상태 확인
- `POST /api/diagnose`: 이력서 텍스트 분석
- `POST /api/diagnose/file`: PDF/DOCX 업로드 분석
- `POST /api/jd/fetch`: JD URL에서 본문 수집
- `POST /api/match/preview`: 이력서와 JD 매칭 미리보기
- `POST /api/interview/preview`: 이력서 기반 모의 면접 질문 생성

## 기술 스택

- Frontend: React, TypeScript, Vite
- Backend: Spring Boot, Java, Gradle
- AI: Gemini API, 로컬 `ai-local` 모드
- Test/Fixture: H2, JUnit, Vitest, Playwright
- Runtime: Docker Compose 분리 컨테이너
- Docs Harness: `.agent-os/`, `AGENTS.md`, `CLAUDE.md`, `.claude/`

## 저장소 구조

```text
jdsnack-agent-os/
├── AGENTS.md
├── CLAUDE.md
├── README.md
├── CHANGELOG.md
├── .agent-os/
│   ├── product/
│   ├── specs/
│   ├── archive/
│   ├── standards/
│   └── operations/
├── .claude/
│   ├── agents/
│   └── skills/
├── docs/
│   └── architecture/
├── backend/
├── frontend/
└── scripts/
```

## 핵심 문서

- 작업 진입 지도(코덱스): `AGENTS.md`
- 작업 진입 지도(클로드): `CLAUDE.md`
- 제품 목적: `.agent-os/product/mission.md`
- 로드맵: `.agent-os/product/roadmap.md`
- 기술 스택: `.agent-os/product/tech-stack.md`
- 용어집: `.agent-os/product/glossary.md`
- 활성 기능 명세: `.agent-os/specs/`
- 보관 기능 명세: `.agent-os/archive/specs/`
- 아키텍처 문서: `docs/architecture/`
- 변경 이력: `CHANGELOG.md`

## 로컬 실행

루트 디렉토리에서 프론트와 백엔드를 함께 실행합니다. 로컬 개발/검증은 소스에서 이미지를 빌드하는 `compose.local.yaml`을 사용합니다.

```bash
docker compose -f compose.local.yaml up --build
```

접속 주소:

- 프론트: `http://localhost:5173`
- 백엔드 루트: `http://localhost:8080`
- 헬스체크: `http://localhost:8080/api/health`

`ai-local` 모드에서 실제 Gemini 호출을 확인하려면 루트 `.env`에 `GEMINI_API_KEY`가 필요합니다. `.env`는 로컬 전용이며 커밋하지 않습니다.

## 배포 실행 기준

배포/운영 실행은 registry에 올라간 이미지를 pull하는 `compose.prod.yaml`을 사용합니다. 배포 compose에는 `build:`를 두지 않습니다.

```bash
docker compose -f compose.prod.yaml pull
docker compose -f compose.prod.yaml up -d
```

기본 이미지 태그는 `latest`이며, 특정 커밋 이미지를 확인할 때는 `JDSNACK_IMAGE_TAG=<git-sha>`를 지정합니다.

`docker compose config`는 `env_file` 값을 해석하면 secret이 출력될 수 있으므로, 결과를 PR/이슈/채팅에 붙여넣지 않습니다. 설정 구조만 확인할 때는 `--no-env-resolution`을 사용합니다.

## 개발 원칙

1. `AGENTS.md`에서 현재 활성 문서와 금지 규칙을 확인합니다.
2. 기능 변경은 `REQ -> AC -> TC -> API/UI -> 구현/테스트` 순서로 맞춥니다.
3. API/UI 계약 변경은 관련 spec 문서와 함께 수정합니다.
4. 커밋과 PR 제목은 Conventional Commits 형식을 따릅니다.
5. 문서 계획, PR, 리뷰, 머지는 클로드가 담당합니다.
6. 코덱스는 구현, 리뷰 기반 코드 수정, 테스트, 별도 지시된 자동 배포를 담당합니다.
7. 완료 후 테스트 결과와 PR 요약을 남깁니다.
