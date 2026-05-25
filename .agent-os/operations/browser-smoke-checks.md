# 브라우저 스모크 체크

## 목적

브라우저 스모크 체크는 사용자가 가장 먼저 밟는 핵심 흐름이 깨지지 않았는지 빠르게 확인하는 얇은 검증입니다.

현재 스모크 체크는 1.5차 MVP 기준으로 **프론트 진입 가능 여부, 프론트 프록시, fixture 분석 응답, 업로드 오류 흐름**을 빠르게 확인하는 데 집중합니다.

## 현재 범위

### 현재 스모크 기준

1. 프론트 루트 페이지가 열린다.
2. 프론트 프록시를 통해 `/api/health`가 응답한다.
3. 짧은 이력서 입력은 `TEXT_TOO_SHORT`를 반환한다.
4. 정상 길이 이력서 입력은 fixture 결과를 반환한다.
5. PDF 업로드 성공 시 fixture 결과를 반환한다.
6. DOCX 업로드 성공 시 fixture 결과를 반환한다.
7. TXT 업로드는 `UNSUPPORTED_FILE_TYPE`를 반환한다.
8. 깨진 PDF 업로드는 `FILE_TEXT_EXTRACTION_FAILED`를 반환한다.
9. fixture가 없는 업로드는 `FIXTURE_NOT_FOUND`를 반환한다.

### Playwright 브라우저 smoke 기준

1. PDF 업로드 후 JD 직접 입력으로 매칭 리포트를 확인한다.
2. JD 링크 불러오기 성공 시 JD textarea가 자동 채워진다.
3. 자동 채움된 JD 본문으로 `JD 비교 미리보기`를 실행하면 매칭 리포트가 표시된다.
4. JD 링크 불러오기 실패 시 `JD 본문을 직접 붙여넣어 주세요.` 안내가 표시된다.
5. JD 링크 실패 후에도 기존 JD textarea 값이 유지되고 직접 입력으로 매칭 리포트를 확인할 수 있다.

## 실행 방식

기본 컨테이너 스모크 체크는 `docker compose`로 프론트/백엔드를 함께 띄운 뒤 프론트 진입점과 프록시 응답, 텍스트/파일 업로드 API 흐름을 검증하는 경량 스크립트로 운영한다.

Playwright smoke는 실제 외부 사이트와 Gemini를 호출하지 않고 route mock으로 화면 연결 흐름만 검증한다. CI 필수화는 별도 운영 PR에서 결정한다.

`ai-local` 수동 smoke는 사용자가 직접 설정한 로컬 `.env`와 Gemini API Key로 화면에서 실제 AI 결과를 확인하는 절차다. 이 검증은 CI에 포함하지 않고 `.agent-os/operations/gemini-local-test-policy.md`를 기준으로 수행한다.

실행 스크립트:

- [scripts/smoke-test.sh](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/scripts/smoke-test.sh)
- `cd frontend && npm run test:e2e`

## 로컬 실행 순서

```sh
docker compose up --build -d
./scripts/smoke-test.sh
docker compose down
```

기본 URL:

- 프론트: `http://localhost:5173`
- 백엔드: `http://localhost:8080`

## CI 적용 기준

- PR과 `main` push에서 컨테이너 기반 스모크 체크를 실행한다.
- 실패 시 PR은 머지하지 않는다.
- 실패 원인이 문서-구현 불일치면 spec 문서를 먼저 갱신한다.
- compose 기반 스모크 환경에서는 백엔드를 `fixture` 모드로 올린다.

## 향후 확장

- Playwright smoke를 CI 필수 체크로 승격
- 실제 브라우저 통합 smoke와 route mock smoke 분리
- 운영 배포용 Gemini 연동 검증은 별도 정책으로 분리
