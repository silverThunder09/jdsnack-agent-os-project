# RocketPunch JD source adapter 테스트 시나리오

테스트는 외부 서비스 실호출 대신 fixture, fake, stub, 주입 가능한 client를 우선 사용합니다.

## TC-01

- 시나리오: 정상 fixture
- 기대: 성공·실패·권한·경계 조건이 명시된 계약에 맞게 처리됩니다.

## TC-02

- 시나리오: 빈 본문
- 기대: 성공·실패·권한·경계 조건이 명시된 계약에 맞게 처리됩니다.

## TC-03

- 시나리오: 추천 콘텐츠 오탐
- 기대: 성공·실패·권한·경계 조건이 명시된 계약에 맞게 처리됩니다.

## TC-04

- 시나리오: SSRF·redirect 차단
- 기대: 성공·실패·권한·경계 조건이 명시된 계약에 맞게 처리됩니다.

## TC-05

- 시나리오: 기존 source 회귀
- 기대: 성공·실패·권한·경계 조건이 명시된 계약에 맞게 처리됩니다.

## TC-06

- 시나리오: canonical mapping
- 기대: 성공·실패·권한·경계 조건이 명시된 계약에 맞게 처리됩니다.

## 검증 명령

- 백엔드 영향: `cd backend && ./gradlew test`
- 프론트 영향: `cd frontend && npm run lint && npm test && npm run build`
- 통합 영향: `npm run test:e2e` 또는 해당 spec의 compose 검증 명령
