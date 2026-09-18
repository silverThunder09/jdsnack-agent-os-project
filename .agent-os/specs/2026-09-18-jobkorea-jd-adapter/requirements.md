## 요구사항

JobKorea 공고 링크를 기존 공통 JD fetch 경계(`POST /api/jd/fetch` → `JdFetchService` → `JdHtmlExtractor`/`JdCandidateSelector`)에 두 번째 출처로 얹는다. 새 추상화·새 endpoint·새 error code는 만들지 않고 사람인 어댑터와 같은 계약을 따른다. 출처별 격리 근거는 [ADR-016](../../adr/adr-016-jd-source-adapter.md)이다.

- REQ-01: 호스트 allowlist에 `www.jobkorea.co.kr`와 `jobkorea.co.kr`를 추가한다. 사람인과 동일하게 host 기준으로만 판정하고 path·query 형태는 전제하지 않는다. 그 외 호스트는 기존 `JD_FETCH_UNSUPPORTED_SOURCE` 계약을 유지한다.
- REQ-02: JobKorea 성공 응답은 `sourceSite`를 `jobkorea`, `fetchMode`를 `static-html`로 반환하고 `sourceUrl`은 요청 URL을 그대로 보존한다. `JdFetchResponse` 필드 구성은 변경하지 않는다.
- REQ-03: JobKorea 후보 selector와 noise 규칙은 저장소에 커밋된 fixture(`backend/src/test/resources/jd/fixtures/jobkorea-*.html`)에서 관찰되는 구조만 근거로 정의한다. fixture로 재현되지 않는 selector는 추가하지 않으며, 실제 DOM이 fixture와 다르다고 확인되면 fixture와 selector를 함께 갱신하는 후속 변경으로 처리한다. 최소 fixture 집합은 정상 공고, noise 포함 공고, 본문 부족 페이지, 오류/차단 안내 페이지 네 종류다.
- REQ-04: 광고·추천공고·유사공고·네비게이션·헤더·푸터·지원 버튼 같은 비-JD 블록은 본문에서 제거한다. 제거 규칙은 공통 `NOISE_SELECTORS`/`NOISE_HINTS`를 우선 재사용하고, fixture로 증명되는 JobKorea 고유 blocker만 출처 전용 목록으로 분리한다.
- REQ-05: SSRF·리소스 한도는 공통 정책을 그대로 적용한다. `http`/`https`만 허용, loopback·사설·링크로컬·`0.0.0.0/8` IP와 `localhost` 계열은 `INVALID_JD_URL`로 차단, 요청 timeout 15초, 응답 본문 1,000,000자 상한, redirect 이후 최종 호스트도 allowlist를 만족해야 한다. JobKorea 전용 우회 경로는 두지 않는다.
- REQ-06: 실패는 기존 error code로만 표현한다. URL 형식·scheme·차단 호스트는 `INVALID_JD_URL`(400), 비-allowlist 호스트·본문 후보 없음·오류 페이지·fake success는 `JD_FETCH_UNSUPPORTED_SOURCE`(422), 추출 본문 50자 미만은 `JD_FETCH_EMPTY_CONTENT`(422), 비-2xx 응답·본문 초과·네트워크 오류는 `JD_FETCH_FAILED`(502)다.
- REQ-07: 모든 수용 기준은 fixture와 mock `HttpClient`로 검증 가능해야 한다. 구현·테스트 어느 경로도 JobKorea 실서비스를 호출하지 않고, 로그인·세션·API key 같은 인증정보를 사용하지 않는다.
- REQ-08: 분석 이력의 출처 식별을 사람인과 일관되게 유지한다. `JdInputType`에 `JOBKOREA_URL`을 추가(기존 `SARAMIN_URL` 값과 저장된 행은 그대로 유지, `jd_input_type`은 `VARCHAR(32)`이므로 migration 불필요)하고, URL 입력 타입에서 `sourceUrl`·`sourceSite`는 서버 fetch 응답 값을 정본으로 저장한다. 클라이언트가 보낸 `sourceSite`가 다르면 서버 값으로 대체한다.
- REQ-09: 프론트는 JD 링크의 host로 `inputType`과 `sourceSite`를 판별한다. 사람인 호스트는 `SARAMIN_URL`/`saramin`, JobKorea 호스트는 `JOBKOREA_URL`/`jobkorea`, 그 외는 `TEXT`/`null`로 보낸다. 지원 사이트 안내 문구에 JobKorea를 포함하고 API 호출은 `frontend/src/services/`만 담당한다.

## 범위 제외

아래는 이번 Spec의 범위가 아니며 구현·테스트·문서에서 다루지 않는다.

- JobKorea 실서비스 라이브 호출(fixture/mock 검증만 사용)
- 봇 탐지 회피·rate-limit 우회 등 크롤링 우회 기법
- 로그인·세션·API key 등 인증정보 처리
- 프론트엔드에서의 비밀값 입력·저장
- RocketPunch 등 다른 채용 플랫폼 어댑터
- 다중 플랫폼 공통 수집 추상화 재설계(JobKorea 하나로 한정)
- Redis·비동기 worker 큐 처리
- 결제·요금제 기능
- 이미지 OCR fallback 경로 확장

Controller → Service → Repository/External API 경계와 [완료 정의](../../standards/definition-of-done.md)를 지키며, 수집 흐름 전제는 [통합 아키텍처](../../../docs/architecture/integration-architecture.md)를 따른다.
