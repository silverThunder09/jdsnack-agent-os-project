# 분석 실행 전 통합 검증 게이트 API 명세

## 변경 요약

새 엔드포인트나 응답 스키마 변경은 **없다.** 이번 spec은 게이팅 시점을 앞당기고, 프론트·백엔드 검증 기준을 일원화하며, 백엔드의 방어적 재검증을 명시적으로 보장한다. 백엔드 검증 로직은 이미 존재하므로, 이 문서는 **확정된 계약**으로 고정하는 역할이다.

## 영향 엔드포인트 (계약 불변)

- `POST /api/diagnose` — 이력서 텍스트 진단
- `POST /api/diagnose/file` — 업로드 파일 진단(추출 포함)
- `POST /api/match/preview` — JD 적합도 미리보기

요청·응답 본문, `ApiResponse<T>` 래퍼 형태는 변경하지 않는다.

## 검증 기준 (프론트·백엔드 공통 정본)

| 대상 | 최소 | 최대 | 비고 |
| --- | --- | --- | --- |
| 이력서 텍스트(`resumeText` / 매칭 `resumeSource.value`) | 50자 | 10,000자 | trim 후 길이 |
| 파일 추출 본문 | 50자 | 10,000자 | 추출 직후 백엔드에서만 검증 |
| JD(`jdText`) | 50자 | 10,000자 | trim 후 길이 |

- 현행 백엔드 상수: `DiagnoseService.MIN_RESUME_LENGTH=50` / `MAX_RESUME_LENGTH=10_000`, `MatchPreviewService.MIN_JD_LENGTH=50` / `MAX_JD_LENGTH=10_000`.
- 현행 프론트 상수: `useDiagnose.validateResumeText`(50/10,000), `useMatchPreview.validateJdText`(50/10,000).
- 본 spec은 이 값을 정본으로 고정하며 변경하지 않는다.

## 실패 응답 계약 (기존 `ErrorCode` 재사용, 신규 없음)

모든 실패는 `400 Bad Request` + `ApiResponse` 에러 형태로 반환한다.

| 상황 | ErrorCode | 메시지(현행) |
| --- | --- | --- |
| 이력서 빈 값 | `EMPTY_RESUME` | 이력서 내용을 입력해주세요. |
| 이력서/추출 본문 50자 미만 | `TEXT_TOO_SHORT` | 이력서 내용이 너무 짧습니다. 최소 50자 이상 입력해주세요. |
| 이력서/추출 본문 10,000자 초과 | `TEXT_TOO_LONG` | 이력서 내용이 너무 깁니다. 10,000자 이내로 입력해주세요. |
| JD 빈 값 | `EMPTY_JD` | JD 내용을 입력해주세요. |
| JD 50자 미만 | `JD_TEXT_TOO_SHORT` | JD 내용이 너무 짧습니다. 핵심 자격요건이 드러나도록 더 입력해주세요. |
| JD 10,000자 초과 | `JD_TEXT_TOO_LONG` | JD 내용이 너무 깁니다. 핵심 본문만 정리해서 입력해주세요. |

## 백엔드 방어적 재검증 원칙

- 프론트 게이트 통과 여부와 무관하게, `DiagnoseService`·`MatchPreviewService`는 진입 시 위 기준으로 재검증한다(현행 동작 유지·보장).
- `POST /api/diagnose/file`은 추출 직후 본문 길이를 재검증한다(추출 본문이 기준 미만이면 `TEXT_TOO_SHORT`).
- 경계는 `Controller -> Service -> Repository/External API`를 유지하며, 검증은 서비스 계층 책임으로 둔다.

## 보안 원칙

- 비밀 키 등 민감정보는 서버에서만 처리하며 프론트에 저장·노출하지 않는다(기존 원칙 유지).
