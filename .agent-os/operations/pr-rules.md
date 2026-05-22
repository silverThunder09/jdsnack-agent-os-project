# PR 규칙

## 목적

PR은 코드 리뷰 요청이 아니라 **문서, 테스트, 구현이 일치하는지 검증하는 단위**입니다.

## PR 크기

- 한 PR은 하나의 기능 또는 하나의 문제만 다룹니다.
- 요구사항 ID 기준으로 묶습니다.
- 서로 다른 기능의 UI/API/DB 변경을 한 PR에 섞지 않습니다.
- 직접 `main`에 푸시하지 않고 작업 브랜치에서 PR을 생성합니다.

## PR 범위 경계

PR의 주 목적은 PR 본문에 한 문장으로 설명할 수 있어야 합니다.

같은 PR에 포함할 수 있는 변경:

- 주 목적에 해당하는 구현 코드
- 그 구현을 검증하는 테스트
- 그 구현과 직접 연결된 `requirements.md`, `acceptance-criteria.md`, `test-scenarios.md`, `traceability.md`
- API/UI 계약이 바뀐 경우의 `api-spec.md`, `ui-spec.md`
- 같은 기능을 다음 에이전트가 이어받기 위한 handoff

별도 PR로 분리해야 하는 변경:

- CI 워크플로우 추가/수정
- 브랜치 보호 규칙, required status check, 머지 정책 변경
- PR 템플릿, Issue 템플릿, 자동화 루프 변경
- 컨테이너, 배포, 릴리즈 운영 흐름 변경
- 광범위한 문서 링크 정리, 파일 이동, 포맷팅
- 현재 기능과 직접 연결되지 않은 표준 문서 변경

예외:

- PR 안에서 변경한 코드 때문에 같은 PR의 테스트나 문서 하네스가 실패한 경우, 해당 실패를 고치는 최소 수정은 같은 PR에 포함할 수 있습니다.
- required check 자체가 없거나 보호 규칙이 잘못된 경우에는 기능 PR에 섞지 않고 운영 PR을 먼저 머지한 뒤 기능 PR을 다시 검사합니다.
- 예외를 적용하면 PR 본문 `범위 판단`에 이유를 남깁니다.

분리 예시:

```text
feat(frontend): add no-key mvp flow
ci(frontend): add frontend ci required check
ci(container): run container flow on pull requests
docs(agent-os): fix document links
docs(pr): tighten pr scope rules
```

## PR 제목

커밋 메시지와 같은 형식을 사용합니다.

```text
<type>(<scope>): <summary>
```

예시:

```text
feat(api): 이력서 진단 API 추가
docs(harness): Git 운영 규칙 추가
```

## PR 본문 템플릿

PR 본문은 `.github/pull_request_template.md`를 기본으로 사용합니다.

```md
## 변경 요약

- 

## 범위 판단

- 주 목적:
- 같은 PR에 포함한 이유:
- 별도 PR로 분리한 항목:

## 연결 문서

- 요구사항:
- 수용 기준:
- 테스트 시나리오:
- API/UI 명세:

## 검증

- [ ] 문서 갱신
- [ ] 테스트 추가/수정
- [ ] 테스트 실행
- [ ] CI 체크리스트 확인
- [ ] 컨테이너 영향 확인
- [ ] 수동 검증
- [ ] 에이전트 handoff 확인

## 영향 범위

- 

## 리뷰 포인트

- 
```

## 필수 체크

- 요구사항 변경 시 `requirements.md`, `acceptance-criteria.md`, `traceability.md` 갱신
- API 변경 시 `api-spec.md` 갱신
- UI 변경 시 `ui-spec.md` 갱신
- 테스트 기준 변경 시 `test-scenarios.md` 갱신
- 완료 기준은 [standards/definition-of-done.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/standards/definition-of-done.md)를 따름
- 서브 에이전트 작업은 [standards/sub-agent-operations.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/standards/sub-agent-operations.md)를 따름
- CI 기준은 [ci-checklist.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/ci-checklist.md)를 따름
- PR 자동 운영 루프는 [pr-automation-loop.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/pr-automation-loop.md)를 따름

## PR 전 필수 검증 기준

- PR 주 목적이 한 문장으로 설명된다.
- 변경 파일이 `PR 범위 경계`의 같은 PR 허용 조건 안에 있다.
- CI/운영/템플릿/광범위한 문서 정리는 기능 PR과 분리되어 있다.
- `requirements.md`에 `REQ`가 존재한다.
- `acceptance-criteria.md`에 `AC`가 존재한다.
- `test-scenarios.md`에 `TC`가 존재한다.
- `traceability.md`에 `REQ -> AC -> TC` 매핑이 존재한다.
- API 변경이 있으면 `api-spec.md`가 갱신되어 있다.
- UI 변경이 있으면 `ui-spec.md`가 갱신되어 있다.
- 문서/백엔드/프론트 변경 범위에 맞는 CI 체크리스트가 확인되어 있다.
- 담당 에이전트 검사 결과가 `PASS`다.
- Gemini API 또는 외부 API 사용 시 `Security Reviewer` 검토가 완료되어 있다.
- 문서와 구현이 불일치하는 상태로 PR을 생성하지 않는다.

## PR 실패 처리

- GitHub Actions 또는 리뷰가 실패하면 `.github/ISSUE_TEMPLATE/pr-failure.yml` 형식으로 Issue를 생성한다.
- Issue에는 실패 PR, 실패 체크, 핵심 로그, 관련 `REQ/AC/TC`, 수정 계획을 남긴다.
- 수정은 같은 브랜치에서 진행하고 다시 담당 에이전트 검사를 받는다.

## 리뷰 기준

리뷰어는 아래 순서로 봅니다.

1. PR 주 목적과 변경 파일 범위가 맞는가
2. 요구사항과 변경 범위가 맞는가
3. API/UI 계약이 문서와 맞는가
4. 테스트가 수용 기준을 검증하는가
5. 계층 경계가 유지되는가
6. CI/CD 영향이 별도 PR 또는 명확한 예외로 기록되었는가
7. 배포/운영 영향이 별도 PR 또는 명확한 예외로 기록되었는가
8. 에이전트 handoff가 다음 작업자가 이어받을 만큼 충분한가

## 반려 기준

- 문서 없는 API/UI 계약 변경
- 테스트 시나리오 없는 수용 기준 변경
- 구현과 문서 불일치
- 한 PR에 여러 목적 혼합
- 기능 PR에 CI/운영/템플릿/광범위 문서 정리를 함께 포함
- 에러 처리 또는 검증 누락
- 에이전트 권한 위반 또는 handoff 누락
