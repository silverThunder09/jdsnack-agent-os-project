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
| Claude 문서 계획 | spec·계약·운영 문서 설계 | `workers.claude.documentation-planning` |
| Claude 리뷰 | 독립 리뷰, 변경 범위·품질 판정 | `workers.claude.review` |
| Claude 구현 폴백 | Codex outage 시 구현·테스트 대행 | `workers.claude.implementation-fallback` |

## 변경 규칙

- 배정에는 `provider`, `model`, `reason`을 모두 둡니다.
- 모델명 변경은 `backends.json`만 수정하고, 역할·권한 변경은 이 문서와 `AGENTS.md` 또는 `CLAUDE.md`를 함께 수정합니다.
- 빌드·lint·test·E2E 명령 실행 자체에는 모델 배정을 적용하지 않습니다.
- Claude 문서 계획·Claude 리뷰에는 폴백을 두지 않습니다. 리뷰 5점 채점과 spec 품질은 루프의 판정 기준 자체이므로, 판정자가 바뀌면 기준의 일관성이 깨집니다. 리뷰어 불가는 폴백이 아니라 루프 중단 사유입니다.

## 폴백 전환 조건 (outage 판정)

1. Codex 호출이 **인증·쿼터·토큰 오류**로 실패하면 outage 후보입니다. 일시 네트워크 오류와 구분하기 위해 1회 재시도 후 판정합니다.
2. outage 판정 시 오케스트레이터는 티켓을 진행하지 않고 **사용자에게 폴백 승인을 요청**합니다. 기존의 "네가 구현해" 지시가 이 승인에 해당합니다. 승인 요청 시 [needs-human 알림](needs-human-alerts.md)을 함께 보냅니다(`--source worker-fallback`).
3. 승인은 **outage 1건당 1회**입니다. 같은 outage가 이어지는 동안의 후속 티켓에는 재승인 없이 적용되며, `run-state`에 승인 사실을 기록합니다. 복귀 후 새 outage가 발생하면 다시 승인을 받습니다.

## 폴백 중 가드레일

- **자기 구현·자기 검수 차단**: 구현과 리뷰가 모두 Claude가 되므로, 폴백 중 만든 PR은 `jdsnack-review-merge-loop`의 자동 머지 대상에서 제외하고 **사용자 머지로 강등**합니다([merge-rules.md](merge-rules.md)).
- **중간 교체 금지**: 진행 중 티켓은 시작한 백엔드로 완주합니다. 티켓 도중 백엔드를 바꾸지 않습니다.
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
```
