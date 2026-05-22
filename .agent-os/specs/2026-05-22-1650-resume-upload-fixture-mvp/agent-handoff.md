# Agent Handoff

## Feature

- 기능명: 1.5차 MVP 업로드 + fixture 분석 백엔드 구현

## Current Phase

- Backend

## Source Documents

- `.agent-os/specs/2026-05-22-1650-resume-upload-fixture-mvp/requirements.md`
- `.agent-os/specs/2026-05-22-1650-resume-upload-fixture-mvp/acceptance-criteria.md`
- `.agent-os/specs/2026-05-22-1650-resume-upload-fixture-mvp/api-spec.md`
- `.agent-os/specs/2026-05-22-1650-resume-upload-fixture-mvp/architecture.md`
- `.agent-os/specs/2026-05-22-1650-resume-upload-fixture-mvp/fixture-data-model.md`

## Changed Files

- `backend/build.gradle`
- `backend/src/main/resources/application.properties`
- `backend/src/main/resources/schema.sql`
- `backend/src/main/resources/data.sql`
- `backend/src/main/java/com/jdsnack/common/ErrorCode.java`
- `backend/src/main/java/com/jdsnack/diagnose/DiagnoseController.java`
- `backend/src/main/java/com/jdsnack/diagnose/DiagnoseService.java`
- `backend/src/main/java/com/jdsnack/diagnose/DiagnosisMode.java`
- `backend/src/main/java/com/jdsnack/diagnose/DiagnosisProvider.java`
- `backend/src/main/java/com/jdsnack/diagnose/DiagnosisResultResponse.java`
- `backend/src/main/java/com/jdsnack/diagnose/StubDiagnosisProvider.java`
- `backend/src/main/java/com/jdsnack/diagnose/FixtureDiagnosisProvider.java`
- `backend/src/main/java/com/jdsnack/diagnose/FixtureAnalysis.java`
- `backend/src/main/java/com/jdsnack/diagnose/FixtureAnalysisRepository.java`
- `backend/src/main/java/com/jdsnack/diagnose/ResumeExtractionService.java`
- `backend/src/main/java/com/jdsnack/diagnose/TextNormalizer.java`
- `backend/src/main/java/com/jdsnack/diagnose/TextHashGenerator.java`
- `backend/src/main/java/com/jdsnack/diagnose/UploadedResumeType.java`
- `backend/src/test/java/com/jdsnack/diagnose/DiagnoseStubModeControllerTest.java`
- `backend/src/test/java/com/jdsnack/diagnose/DiagnoseFixtureModeControllerTest.java`
- `backend/src/test/java/com/jdsnack/diagnose/TestResumeSamples.java`
- `.agent-os/specs/2026-05-22-1650-resume-upload-fixture-mvp/api-spec.md`
- `.agent-os/specs/2026-05-22-1650-resume-upload-fixture-mvp/architecture.md`

## Decisions Made

- 운영 모드는 `jdsnack.diagnosis.mode`로 분리하고 기본값은 `stub`로 둡니다.
- fixture 저장소는 JSON 대신 H2 테스트 DB와 `JdbcTemplate`로 구현합니다.
- PDF는 PDFBox, DOCX는 Apache POI로 실제 텍스트를 추출합니다.
- 텍스트와 파일 업로드 모두 `TEXT_HASH` 기준 fixture 매핑을 사용합니다.

## Change Requests

- `Frontend Engineer`: 다음 작업에서 텍스트/파일 입력 모드 전환과 fixture 성공 결과 카드 렌더링을 붙여주세요.
- `QA Reviewer`: stub 모드와 fixture 모드가 프론트 기준으로도 분리되는지 확인해주세요.

## Open Questions

- 없음

## Risks

- 현재 fixture 샘플은 1건이라 시연 전 샘플 추가가 필요할 수 있습니다.
- 프론트가 아직 성공 응답 DTO를 렌더링하지 않아, PR 2 머지 전까지 최종 사용자 흐름은 완성되지 않습니다.

## Next Agent

- Frontend Engineer
