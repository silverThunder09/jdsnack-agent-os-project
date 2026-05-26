# JD 링크 to AI 매칭 안정화 테스트 시나리오

## `TC-01` JD 링크 성공 후 textarea 자동 채움

- 대응 AC: `AC-01`
- 절차:
  - 이력서를 준비한다.
  - JD 링크를 입력한다.
  - `링크로 JD 불러오기`를 누른다.
- 기대 결과:
  - `POST /api/jd/fetch`가 호출된다.
  - 성공 응답의 `jdText`가 JD textarea에 반영된다.

## `TC-02` 자동 채움 후 JD 매칭 리포트 표시

- 대응 AC: `AC-02`
- 절차:
  - `TC-01` 상태에서 `JD 비교 미리보기`를 누른다.
- 기대 결과:
  - `POST /api/match/preview`가 호출된다.
  - 매칭 점수, 요약, 강점, 보완 포인트, 개선 제안이 표시된다.

## `TC-03` JD 링크 실패 후 직접 입력 복구

- 대응 AC: `AC-03`
- 절차:
  - 실패하는 JD 링크를 입력한다.
  - `링크로 JD 불러오기`를 누른다.
  - JD 본문을 직접 입력한다.
  - `JD 비교 미리보기`를 누른다.
- 기대 결과:
  - 실패 안내에 `JD 본문을 직접 붙여넣어 주세요.`가 포함된다.
  - 직접 입력 후 매칭 요청이 가능하다.

## `TC-04` 기존 JD textarea 값 보존

- 대응 AC: `AC-03`
- 절차:
  - JD textarea에 값을 입력한다.
  - 실패하는 JD 링크 수집을 시도한다.
- 기대 결과:
  - 기존 JD textarea 값이 지워지지 않는다.

## `TC-05` PDF/DOCX 이력서 분석 후 JD 매칭

- 대응 AC: `AC-04`
- 절차:
  - PDF 또는 DOCX 이력서를 업로드해 분석한다.
  - JD 링크 수집 또는 직접 입력으로 JD 본문을 준비한다.
  - `JD 비교 미리보기`를 누른다.
- 기대 결과:
  - 분석 성공 응답의 `sourceText`가 resume source로 사용된다.
  - 매칭 리포트가 표시된다.

## `TC-06` 범위 제외 확인

- 대응 AC: `AC-05`
- 절차:
  - 변경 파일과 구현 범위를 확인한다.
- 기대 결과:
  - 새 API, 외부 사이트 확장, 브라우저 렌더링 수집, 로그인 우회, anti-bot 우회가 포함되지 않는다.

## `TC-07` 브라우저 기준 JD 링크 성공 smoke

- 대응 AC: `AC-01`, `AC-02`
- 절차:
  - 브라우저에서 PDF 이력서를 업로드해 분석한다.
  - JD 링크를 입력하고 `링크로 JD 불러오기`를 누른다.
  - 자동 채움된 JD 본문으로 `JD 비교 미리보기`를 누른다.
- 기대 결과:
  - JD textarea에 수집된 본문이 표시된다.
  - 매칭 점수와 리포트가 화면에 표시된다.

## `TC-08` 브라우저 기준 JD 링크 실패 복구 smoke

- 대응 AC: `AC-03`
- 절차:
  - 브라우저에서 PDF 이력서를 업로드해 분석한다.
  - JD 본문을 직접 입력한다.
  - 실패하는 JD 링크로 `링크로 JD 불러오기`를 누른다.
  - 기존 JD 본문으로 `JD 비교 미리보기`를 누른다.
- 기대 결과:
  - 실패 안내에 `JD 본문을 직접 붙여넣어 주세요.`가 표시된다.
  - 기존 JD textarea 값이 유지된다.
  - 직접 입력한 JD 본문으로 매칭 리포트가 표시된다.

## `TC-09` ai-local 이력서 분석 수동 검증

- 대응 AC: `AC-04`
- 절차:
  - 사용자가 직접 로컬 `.env`에 `GEMINI_API_KEY`를 설정한다.
  - `JDSNACK_DIAGNOSIS_MODE=ai-local`로 화면을 실행한다.
  - 이력서 텍스트 입력 또는 PDF/DOCX 업로드 후 진단을 요청한다.
- 기대 결과:
  - 실제 AI 분석 결과가 점수, 요약, 강점, 보완 포인트로 표시된다.
  - 로그에 API Key와 Gemini 원문 전체 응답이 노출되지 않는다.

## `TC-10` ai-local JD 매칭 수동 검증

- 대응 AC: `AC-01`, `AC-02`
- 절차:
  - `TC-09` 상태에서 JD 본문을 직접 입력하거나 JD 링크를 불러온다.
  - `JD 비교 미리보기`를 실행한다.
- 기대 결과:
  - 실제 AI 매칭 리포트가 매칭 점수, 요약, 강점, 보완 포인트, 개선 제안으로 표시된다.
  - CI나 Playwright route mock 없이 로컬 수동 검증으로만 수행된다.

## `TC-11` ai-local 키 누락 수동 검증

- 대응 AC: `AC-04`
- 절차:
  - `GEMINI_API_KEY` 없이 `ai-local` 화면 검증을 시도한다.
  - 이력서 분석 또는 JD 매칭을 요청한다.
- 기대 결과:
  - 키 누락 안내가 표시된다.
  - 키 누락은 보안 실패가 아니라 정상적인 설정 실패로 판단한다.

## `TC-12` 로컬 build compose 검증

- 대응 AC: `AC-05`
- 절차:
  - `docker compose -f compose.local.yaml config --no-env-resolution`를 실행한다.
  - PR 컨테이너 smoke에서 `compose.local.yaml`로 서비스를 올린다.
- 기대 결과:
  - backend/frontend가 `build:` 기준으로 구성된다.
  - PR 검증은 registry image pull 없이 로컬 소스 빌드로 수행된다.

## `TC-13` 배포 pull compose 검증

- 대응 AC: `AC-05`
- 절차:
  - `docker compose -f compose.prod.yaml config --no-env-resolution`를 실행한다.
  - main 반영 후 push된 이미지 태그로 `docker compose -f compose.prod.yaml pull`을 실행한다.
- 기대 결과:
  - backend/frontend가 `image:` 기준으로 구성된다.
  - `compose.prod.yaml`에는 `build:`가 없다.
  - `JDSNACK_IMAGE_TAG`로 `latest` 또는 `<git-sha>` 이미지를 선택할 수 있다.
