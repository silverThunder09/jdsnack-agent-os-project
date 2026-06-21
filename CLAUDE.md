# CLAUDE.md

JDSnack(이력서↔JD AI 매칭) 작업 규칙·계약·탐색정책·Git 규약의 **정본은 `AGENTS.md`와 `.agent-os/`** 입니다.
작업 전 `AGENTS.md`를 먼저 읽으세요. 이 파일은 Claude 전용 역할 경계와 명령어만 보강합니다.

## Claude의 역할 (단일 에이전트 end-to-end)

Claude가 한 기능을 **기획 → 구현 → 게이트 검증 → 독립 리뷰 → PR → 머지까지 한 세션에서** 소유한다.

- ✅ 문서 계획·작성 → `doc-planner` 서브에이전트(opus) 또는 메인 plan 모드. `.agent-os/` 하네스 규칙(`doc-lifecycle.md`·`definition-of-done.md` 등)에 맞춘다.
- ✅ **구현** → `backend/src`·`frontend/src`를 Claude가 직접 작성한다. 활성 spec(`requirements`·`acceptance-criteria`·`test-scenarios`·`api-spec`·`ui-spec`)을 따른다.
- ✅ 게이트 검증 → 빌드/lint/test/e2e(아래 명령).
- ✅ 독립 리뷰 → `code-reviewer` 서브에이전트에 **diff와 합격기준만** 넘겨 5점 채점(`/review-loop`). 작성자·리뷰어 관점을 분리하기 위해 레포 전체를 주입하지 않는다. 4점 미만이면 **같은 세션에서 직접 수정·재리뷰**한다.
- ✅ PR 생성·관리, merge → 메인 세션. **머지는 사용자 승인**으로 한다.
- CI/CD 배포(GHCR publish, `compose.prod.yaml`, 배포 워크플로/런북, 자동 배포·검증)는 **사용자가 지시할 때만** 수행한다.

**Codex는 기본 흐름에서 제외한다.** 사용자가 명시적으로 "Codex로 구현"이라고 지시할 때만 보조로 쓰며, 그 경우에도 spec·리뷰·머지는 Claude가 맡는다. 과거의 cron 리뷰-머지 루프(`jdsnack-review-merge-loop`)는 **폐지(비활성)**되었다 — `.agent-os/operations/pr-automation-loop.md` 참조.

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
