# JDSnack 용어집

이 문서는 JDSnack을 기획, 개발, 검증할 때 같은 단어를 같은 의미로 쓰기 위한 기준입니다.

## 제품/도메인

- `JDSnack`: 개발자 이력서와 JD를 AI로 비교 분석해 개선 피드백과 매칭 인사이트를 제공하는 서비스입니다.
- `JD`: Job Description의 약자입니다. 채용공고 또는 직무기술서를 뜻합니다.
- `Resume`: 사용자가 직접 입력하거나 PDF/DOCX로 업로드하는 이력서 원문입니다.
- `Analysis Input Snapshot`: 분석 요청 시 제출한 이력서 텍스트와 JD 입력을 결과에 연결해 보존한 사본입니다. PDF/DOCX 원본 파일은 텍스트 추출 뒤 보관하지 않으며, 이후 입력 변경은 과거 사본을 바꾸지 않습니다.
- `JD Match`: 이력서와 JD를 비교해 적합도, 강점, 부족한 역량, 개선 제안을 만드는 기능입니다.
- `Gap`: JD가 요구하지만 이력서에서 약하게 드러나는 역량 또는 경험입니다.

## JD 수집

- `JD Fetch`: JD URL에서 HTML을 가져오는 기능입니다.
- `JD Scraping`: 가져온 HTML에서 실제 채용공고 본문만 추출하는 과정입니다.
- `sourceSite`: JD URL의 출처 사이트입니다. 예: `saramin`.
- `fetchMode`: JD 본문 수집 방식입니다. 현재 기본값은 `static-html`입니다.
- `Fake Success`: `200 OK`가 반환됐지만 `jdText`가 실제 JD 본문이 아니라 개인정보, 푸터, 홍보문, 추천공고 문구인 상태입니다.

## 런타임 모드

- `Stub`: 실제 분석 없이 준비중 또는 고정 응답을 반환하는 안전 모드입니다.
- `Fixture`: 외부 API 없이 고정 샘플 데이터로 결과를 검증하는 테스트 모드입니다.
- `ai-local`: 로컬 서버의 환경변수 `GEMINI_API_KEY`를 사용해 Gemini를 실호출하는 개발 모드입니다.
- `googleTest`: 명시적으로 실행할 때만 Gemini 실호출을 검증하는 테스트 경로입니다.

## 문서 하네스

- `Agent OS`: 제품 방향, 기능 spec, 운영 규칙, 에이전트 규칙을 담는 프로젝트 문서 체계입니다.
- `Active Spec`: 현재 구현 대상 spec입니다. **정확히 1개**(`index.yml`의 `active_specs`)만 유지합니다.
- `Feature Spec`: 하나의 사용자 가치 흐름을 요구사항·계약·수용 기준·테스트·내부 티켓으로 고정한 구현 계약입니다.
- `Pending Spec`: 호환성을 위해 `index.yml`에 남긴 비어 있는 필드입니다. 미래 후보는 `spec-backlog.md`에서 관리합니다(승격 규칙 정본은 `standards/doc-lifecycle.md`).
- `Archived Spec`: 과거 기획 보관 문서입니다. 사용자가 요청하거나 활성 spec이 참조할 때만 확인합니다.
- `REQ`: 요구사항 ID입니다.
- `AC`: Acceptance Criteria의 약자입니다. 수용 기준을 뜻합니다.
- `TC`: Test Case의 약자입니다. 테스트 시나리오를 뜻합니다.
- `Traceability`: `REQ -> AC -> TC -> 계약/구현` 연결을 추적하는 문서입니다.
- `Service MVP`: 로그인부터 분석 결과 재조회·재시도·삭제까지 사용자가 완료할 수 있는 최소한의 서비스 가치 흐름입니다. 상세 범위·티켓 정의는 활성 spec `.agent-os/specs/2026-07-18-service-mvp/`가 정본입니다.
- `Analysis History`: 사용자의 분석 입력 사본, JD, AI 분석 결과 또는 실패 상태를 저장해 나중에 목록·상세로 다시 확인하는 기능입니다. 재시도는 기존 입력 사본을 재사용하고 결과는 기존 이력을 덮어쓰지 않고 새 이력으로 저장하며, 사용자가 삭제하면 해당 이력의 입력·JD·결과를 함께 즉시 영구 삭제합니다.
- `JD Source Adapter`: 사람인·JobKorea·RocketPunch처럼 출처별 JD 수집 차이를 공통 JD 계약으로 변환하는 경계입니다.

## 운영

- `Review Gate`: PR이 범위, 문서, CI, 리뷰 기준을 통과했는지 확인하는 자체 검증 절차입니다.
- `Planning Thread`: JDSnack의 단일 작업 스레드입니다. 계획, 변경, 검증 기록을 한 흐름에서 관리합니다.
- `Session Switch`: 주제가 바뀔 때 새 세션을 시작해 컨텍스트 오염을 줄이는 운영 방식입니다.
