# Git 훅 표준

## 목적

Git 훅은 사람이 놓치기 쉬운 하네스 규칙을 커밋/푸시 전에 막는 안전장치입니다.

## 적용 단계

현재 저장소는 버전관리되는 `.githooks/pre-commit`을 사용합니다. clone마다 한 번 `sh scripts/install-git-hooks.sh`를 실행해 `core.hooksPath`를 연결합니다.

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
  feat\(*\):*|fix\(*\):*|docs\(*\):*|test\(*\):*|refactor\(*\):*|style\(*\):*|chore\(*\):*|ci\(*\):*|perf\(*\):*) ;;
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

푸시 전 검증을 수행합니다.

검사 규칙:

- 백엔드 테스트 실행
- 프론트엔드 타입 체크/빌드 실행
- 문서 링크 깨짐 여부는 추후 자동화

예시 명령:

```sh
cd backend
./gradlew test
cd ../frontend
npm run build
```

## 운영 규칙

- 훅은 개발자 실수를 줄이는 장치입니다.
- 훅 실패를 우회하려면 PR 설명에 이유를 남깁니다.
- 같은 예외가 2회 이상 발생하면 훅 규칙 자체를 조정합니다.
