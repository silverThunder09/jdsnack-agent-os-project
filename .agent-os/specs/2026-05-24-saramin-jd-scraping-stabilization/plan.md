# 사람인 JD 수집 안정화 계획

## Summary

사람인 JD 링크 수집에서 `200 OK`가 나와도 개인정보 안내문이나 AI매치 홍보문이 `jdText`로 반환되는 가짜 성공을 막는다. 이번 작업은 개발 전 기준을 고정하는 문서 작업이며, 실제 구현은 개발 쓰레드의 `Backend Engineer`가 수행한다.

## 변경 범위

- 새 활성 spec 추가
- 기존 활성 spec archive 이동
- `AGENTS.md`와 `standards/index.yml` 활성 spec 갱신
- `POST /api/jd/fetch` 성공/실패 기준 문서화
- 사람인 fixture 기반 개발/검증 기준 문서화

## 구현 지침

- 기존 `JdFetchService`, `JdHtmlExtractor`를 개선 대상으로 삼는다.
- Jsoup 기반 정적 HTML 파싱을 유지한다.
- 사람인 selector 후보는 `recruit_detail`, `jv_cont`, `wrap_jv_cont`, `dt/dd` 계열을 기준으로 보강한다.
- fallback은 텍스트 밀도 기반으로 하되 개인정보, AI매치, 추천공고, 푸터성 문구는 성공 후보에서 제외한다.

## 제외 범위

- 백엔드 코드 직접 수정
- 프론트엔드 UI 변경
- 브라우저 렌더링
- 로그인 우회
- anti-bot 우회
- 잡코리아, 원티드, 기타 플랫폼 자동 수집
