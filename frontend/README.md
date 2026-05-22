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

`docker compose`로 함께 띄울 때는 `VITE_API_PROXY_TARGET=http://backend:8080`을 사용합니다.

## 로컬 통합 실행

루트 디렉토리에서 아래 명령으로 프론트와 백엔드를 함께 띄울 수 있습니다.

```bash
docker compose up --build
```

실행 후 접속 주소:

- 프론트: `http://localhost:5173`
- 백엔드: `http://localhost:8080`
- 헬스체크: `http://localhost:8080/api/health`

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
