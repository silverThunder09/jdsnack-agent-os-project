# ATS 점수·포맷 진단 수용 기준

- **AC-01** `ANALYSIS_OPTIONS`의 `ats`가 `enabled: true`로 선택 가능하고 "준비중" 태그를 갖지 않으며, 결과 화면에서 `ats` 선택 시 `ComingSoonPanel` 대신 실제 ATS 진단 패널이 렌더된다. (REQ-01)
- **AC-02** `POST /api/ats/preview`가 매칭과 동일한 `resumeSource`/`jdText`/`jdUrl` 요청을 받아 `ApiResponse<AtsPreviewResponse>`로 성공 응답을 반환하고, 입력 검증 실패는 새 코드 없이 기존 `ErrorCode`(`EMPTY_RESUME`, `TEXT_TOO_SHORT/LONG`, `EMPTY_JD`, `JD_TEXT_TOO_SHORT/LONG`, `INVALID_JD_URL`)로 반환된다. (REQ-02)
- **AC-03** 응답이 파싱 위험 요소를 `parsingWarnings` 목록으로 반환하며, 표·이미지·비표준 섹션이 감지되면 경고가 채워지고 깨끗한 텍스트면 빈 배열이다. (REQ-03)
- **AC-04** 응답이 표준 섹션 진단을 `presentSections`/`missingSections`/`sectionOrderWarnings`로 반환한다. (REQ-04)
- **AC-05** 응답이 JD 대비 키워드 최적화를 `jdKeywordsCovered`/`jdKeywordsMissing`로 반환한다. (REQ-05)
- **AC-06** 응답이 세 진단을 종합한 `atsScore`(0~100 정수)와 `summary` 문자열을 반환한다. (REQ-06)
- **AC-07** `stub`/`fixture`는 동일 입력에 결정적 결과를 반환하고 모든 필드가 항상 직렬화(목록은 빈 배열, 점수 기본값, null 아님)되며, `ai-local` Gemini는 진단 필드 누락/비배열을 기본값으로 관대 처리하고 성공을 유지한다. 기존 `GEMINI_API_*` 정책은 변경되지 않는다. (REQ-07)
- **AC-08** `com.jdsnack.ats`의 `Controller -> Service -> Provider` 경계가 유지되고 Entity가 응답으로 직접 노출되지 않으며, 프론트는 `services/` 계층을 통해서만 ATS API를 호출하고 비밀값이 클라이언트 번들에 포함되지 않는다. (REQ-08)
- **AC-09** ATS 패널이 점수·요약과 파싱 안전성·구조·키워드 세 섹션을 표시하고 로딩·에러·빈 상태를 기존 패턴대로 처리하며, 내보내기 마크다운에 `ats` 선택 시 ATS 섹션이 포함된다. (REQ-09)
