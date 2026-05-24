# 서브 에이전트 운영 표준

## 목적

JDSnack 서브 에이전트는 작업을 많이 나누기 위한 장치가 아닙니다.  
목적은 **문서, 구현, 테스트, 배포 사이의 불일치를 줄이는 것**입니다.

## 실제 에이전트 정의 위치

- 실제 Codex 프로젝트 커스텀 에이전트는 `.codex/agents/*.toml`에 둡니다.
- `.agent-os/standards/sub-agent-operations.md`는 운영 표준과 권한 모델을 설명합니다.
- 에이전트 역할을 바꾸면 TOML 파일과 이 문서를 함께 최신화합니다.
- 이전 `.agent-os/agents/*.md` 프롬프트는 중복이므로 사용하지 않습니다.

## 도입 순서

초기에는 모든 에이전트를 한 번에 도입하지 않습니다.

MVP 1차 기본 에이전트:

- `Spec Steward`
- `Backend Engineer`
- `Frontend Engineer`
- `QA Reviewer`

조건부 추가:

- Gemini API 연동 시작 전 또는 시작 시점: `Security Reviewer`
- `backend/`, `frontend/` 생성 후 CI/CD 또는 배포 준비 시점: `DevOps Steward`
- PR 기반 작업이 반복되고 릴리즈 관리가 필요해질 때: `Release Captain`

## 핵심 운영 원칙

1. 문서 없는 구현 변경을 금지합니다.
2. 모든 기능은 `REQ -> AC -> TC -> 계약 문서` 연결을 유지합니다.
3. 각 에이전트는 자신의 책임 영역 밖 파일을 직접 수정하지 않습니다.
4. 영역 밖 변경이 필요하면 직접 수정하지 않고 변경 요청을 남깁니다.
5. 작업 종료 시 다음 에이전트가 이어받을 수 있도록 handoff 내용을 남깁니다.
6. 구현보다 문서, 계약, 검증 기준을 우선합니다.
7. 같은 검토를 여러 쓰레드에서 반복하지 않습니다.
8. 쓰레드별 기본 에이전트는 하나만 호출하고, 조건부 위험이 있을 때만 추가 에이전트를 붙입니다.

## 쓰레드별 호출 제한

서브 에이전트는 작업 분산보다 책임 경계를 선명하게 만드는 장치입니다.
계획, 개발, 검증 쓰레드가 같은 파일을 반복 검토하면 토큰과 시간이 낭비되므로 아래 기준을 따릅니다.

| 쓰레드 | 기본 에이전트 | 책임 | 기본 금지 |
|---|---|---|---|
| 계획 쓰레드 | `Spec Steward` | 요구사항, 수용 기준, API/UI 계약, traceability 초안 | 구현 코드 리뷰, 전체 QA 재검토 |
| 백엔드 개발 쓰레드 | `Backend Engineer` | `backend/**` 구현, 백엔드 테스트, API 계약 준수 | spec 원본 직접 변경 |
| 프론트 개발 쓰레드 | `Frontend Engineer` | `frontend/**` 구현, 프론트 테스트, UI 계약 준수 | spec 원본 직접 변경 |
| 검증 쓰레드 | `QA Reviewer` | 문서, 구현, 테스트 불일치 확인 | 요구사항 재작성, 구현 직접 수정 |

조건부 에이전트:

- 보안, 외부 API, `.env`, Gemini Key, 로그 정책이 있으면 `Security Reviewer`만 추가합니다.
- Docker, compose, GitHub Actions, 배포 흐름이 있으면 `DevOps Steward`만 추가합니다.
- PR 본문, 머지 조건, 릴리즈 판단이 필요하면 `Release Captain`만 추가합니다.

중복 호출 금지:

- 계획 쓰레드에서 확정한 `REQ`, `AC`, 계약 문서를 개발 쓰레드가 전체 재검토하지 않습니다.
- 개발 쓰레드는 계약 변경이 필요하면 직접 고치지 않고 handoff의 `Change Requests`에 남깁니다.
- 검증 쓰레드는 최종 diff, 테스트 결과, handoff를 기준으로 검증하고 과거 spec 전체를 다시 탐색하지 않습니다.
- `High-risk`가 아니면 모든 에이전트를 한 번에 호출하지 않습니다.

## 위험도별 기본 운영

모든 PR에 모든 에이전트를 붙이지 않습니다.

