# 문서 생명주기

## 목적

문서를 한번 쓰고 버리는 것이 아니라, 기능의 생애주기와 함께 유지하기 위한 규칙입니다.

## 문서 단계

### 1. 초안

- 아이디어 또는 기능 초안
- 아직 구현 시작 전
- 보통 `requirements.md` 또는 `shape.md` 수준

### 2. 활성

- 현재 구현 중인 기능 문서
- `requirements`, `acceptance-criteria`, `test-scenarios`, `traceability`를 갖춘 상태
- `specs/YYYY-MM-DD-<slug>/`에 위치

### 3. 안정화

- 구현 완료 후 기준 문서로 유지되는 상태
- API/UI 계약이 실제 구현과 일치

### 4. 보관

- 더 이상 활성 변경 대상이 아님
- 이전 계획, 폐기된 방향, 완료된 일정표 등을 보관
- 기능 폴더의 `archive/` 또는 추후 공용 `archive/`로 이동

## 문서 갱신 규칙

- 요구사항 변경 시:
  - `requirements.md`
  - `acceptance-criteria.md`
  - `traceability.md`
- API 변경 시:
  - `api-spec.md`
  - 필요 시 `test-scenarios.md`
- UI 흐름 변경 시:
  - `ui-spec.md`
  - 필요 시 `test-scenarios.md`
- 표준 변경 시:
  - `standards/` 하위 문서
  - 영향 받는 활성 spec의 참조 링크

## 문서 신선도 규칙

- 활성 기능 spec은 마지막 수정일을 유지합니다.
- 문서가 실제 구현과 다르면 구현이 아니라 문서가 먼저 부정확한 상태로 간주됩니다.
- 문서 드리프트가 반복되면 수동 리뷰가 아니라 표준 규칙으로 승격합니다.

## 최소 문서 세트

새 기능은 최소 아래 문서 없이 시작하지 않습니다.

- `requirements.md`
- `acceptance-criteria.md`
- `test-scenarios.md`
- `traceability.md`

## 레거시 문서 처리

- 기존의 상세 문서는 당장 삭제하지 않습니다.
- 대신 새 상위 문서에서 역할을 재정의하고, 필요한 경우 `레거시 상세 문서`로 표시합니다.
