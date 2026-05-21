# 컨테이너 워크플로우

## 목적

JDSnack은 로컬 실행과 배포 환경 차이를 줄이기 위해 Dockerfile 기반 컨테이너 흐름을 사용합니다.

1차 MVP에서는 먼저 백엔드 컨테이너 빌드를 고정하고, 프론트엔드가 생성되면 단일 서비스 컨테이너 또는 분리 컨테이너 전략을 다시 결정합니다.

## 현재 기준

- 백엔드 Dockerfile: `backend/Dockerfile`
- 컨테이너 검증 워크플로우: `.github/workflows/container.yml`
- 실행 포트: `8080`
- 헬스체크: `GET /api/health`
- 외부 AI 비밀값: 1차 MVP에서는 없음

## 컨테이너 빌드 조건

- 백엔드 테스트 통과
- `bootJar` 생성 가능
- `backend/Dockerfile` 존재
- 이미지 빌드 성공
- 컨테이너 기동 후 `/api/health` 응답 확인

## 로컬 명령 후보

```sh
docker build -f backend/Dockerfile -t jdsnack-backend:local backend
docker run --rm -p 8080:8080 jdsnack-backend:local
curl -i http://localhost:8080/api/health
```

## GitHub Actions 흐름

- PR에서는 백엔드 테스트와 문서 하네스를 우선 검증합니다.
- `main` 반영 후 컨테이너 빌드 검증을 실행합니다.
- 컨테이너 빌드 실패 시 PR 실패 Issue와 같은 형식으로 Issue를 생성합니다.

## 2차 확장

- 프론트엔드 빌드 결과물을 백엔드 정적 리소스로 포함하는 단일 컨테이너
- 또는 `backend`, `frontend` 분리 컨테이너와 reverse proxy 구성
- 외부 AI 연동 시 서버 비밀값 주입과 로그 정책 검증

