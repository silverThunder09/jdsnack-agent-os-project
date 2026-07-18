# PostgreSQL 서비스 기반과 마이그레이션 수용 기준

## AC-01

- 로컬 Compose에서 PostgreSQL이 기동되고 backend가 연결된다.

## AC-02

- migration을 두 번 실행해도 실패하거나 중복 객체를 만들지 않는다.

## AC-03

- DB 중단 시 health readiness가 실패하고 거짓 성공을 반환하지 않는다.

## AC-04

- 기존 backend·frontend 테스트가 통과한다.

## 완료 조건

- 모든 AC가 테스트 결과와 연결됩니다.
- 문서·코드·테스트·CI 결과가 일치합니다.