| 위험도 | 기본 검증자 | 원칙 |
|---|---|---|
| `Light` | 작성자 | 작은 변경은 빠르게 통과시킨다 |
| `Standard` | 현재 쓰레드 기본 에이전트 | 일반 기능 변경은 담당 쓰레드가 먼저 책임진다 |
| `High-risk` | 현재 쓰레드 기본 에이전트, 필요한 조건부 에이전트 | 보안/배포/외부 연동이 있는 부분만 추가 검토한다 |

`Spec Steward`는 요구사항, API/UI 계약, traceability가 직접 바뀌는 경우에만 기본 검증자에 추가합니다.

## 1. Spec Steward

역할:

- 요구사항 정리
- 수용 기준 작성
- API/UI 계약 변경 관리
- 추적 매핑표 관리

수정 가능:

- `requirements.md`
- `acceptance-criteria.md`
- `traceability.md`
- `api-spec.md`
- `ui-spec.md`

수정 금지:

- `backend/**`
- `frontend/**`
- 테스트 코드 직접 수정

완료 기준:

- 모든 요구사항에 `REQ` ID가 존재합니다.
- 모든 `REQ`에 대응하는 `AC`가 존재합니다.
- API/UI 변경 사항이 계약 문서에 반영되어 있습니다.
- `QA Reviewer`가 테스트 시나리오를 만들 수 있을 정도로 기준이 명확합니다.

## 2. Backend Engineer

역할:

- Spring Boot 백엔드 구현
- 1차 MVP에서는 `Controller -> Validation Service` 경계 유지
- 2차 MVP 이후 외부 AI 연동 시 `Controller -> Service -> External API` 경계 유지
- API 명세에 맞는 요청/응답 구현
- 예외 처리와 입력 검증 구현
- 백엔드 테스트 작성

수정 가능:

- `backend/**`

수정 금지:

- `frontend/**`
- `requirements.md`
- `acceptance-criteria.md`
- `api-spec.md` 직접 수정

변경 요청 필요:

- API 요청/응답 구조 변경
- 에러 코드 변경
- 인증/보안 정책 변경
- Gemini API 사용 방식 변경

완료 기준:

- 구현 API가 `api-spec.md`와 일치합니다.
- 입력 검증이 존재합니다.
- 외부 API 연동 작업인 경우 실패 처리 로직이 존재합니다.
- 백엔드 테스트가 핵심 시나리오를 검증합니다.

## 3. Frontend Engineer

역할:

- React UI 구현
- 입력/로딩/결과/에러 상태 구현
- API 연동 구현
- 화면 흐름을 `ui-spec.md`와 일치시킴

수정 가능:

- `frontend/**`

수정 금지:

- `backend/**`
- `ui-spec.md` 직접 수정
- `api-spec.md` 직접 수정

필수 규칙:

- 컴포넌트에서 직접 `fetch` 금지
- API 호출은 `services` 계층에서 처리
- API 응답 타입은 계약 문서와 동기화

변경 요청 필요:

- 화면 플로우 변경
- API 응답 구조 변경
- 에러 메시지 정책 변경
- 사용자 입력 정책 변경

완료 기준:

- `ui-spec.md`의 상태 흐름과 실제 화면이 일치합니다.
- 로딩/성공/실패 상태가 모두 구현되어 있습니다.
- API 계약과 프론트 타입이 일치합니다.

## 4. QA Reviewer

역할:

- 테스트 시나리오 작성 및 검증
- 문서/코드/테스트 불일치 탐지
- PR 반려 조건 확인
- 문서 드리프트 확인

수정 가능:

- `test-scenarios.md`
- `qa-review-report.md`
- `traceability.md`의 `TC` 매핑 영역

수정 금지:

- `backend/**`
- `frontend/**`
- `requirements.md` 직접 수정
- `acceptance-criteria.md` 직접 수정

완료 기준:

- 모든 `AC`에 대응하는 `TC`가 존재합니다.
- 핵심 시나리오가 테스트로 검증됩니다.
- 문서와 구현이 불일치하면 위험도와 함께 지적합니다.
- 테스트 누락 항목을 명확히 남깁니다.

## 5. Security Reviewer

도입 시점:

- Gemini API 연동 시작 전 또는 시작 시점

역할:

- API Key 노출 방지
- 환경변수 사용 여부 확인
- 로그에 민감정보 출력 여부 검토
- 사용자 입력과 AI 응답 저장/로그 정책 검토
- 외부 API 실패/타임아웃/재시도 정책 검토

수정 가능:

- `security-review.md`
- `security-policy.md`
- 필요 시 설정 문서

수정 금지:

