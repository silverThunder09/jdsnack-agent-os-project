# Worker 모델 배정

## 목적

Worker의 역할·권한·작업 경계와 모델 배정을 분리합니다.

- 역할과 작업 경계의 정본은 `AGENTS.md`, `CLAUDE.md`, 이 문서입니다.
- provider, 모델명, 역할별 선택 근거의 정본은 루트 [backends.json](../../backends.json)입니다.

모델 교체는 `backends.json`의 해당 역할 한 곳만 수정합니다. 역할 문서에 모델명을 다시 적지 않습니다.

## 역할

| Worker 역할 | 책임 | 배정 키 |
|---|---|---|
| Codex 구현 | 기능 구현, 관련 테스트, 커밋, push | `workers.codex.implementation` |
| Codex 테스트 | 테스트 코드 작성, 실패 결과 분석 | `workers.codex.test-authoring-and-analysis` |
| Codex 리뷰 폴백 | Claude review backend 장애 시 diff 기반 읽기 전용 리뷰 | `workers.codex.review-fallback` |
| Claude 문서 계획 | spec·계약·운영 문서 설계 | `workers.claude.documentation-planning` |
| Claude 리뷰 | 독립 리뷰, 변경 범위·품질 판정 | `workers.claude.review` |
| Claude 구현 폴백 | Codex outage 시 구현·테스트 대행 | `workers.claude.implementation-fallback` |

## 변경 규칙

- 배정에는 `provider`, `model`, `reason`을 모두 둡니다.
- 모델명 변경은 `backends.json`만 수정하고, 역할·권한 변경은 이 문서와 `AGENTS.md` 또는 `CLAUDE.md`를 함께 수정합니다.
- 빌드·lint·test·E2E 명령 실행 자체에는 모델 배정을 적용하지 않습니다.
- Claude 문서 계획에는 자동 폴백을 두지 않습니다. Claude review backend가 구독·인증·쿼터 또는 명시적으로 식별된 실행 불가 신호로 unavailable일 때만, 동일 5점 루브릭을 사용하는 Codex 리뷰 폴백을 허용합니다. 유효한 리뷰의 `REQUEST_CHANGES`, `COMMENT`, `NEEDS_HUMAN`, 점수 미달과 분류되지 않은 실행·구조화 결과 오류는 서비스 장애로 바꾸지 않습니다.

## 리뷰 폴백 전환 조건

- Claude review-loop를 한 번 실행하고 종료 코드와 구조화된 리뷰 필드를 확인합니다. 구독·인증·쿼터·CLI unavailable·timeout처럼 명시적으로 식별한 availability 신호가 있을 때만 `active_reviewer: codex-fallback`으로 전환합니다. 그 밖의 nonzero 종료와 필수 필드 누락·형식 오류는 원문 로그를 공개하지 않고 `needs-human`으로 중단합니다.
- Claude가 유효한 리뷰 결과를 냈을 때는 `REQUEST_CHANGES`, `COMMENT`, `NEEDS_HUMAN`, 점수 미달을 Codex fallback으로 바꾸지 않습니다.
- Codex는 read-only sandbox에서 diff와 해당 acceptance/test 기준만 읽고 `decision`, `score`, `risk`, `findings`를 반환합니다. 위험도 score와 Security·Performance·Test Coverage·Architecture 라벨은 trusted base의 결정론 계산기가 정하고 Codex가 임의로 바꾸지 않습니다.
- Codex가 실행되지 않거나 출력 형식이 깨지거나 score가 4점 미만이면 `needs-human`입니다.
- `High-risk` PR은 Codex fallback만으로 자동 머지하지 않고 사람 판단으로 멈춥니다.

## 리뷰 산식·드라이런

