# CLAUDE.md

JDSnack(이력서↔JD AI 매칭) 작업 규칙·계약·탐색정책·Git 규약의 **정본은 `AGENTS.md`와 `.agent-os/`** 입니다.
작업 전 `AGENTS.md`를 먼저 읽으세요. 이 파일은 Claude 전용 역할 경계와 명령어만 보강합니다.

## Claude의 역할 (Codex와 분업)

Claude는 **기획·검증·리뷰·통합**을 맡고, **기능 구현·테스트는 하지 않습니다.** 구현과 기능 테스트는 Codex가 담당합니다.

- ✅ 문서 계획·작성 → `doc-planner` 서브에이전트(opus) 또는 메인 plan 모드. `.agent-os/` 하네스 규칙(`doc-lifecycle.md`·`definition-of-done.md` 등)에 맞춘다.
- ✅ 게이트 검증 → 빌드/lint/test/e2e(아래 명령)로 Codex 산출물을 확인한다.
- ✅ 독립 리뷰·채점 → `code-reviewer` 서브에이전트에 **diff와 합격기준만** 넘겨 5점 채점(`/review-loop`). 레포 전체를 주입하지 않는다.
- ✅ PR 생성·관리 → 메인 세션. **머지 권한: spec·거버넌스 PR = 사용자 승인("머지해"). `codex/*` 구현 PR = 무인 리뷰-머지 루프(`jdsnack-review-merge-loop`)가 code-reviewer 4점 이상이면 자동 머지**(사용자 개입 0).
- ❌ **기능 구현 + 기능 테스트 작성, 리뷰 기반 코드 수정·커밋·푸시 → Codex 담당.**
- ❌ CI/CD 배포(GHCR publish, `compose.prod.yaml`, 배포 워크플로/런북, 자동 배포·검증) → Codex 담당(사용자 지시 시).

**Claude는 `backend/src`, `frontend/src` 등 소스 코드를 직접 수정하지 않습니다.** 리뷰에서 문제를 찾으면 직접 고치지 말고 `code-reviewer` 형식의 변경요청으로 정리해 Codex에 넘깁니다. 단, 이미 리뷰를 통과한 변경을 PR로 마무리하는 커밋·푸시는 Claude가 할 수 있습니다(PR 관리 범위).

### 폴백: Codex 토큰 부재 시 Claude 직접 구현

**Codex가 토큰이 없어 구현이 막힌 경우에 한해**, 사용자가 "네가 구현해"라고 지시하면 Claude가 활성 spec(`requirements`·`acceptance-criteria`·`test-scenarios`·`api-spec`·`ui-spec`)을 읽고 그대로 구현·테스트한다. 구현 후 게이트+자체 리뷰로 검증하고 머지는 사용자 승인. 토큰 복구되면 구현=Codex로 복귀한다.

### 컨텍스트 관리: 무거운 작업은 서브에이전트로

Claude의 기획·리뷰·탐색 중 토큰 무거운 bounded 작업은 서브에이전트에 위임해 메인 세션을 린(lean)하게 유지한다: spec 작성=`doc-planner`, 코드베이스 탐색=`Explore`/`general-purpose`(결론만), 독립 리뷰=`code-reviewer`(diff만). 기능이 바뀌면 새 세션을 시작한다(상태는 메모리가 이어줌).

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
