# Codex 하네스 표준

## 목적

이 문서는 JDSnack 저장소를 **Codex가 읽기 쉽고, 지키기 쉽고, 검증하기 쉬운 상태**로 유지하기 위한 운영 규정입니다.

## 왜 필요한가

문서만 많다고 좋은 저장소가 되지는 않습니다.  
좋은 하네스는 “어디를 읽어야 하는지”, “무엇을 바꾸면 어떤 문서를 같이 바꿔야 하는지”, “완료를 어떻게 검증하는지”를 분명하게 만듭니다.

## 핵심 원칙

### 1. `AGENTS.md`는 지도다

- `AGENTS.md`는 짧은 진입점만 제공합니다.
- 긴 설명과 상세 규칙은 `agent-os/` 아래 구조화된 문서로 보냅니다.

### 2. 문서가 구현보다 먼저 온다

- 기능 구현 전 `requirements.md`를 먼저 정리합니다.
- 구현 전 `acceptance-criteria.md`와 `test-scenarios.md`를 준비합니다.
- 구현 후 `traceability.md`로 요구사항과 검증을 연결합니다.

### 3. 경계는 글이 아니라 규칙으로 다룬다

- API 계약, UI 흐름, 아키텍처 경계는 문서에만 남기지 않습니다.
- 반복되는 리뷰 피드백은 `standards/` 문서나 자동 체크 규칙으로 승격합니다.

### 4. 에이전트 가독성을 우선한다

- 한 문서에 하나의 책임만 둡니다.
- 디렉토리와 파일명은 역할 중심으로 단순하게 유지합니다.
- 오래된 계획은 `archive/`로 이동하고 현재 활성 문서만 전면에 둡니다.

### 5. 탐색 표면을 줄인다

- 작업 시작 시 active spec, 관련 코드 폴더, 관련 테스트만 읽습니다.
- 기본 탐색은 `rg --files`와 `rg`로 수행합니다.
- `frontend/node_modules`, `frontend/dist`, `backend/build`, `backend/.gradle`, `.agent-os/archive`, `.git`는 기본 탐색에서 제외합니다.
- archive는 사용자가 직접 요청하거나 active spec이 명시적으로 참조할 때만 읽습니다.
- 컨텍스트가 커지면 추가 탐색보다 현재 읽은 파일과 결정사항 요약을 우선합니다.

## 필수 작업 순서

`requirements -> acceptance-criteria -> test-scenarios -> implementation -> verification`

## 변경 시 필수 동기화 규칙

- API 변경: `api-spec.md` 갱신 필수
- UI 흐름 변경: `ui-spec.md` 갱신 필수
- 요구사항 변경: `requirements.md`, `acceptance-criteria.md`, `traceability.md` 갱신 필수
- 새 테스트 추가/변경: `test-scenarios.md`와 연결 필수

## 금지 규칙

- 거대한 단일 지침 파일 작성
- 문서 없는 API 변경
- 테스트 시나리오 없는 acceptance criteria 추가
- 암묵적 구조 변경
- 반복 피드백을 구두로만 남기고 표준으로 승격하지 않는 것
- 전체 `find .`, 전체 `ls -R`, archive 전체 탐색으로 컨텍스트를 낭비하는 것

## 승격 규칙

다음 항목이 2회 이상 반복되면 문서 또는 자동 체크로 승격합니다.

- 같은 리뷰 코멘트
- 같은 구조 위반
- 같은 테스트 누락
- 같은 naming drift

## 적용 범위

- 제품 코드
- 테스트 코드
- 설계 문서
- 릴리즈 및 운영 문서
- 이후 추가될 CI/검증 스크립트
