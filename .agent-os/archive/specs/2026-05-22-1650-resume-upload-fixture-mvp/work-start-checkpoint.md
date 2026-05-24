# Work Start Checkpoint

## Target Spec

- 대상 spec: `2026-05-22-1650-resume-upload-fixture-mvp`

## Change Scope

- 이번 작업에서 바꾸는 것:
  - `POST /api/diagnose/file` 업로드 API 구현
  - `ResumeExtractionService` 초안 구현
  - fixture JSON 저장소 또는 로더 구현
  - `FixtureDiagnosisProvider`와 결과 DTO 구현
  - 업로드/fixture 성공 및 실패 테스트 추가
- 이번 작업에서 바꾸지 않는 것:
  - 실제 외부 AI 연동
  - JD 입력/링크 기능
  - 운영 배포 인프라 추가 변경
  - Playwright 같은 별도 브라우저 러너 도입

## Test Plan

- 로컬 테스트:
  - `backend` 단위 테스트
  - `frontend` 단위 테스트
  - fixture 응답 기준 API 테스트
  - `docker compose` 기반 스모크 테스트
- 수동 검증:
  - 텍스트 입력 fixture 결과 확인
  - PDF/DOCX 업로드 성공/실패 확인
  - `FIXTURE_NOT_FOUND`, `UNSUPPORTED_FILE_TYPE`, `FILE_TEXT_EXTRACTION_FAILED` 확인
- CI 기대 항목:
  - `Docs Harness`
  - `Backend CI`
  - `Frontend CI`
  - `Container Flow`

## PR Scope

- PR 주 목적:
  - `1.5차 MVP 업로드 + fixture 분석 흐름 구현`
- 같은 PR에 포함할 항목:
  - 관련 백엔드 구현
  - 관련 프론트 구현
  - 직접 연결된 spec 문서 갱신
  - 관련 테스트 코드
  - handoff
- 별도 PR로 분리할 항목:
  - CI/CD 정책 변경
  - 브랜치 보호 규칙 변경
  - 광범위 문서 리팩토링
  - 2차 MVP AI 계약 설계
