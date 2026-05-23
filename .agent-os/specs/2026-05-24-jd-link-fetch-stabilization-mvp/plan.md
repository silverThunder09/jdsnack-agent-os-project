# JD 링크 수집 안정화 MVP 계획

## Summary

`/api/jd/fetch`의 다음 목표는 단순 HTML 수집이 아니라, 사람인 공고에서 실제 JD 본문을 추출하거나 실패를 명확히 반환하는 것이다.

## 작업 방향

- 사람인 selector와 본문 후보 우선순위를 정의한다.
- 개인정보/푸터/추천공고/광고 문구를 본문으로 오탐하지 않게 한다.
- 본문 품질 기준 미달 시 `success: true`를 반환하지 않는다.
- 실제 외부 호출 테스트보다 HTML fixture/mock 테스트를 우선한다.

## 개발 쓰레드 전달 항목

- `JdHtmlExtractor` 후보 선택 점수 개선
- 사람인 공고 HTML fixture 추가
- boilerplate 필터링 테스트 추가
- private/local/metadata URL 차단 검증
- 실패 코드 매핑 확인

## 제외 항목

- 잡코리아 등 추가 사이트 지원
- 프론트 UI 대규모 변경
- AI 매칭 품질 개선
- 운영 크롤링 파이프라인
