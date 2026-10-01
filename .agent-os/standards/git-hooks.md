# Git 훅 표준

## 목적

Git 훅은 사람이 놓치기 쉬운 하네스 규칙을 커밋/푸시 전에 막는 안전장치입니다.

## 적용 단계

현재 저장소는 버전관리되는 `.githooks/pre-commit`과 `.githooks/pre-push`를 사용합니다. clone 직후 `sh scripts/install-git-hooks.sh`를 실행하면 두 hook 파일의 존재와 `core.hooksPath=.githooks` 설정을 확인한 뒤 로컬 Git 설정에 연결합니다. 설정 검증이 실패하면 초기화를 성공으로 처리하지 않습니다.

## `commit-msg` 훅

커밋 메시지 형식을 검사합니다.

검사 규칙:

- 첫 줄은 `<type>(<scope>): <summary>` 형식
- 허용 타입만 사용
- summary는 10자 이상
- `wip`, `temp`, `update`, `fix stuff` 금지

예시 스크립트:

```sh
#!/bin/sh
msg_file="$1"
first_line="$(head -n 1 "$msg_file")"

case "$first_line" in
  feat\(*\):*|fix\(*\):*|docs\(*\):*|test\(*\):*|refactor\(*\):*|style\(*\):*|chore\(*\):*|ci\(*\):*|perf\(*\):*|build\(*\):*|revert\(*\):*) ;;
  *)
    echo "커밋 메시지 형식 오류: <type>(<scope>): <summary>"
    exit 1
    ;;
esac

echo "$first_line" | grep -Eiq 'wip|temp|fix stuff|update$' && {
  echo "의미 없는 커밋 메시지 금지"
  exit 1
}
```

## `pre-commit` 훅

문서 계약 변경 누락과 AI 준비도 문서 drift를 빠르게 검사합니다.

검사 규칙:

- `api` 또는 `controller` 변경 시 `api-spec.md` 변경 필요
- `components`, `hooks`, `services` 변경 시 `ui-spec.md` 또는 `test-scenarios.md` 변경 필요
- `requirements.md` 변경 시 `acceptance-criteria.md`와 `traceability.md` 변경 필요
- `python3 scripts/check-ai-readiness.py`가 모듈 문서, Markdown 링크, freshness, 정적 eval 케이스를 검사

예시 스크립트:

```sh
#!/bin/sh
changed="$(git diff --cached --name-only)"

echo "$changed" | grep -Eq '(^|/)controller/|(^|/)api/|api-spec' && {
  echo "$changed" | grep -q 'api-spec.md' || {
    echo "API 변경 감지: api-spec.md 갱신 필요"
    exit 1
  }
}

echo "$changed" | grep -Eq '(^|/)components/|(^|/)hooks/|(^|/)services/' && {
  echo "$changed" | grep -Eq 'ui-spec.md|test-scenarios.md' || {
    echo "UI 변경 감지: ui-spec.md 또는 test-scenarios.md 갱신 필요"
    exit 1
  }
}

echo "$changed" | grep -q 'requirements.md' && {
  echo "$changed" | grep -q 'acceptance-criteria.md' || {
    echo "요구사항 변경 감지: acceptance-criteria.md 갱신 필요"
    exit 1
  }
  echo "$changed" | grep -q 'traceability.md' || {
    echo "요구사항 변경 감지: traceability.md 갱신 필요"
    exit 1
  }
}
```

## `pre-push` 훅

푸시 전 결정론 검증과 읽기 전용 Codex AI 리뷰를 수행합니다. `scripts/pre-push-ai-review.sh`는 staged diff, working-tree diff, 현재 branch와 `origin/main`의 branch diff를 함께 전달하고 `scripts/review-policy.json`의 Security·Performance·Test Coverage·Architecture 라우팅 규칙도 프롬프트에 포함합니다. 모델은 `backends.json`의 `workers.codex.review-fallback.model`을 사용합니다.

검사 규칙:

- Codex review-fallback 모델(`backends.json`)이 구조화된 `PASS`와 4점 이상을 반환해야 합니다.
- 리뷰 실행 실패, 필드 누락, `COMMENT`, `REQUEST_CHANGES`, `NEEDS_HUMAN`, 4점 미만이면 push를 차단합니다.
- Codex에는 diff만 전달하고 shell·network·credential·repository access를 허용하지 않습니다.
- 빌드·lint·test·E2E는 CI가 담당하며 hook에서 모델 배정으로 대체하지 않습니다.

예시 명령:

```sh
cd backend
./gradlew test
cd ../frontend
npm run build
```

## 운영 규칙

- 훅은 개발자 실수를 줄이는 장치입니다.
- hook 설치 실패 또는 AI 리뷰 기준 미달은 push 실패로 남깁니다.
- 같은 예외가 2회 이상 발생하면 훅 규칙 자체를 조정합니다.
