# 배포 런북

## 목적

JDSnack의 기본 배포 방식과 운영 중 확인해야 할 항목을 기록합니다.

## 기본 배포 모델

- Spring Boot 단일 JAR 배포
- React 정적 자산 포함
- AWS EC2 또는 Elastic Beanstalk 사용
- 상세 CD 기준은 [cd-checklist.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/.agent-os/operations/cd-checklist.md)를 따름

## 준비 항목

- CI 체크리스트 통과
- CD 체크리스트 확인
- Java 17 런타임
- 포트/보안 그룹 설정
- 헬스체크 경로 `/api/health`

## 배포 절차

1. 프론트 빌드 결과물을 백엔드 정적 리소스로 포함합니다.
2. 단일 JAR를 빌드합니다.
3. 서버에 배포하고 애플리케이션을 기동합니다.
4. 헬스체크와 핵심 사용자 시나리오를 확인합니다.

## 실패 시 점검 순서

- 애플리케이션 기동 실패 여부
- 환경 변수 누락 여부
- 정적 리소스 포함 여부
- 보안 그룹/포트 개방 여부
