# 컨테이너 워크플로우

## 목적

JDSnack은 로컬 실행과 배포 환경 차이를 줄이기 위해 Dockerfile 기반 컨테이너 흐름을 사용합니다.

최종 배포 전략은 `frontend`, `backend` **분리 컨테이너형**입니다.

## 현재 기준

- 백엔드 Dockerfile: `backend/Dockerfile`
- 프론트 Dockerfile: `frontend/Dockerfile`
- 로컬 통합 실행 파일: `compose.yaml`
- 컨테이너 검증 워크플로우: `.github/workflows/container.yml`
- 운영 배포 단위: `frontend` 컨테이너 + `backend` 컨테이너
- 실행 포트: `8080`
- 프론트 포트: `5173`
- 헬스체크: `GET /api/health`
- 외부 AI 비밀값: 1차 MVP에서는 없음
- compose 기본 진단 모드: `fixture`

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

프론트와 백엔드를 함께 확인할 때:

```sh
docker compose up --build
```

기본 접속 주소:

- 프론트: `http://localhost:5173`
- 백엔드: `http://localhost:8080`
- 헬스체크: `http://localhost:8080/api/health`

## GitHub Actions 흐름

- PR에서는 문서 하네스, 백엔드 테스트, 컨테이너 빌드와 `/api/health` 검증을 함께 실행합니다.
- PR에서는 `docker compose` 기반 스모크 테스트로 프론트 프록시, `POST /api/diagnose`, `POST /api/diagnose/file` 흐름도 함께 확인합니다.
- `main` 반영 후 모든 push에서도 같은 컨테이너 검증을 다시 실행합니다.
- 컨테이너 빌드 실패 시 PR 실패 Issue와 같은 형식으로 Issue를 생성합니다.

## 운영 원칙

- 프론트는 정적 자산과 사용자 진입점을 담당한다.
- 백엔드는 API와 이후 외부 AI 연동 경계를 담당한다.
- 운영 환경에서는 reverse proxy 또는 ingress로 두 컨테이너를 묶는다.
- CI와 로컬 검증은 `compose.yaml` 기준으로 맞춘다.

## 2차 확장

- 외부 AI 연동 시 서버 비밀값 주입과 로그 정책 검증
- reverse proxy 캐시/압축 정책 고도화
- 필요 시 `frontend`, `backend` 외 별도 gateway 또는 worker 컨테이너 추가
