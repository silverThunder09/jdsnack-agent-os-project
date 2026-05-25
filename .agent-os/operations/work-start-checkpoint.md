# 작업 시작 체크포인트

## 목적

작업 시작 체크포인트는 수정 전에 범위와 검증 방법을 먼저 잠그는 짧은 선언입니다.

쉽게 말하면, PR이 커지기 전에 **이번 작업의 울타리**를 먼저 치는 문서입니다.

## 사용 시점

- 기능 구현 시작 전
- 문서 규칙 변경 전
- CI/CD 또는 운영 변경 전
- 버그 수정 시작 전

## 필수 항목

아래 7개는 반드시 먼저 적습니다.

1. 대상 spec
2. 위험도
3. 바꾸는 범위
4. 읽을 범위
5. 읽지 않을 범위
6. 테스트 방법
7. PR 범위

## 작성 형식

```md
# Work Start Checkpoint

## Target Spec
- 대상 spec:

## Risk Level
- `Light` / `Standard` / `High-risk`:
- 판단 이유:

## Change Scope
- 이번 작업에서 바꾸는 것:
- 이번 작업에서 바꾸지 않는 것:

## Read Scope
- 반드시 읽을 문서/폴더:
- 필요할 때만 읽을 문서/폴더:

## Do Not Read
- 기본 탐색 제외:
- 예외적으로만 확인할 범위:

## Test Plan
- 로컬 테스트:
- 수동 검증:
- CI 기대 항목:

## PR Scope
- PR 주 목적:
- 같은 PR에 포함할 항목:
- 별도 PR로 분리할 항목:
```

## 운영 규칙

- 체크포인트 없이 바로 큰 수정에 들어가지 않습니다.
- 먼저 이 작업이 `Light`, `Standard`, `High-risk` 중 무엇인지 판단합니다.
- 계획 쓰레드는 active spec과 제품/하네스 문서만 우선 읽습니다.
- 개발 쓰레드는 active spec, 해당 구현 폴더, 관련 테스트만 우선 읽습니다.
- 검증 쓰레드는 PR diff, 테스트 결과, handoff를 우선 읽습니다.
- `.agent-os/archive`, `frontend/node_modules`, `frontend/dist`, `backend/build`, `backend/.gradle`, `.git`는 기본 탐색에서 제외합니다.
- PR 본문 `범위 판단`은 이 체크포인트와 같은 말을 해야 합니다.
- 범위가 커지면 작업을 쪼개고 체크포인트를 다시 작성합니다.
- CI, 배포, 템플릿, 광범위 문서 정리는 기능 PR과 분리합니다.
