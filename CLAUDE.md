# CLAUDE.md

JDSnack(이력서↔JD AI 매칭) 작업 규칙·계약·탐색정책·Git 규약의 **정본은 `AGENTS.md`와 `.agent-os/`** 입니다.
작업 전 `AGENTS.md`를 먼저 읽으세요. 이 파일은 Claude 전용 역할 경계와 명령어만 보강합니다.

## Claude의 역할 (Codex와 분업)

Claude는 **기획·검증·리뷰·통합**을 맡고, **기능 구현·테스트는 하지 않습니다.** 구현과 기능 테스트는 Codex가 담당합니다.

- ✅ 문서 계획·작성 → `doc-planner` 서브에이전트 또는 메인 plan 모드. 모델 배정은 [backends.json](backends.json)을 따른다. `.agent-os/` 하네스 규칙(`doc-lifecycle.md`·`definition-of-done.md` 등)에 맞춘다.
- ✅ 게이트 검증 → 빌드/lint/test/e2e(아래 명령)로 Codex 산출물을 확인한다.
- ✅ 독립 리뷰·채점 → `code-reviewer` 서브에이전트에 **diff와 합격기준만** 넘겨 5점 채점(`/review-loop`). 레포 전체를 주입하지 않는다.
- ✅ PR 생성·관리 → 이벤트 기반 자동 루프. **일반 `codex/*` 구현 PR과 자동 생성된 Spec promotion PR은 게이트 통과 시 자동 머지**하고, High-risk·충돌·사람 판단이 필요한 큐 후보는 `needs-human`으로 중단합니다.
- ❌ **기능 구현 + 기능 테스트 작성, 리뷰 기반 코드 수정·커밋·푸시 → Codex 담당.**
- ❌ CI/CD 배포(GHCR publish, `compose.prod.yaml`, 배포 워크플로/런북, 자동 배포·검증) → Codex 담당(사용자 지시 시).

**Claude는 `backend/src`, `frontend/src` 등 소스 코드를 직접 수정하지 않습니다.** 리뷰에서 문제를 찾으면 직접 고치지 말고 `code-reviewer` 형식의 변경요청으로 정리해 Codex에 넘깁니다. 단, 이미 리뷰를 통과한 변경을 PR로 마무리하는 커밋·푸시는 Claude가 할 수 있습니다(PR 관리 범위).

### 폴백: Codex 토큰 부재 시 Claude 직접 구현

전환·복귀·가드레일의 정본은 `.agent-os/operations/worker-backends.md`의 폴백 규칙이다. 요지: Codex 인증·쿼터 장애 판정 시 사용자 승인(outage당 1회, 기존 "네가 구현해" 지시) 후 Claude가 활성 spec(`requirements`·`acceptance-criteria`·`test-scenarios`·`api-spec`·`ui-spec`)을 읽고 그대로 구현·테스트한다. 이 동안 만든 PR은 자동 머지에서 제외되고 사용자 머지로 강등된다(자기 구현·자기 검수 차단). Codex 가용성이 확인되면 다음 티켓부터 자동 복귀한다.

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
- 역할별 모델 배정은 [backends.json](backends.json)과 [Worker 모델 배정](.agent-os/operations/worker-backends.md)을 따른다.
