# Frontend

JDSnack 1차 MVP React 프론트엔드입니다.

## 현재 구현 범위

- 이력서 `textarea` 입력
- 공백 제외 글자 수 표시
- 클라이언트 입력 검증
- `/api/diagnose` 호출
- `loading / not-enabled / error` 상태 렌더링
- LocalStorage 임시 저장

## 실행 명령

```bash
npm install
npm run dev
```

기본 개발 서버는 `/api` 요청을 `http://localhost:8080`으로 프록시합니다.

## 테스트 명령

```bash
npm run lint
npm run test
npm run build
```

## 디렉토리 구조

```text
src/
├── components/
├── hooks/
├── services/
├── test/
└── types/
```
