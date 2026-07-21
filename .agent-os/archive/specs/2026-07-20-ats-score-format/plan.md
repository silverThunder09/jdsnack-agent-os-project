# ATS 점수·포맷 진단 구현 계획

## 상태

- Feature Spec 상태: `active`
- 구현 상태: `completed`

## 내부 수직 티켓

### T1. ATS 정적 진단 API와 결과 화면

- 범위: 결정론적 ATS 계산 서비스·보호 API·프론트 서비스/hook·결과 패널·Markdown 내보내기·기능 테스트
- 의존성: 기존 인증·이력서 추출·JD 검증 흐름
- 완료 조건: AC-01~AC-09, TC-01~TC-10
- 상태: `completed`

## 공통 검증

- 백엔드: `cd backend && ./gradlew test`
- 프론트: `cd frontend && npm run lint`, `npm test`, `npm run build`, `npm run test:e2e`
- 문서: active spec 필수 문서·traceability·index 포인터·링크 검증
- 운영: `docker compose -f compose.local.yaml up -d --build`, 컨테이너 상태, `GET /api/health`, smoke test
