# ATS 점수·포맷 진단 테스트 시나리오

## 옵션 해금과 결과 표시

- **TC-01 ATS 옵션 해금과 패널 렌더**: `ANALYSIS_OPTIONS`의 `ats`가 선택 가능하고 "준비중" 태그가 없으며, `submittedOptions.ats`가 true일 때 결과 화면에 `ComingSoonPanel`이 아닌 ATS 진단 패널이 렌더되는지 프론트 테스트로 확인한다.

## 엔드포인트 계약

- **TC-02 ATS preview 성공 응답 계약**: `POST /api/ats/preview`가 유효한 `resumeSource`/`jdText`로 호출될 때 `ApiResponse<AtsPreviewResponse>`를 반환하고 `atsScore`·`summary`·`parsingWarnings`·`presentSections`·`missingSections`·`sectionOrderWarnings`·`jdKeywordsCovered`·`jdKeywordsMissing`가 모두 직렬화되는지 3개 모드(stub/fixture/ai-local) 컨트롤러 테스트로 확인한다.
- **TC-02a 입력 검증 실패**: 빈 이력서·빈 JD·길이 미달/초과·잘못된 `jdUrl` 입력이 매칭과 동일한 기존 `ErrorCode`로 반환되고 새 코드가 추가되지 않는지 확인한다.

## 진단 차원

- **TC-03 파싱 안전성 진단**: 표 구조·이미지 placeholder·비표준 섹션 제목이 포함된 이력서가 `parsingWarnings`에 대응 경고를 채우고, 표준 텍스트 이력서는 `parsingWarnings`가 빈 배열인지 확인한다.
- **TC-04 구조 진단**: 표준 섹션이 일부 누락·순서 뒤바뀐 이력서가 `presentSections`/`missingSections`/`sectionOrderWarnings`로 정확히 분류되는지 확인한다.
- **TC-05 JD 대비 키워드 최적화**: JD 키워드 중 이력서에서 발견되는 키워드가 `jdKeywordsCovered`, 발견되지 않는 키워드가 `jdKeywordsMissing`로 상호 배타적으로 분류되는지 확인한다.
- **TC-06 종합 ATS 점수**: `atsScore`가 0~100 정수 범위 안에 있고 `summary`가 비어 있지 않은지, 진단 결과에 따라 점수가 달라지는지 확인한다.

## 모드·경계 회귀

- **TC-07 모드 결정성과 관대 처리**: `stub`/`fixture`가 동일 입력에 동일 결과를 반환하고 모든 필드가 null 아님을 확인한다. `ai-local` Gemini 응답에서 진단 필드가 누락/비배열일 때 기본값(빈 배열·기본 점수)으로 채워 성공을 유지하고, JSON 파싱 불가·호출 실패에서만 기존 `GEMINI_API_RESPONSE_INVALID`/`GEMINI_API_REQUEST_FAILED`를 따르는지 확인한다.
- **TC-08 계층·비밀값 회귀**: `com.jdsnack.ats` Controller가 비즈니스 로직을 갖지 않고 Service/Provider 경계를 지키며, 프론트 컴포넌트가 직접 fetch하지 않고 `services/` 계층을 통해 호출하며, 비밀값이 클라이언트 번들에 포함되지 않는지 확인한다.
- **TC-09 내보내기 마크다운 ATS 섹션**: `ats` 선택 시 `buildResultMarkdown` 결과에 ATS 점수·요약·세 진단 섹션이 포함되고, 빈 분류가 안전하게("(없음)" 등) 처리되는지 프론트 테스트로 확인한다.
