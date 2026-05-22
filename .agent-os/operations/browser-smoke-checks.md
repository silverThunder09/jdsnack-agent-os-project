# 브라우저 스모크 체크

## 목적

브라우저 스모크 체크는 사용자가 가장 먼저 밟는 핵심 흐름이 깨지지 않았는지 빠르게 확인하는 얇은 검증입니다.

JDSnack 1차 MVP에서는 아직 실제 AI 분석이 없으므로, 스모크 체크는 **프론트 진입 가능 여부, 프론트 프록시, 백엔드 검증 응답, 준비중 응답**을 확인하는 데 집중합니다.

## 현재 범위

### 1차 MVP 스모크 기준

1. 프론트 루트 페이지가 열린다.
2. 프론트 프록시를 통해 `/api/health`가 응답한다.
3. 짧은 이력서 입력은 `TEXT_TOO_SHORT`를 반환한다.
4. 정상 길이 이력서 입력은 `AI_ANALYSIS_NOT_ENABLED`를 반환한다.

### 1.5차 MVP 확장 예정

1. PDF 업로드 성공
2. DOCX 업로드 성공
3. fixture 결과 카드 렌더링
4. `FIXTURE_NOT_FOUND` 안내 문구

## 실행 방식

현재 스모크 체크는 Playwright 같은 전용 브라우저 러너 대신, `docker compose`로 프론트/백엔드를 함께 띄운 뒤 프론트 진입점과 프록시 응답을 검증하는 경량 스크립트로 운영한다.

실행 스크립트:

- [scripts/smoke-test.sh](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/scripts/smoke-test.sh)

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

## 향후 확장

- 1.5차 MVP 구현 후 파일 업로드 스모크 시나리오 추가
- 2차 MVP에서 실제 브라우저 러너 도입 검토
- 결과 카드의 점수/요약/피드백 시각 요소 검증 추가

