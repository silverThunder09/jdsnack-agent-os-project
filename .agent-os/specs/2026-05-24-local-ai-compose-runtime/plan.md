# 로컬 AI Compose 런타임 계획

## Summary

로컬 통합 실행의 기본 백엔드 모드를 fixture에서 `ai-local`로 전환한다. `.env`는 로컬 전용으로 참조만 하고, 실제 값은 읽거나 커밋하지 않는다.

## 변경 범위

- `compose.yaml` 백엔드 모드 전환
- 선택적 `.env` 참조
- README 실행 안내 갱신
- 활성 spec 최신화
- compose 검증은 비밀값이 출력되지 않도록 `--no-interpolate`를 사용

## 제외 범위

- Gemini 프롬프트 수정
- 토큰 사용량 로깅
- 이력서 길이 제한 변경
- ResultPanel UI 고도화
- 운영 배포 자동화
