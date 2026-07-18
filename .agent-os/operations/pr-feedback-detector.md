# PR 피드백 감지기

## 목적

`codex/*` 브랜치에 새 PR 반려·CI 실패·리뷰 변경요청이 생겼는지 **한 번만 확인**하고, Codex 세션이 처리할 수 있는 JSON 이벤트를 출력합니다.

이 스크립트는 수정·커밋·푸시·머지를 수행하지 않습니다. 감지와 변경 실행을 분리해 중복 실행과 무인 파괴적 변경을 막습니다.

## 실행

```sh
./scripts/pr-feedback-detector.sh --branch codex/service-mvp-t2
```

기본값은 현재 Git 브랜치와 `gh repo view`의 저장소를 사용합니다. 외부 스케줄러나 Codex 호출기가 `actionable` 결과를 받은 경우 출력의 `prompt`를 다음 작업 입력으로 전달합니다.

```sh
set +e
event="$(./scripts/pr-feedback-detector.sh --branch codex/service-mvp-t2)"
code=$?
set -e

if [ "$code" -eq 10 ]; then
  printf '%s\n' "$event"
fi
```

## 감지 대상

- 열린 `리뷰 반려: codex/<branch>` Issue
- PR 리뷰 결정 `CHANGES_REQUESTED`
- PR required check의 `FAILURE`, `CANCELLED`, `TIMED_OUT`, `ACTION_REQUIRED`, `STARTUP_FAILURE`
- PR 추가·삭제 변경량 합계가 기본 1,000줄을 초과한 경우

반려 Issue를 가장 먼저 처리합니다. 같은 사건을 반복 감지하지 않도록 `event_key`에 Issue 갱신 시각 또는 PR head SHA를 포함합니다. 상태 저장·중복 제거는 호출하는 스케줄러가 담당합니다.

CI 실패는 base 브랜치 보호 규칙의 required status check와 일치하는 항목만 감지합니다. 보호 규칙을 읽을 수 없으면 조용히 통과시키지 않고 `needs_human`을 반환합니다. 일시적으로 API를 읽을 수 없는 환경은 `PR_FEEDBACK_REQUIRED_CHECKS=check-a,check-b`로 명시할 수 있습니다. `ERROR` 상태도 실패로 처리합니다.

## 출력과 종료 코드

| 종료 코드 | `status` | 의미 |
|---:|---|---|
| 0 | `no_action` | 처리할 피드백 없음 |
| 10 | `actionable` | 같은 브랜치에서 수정할 피드백 발견 |
| 20 | `needs_human` | `gh` 인증·저장소·GitHub 조회 실패 |
| 2 | 해당 없음 | 인자가 잘못되어 실행하지 못함 |

`actionable` 결과에는 `event_type`, `event_key`, `branch`, `pr`, `issue`, `failed_checks`, `prompt`를 포함합니다. 감지 결과가 `diff_over_limit`이면 현재 base 기준으로 브랜치를 재정렬하고 관심사별 PR을 분리해야 합니다.

## 운영 경계

- 감지기는 polling loop를 내장하지 않습니다. cron·launchd·외부 오케스트레이터가 필요할 때 한 번씩 호출합니다.
- 감지기는 GitHub 상태만 읽습니다. 코드 수정, 강제 push, PR 생성, 머지는 호출기가 별도 권한으로 수행합니다.
- `needs_human`은 자동으로 실패를 숨기지 않고 인증·권한·외부 상태 문제를 사람에게 올립니다.
- Codex 수정 작업은 기존 PR 규칙의 동일 브랜치·관련 테스트·업무 assertion 보존 규칙을 따릅니다.
- 감지기 계약 테스트는 별도 CI workflow 변경 PR에서 Docs Harness에 연결합니다.
