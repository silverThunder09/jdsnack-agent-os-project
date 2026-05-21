# AI 이력서 진단 서비스 개발 계획서 (AI Resume Diagnoser Plan)

## Task 1: 스펙 문서 저장 (Save Spec Documentation) - [완료]

- **설명**: 기획 및 스펙 도출 내용을 `agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/` 경로에 저장하고 버전 관리 기반을 마련합니다.
- **산출물**: `shape.md`, `standards.md`, `references.md`, `plan.md`

## Task 2: Spring Boot 백엔드 및 Gemini AI 연동 구현 (Spring Boot Backend)

- **설명**: Spring Boot 프로젝트를 초기화하고, 보안이 강화된 환경에서 Google Gemini API와 연동하는 REST API 서버를 구현합니다.
- **주요 내용**:
  - Spring Boot 3.x 프로젝트 초기화 (Dependencies: Spring Web, Lombok)
  - 이력서 데이터를 받는 POST `/api/diagnose` 엔드포인트 구현
  - Java `RestClient` 혹은 `WebClient`를 활용한 Gemini API 연동 서비스 클래스 구축
  - 이력서 분석용 고성능 구조화 JSON(점수, 가독성 피드백 목록, 프로젝트 기여도 피드백 목록) 추출 프롬프트 설계
  - `.env` 혹은 시스템 환경변수를 통한 Gemini API Key 보안 관리

## Task 3: React 프론트엔드 구축 및 애플 스타일 미니멀 UI 퍼블리싱 (React Frontend & UI)

- **설명**: Vite + React + TypeScript 기반으로 초경량, 고성능 프론트엔드를 구성하고 텍스트 가독성이 극대화된 애플 스타일의 미니멀 대시보드 화면을 퍼블리싱합니다.
- **주요 내용**:
  - Vite를 활용한 React 프로젝트 초기화
  - 애플 스타일 디자인 시스템 정립 (San Francisco 계열 폰트 적용, 명확한 타이포그래피 계층 구조, 섀도우 카드 레이아웃)
  - **입력 영역**: 이력서 복사/붙여넣기 textarea 및 글자수 세기, LocalStorage 자동 보관 기능
  - **대시보드 영역**: 종합 진단 점수를 표현하는 미니멀 원형 게이지 차트, 개선 피드백(가독성 팁, 프로젝트 기여도 구체화) 리스트 시각화
  - 분석 실행 시의 유려한 스켈레톤 로딩 피드백 및 프로그레스 애니메이션 적용

## Task 4: 프론트-백엔드 연동 및 단일 JAR 패키징 설정 (Single JAR Packaging)

- **설명**: 개발 생산성과 배포 편의성을 극대화하기 위해 React 빌드 자산(`dist`)을 Spring Boot static 경로로 복사하여 단일 JAR 파일로 배포할 수 있는 빌드 스크립트를 세팅합니다.
- **주요 내용**:
  - Gradle/Maven 빌드 태스크 커스텀 설정을 통해 프론트엔드 빌드 결과물을 `src/main/resources/static` 하위로 자동 복사 설정
  - React에서 Spring Boot의 `/api/diagnose` API 호출 연동 및 CORS 이슈 완전 제거 확인

## Task 5: AWS EC2 / Elastic Beanstalk 단일 JAR 배포 세팅 (AWS Deployment)

- **설명**: 다음 주 월요일의 안정적이고 빠른 론칭을 위해 AWS 인프라 환경을 심플하게 구축하고 단일 JAR 실행 테스트를 마칩니다.
- **주요 내용**:
  - AWS EC2 인스턴스 생성 (Amazon Linux 2023, t3.micro 권장) 혹은 Elastic Beanstalk 환경 구축
  - EC2 내 Java 17 런타임 설치 및 환경 설정
  - 보안 그룹(Security Group) 설정 (80포트 리다이렉트 혹은 8080포트 오픈, HTTPS 적용 검토)
  - 빌드된 단일 JAR 파일을 AWS에 전송하여 백그라운드 구동 (`nohup java -jar ... &` 또는 systemd 서비스 등록)
