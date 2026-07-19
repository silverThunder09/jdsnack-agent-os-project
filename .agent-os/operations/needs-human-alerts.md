# Needs-human Discord 알림

## 목적

무인 리뷰·머지 흐름이 사람 판단을 기다리는 순간을 Discord로 한 번 알립니다. 승인·머지·코드 수정은 자동화하지 않습니다.

## 발송 범위

- `pr-feedback-detector`가 `needs_human`을 반환할 때
- `jdsnack-review-merge-loop`가 `needs-human`으로 중단할 때
- 워커 폴백 승인을 요청할 때(`--source worker-fallback`, [worker-backends.md](worker-backends.md)의 폴백 전환 조건)

알림에는 발생원, 브랜치, 사유, PR 또는 Issue 링크만 포함합니다. PR 또는 Issue를 아직 특정하지 못한 경우에는 GitHub 알림 링크를 보냅니다. CI 로그, 리뷰 원문, webhook URL, 비밀값은 보내지 않습니다.

## Keychain 설정

webhook URL은 저장소·`.env`·GitHub Issue에 넣지 않고 macOS Keychain에만 저장합니다.

```sh
read -rs 'JDSNACK_DISCORD_WEBHOOK_URL?Discord webhook URL: '
security add-generic-password -U \
  -s jdsnack-discord-webhook \
  -a webhook-url \
  -w "$JDSNACK_DISCORD_WEBHOOK_URL"
unset JDSNACK_DISCORD_WEBHOOK_URL
```

기본 Keychain service/account는 `jdsnack-discord-webhook` / `webhook-url`입니다. 다른 값을 사용해야 하면 실행기에 `JDSNACK_DISCORD_KEYCHAIN_SERVICE`, `JDSNACK_DISCORD_KEYCHAIN_ACCOUNT` 환경변수로만 전달합니다.

## 호출 계약

```sh
bash scripts/notify-needs-human.sh \
  --source pr-feedback-detector \
  --repository silverThunder09/jdsnack-agent-os-project \
  --branch codex/example \
  --reason required_checks_unknown \
  --url https://github.com/silverThunder09/jdsnack-agent-os-project/pulls
```

Keychain 값이 없거나 Discord 전송이 실패하면 helper는 경고만 남기고 성공으로 종료합니다. 알림 실패가 리뷰·머지 루프를 멈추면 안 됩니다. `--event-key`를 전달하면 macOS Application Support의 상태 파일로 같은 사건의 재발송을 막고, 전송 실패 때는 상태를 기록하지 않아 다음 실행에서 재시도할 수 있습니다.

## 외부 리뷰-머지 루프 연결

`jdsnack-review-merge-loop`는 repo 밖 cron/launchd 실행기이므로, `needs-human`으로 상태를 기록하는 분기에 아래 호출을 추가합니다.

```sh
bash "$JDSNACK_REPO/scripts/notify-needs-human.sh" \
  --source jdsnack-review-merge-loop \
  --repository "$repository" \
  --branch "$branch" \
  --reason "$blocked_reason" \
  --event-key "$run_id:$branch:$blocked_reason" \
  --url "$pr_or_issue_url"
```

이 호출은 한 사건당 상태를 `needs-human`으로 전환하는 지점에서 한 번만 수행합니다. 재시도 loop 안에 넣지 않습니다.
