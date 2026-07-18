# Work Start Checkpoint

## Target Spec
- 대상 spec: `.agent-os/specs/2026-06-20-saramin-jd-image-ocr/`

## Risk Level
- `Elevated`
- 판단 이유: 외부에서 받은 이미지 URL로 바이트를 다운로드하는 신규 네트워크 경로가 추가되어 **SSRF 위험**이 핵심이다. 기존 `isUnsafeHost` 재사용 + 신뢰 호스트 allowlist + 크기/타입/타임아웃/리다이렉트 최종 호스트 재검증이 모두 강제되어야 한다. Gemini 비전 호출이 추가되지만 새 의존성·새 엔드포인트·새 에러 코드는 없고, 폴백은 텍스트 추출이 끝내 실패한 사람인 공고에서만 동작하며 실패 시 기존 에러로 graceful fallback 한다. 텍스트 공고의 기존 동작은 회귀 없이 보존되어야 한다.

## Change Scope

- 이번 작업에서 바꾸는 것(추가): 백엔드 `com.jdsnack.jd` — `JdImageOcr` 인터페이스, `GeminiJdImageOcr` 구현체, `JdFetchService.fetch()` 마지막 폴백 단계(이미지 탐지·SSRF 검증 다운로드·OCR 호출), `image-ocr` fetchMode 값. 신규/보강 백엔드 테스트(`GeminiJdImageOcrTest`, `JdFetchServiceTest` OCR 경로, `JdFetchControllerTest` 직렬화).
- 이번 작업에서 바꾸지 않는 것: `POST /api/jd/fetch` 엔드포인트·`JdFetchRequest`·`ApiResponse<T>` 래퍼·`ErrorCode`(새 코드 없음), `JdHtmlExtractor`의 텍스트 추출/`static-html` 경로·`fetchSaraminFallback` 동작, `validateUrl`/`isUnsafeHost`/`isSupportedHost`의 기존 의미(재사용은 하되 의미 변경 금지), 프론트 전체(`frontend/src`).

## Read Scope
- 반드시 읽을 문서/폴더: 본 spec의 `requirements.md`·`acceptance-criteria.md`·`test-scenarios.md`·`api-spec.md`·`ui-spec.md`·`traceability.md`, `AGENTS.md`, `.agent-os/standards/backend.md`·`api.md`·`testing-standards.md`, `.agent-os/operations/gemini-local-test-policy.md`.
- 필요할 때만 읽을 문서/폴더: `backend/src/main/java/com/jdsnack/jd/*`(JdFetchService·JdHtmlExtractor·JdFetchResponse·JdFetchController), `backend/src/main/java/com/jdsnack/match/GeminiMatchPreviewProvider.java`(Gemini 호출 패턴), `backend/src/test/java/com/jdsnack/jd/*`(테스트 패턴), `backend/src/main/java/com/jdsnack/common/ErrorCode.java`.

## Do Not Read
- 기본 탐색 제외: `frontend/node_modules`, `frontend/dist`, `backend/build`, `backend/.gradle`, `.agent-os/archive`, `.git`.
- 예외적으로만 확인할 범위: archive된 이전 spec(맥락 필요 시).

## Test Plan
- 로컬 테스트: `cd backend && ./gradlew test`, `cd frontend && npm run lint && npm test && npm run build && npm run test:e2e`.
- 백엔드: `JdFetchServiceTest`에 OCR 폴백 경로(텍스트 실패→이미지 탐지→OCR 성공, SSRF 차단 케이스, 크기/타입 위반, 키 부재 graceful fallback, OCR 실패 폴백) 추가. `GeminiJdImageOcrTest`(주입 HttpClient 스텁으로 `inlineData` 요청 구성·응답 텍스트 추출). `JdFetchControllerTest`로 `fetchMode: "image-ocr"` 직렬화 확인.
- 프론트: 무변경 회귀(기존 lint/test/build/e2e가 수정 없이 통과).
- 수동 검증: `gemini-local-test-policy.md`에 따라 실제 사람인 이미지 공고로 라이브 OCR 동작 1회 확인(선택).
- CI 기대 항목: 백엔드 test, 프론트 lint/test/build/e2e, 문서 harness 인덱스/traceability 검증.

## PR Scope
- PR 주 목적: 사람인 JD 이미지 OCR 폴백(백엔드 전용).
- 같은 PR에 포함할 항목: `JdImageOcr`/`GeminiJdImageOcr`/`JdFetchService` 폴백·SSRF 검증·`image-ocr` fetchMode, 관련 백엔드 테스트.
- 별도 PR로 분리할 항목: 문서 PR(이 spec 추가·archive 이동·포인터 갱신), 사람인 외 사이트 확장·PDF OCR·출처 표기 UI 등 향후 항목.
