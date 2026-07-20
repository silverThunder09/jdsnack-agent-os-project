# 컨테이너 워크플로우

## 목적

JDSnack은 로컬 실행과 배포 환경 차이를 줄이기 위해 Dockerfile 기반 컨테이너 흐름을 사용합니다.

최종 배포 전략은 `frontend`, `backend` **분리 컨테이너형**입니다.

## 현재 기준

- 백엔드 Dockerfile: `backend/Dockerfile`
- 프론트 Dockerfile: `frontend/Dockerfile`
- 로컬 build compose: `compose.local.yaml`
- 배포 pull compose: `compose.prod.yaml`
- 호환용 기본 compose: `compose.yaml`
- 컨테이너 검증 워크플로우: `.github/workflows/container.yml`
- 운영 배포 단위: `frontend` 컨테이너 + `backend` 컨테이너
- 실행 포트: `8080`
- 프론트 포트: `5173`
- 헬스체크: `GET /api/health`
- 외부 AI 비밀값: `GEMINI_API_KEY`
- 로컬 compose 기본 진단 모드: `ai-local`

## Compose 분리 원칙

- 로컬 개발/검증은 `compose.local.yaml`에서 `build:`로 소스 이미지를 직접 빌드합니다.
- 배포/운영 실행은 `compose.prod.yaml`에서 `image:`로 registry 이미지를 pull합니다.
- 배포 compose에는 `build:`를 두지 않습니다.
- Docker image 경로는 소문자 registry 이름을 사용합니다.
- `.env`는 로컬 전용이며, 운영에서는 배포 플랫폼 secret 또는 환경변수 주입을 우선합니다.
- `docker compose config` 출력에는 `env_file` secret이 포함될 수 있으므로 PR/이슈/채팅에 붙여넣지 않습니다.

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

프론트와 백엔드를 로컬에서 함께 확인할 때:

```sh
docker compose -f compose.local.yaml up --build
```

기본 접속 주소:

- 프론트: `http://localhost:5173`
- 백엔드: `http://localhost:8080`
- 헬스체크: `http://localhost:8080/api/health`

배포 이미지를 기준으로 확인할 때:

```sh
docker compose -f compose.prod.yaml pull
docker compose -f compose.prod.yaml up -d
```

권장 이미지 태그:

```text
ghcr.io/silverthunder09/jdsnack-backend:latest
ghcr.io/silverthunder09/jdsnack-frontend:latest
ghcr.io/silverthunder09/jdsnack-backend:<git-sha>
ghcr.io/silverthunder09/jdsnack-frontend:<git-sha>
```

설정 구조만 확인할 때는 secret 해석을 막습니다.

```sh
docker compose -f compose.local.yaml config --no-env-resolution
docker compose -f compose.prod.yaml config --no-env-resolution
```

## GitHub Actions 흐름

- PR에서 Dockerfile·Compose·smoke 스크립트가 변경된 경우에만 컨테이너 빌드와 `/api/health` 검증을 실행합니다.
- PR에서 Compose 또는 smoke 스크립트가 변경된 경우에만 `compose.local.yaml` 기반 스모크 테스트를 실행합니다.
- `main` 반영 후 모든 push에서도 같은 컨테이너 검증을 다시 실행합니다.
- `main` 반영 후 backend/frontend 이미지를 GitHub Container Registry에 `latest`와 `<git-sha>` 태그로 push합니다.
- 배포 검증은 `compose.prod.yaml`이 push된 이미지를 pull할 수 있는지 확인합니다.
- 컨테이너 빌드 실패 시 PR 실패 Issue와 같은 형식으로 Issue를 생성합니다.

## 운영 원칙

- 프론트는 정적 자산과 사용자 진입점을 담당한다.
- 백엔드는 API와 이후 외부 AI 연동 경계를 담당한다.
- 운영 환경에서는 reverse proxy 또는 ingress로 두 컨테이너를 묶는다.
- CI와 로컬 검증은 `compose.local.yaml` 기준으로 맞춘다.
- 배포 실행 검증은 `compose.prod.yaml` 기준으로 맞춘다.

## 2차 확장

- 외부 AI 연동 시 서버 비밀값 주입과 로그 정책 검증
- reverse proxy 캐시/압축 정책 고도화
- 필요 시 `frontend`, `backend` 외 별도 gateway 또는 worker 컨테이너 추가
