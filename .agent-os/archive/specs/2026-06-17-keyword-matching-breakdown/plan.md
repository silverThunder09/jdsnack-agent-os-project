# 키워드 매칭 구조화 / 키워드 분석 옵션 해금 계획

## Summary

JD 적합도 매칭(`POST /api/match/preview`) 응답에 구조화된 키워드 브레이크다운(`matchedKeywords`/`partialKeywords`/`missingKeywords`)을 하위호환으로 추가하고, "준비중"이던 프론트 `keyword` 옵션을 해금해 결과 화면에 키워드 패널을 표시한다. 새 엔드포인트·새 ErrorCode·스키마 파괴 없이 기존 매칭 호출 1회를 재사용한다. `stub`/`fixture`/`ai-local` 모두 키워드 필드를 반환한다. 구현은 Codex가 담당.

## 변경 범위

- 문서: 새 active spec 추가, 직전 `2026-06-17-analysis-prevalidation-gate` spec archive 이동, `.agent-os/standards/index.yml`·`AGENTS.md` 활성 spec 포인터 갱신(이 문서 PR).
- 구현(백엔드):
  - `MatchPreviewResponse`에 키워드 필드 3개 추가(record).
  - `MatchPreviewService.buildPreview`에서 matched/missing(/partial) 구조화 산출(기존 `extractKeywords` 재사용, 기존 산문 산출 로직 불변).
  - `GeminiMatchPreviewProvider` 프롬프트 스키마·파싱에 키워드 배열 추가(키워드 필드는 관대 처리 권장).
- 구현(프론트):
  - `ANALYSIS_OPTIONS.keyword`를 `enabled: true`로 변경, 결과 화면 `keyword` 분기를 키워드 패널로 교체.
  - `MatchPreviewResult` 타입·`previewMatch` 매핑에 새 필드 추가.
  - `handleStartAnalysis`의 매칭 트리거 조건을 `jdMatch || keyword`로 확장.

## 구현 지침

- 응답 확장은 하위호환 추가만 한다(기존 필드 유지). 세 키워드 리스트는 항상 존재(빈 배열)·상호 배타.
- stub/fixture의 partial 판정은 `api-spec.md`의 권장안(권장 A: partial 빈 리스트)으로 단순하게 시작하고, 필요 시 별도 spec에서 고도화한다.
- Gemini 키워드 필드는 관대 처리(누락 시 빈 리스트, 성공 유지). 기존 필수 필드 검증·`GEMINI_API_RESPONSE_INVALID` 정책은 변경하지 않는다.
- 키워드 패널은 기존 `detail-card`/`detail-list-grid` 스타일을 재사용하고 서비스 계층을 통해서만 데이터를 받는다.
- 직전 spec의 통합 검증 게이트를 깨지 않는다(`keyword` 선택 시에도 게이트 통과 후 실행).
- 검증: 프론트 `npm run lint`/`npm test`/`npm run build`/`npm run test:e2e`, 백엔드 `./gradlew test`. 백엔드 3개 모드 컨트롤러 테스트(`MatchPreviewControllerTest`/`MatchPreviewFixtureModeControllerTest`/`MatchPreviewAiLocalModeControllerTest`)에 키워드 필드 검증을 추가하고, 프론트에 keyword 옵션 해금·패널 표시 테스트를 추가한다.

## 제외 범위

- 새 API 엔드포인트, 새 ErrorCode, `ApiResponse<T>` 래퍼 변경.
- 키워드 추출 알고리즘 고도화(형태소 분석기·임베딩 유사도). 토큰 기반 추출 위에서 분류 구조화만.
- 검증 임계값(50/10,000) 변경, JD 적합도 점수 계산식 변경.
- ATS·문장 첨삭 등 다른 "준비중" 옵션 해금.

## 컨테이너 운영 기준

- 로컬 개발/검증은 `compose.local.yaml`(또는 `npm run dev` + 백엔드 로컬) 기준. `ai-local` 모드 검증은 `gemini-local-test-policy.md`를 따른다. 배포 영향 없음.

## 결정 사항 (확정 — 메인 세션 확정, Codex는 이대로 구현)

- **stub/fixture의 partial**: **빈 리스트로 확정**(권장 A). 동의어 사전·형태소 분석기 없는 토큰 매칭에서 거짓 partial을 만들지 않는다. matched/missing만 정확히 제공. partial 근사 고도화는 별도 후속 spec.
- **keyword 단독 선택 동작**: 매칭은 호출하되 **키워드 패널만 표시**. JD 적합도 점수·강점·gap·제안 패널은 `jdMatch` 선택 시에만. **내보내기/인쇄 버튼은 성공 결과가 있으면(`jdMatch || keyword` 성공) 노출**해 키워드 단독 사용자도 결과를 내보낼 수 있게 한다.
- **Gemini 키워드 필드 검증**: **관대 처리 확정** — 누락/비배열이면 빈 리스트로 채우고 성공 유지. 기존 필수 필드 검증·`GEMINI_API_RESPONSE_INVALID` 정책은 불변.
- **항목 수 상한**: 현행 **`MAX_KEYWORDS=8` 재사용**(분류별 상한도 8).
- **내보내기 마크다운**: `buildResultMarkdown`에 **키워드 섹션 추가**(keyword 선택 시). 빈 분류는 "없음" 등으로 안전 처리.
- (확인 완료) stub/fixture는 둘 다 `MatchPreviewService.buildPreview`를 타고 AI_LOCAL만 Gemini로 분기한다. 매칭 트리거는 `jdMatch || keyword`.
