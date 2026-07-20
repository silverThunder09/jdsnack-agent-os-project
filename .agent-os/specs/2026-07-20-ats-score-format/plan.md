# ATS 점수·포맷 진단 구현 계획

## 상태

- Feature Spec 상태: `active`
- 구현 상태: `in-progress`
- 구현 전제: 이 문서와 내부 티켓의 범위·계약·테스트 시나리오를 기준으로 Codex가 구현합니다. 계약 정본은 [api-spec.md](api-spec.md)·[ui-spec.md](ui-spec.md), 추적성은 [traceability.md](traceability.md)입니다.

## 내부 수직 티켓

각 티켓은 백엔드 필드 산출 → 프론트 패널 표시 → 테스트까지 이어지는 수직 슬라이스이며, T2·T3는 응답을 하위호환으로 확장하고 패널 섹션을 추가합니다.

### T1. ATS 엔드포인트와 파싱 안전성 진단 · 옵션 해금

- 범위: 신규 패키지 `com.jdsnack.ats`(`AtsPreviewController`/`AtsPreviewService`/`AtsPreviewRequest`/`AtsPreviewResponse`), `POST /api/ats/preview`, 매칭·문장과 동일한 검증·`ErrorCode` 재사용, stub/fixture 결정적 provider와 ai-local provider 골격, 파싱 안전성(`parsingWarnings`)과 종합 `atsScore`·`summary` 기준선 산출; 프론트 `ats` 옵션 `enabled: true` 해금, `ComingSoonPanel` → ATS 패널(파싱 안전성 섹션 + 점수 카드) 교체, `AtsPreviewResult` 타입·`previewAts` 서비스·ATS 전용 result state·호출 트리거 추가
- 의존성: 없음
- 완료 조건: AC-01, AC-02, AC-03 통과; AC-06(파싱 안전성 기준선 점수)·AC-07·AC-08 충족; TC-01, TC-02, TC-02a, TC-03, TC-06, TC-07(stub/fixture 결정성), TC-08 통과; 새 `ErrorCode` 없음, 비밀값 비노출
- 상태: `ready`

### T2. 구조 진단 (표준 섹션 유무·순서)

- 범위: `AtsPreviewResponse`에 `presentSections`/`missingSections`/`sectionOrderWarnings` 하위호환 추가, stub/fixture 표준 섹션 사전 대조 로직, ai-local 프롬프트·파싱 확장, `atsScore` 종합에 구조 차원 반영; ATS 패널에 구조 진단 섹션 추가
- 의존성: T1
- 완료 조건: AC-04 통과; AC-06 구조 차원 반영; TC-04 통과; 기존 필드·형태 불변(하위호환)
- 상태: `pending`

### T3. JD 대비 키워드 최적화

- 범위: `AtsPreviewResponse`에 `jdKeywordsCovered`/`jdKeywordsMissing` 하위호환 추가, 기존 토큰 추출 재사용해 상호 배타 분류, ai-local 프롬프트·파싱 확장, `atsScore` 종합에 키워드 차원 반영; ATS 패널에 키워드 최적화 섹션(`KeywordList`) 추가
- 의존성: T2
- 완료 조건: AC-05 통과; AC-06 키워드 차원 반영; TC-05 통과; covered/missing 상호 배타·빈 배열 보장
- 상태: `pending`

### T4. ai-local Gemini 프로바이더 완성 · 내보내기 · 회귀

- 범위: `GeminiAtsPreviewProvider`가 세 진단·점수를 모두 산출하도록 프롬프트·파싱 완성과 관대 처리 정책 확정, `buildResultMarkdown`에 ATS 섹션(점수·요약·세 진단) 추가, 3개 모드 전반 회귀
- 의존성: T3
- 완료 조건: AC-07(ai-local 관대 처리), AC-09 통과; TC-07(Gemini 관대 처리), TC-09 통과; 기존 `GEMINI_API_*` 정책 불변
- 상태: `pending`

## 공통 검증

- 백엔드: `cd backend && ./gradlew test` — ATS 3개 모드 컨트롤러/서비스 테스트 추가(stub/fixture 결정성·필드 계약, 검증 실패 기존 `ErrorCode`, 관대 처리)
- 프론트: `cd frontend && npm run lint`, `npm test`, `npm run build`, `npm run test:e2e` — ATS 옵션 해금·패널 렌더·내보내기 섹션 테스트 추가
- 문서: active spec 필수 문서, traceability, index 포인터, 링크 검증
- 외부 Gemini는 fixture/stub 또는 격리된 테스트 경계로 검증하며 운영 secret을 테스트에 포함하지 않는다(`ai-local` 실호출 검증은 [gemini-local-test-policy](../../operations/gemini-local-test-policy.md)를 따른다).
- `frontend/` 또는 `backend/` 코드 변경이므로 각 티켓 완료 시 Compose 재빌드·컨테이너/health 확인을 [definition-of-done](../../standards/definition-of-done.md) 기준으로 수행한다.

## 제외 범위

- 새 `ErrorCode`, `ApiResponse<T>` 래퍼 변경, 기존 매칭·문장·인터뷰 엔드포인트 계약 변경
- 원본 PDF/DOCX 바이너리 레이아웃 분석(추출된 텍스트만 대상)
- 형태소 분석기·임베딩 등 키워드 추출 알고리즘 고도화
- Analysis History 저장 스키마·저장 계약 변경(본 spec은 preview 계층만)
