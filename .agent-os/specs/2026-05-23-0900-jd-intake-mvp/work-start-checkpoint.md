# Work Start Checkpoint

## Target Spec
- 대상 spec: `2026-05-23-0900-jd-intake-mvp`

## Risk Level
- `Standard`
- 판단 이유: 새 기능 설계 문서를 추가하고 로드맵/README 연결만 조정하는 일반 문서 작업이다.

## Change Scope
- 이번 작업에서 바꾸는 것:
  - JD 입력 MVP spec 문서 추가
  - JD 텍스트, JD 링크, 비교 API 초안 계약 정리
  - roadmap/README에 다음 설계 단계 연결
- 이번 작업에서 바꾸지 않는 것:
  - 실제 백엔드 API 구현
  - 실제 프론트 UI 구현
  - AI 비교 분석 계약 상세화
  - JD 링크 자동 수집

## Test Plan
- 로컬 테스트:
  - 문서 구조 확인
  - `REQ`, `AC`, `TC` 연결 확인
  - legacy MVP 금지 패턴 확인
- 수동 검증:
  - JD 텍스트 필수 / 링크 선택 규칙이 모든 문서에서 일관적인지 확인
  - `POST /api/match/preview` 요청 초안과 UI 흐름이 충돌하지 않는지 확인
- CI 기대 항목:
  - `Docs Harness`
  - 공통 required check

## PR Scope
- PR 주 목적:
  - `JD 입력 MVP 설계 문서 고정`
- 같은 PR에 포함할 항목:
  - 새 spec 문서
  - roadmap/README 연결
- 별도 PR로 분리할 항목:
  - JD 비교 API 구현
  - Gemini AI 계약
  - 브라우저 자동화
