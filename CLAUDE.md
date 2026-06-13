# CLAUDE.md

JDSnack(이력서↔JD AI 매칭) 작업 규칙·계약·탐색정책·Git 규약의 **정본은 `AGENTS.md`와 `.agent-os/`** 입니다.
작업 전 `AGENTS.md`를 먼저 읽으세요. 이 파일은 Claude 전용 역할 경계와 명령어만 보강합니다.

## Claude의 역할 (Codex와 분업)

Claude는 **기획·검증·통합**을 맡고, **구현은 하지 않습니다.**

- ✅ 문서 계획·작성 → `doc-planner` 서브에이전트 (opus, 깊은 기획은 메인에서 plan 모드)
  - **문서 계획은 예외 없이 `.agent-os/` 하네스 규칙(`codex-harness.md`, `doc-lifecycle.md`, `definition-of-done.md`)에 맞춰 짠다.** 규칙에 어긋나는 구조·순서·동기화 누락은 작성하지 않는다.
- ✅ 코드 리뷰·채점 → `code-reviewer` 서브에이전트 + `/review-loop` 스킬
- ✅ PR 생성·관리, merge → 메인 세션
- ❌ 에이전트 코딩(구현), 리뷰 기반 코드 수정·커밋·푸시 → **Codex 담당**
- ❌ CI/CD 배포(GHCR publish, `compose.prod.yaml`, 배포 워크플로/런북, 자동 배포·배포 검증) → **Codex 담당**
  - 단, PR 검증용 CI 체크(테스트/빌드 게이트, 경로 필터 등)의 운영·효율화는 Claude의 PR/merge 운영 범위.

**Claude는 `backend/src`, `frontend/src` 등 소스 코드를 직접 수정하지 않습니다.**
리뷰에서 문제를 찾으면 수정하지 말고 `code-reviewer` 형식의 변경요청으로 정리해 Codex에 넘깁니다.
단, **이미 리뷰를 통과한 변경을 PR로 마무리하는 커밋·푸시는 Claude가 수행할 수 있습니다**(PR 생성·관리 범위). 새로운 구현·수정은 여전히 Codex가 합니다.

## 빌드 / 테스트 (게이트·검증용)

```bash
cd backend && ./gradlew test            # 백엔드 테스트
cd frontend && npm run lint && npm test # 프론트 lint + 테스트
cd frontend && npm run test:e2e         # playwright
docker compose up --build               # 전체 기동 backend:8080 / frontend:5173
```

## 잊지 말 것

- 규칙·계약·탐색정책·Git 규약은 모두 `AGENTS.md` → `.agent-os/` 참조 (여기서 재서술하지 않음)
- 비밀 키는 서버에서만 처리(프론트 입력·저장 금지)
- 기본 모델은 sonnet, 문서 작업 때만 opus + plan 모드로 수동 전환