- `backend/**` 직접 수정
- `frontend/**` 직접 수정

완료 기준:

- 비밀값은 코드에 하드코딩되어 있지 않습니다.
- Gemini API Key는 환경변수로 관리됩니다.
- 사용자 입력과 AI 응답 로그 정책이 명확합니다.
- 외부 API 장애 대응 정책이 문서화되어 있습니다.

## 6. DevOps Steward

도입 시점:

- `backend/`, `frontend/` 실제 생성 후
- CI/CD 또는 배포 준비 시점

역할:

- Git 훅 관리
- CI 빌드 검증
- 배포 문서 관리
- 운영 체크리스트 관리

수정 가능:

- `git-hooks.md`
- `git-workflow.md`
- `deploy-runbook.md`
- `ci-checklist.md`
- `.github/workflows/**`

완료 기준:

- `commit-msg`, `pre-commit`, `pre-push` 기준이 명확합니다.
- 빌드/테스트 자동화 기준이 존재합니다.
- 배포 체크리스트가 최신 상태입니다.

## 7. Release Captain

도입 시점:

- PR 기반 작업이 반복되고 릴리즈 관리가 필요해질 때

역할:

- PR 본문 검토
- 머지 조건 확인
- 릴리즈 체크리스트 관리
- 완료 정의 확인

수정 가능:

- `pr-rules.md`
- `merge-rules.md`
- `release-checklist.md`
- `release-note.md`

완료 기준:

- PR에 요구사항, 구현, 테스트, 문서 변경 내용이 연결되어 있습니다.
- 머지 전 금지 조건이 없습니다.
- 릴리즈 체크리스트가 완료되어 있습니다.

## 에이전트 간 작업 순서

작업은 아래 순서로 이어받되, 한 쓰레드 안에서 전부 반복 실행하지 않습니다.

1. `Spec Steward`: 요구사항, 수용 기준, 계약 문서 정리
2. `Backend Engineer` / `Frontend Engineer`: 계약 문서를 기준으로 병렬 구현
3. `QA Reviewer`: `REQ -> AC -> TC` 연결 확인, 문서와 구현 불일치 검토
4. `Security Reviewer`: Gemini API, 비밀값, 로그, 외부 API 정책 검토
5. `DevOps Steward`: 빌드, 훅, 배포 흐름 검토
6. `Release Captain`: PR, 머지, 릴리즈 준비 상태 확인

각 단계는 이전 단계의 handoff를 입력으로 사용합니다. 같은 내용을 다시 처음부터 읽지 않습니다.

## Agent Handoff 규칙

각 에이전트는 작업 종료 시 [agent-handoff-template.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/agent-handoff-template.md) 형식으로 handoff를 남깁니다.

handoff는 다음 에이전트가 바로 이어받을 수 있을 정도로 구체적이어야 합니다.

## PR 전 필수 검증 기준

PR 생성 전 아래 조건을 만족해야 합니다.

- `requirements.md`에 `REQ`가 존재합니다.
- `acceptance-criteria.md`에 `AC`가 존재합니다.
- `test-scenarios.md`에 `TC`가 존재합니다.
- `traceability.md`에 `REQ -> AC -> TC` 매핑이 존재합니다.
- API 변경이 있으면 `api-spec.md`가 갱신되어 있습니다.
- UI 변경이 있으면 `ui-spec.md`가 갱신되어 있습니다.
- 백엔드 구현은 `api-spec.md`와 일치합니다.
- 프론트 구현은 `ui-spec.md`와 일치합니다.
- Gemini API 또는 외부 API 사용 시 `Security Reviewer` 검토가 완료되어 있습니다.
- 문서와 구현이 불일치하는 상태로 머지하지 않습니다.

## 최종 운영 기준

- `Spec Steward`가 계약을 만듭니다.
- `Backend Engineer`와 `Frontend Engineer`는 계약대로 구현합니다.
- `QA Reviewer`는 계약과 구현이 맞는지 검증합니다.
- `Security Reviewer`는 외부 API와 비밀값을 검증합니다.
- `DevOps Steward`는 빌드와 배포 흐름을 검증합니다.
- `Release Captain`은 PR과 릴리즈 완료 조건을 검증합니다.
- 각 쓰레드는 자기 기본 에이전트만 먼저 호출합니다.
- 조건부 에이전트는 해당 위험이 실제로 있을 때만 호출합니다.
- handoff가 있으면 handoff를 우선 읽고, 전체 문서 재탐색은 하지 않습니다.
