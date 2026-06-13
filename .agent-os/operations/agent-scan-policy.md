# 에이전트 탐색 정책

## 목적

Codex가 작업할 때 불필요한 파일을 읽지 않도록 탐색 표면을 줄입니다.
목표는 RAG 도입이 아니라, 현재 저장소 안에서 필요한 컨텍스트만 읽는 운영 규칙을 고정하는 것입니다.

## 기본 원칙

- 먼저 `AGENTS.md`와 현재 active spec만 확인합니다.
- 작업과 직접 관련된 구현 폴더와 테스트만 추가로 읽습니다.
- archive, 빌드 산출물, 의존성 폴더는 기본 컨텍스트에서 제외합니다.
- 주제가 바뀌면 새 세션을 시작하고, 이전 주제의 과거 spec 전체를 기본 탐색하지 않습니다.
- `.env`는 존재 여부만 확인할 수 있고, 내용 읽기와 수정은 금지합니다.

## 표준 탐색 명령

파일 목록 확인:

```sh
rg --files \
  -g '!frontend/node_modules/**' \
  -g '!frontend/dist/**' \
  -g '!backend/build/**' \
  -g '!backend/.gradle/**' \
  -g '!.agent-os/archive/**' \
  -g '!.git/**'
```

텍스트 검색:

```sh
rg "검색어" \
  -g '!frontend/node_modules/**' \
  -g '!frontend/dist/**' \
  -g '!backend/build/**' \
  -g '!backend/.gradle/**' \
  -g '!.agent-os/archive/**' \
  -g '!.git/**'
```

## 금지 탐색

- 전체 `find .`
- 전체 `ls -R`
- `.agent-os/archive` 전체 탐색
- `frontend/node_modules`, `frontend/dist`, `backend/build`, `backend/.gradle`, `.git` 직접 탐색
- `.env` 내용 출력 또는 수정

## 예외 조건

- 사용자가 archive 확인을 직접 요청한 경우
- active spec이 특정 archive 문서를 명시적으로 참조한 경우
- 빌드 실패 원인 확인을 위해 `backend/build/reports` 같은 산출물 일부가 필요한 경우
- 의존성 문제 조사 중 특정 lockfile 또는 package manifest 확인이 필요한 경우

예외 탐색 시에도 전체 폴더를 열지 않고, 필요한 파일 1개 또는 좁은 패턴만 확인합니다.

## 읽기 범위

- 기본: `AGENTS.md`, active spec, 직접 관련 구현 폴더, 관련 테스트
- 운영 변경: 관련 workflow, script, 운영 문서
- PR 확인: PR diff, 테스트 결과, 관련 spec
- 새 세션: 새 주제의 active spec과 직접 관련 문서부터 확인

## 컨텍스트 압축 기준

- 읽은 파일이 많아지면 추가 탐색 전에 현재까지 확인한 사실을 요약합니다.
- 반복 질문이 나오면 새 탐색보다 active spec과 traceability를 먼저 확인합니다.
- archive를 읽은 경우, 현재 판단에 필요한 결론만 요약하고 원문을 다시 확장하지 않습니다.