- 고정 산식과 경로 규칙은 [review-routing.md](review-routing.md)와 `scripts/review-policy.json`에 둡니다. fallback 프롬프트와 로컬 `pre-push` hook은 같은 규칙을 사용합니다.
- Claude 구독이 비활성화되어 실행되지 않는 경우에도 Claude 결과를 기다리거나 반려를 숨기지 않고 `claude-subscription` 사유로 Codex read-only reviewer에 위임합니다.
- Claude unavailable 시 Codex 리뷰 fallback은 `backends.json`의 `model`과 `effort`를 그대로 사용합니다. 현재 설정은 `gpt-6-luna` 모델과 `max` 추론 강도이며, pre-push와 PR fallback 실행 경로 모두 같은 값을 전달합니다.
- 초기 `dryRun=true`에서는 리뷰 실행·PR 코멘트·전문 라벨만 허용하고 병합 명령을 금지합니다. 산식 구간별 승인 정책은 드라이런을 해제한 뒤에만 적용됩니다.

## 폴백 전환 조건 (outage 판정)

1. Codex 호출이 **인증·쿼터·토큰 오류**로 실패하면 outage 후보입니다. 일시 네트워크 오류와 구분하기 위해 1회 재시도 후 판정합니다.
2. outage 판정 시 오케스트레이터는 티켓을 진행하지 않고 **사용자에게 폴백 승인을 요청**합니다. 기존의 "네가 구현해" 지시가 이 승인에 해당합니다. 승인 요청 시 [needs-human 알림](needs-human-alerts.md)을 함께 보냅니다(`--source worker-fallback`).
3. 승인은 **outage 1건당 1회**입니다. 같은 outage가 이어지는 동안의 후속 티켓에는 재승인 없이 적용되며, `run-state`에 승인 사실을 기록합니다. 복귀 후 새 outage가 발생하면 다시 승인을 받습니다.

## 폴백 중 가드레일

- **자기 구현·자기 검수 차단**: 구현과 리뷰가 같은 backend가 되면 fallback PR은 `jdsnack-review-merge-loop`의 자동 머지 대상에서 제외하고 **사용자 머지로 강등**합니다([merge-rules.md](merge-rules.md)).
- **리뷰 backend 기록**: 구현은 Codex가 수행하고 Claude가 unavailable하여 Codex fallback reviewer가 실행된 PR은 PR review report에 `reviewer backend: codex-fallback`과 fallback reason을 남깁니다. fallback은 파일을 수정하지 않습니다.
- **중간 교체 금지**: 진행 중인 구현 티켓은 시작한 구현 백엔드로 완주합니다. 단, Claude review backend unavailable은 구현 티켓 백엔드를 바꾸는 것이 아니라 별도로 정의된 읽기 전용 리뷰 fallback 전환입니다.
- **범위 동결**: 폴백 중에도 active spec의 준비된 티켓만 구현합니다. spec 변경·범위 확장·백로그 승격은 하지 않습니다.
- **규약 동일**: 브랜치(`codex/<spec-slug>-<ticket-id>`)·PR·traceability 규약은 백엔드와 무관하게 동일합니다. 단, PR 본문에 `backend: claude-fallback`을 명시해 리뷰·머지 단계에서 강등 여부를 판별할 수 있게 합니다.

## 폴백 복귀 조건

- 다음 티켓을 claim하기 전에 Codex 가용성을 가벼운 호출 1회로 확인합니다. 성공하면 **자동으로 primary 복귀**하며 별도 승인은 필요 없습니다.
- 진행 중 티켓은 폴백 백엔드로 완주한 뒤, 다음 티켓부터 복귀합니다.

## 폴백 상태의 run-state 기록

[pr-automation-loop.md](pr-automation-loop.md)의 run-state 최소 필드 중 아래 4개가 폴백 상태를 담습니다.

```yaml
active_backend: codex | claude-fallback
fallback_reason: codex-auth | codex-quota | null
fallback_since: <ISO8601> | null
fallback_approved: true | false
active_reviewer: claude | codex-fallback
review_fallback_reason: claude-auth | claude-subscription | claude-quota | claude-unavailable | null
```

`claude-invalid-output`과 분류되지 않은 실행 오류는 fallback reason이 아니라 `needs-human` 사유입니다.
