# AI 이력서 진단 서비스 (AI Resume Diagnoser) — 기획 및 설계 노트

> 상태: 레거시 상세 문서  
> 현재 상위 요구사항 문서: [requirements.md](/Users/t2025-m0141/AI-Project/JDSnack/agent-os/specs/2026-05-21-0943-ai-resume-diagnoser/requirements.md)

## 범위 (Scope)

- **핵심 기능**: 사용자가 이력서 내용을 작성하고 제출하면, AI(Google Gemini API)를 활용해 이력서 진단 점수와 구체적인 개선 피드백을 실시간 제공.
- **주요 진단 피드백 항목**:
  1. 이력서 진단 점수 (100점 만점)
  2. 가독성 개선을 위한 타이포그래피 및 구조 팁
  3. 프로젝트 기여도 및 성과 구체화 제안
- **디자인 컨셉**: 애플 스타일의 깔끔하고 모던한 미니멀 화이트/그레이 레이아웃 (가독성 극대화, 여백의 미, 부드러운 전환 효과).

## 결정 사항 (Decisions)

- **백엔드**: **Spring Boot 3.x (Java 17)**
  - `/api/diagnose` REST 엔드포인트 개설.
  - 백엔드 서버에서 안전하게 Google Gemini API를 호출하여 클라이언트에 구조화된 JSON 데이터 반환 (API Key 노출 최소화).
- **프론트엔드 (추천)**: **React (Vite + TS) + Vanilla CSS**
  - 빌드 결과물(dist)을 Spring Boot의 `src/main/resources/static/` 하위로 빌드하여 하나의 JAR 파일로 합치는 아키텍처 채택.
- **배포 인프라**: **AWS (EC2 또는 Elastic Beanstalk)**
  - 단일 JAR 실행 형태 배포로 인프라 설정 최소화 및 개발 속도 극대화.

## 맥락 (Context)

- **배포 기한**: 다음 주 월요일 배포 목표 (매우 긴박함).
- **아키텍처 강점**: 단일 포트(8080) 서빙으로 CORS 이슈 완전 배제 및 SSL/인증서 처리 단순화.
