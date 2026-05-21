# 기술 스택 (Tech Stack)

신속한 1차 MVP 개발을 목표로 하는 모던 풀스택 기술 스택입니다. 1차 MVP는 외부 AI 연동 없이 입력 검증과 준비중 안내까지 구현합니다.

## 백엔드 (Backend)

- **Spring Boot 3.x (Java 17+)**:
  - 안정적이고 확장성 높은 엔터프라이즈급 API 서비스 구축.
  - **Spring Web**: RESTful API 엔드포인트 구현 및 클라이언트 통신 담당.
  - **입력 검증 API**: 이력서 텍스트 검증과 준비중 응답 반환.
  - **Static Resource Serving**: 빌드된 프론트엔드 자산을 `src/main/resources/static/` 폴더에 패키징하여 단일 JAR 파일 배포 형태 구축 (AWS 배포 단순화).

## 프론트엔드 (Frontend - 추천 스택)

- **Vite + React (TypeScript)**:
  - **강력 추천 이유**: 높은 생산성과 초고속 빌드 성능(Vite), 풍부한 컴포넌트 생태계를 갖춘 React, 타입 안전성을 보장하는 TypeScript의 조합으로 다음 주 월요일까지의 타이트한 배포 일정을 맞추기에 최적입니다.
  - **Vanilla CSS3**: 애플 스타일의 정교한 타이포그래피, 글래스모피즘 계열의 세련된 반응형 대시보드 및 자연스러운 전환 애니메이션 구현.

## 인프라 및 배포 (Infrastructure & Deployment)

- **AWS (Amazon Web Services)**:
  - **배포 아키텍처**: Spring Boot가 내장 톰캣을 통해 React 정적 자산까지 서빙하는 단일 패키지(JAR) 형태를 구성하여, AWS **EC2** 또는 **Elastic Beanstalk**에 단일 애플리케이션 파일 업로드만으로 즉시 배포가 가능하게 설계합니다.

## 2차 MVP 확장 기술

- **Gemini API 연동**: 2차 MVP에서 서버 환경변수 기반으로 추가합니다.
- **비밀값 관리**: 운영 배포 시 환경변수 또는 AWS Secrets Manager를 사용합니다.
