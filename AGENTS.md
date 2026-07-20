# JDSnack 에이전트 안내 지도

JDSnack은 개발자 이력서와 JD를 AI로 분석하는 웹 서비스입니다. `./.agent-os/standards/index.yml`에는 현재 구현할 `active_specs` 하나만 두고, 다음 후보는 `./.agent-os/product/spec-backlog.md`에 짧게 관리합니다. 과거·대체된 기획 문서는 archive에 보관합니다.

이 파일은 긴 설명서가 아니라, 작업을 시작할 때 보는 짧은 지도입니다.

## 코덱스와 분업 운영

클로드는 **기획·검증·리뷰·통합**을 맡고, **기능 구현·테스트는 코덱스**가 맡습니다.

- 클로드: 문서 계획(spec), 게이트 검증, 독립 리뷰(`code-reviewer` 서브에이전트에 diff만 넘겨 채점), PR 작성/관리, merge 판단/실행. `backend`/`frontend` 소스는 직접 수정하지 않습니다.
- 코덱스: 활성 spec 기준 기능 **구현 + 기능 테스트 작성**을 담당합니다. 리뷰·판정은 담당하지 않습니다.
- 폴백: 코덱스가 토큰이 없어 막힐 때만, 사용자가 "네가 구현해"라고 지시하면 클로드가 직접 구현·테스트합니다. 전환·복귀·가드레일은 `.agent-os/operations/worker-backends.md`의 폴백 규칙을 따릅니다.
- **무인 배치**: Codex 구현 PR은 이벤트 기반 리뷰-머지 루프가 리뷰·CI를 확인합니다. 마지막 Feature가 머지되면 `spec-queue.json`의 eligible 후보를 자동으로 Spec으로 승격하고 T1을 다시 Codex에 디스패치합니다. 사람이 필요한 제품 판단·High-risk·충돌은 `needs-human`으로 멈춥니다.

### Codex 모델 정책

- 기능 구현과 테스트 코드 작성·결과 분석의 모델 배정은 [backends.json](backends.json)과 [Worker 모델 배정](./.agent-os/operations/worker-backends.md)을 따릅니다.
- 빌드·lint·test·E2E 명령 실행 자체: 모델을 사용하지 않습니다.
- 리뷰·판정은 Codex 모델 대상이 아니며, Claude `code-reviewer`가 담당합니다.

## 먼저 읽을 문서

1. 제품 목적: `.agent-os/product/mission.md`
2. 기술 방향: `.agent-os/product/tech-stack.md`
3. 프로젝트 용어: `.agent-os/product/glossary.md`
4. 하네스 규칙: `.agent-os/standards/codex-harness.md`
5. 현재 구현 기능: `.agent-os/standards/index.yml`의 `active_specs` 1개와 `.agent-os/product/spec-queue.json`의 실행 큐 참조

## 기준 문서 위치

- 제품 방향: `./.agent-os/product/`
- 활성 기능 명세: `./.agent-os/specs/`
- 보관 기능 명세: `./.agent-os/archive/specs/`
- 전역 표준: `./.agent-os/standards/`
- 운영 규칙: `./.agent-os/operations/`
- 상세 아키텍처 문서: `docs/architecture/`
- 백엔드 코드: `backend/`
- 프론트엔드 코드: `frontend/`

## 작업 순서

1. `requirements.md`에서 요구사항을 확인합니다.
2. `acceptance-criteria.md`에서 완료 기준을 확인합니다.
3. `test-scenarios.md`에서 검증 시나리오를 확인합니다.
4. `api-spec.md`와 `ui-spec.md`에서 계약을 확인합니다.
5. 구현 후 `traceability.md`와 테스트 결과를 맞춥니다.

## AI 준비도 유지

- 모듈 문서·Markdown 링크·정적 eval 케이스는 `python3 scripts/check-ai-readiness.py`로 검증합니다.
- 구조·데이터 흐름 변경은 `docs/architecture/system-overview.md`의 Mermaid map도 함께 갱신합니다.
- context-on/off eval은 GitHub Actions에서 자동 실행하지 않습니다. 형님 로컬 Codex 로그인 세션에서 필요할 때 `python3 scripts/run-ai-readiness-evals.py`로 실행합니다.

## Dependencies

- 프론트는 `frontend/src/services/`만 통해 백엔드 API를 호출하고, 계약은 활성 spec의 `api-spec.md`를 따릅니다.
- 백엔드는 Controller → Service → Repository/External API 경계를 지키며, 외부 JD 수집 흐름은 `docs/architecture/integration-architecture.md`를 참조합니다.
- 변경 영향은 `docs/ARCHITECTURE.md`와 상세 아키텍처 문서에서 먼저 확인합니다.

## 기본 탐색 명령

- 파일·텍스트 검색은 `rg --files`와 `rg`를 사용하며, 기본 제외 경로는 `frontend/node_modules/**`, `frontend/dist/**`, `backend/build/**`, `backend/.gradle/**`, `./.agent-os/archive/**`, `.git/**`입니다.
- 전체 `find .`, 전체 `ls -R`, archive 전체 탐색은 금지하며 세부 규칙은 `./.agent-os/operations/agent-scan-policy.md`를 따릅니다.

## 강제 규칙

- 문서 없는 API/UI 계약 변경과 대응 테스트 없는 수용 기준 추가는 하지 않습니다.
- 기본 탐색에서 `frontend/node_modules`, `frontend/dist`, `backend/build`, `backend/.gradle`, `./.agent-os/archive`, `.git`는 제외하며, archive 문서는 사용자 요청이나 활성 spec의 직접 참조가 있을 때만 확인합니다.
- 커밋과 PR 제목은 Conventional Commits 형식을 따릅니다. 요약 언어는 작업 맥락에 맞게 선택합니다.
- 운영은 기획 스레드 하나에서 진행하고, 주제가 바뀌면 새 세션을 시작합니다.
- 별도 작업 스레드는 사용하지 않습니다.
- 검증은 현재 기획 스레드에서 변경 범위, 테스트 결과, CI 결과를 기준으로 확인합니다.
- AI eval은 `evals/context-tasks.json`의 대표 작업을 기준으로 정적으로 검증하며, 모델 품질 측정은 runner가 연결되기 전까지 `not-run`으로 기록합니다.
- `frontend/` 또는 `backend/` 코드 변경 후에는 테스트·lint·build와 함께 `docker compose -f compose.local.yaml up -d --build`, 컨테이너 상태, 관련 health endpoint를 자동 확인합니다. Docker 재빌드·재실행을 생략한 상태는 로컬 실행 검증 완료로 보고하지 않습니다.
- 사용자가 브라우저에서 비밀 키를 넣거나 프론트에 저장하는 흐름은 만들지 않습니다.
- 백엔드는 `Controller -> Service -> Repository/External API` 경계를 지킵니다.
- 프론트는 컴포넌트에서 직접 API 호출을 하지 않고 서비스 계층을 둡니다.
- 커밋/PR/머지 규칙은 `./.agent-os/standards/git-workflow.md`, `./.agent-os/operations/pr-rules.md`, `./.agent-os/operations/merge-rules.md`를 따릅니다.
