# 머지 규칙

## 목적

머지는 “코드 합치기”가 아니라 **완료 정의를 통과한 변경만 기준 브랜치에 반영하는 절차**입니다.

## 실행 주체

- 머지 판단은 리뷰·검증 결과로 자동화하며, trusted GitHub approval job만 Squash auto-merge를 큐에 넣습니다.
- 코덱스는 GitHub에서 직접 머지 명령을 실행하지 않습니다.
- 코덱스는 머지 전 리뷰 결과에 따른 코드 수정, 테스트, 사용자가 지시한 자동 배포 작업만 수행합니다.
- **무인 배치**: `codex/*` 구현 PR은 configured reviewer의 `PASS`와 **4/5 이상**, 최신 base/head SHA, PR 계약, PR CI Gate, 모든 branch-required check, 미해결 변경요청 부재를 확인하면 Squash auto-merge를 큐에 넣습니다. 4점 미만이면 구조화된 변경요청을 Codex에 전달합니다. 자율 루프가 `spec-queue.json`에서 선택한 `automation/spec-*` promotion PR은 Docs Harness·traceability·diff 범위 검증을 통과하면 자동 머지합니다. 위험도는 라벨로만 기록하며, High-risk 또는 구현/reviewer backend 동일 여부만으로 추가 사람 승인을 요구하지 않습니다.

## 기본 전략

현재는 Claude 구독이 비활성화되어 Codex read-only reviewer가 바로 시작됩니다. Claude를 기본으로 선택한 경우 Claude가 unavailable이거나 구조화 결과를 만들지 못하면 같은 Codex reviewer로 전환합니다. 두 번째 리뷰도 실행 불가·형식 오류면 `needs-human`으로 멈춥니다. 각 경우 모두 동일한 5점 루브릭과 결정론 필수 게이트를 적용합니다.

위험도 점수와 라벨은 `scripts/review-policy.json` 및 [review-routing.md](review-routing.md)를 정본으로 사용합니다. 위험도는 병합 조건이 아닙니다.

| 위험도 | 추가 사람 승인 조건 | 자동 병합 |
|---|---|---|
| `0~30 Light` | 없음* | PASS 4/5 이상 및 필수 게이트 통과 시 허용 |
| `31~60 Standard` | 없음* | PASS 4/5 이상 및 필수 게이트 통과 시 허용 |
| `61~100 High-risk` | 없음* | PASS 4/5 이상 및 필수 게이트 통과 시 허용 |

`dryRun=false`이며 위험도별 추가 승인 정책은 없습니다. *GitHub branch protection에 실제로 설정된 필수 승인 수가 있으면 그 규칙은 GitHub가 계속 적용합니다. 구현 backend와 reviewer backend가 같은 경우도 점수·check 조건을 통과하면 동일하게 처리합니다.

- 기본 브랜치는 `main`입니다.
- MVP 초기에는 작은 PR 단위로 `main`에 머지합니다.
- 머지 방식은 `Squash and merge`를 기본값으로 둡니다.
- `main` 직접 푸시는 금지하고 PR 머지를 통해서만 반영합니다.

## 머지 전 필수 조건

- PR 주 목적이 하나이고 변경 범위가 [pr-rules.md](pr-rules.md)의 `PR 범위 경계`를 통과
- PR 본문 체크리스트 완료
- 작업 시작 체크포인트와 PR 범위 판단이 일치
- [pr-review-gate.md](pr-review-gate.md) 기준 자동 병합 후보의 리뷰 결과가 `PASS`이고 4점 이상
- 관련 문서 최신화
- 테스트 통과
- CI 체크리스트 통과
- 충돌 없음
- 저장소 보호 규칙이 요구하는 승인 수 충족
- 배포 영향이 있으면 `cd-checklist.md`, `deploy-runbook.md`, `release-checklist.md` 확인
- PR 실패 Issue가 있으면 해결 또는 후속 이슈 연결 확인

## Squash 커밋 메시지

형식:

```text
<type>(<scope>): <summary>

Refs: REQ-xx, AC-xx, TC-xx
Docs: <changed-doc-path>
```

예시:

```text
feat(api): 이력서 진단 API 추가

Refs: REQ-01, AC-01, TC-01
Docs: specs/2026-05-21-0943-ai-resume-diagnoser/api-spec.md
```

## 머지 금지 조건

- 테스트 실패
- CI 체크리스트 미확인
- PR 주 목적과 무관한 CI/운영/템플릿/광범위 문서 정리 포함
- 문서 드리프트 존재
- PR 범위 초과 변경 포함
- 보안 정보 노출
- 배포 절차 미확인 상태에서 운영 영향 있는 변경
- 문서와 구현 불일치
- 자체 리뷰 결과 `REQUEST_CHANGES` 존재
- 해결되지 않은 PR 실패 Issue 존재

## 머지 후 작업

- 필요 시 릴리즈 체크리스트 갱신
- `main` 반영 후 GitHub Actions 결과 확인
- CI/CD 기준이 바뀌었으면 [ci-checklist.md](ci-checklist.md) 또는 [cd-checklist.md](cd-checklist.md) 갱신
- 배포 대상이면 [release-checklist.md](release-checklist.md) 확인
- 장애 가능성이 있으면 [incident-playbook.md](incident-playbook.md) 확인
- 머지 후 짧은 운영 기록으로 무엇을 머지했고 어떤 체크를 통과했는지 남김

## 핫픽스 예외

운영 장애 대응은 빠른 머지를 허용합니다. 단, 머지 후 반드시 문서와 테스트를 보강합니다.

핫픽스 후속 작업:

- 원인 기록
- 재발 방지 테스트 추가
- 관련 표준 또는 운영 문서 갱신
