# 사람인 JD 이미지 OCR 폴백 계획

## Summary

사람인 채용공고 중 JD 본문을 이미지 한 장으로 올린 공고는 현재 텍스트 스크래핑이 빈 결과로 실패한다. 본 기능은 **기존 텍스트 추출이 끝내 실패할 때만** JD 본문 이미지를 탐지·다운로드해 Gemini 비전(`gemini-2.5-flash` 멀티모달, `inlineData` 입력)으로 OCR하고, 결과를 JD 텍스트로 쓰는 **폴백**을 `JdFetchService`에 추가한다. 새 의존성·새 엔드포인트·새 에러 코드는 없고, 응답 `fetchMode`에 신규 값 `image-ocr`만 추가한다. SSRF 방어(기존 `isUnsafeHost` 재사용 + 신뢰 호스트 allowlist + 크기/타입/타임아웃)는 필수다. 범위는 사람인만이며 프론트는 변경하지 않는다. 구현은 Codex가 담당.

## 변경 범위

- 문서: 새 active spec 추가, 직전 `2026-06-18-sentence-editing` spec archive 이동, `.agent-os/standards/index.yml`·`AGENTS.md` 활성 spec 포인터 갱신(이 문서 PR).
- 구현(백엔드, `com.jdsnack.jd` 패키지):
  - `JdImageOcr` — OCR 추상화 인터페이스(입력 이미지 바이트+MIME, 출력 텍스트). 테스트 fake/stub 주입 가능.
  - `GeminiJdImageOcr` — Gemini 비전 구현체. `GeminiMatchPreviewProvider`(URI 빌드 약 90~97행, 키/모델 주입 약 33~59행, HTTP 호출·상태 검사 약 61~88행, 응답 텍스트 경로 약 148~160행) 패턴 복제. 요청은 `contents:[{parts:[{inlineData:{mimeType,data}}, {text}]}]`. 키 공백이면 OCR 미수행을 표현.
  - `JdFetchService` 폴백 단계 추가(`fetch()` 마지막 단계): 텍스트 추출(+`fetchSaraminFallback`) 실패 + 사람인일 때 이미 받은 상세 HTML에서 JD 이미지 탐지→다운로드(SSRF 검증)→`JdImageOcr` 호출→성공 시 `JdFetchResponse(fetchMode="image-ocr")`. 실패/키 없음/후보 없음이면 기존 에러 그대로.
  - 이미지 탐지·다운로드 헬퍼: 사람인 상세 컨테이너 `img` 후보 선정, 상대경로 `URI.resolve`, 호스트 안전성(`isUnsafeHost` 재사용)·신뢰 호스트 allowlist·크기 상한(8MB)·`Content-Type` `image/*`·타임아웃 검증.
  - `fetchMode` 상수 정리: OCR 경로용 `image-ocr` 값 도입(기존 `JdHtmlExtractor.FETCH_MODE="static-html"`은 불변).
- 구현(프론트): **없음**(REQ-07, `ui-spec.md`).

## 구현 지침

- OCR 폴백은 텍스트 추출이 끝내 실패한 사람인 공고에서만, `fetch()`의 마지막 단계로 **한 번**만 시도한다. 텍스트 성공 시 OCR을 호출하지 않는다(추가 비용 0).
- SSRF: 이미지 다운로드 호스트는 반드시 `isUnsafeHost` 규칙으로 검증하고 신뢰 이미지 호스트 allowlist(사람인 도메인 서브도메인 + 사람인 이미지 CDN)만 허용한다. 크기 상한 8MB·`image/*`·타임아웃·리다이렉트 최종 호스트 재검증을 강제한다.
- 테스트 격리: 단위·컨트롤러 테스트는 `JdImageOcr` fake 또는 주입 `HttpClient` 스텁으로 실제 Gemini 호출을 막는다(`JdFetchServiceTest`의 mock `HttpClient` 패턴, `GeminiMatchPreviewProvider` 테스트 감각 재사용).
- graceful fallback: 키 공백·후보 없음·allowlist 외·크기/타입 위반·OCR 실패·결과 미달은 모두 텍스트 추출이 던진 기존 에러로 수렴한다. 새 `ErrorCode` 금지.
- 검증: `cd backend && ./gradlew test`(신규 `GeminiJdImageOcrTest`·`JdFetchServiceTest` OCR 경로·`JdFetchControllerTest` 직렬화 추가), `cd frontend && npm run lint && npm test && npm run build && npm run test:e2e`(프론트 무변경 회귀).

## 제외 범위

- 사람인 외 사이트 OCR, 항상-OCR(텍스트 있어도 OCR), 첨부 PDF OCR, 다국어 번역, 다중 이미지 합성 OCR.
- 프론트 UI 변경(출처 배지 등), 새 `ErrorCode`, `ApiResponse<T>` 래퍼 변경, `POST /api/jd/fetch` 요청 스키마 변경.
- 이미지 탐지 휴리스틱·OCR 정확도 고도화(표/레이아웃 복원 등). 단일 본문 이미지 한 장 OCR로 한정.

## 컨테이너 운영 기준

- 로컬 개발/검증은 `compose.local.yaml`(또는 `npm run dev` + 백엔드 로컬) 기준. Gemini 비전 OCR 라이브 검증은 `.agent-os/operations/gemini-local-test-policy.md`를 따른다. 배포 영향 없음(새 의존성·새 엔드포인트 없음).

## 결정 사항 (확정 — 사용자 확정, Codex는 이대로 구현)

- **OCR 엔진**: Gemini 비전(`gemini-2.5-flash` 멀티모달, `inlineData`) **확정**. 새 의존성 없음.
- **트리거**: 텍스트 추출 실패 시에만 동작하는 **폴백** 확정. 텍스트 공고는 기존대로(추가 비용 0).
- **범위**: **사람인만** 확정. 사람인 외는 OCR 미시도.
- **이미지 선정**: 사람인 상세 컨테이너 내부 `img` 중 본문성 가장 높은 **단일 한 장** 확정. 다중 합성은 범위 밖.
- **SSRF**: `isUnsafeHost` 재사용 + 신뢰 이미지 호스트 allowlist + 크기 상한 **8MB** + `Content-Type` `image/*` + 타임아웃 확정.
- **OCR 추상화**: `JdImageOcr` 인터페이스 + `GeminiJdImageOcr` 구현 + 테스트 fake 주입 확정.
- **키 부재·실패**: graceful fallback 확정 — 기존 에러(`JD_FETCH_EMPTY_CONTENT`/`JD_FETCH_UNSUPPORTED_SOURCE`)로 수렴. **새 에러 코드 없음**.
- **응답**: 이미지 OCR 성공 시 `fetchMode = "image-ocr"`(신규 값) 확정. 필드 집합·엔드포인트·요청 스키마 불변.
- **프론트**: **무변경** 확정. 출처 표기는 범위 밖.
