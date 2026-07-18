# 비동기 분석 worker와 재개 상태 수용 기준

## AC-01

- job 생성 후 상태가 queued→running→succeeded/failed로 이동한다.

## AC-02

- worker 재시작 후 저장된 상태에서 재개한다.

## AC-03

- lock 만료 시 단 하나의 worker만 결과를 확정한다.

## AC-04

- 필수 dependency 중단 시 거짓 성공이 없다.

## AC-05

- 최종 결과가 한 번만 저장된다.

## 완료 조건

- 모든 AC가 테스트 결과와 연결됩니다.
- 문서·코드·테스트·CI 결과가 일치합니다.
