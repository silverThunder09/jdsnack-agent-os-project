# JDSnack 용어집

이 문서는 JDSnack을 기획, 개발, 검증할 때 같은 단어를 같은 의미로 쓰기 위한 기준입니다.

## 제품/도메인

- `JDSnack`: 개발자 이력서와 JD를 AI로 비교 분석해 개선 피드백과 매칭 인사이트를 제공하는 서비스입니다.
- `JD`: Job Description의 약자입니다. 채용공고 또는 직무기술서를 뜻합니다.
- `Resume`: 사용자가 직접 입력하거나 PDF/DOCX로 업로드하는 이력서 원문입니다.
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
- `Active Spec`: 현재 작업 기준이 되는 최신 spec입니다. 기본적으로 하나만 유지합니다.
- `Archived Spec`: 과거 기획 보관 문서입니다. 사용자가 요청하거나 활성 spec이 참조할 때만 확인합니다.
- `REQ`: 요구사항 ID입니다.
- `AC`: Acceptance Criteria의 약자입니다. 수용 기준을 뜻합니다.
- `TC`: Test Case의 약자입니다. 테스트 시나리오를 뜻합니다.
- `Traceability`: `REQ -> AC -> TC -> 계약/구현` 연결을 추적하는 문서입니다.

## 에이전트/운영

- `Handoff`: 다음 에이전트가 이어받기 위한 작업 인수인계 문서입니다.
- `Review Gate`: PR이 범위, 문서, CI, 리뷰 기준을 통과했는지 확인하는 자체 검증 절차입니다.
- `Spec Steward`: 요구사항, 수용 기준, API/UI 계약, traceability를 정리하는 계획 담당 에이전트입니다.
- `Backend Engineer`: 백엔드 구현과 백엔드 테스트를 담당하는 개발 에이전트입니다.
- `Frontend Engineer`: 프론트엔드 구현과 프론트 테스트를 담당하는 개발 에이전트입니다.
- `QA Reviewer`: 문서, 구현, 테스트의 불일치를 검증하는 검증 에이전트입니다.
- `Security Reviewer`: 비밀값, 외부 API, 로그, 개인정보 정책을 검토하는 보안 에이전트입니다.
- `DevOps Steward`: CI/CD, Docker, compose, 배포 흐름을 관리하는 운영 에이전트입니다.
- `Release Captain`: PR, 머지, 릴리즈 완료 조건을 확인하는 릴리즈 에이전트입니다.
