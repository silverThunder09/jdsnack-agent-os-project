# 배포 런북

## 목적

JDSnack의 기본 배포 방식과 운영 중 확인해야 할 항목을 기록합니다.

## 현재 상태

- 이 문서는 배포 절차 기준이며, EC2 수동 배포 실행 기록이 아닙니다.
- EC2 수동 배포와 운영 배포 검증은 사용자가 별도 지시할 때만 수행합니다.

## 기본 배포 모델

- `frontend`, `backend` 분리 컨테이너 배포
- CI에서 Dockerfile 기반 이미지를 빌드하고 registry에 push
- 배포 환경에서는 `compose.prod.yaml`로 registry 이미지를 pull
- reverse proxy 또는 ingress 뒤에서 단일 서비스처럼 노출
- AWS EC2, ECS 또는 유사한 컨테이너 실행 환경 사용
- 상세 CD 기준은 [cd-checklist.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/cd-checklist.md)를 따름
- 컨테이너 흐름은 [container-workflow.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/container-workflow.md)를 따름

## 준비 항목

- CI 체크리스트 통과
- CD 체크리스트 확인
- Docker 런타임
- 포트/보안 그룹 설정
- reverse proxy 또는 ingress 설정
- 헬스체크 경로 `/api/health`

## 배포 절차

1. `main` 반영 후 CI가 프론트/백엔드 이미지를 빌드합니다.
2. CI가 이미지를 `ghcr.io/silverthunder09/jdsnack-frontend:<tag>`, `ghcr.io/silverthunder09/jdsnack-backend:<tag>`로 push합니다.
3. 배포 환경에서 `JDSNACK_IMAGE_TAG`를 배포할 태그로 지정합니다.
4. `docker compose -f compose.prod.yaml pull`로 이미지를 가져옵니다.
5. `docker compose -f compose.prod.yaml up -d`로 두 컨테이너를 기동합니다.
6. reverse proxy 또는 ingress에서 프론트 진입점과 `/api/**` 라우팅을 연결합니다.
7. 헬스체크와 핵심 사용자 시나리오를 확인합니다.

## 배포 명령

```sh
JDSNACK_IMAGE_TAG=<git-sha> docker compose -f compose.prod.yaml pull
JDSNACK_IMAGE_TAG=<git-sha> docker compose -f compose.prod.yaml up -d
```

`GEMINI_API_KEY`는 `.env` 또는 배포 플랫폼 secret으로 주입합니다. secret 값은 로그와 PR 본문에 기록하지 않습니다.
`docker compose config` 출력에는 secret이 포함될 수 있으므로 공유하지 않습니다. 설정 구조만 확인할 때는 `--no-env-resolution`을 사용합니다.

## 실패 시 점검 순서

- 애플리케이션 기동 실패 여부
- 환경 변수 누락 여부
- 프론트/백엔드 라우팅 연결 여부
- 보안 그룹/포트 개방 여부
