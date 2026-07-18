# Service MVP 구현 계획

## 상태

- Feature Spec 상태: `active`
- 구현 상태: `in-progress`
- 구현 전제: 이 문서와 내부 티켓의 범위·계약·테스트 시나리오를 기준으로 Codex가 구현합니다.

## 내부 수직 티켓

### T1. Google OAuth 로그인과 보호 API 인증 경계

- 범위: Google OAuth/OIDC callback, state 검증, 내부 사용자·세션, 공통 인증 경계, 보호 API 차단, 인증 fake 테스트
- 의존성: 없음
- 완료 조건: AC-01, AC-01a, TC-01, TC-01a, TC-02 통과; secret/token 브라우저 비노출
- 상태: `completed`
- 검증: 백엔드 `GoogleAuthControllerTest`와 보호 API 인증 테스트, 프론트 `AuthGate.test.tsx` 및 보호 API `credentials: 'include'` 검증, 전체 lint/test/build 통과. T2 이후 티켓은 T1에서 만든 공통 인증 경계를 재사용합니다.
- 검증 결과: 백엔드 전체 테스트, 프론트 lint·22개 테스트·build, Docker 재빌드 후 health 및 비로그인 보호 API 401 검증을 완료했습니다.

### T2. 이력서·JD 입력과 저장 계약

- 범위: 기존 텍스트 추출/JD fetch 경계 연결, 입력 정규화, 분석 입력 스냅샷 모델·저장, 원본 파일 미보관
- 의존성: T1의 사용자 식별 경계
- 완료 조건: AC-02, AC-03; TC-03~TC-06 통과

### T3. 기존 AI 진단·JD 매칭 연결과 상태 저장

- 범위: 기존 AI provider 연결, `RUNNING/SUCCEEDED/FAILED`, 결과 정규화, 실패 이력 저장
- 의존성: T2
- 완료 조건: AC-04, AC-05; TC-03, TC-05, TC-07 통과

### T4. 분석 결과 저장과 이력 조회

- 범위: 사용자 소유권 필터, 목록/상세 API와 화면, 결과·실패 상태 표시
- 의존성: T3
- 완료 조건: AC-06; TC-08~TC-10 통과

### T5. 재시도·삭제와 사용자 데이터 제어

- 범위: snapshot 재사용 새 이력 생성, JD 재수집 금지, 즉시 영구 삭제, 확인 UI
- 의존성: T4
- 완료 조건: AC-07~AC-10; TC-11~TC-17 통과

## 공통 검증

- 백엔드: `cd backend && ./gradlew test`
- 프론트: `cd frontend && npm run lint`, `npm test`, `npm run build`, `npm run test:e2e`
- 문서: active spec 필수 문서, traceability, index 포인터, 링크 검증
- 외부 OAuth/Gemini/DB는 fake/stub 또는 격리된 테스트 경계로 검증하며 운영 secret을 테스트에 포함하지 않는다.
