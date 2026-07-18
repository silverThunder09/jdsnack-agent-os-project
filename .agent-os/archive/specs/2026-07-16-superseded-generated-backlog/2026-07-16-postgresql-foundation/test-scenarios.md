# PostgreSQL 서비스 기반과 마이그레이션 테스트 시나리오

테스트는 외부 서비스 실호출 대신 fixture, fake, stub, 주입 가능한 client를 우선 사용합니다.

## TC-01

- 시나리오: 정상 PostgreSQL 연결에서 health readiness 성공
- 기대: 성공·실패·권한·경계 조건이 명시된 계약에 맞게 처리됩니다.

## TC-02

- 시나리오: DB 포트 중단에서 readiness 실패
- 기대: 성공·실패·권한·경계 조건이 명시된 계약에 맞게 처리됩니다.

## TC-03

- 시나리오: migration 최초 실행·재실행
- 기대: 성공·실패·권한·경계 조건이 명시된 계약에 맞게 처리됩니다.

## TC-04

- 시나리오: H2 fixture 테스트 회귀
- 기대: 성공·실패·권한·경계 조건이 명시된 계약에 맞게 처리됩니다.

## TC-05

- 시나리오: Compose 통합 테스트
- 기대: 성공·실패·권한·경계 조건이 명시된 계약에 맞게 처리됩니다.

## 검증 명령

- 백엔드 영향: `cd backend && ./gradlew test`
- 프론트 영향: `cd frontend && npm run lint && npm test && npm run build`
- 통합 영향: `npm run test:e2e` 또는 해당 spec의 compose 검증 명령
