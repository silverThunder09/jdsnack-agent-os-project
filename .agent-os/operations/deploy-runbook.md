# 배포 런북

## 목적

JDSnack의 기본 배포 방식과 운영 중 확인해야 할 항목을 기록합니다.

## 기본 배포 모델

- `frontend`, `backend` 분리 컨테이너 배포
- Dockerfile 기반 컨테이너 빌드
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

1. 프론트 컨테이너 이미지를 빌드합니다.
2. 백엔드 컨테이너 이미지를 빌드합니다.
3. 두 컨테이너를 같은 네트워크 또는 오케스트레이션 환경에 배치합니다.
4. reverse proxy 또는 ingress에서 프론트 진입점과 `/api/**` 라우팅을 연결합니다.
5. 헬스체크와 핵심 사용자 시나리오를 확인합니다.

## 실패 시 점검 순서

- 애플리케이션 기동 실패 여부
- 환경 변수 누락 여부
- 프론트/백엔드 라우팅 연결 여부
- 보안 그룹/포트 개방 여부
