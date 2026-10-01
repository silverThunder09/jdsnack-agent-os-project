# Git 훅 표준

## 목적

Git 훅은 사람이 놓치기 쉬운 하네스 규칙을 커밋/푸시 전에 막는 안전장치입니다.

## 적용 단계

현재 저장소는 버전관리되는 `.githooks/pre-commit`과 `.githooks/pre-push`를 사용합니다. clone 직후 `sh scripts/install-git-hooks.sh`를 실행하면 hook 파일을 확인하고 `jq`, PowerShell(`pwsh` 또는 `powershell.exe`), Codex CLI가 준비된 경우에만 `core.hooksPath=.githooks`를 로컬 Git 설정에 연결합니다. 사전조건이나 설정 검증이 실패하면 hook 활성화를 성공으로 처리하지 않습니다.

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

푸시 전 결정론 검증과 읽기 전용 Codex AI 리뷰를 수행합니다. `scripts/pre-push-ai-review.sh`는 tracked checkout이 clean한지 먼저 확인한 뒤 현재 branch와 `origin/main`의 branch diff만 전달하고, `scripts/review-policy.json`의 Security·Performance·Test Coverage·Architecture 라우팅 규칙도 프롬프트에 포함합니다. 요청 모델은 `backends.json`의 `workers.codex.review-fallback.model`에 기록하고, 실행 모델은 `runtimeModel`을 사용합니다.

검사 규칙:

- Codex review-fallback 모델(`backends.json`)이 구조화된 `PASS`와 4점 이상을 반환해야 합니다.
- 리뷰 결과의 `risk`, `risk_score`, 전문 라벨이 `scripts/review-risk.ps1`의 branch diff 계산과 일치해야 하며 `findings`와 `review_summary` 본문도 비어 있지 않아야 합니다.
- 리뷰 실행 실패, 필드 누락·중복, `COMMENT`, `REQUEST_CHANGES`, `NEEDS_HUMAN`, 4점 미만, findings 형식 오류, 또는 findings에 `P0`, `P1`, `blocker`, `major`가 있으면 push를 차단합니다. PASS 응답은 `findings: - none` 또는 심각도 접두사가 붙은 P2/P3 항목만 허용합니다.
- 한 번에 하나의 ref만 허용하고 `origin/main`의 후손인 단일 push head만 리뷰합니다. push head가 현재 checkout의 `HEAD`와 정확히 같아야 하며, staged·working-tree의 tracked 변경이 있으면 Codex reviewer를 시작하기 전에 차단합니다. reviewer 종료 후에도 staged·working-tree/status/HEAD 증적을 다시 비교해 리뷰 중 checkout 변경을 차단합니다. untracked 파일은 push 증적에 포함되지 않으므로 대상에서 제외합니다.
- Codex에는 diff만 전달하고 shell·network·credential·repository access를 허용하지 않습니다.
- reviewer 프로세스에는 Codex 실행 디렉터리만 `PATH`로 제공하고 실제 Codex CLI의 `exec --help` 기동을 먼저 확인합니다. 사용자 설정·자격 증명 경로는 전달하지 않고 실행에 필요한 Windows/runtime 변수만 명시적 allowlist로 전달하며, 그 밖의 사용자 home·CI·cloud·secret 환경변수도 전달하지 않습니다. sandbox 명령의 network access도 `sandbox_workspace_write.network_access=false`로 고정합니다. hook이 리뷰 후 결과를 판정하는 데 필요한 host 도구는 제한된 PATH에 추가하지 않고 절대 경로로 호출합니다.
- 빌드·lint·test·E2E는 CI가 담당하며 hook에서 모델 배정으로 대체하지 않습니다.

`scripts/pre-push-ai-review-test.sh`는 임시 Git worktree와 fake Codex를 사용해 PASS 경로, 제한된 reviewer 환경, Codex 실패 cleanup, 위험도 불일치, 중복·비정형 findings, blocker/P1 차단, 다중 ref, tracked dirty checkout을 확인합니다. 테스트는 현재 checkout의 추적 파일을 수정하지 않습니다.

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
