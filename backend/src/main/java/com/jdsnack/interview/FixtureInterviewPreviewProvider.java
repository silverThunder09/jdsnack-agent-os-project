package com.jdsnack.interview;

import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class FixtureInterviewPreviewProvider implements InterviewPreviewProvider {

    @Override
    public InterviewPreviewResponse preview(InterviewPreviewRequest request) {
        String jobContext = normalized(request.jobTitle());
        String contextLabel = jobContext == null || jobContext.isBlank() ? "지원 직무" : jobContext;

        return new InterviewPreviewResponse(
                List.of(
                        new InterviewPreviewResponse.Question(
                                contextLabel + " 관점에서 가장 설득력 있는 프로젝트 경험을 설명해 주세요.",
                                "experience",
                                "문제 상황, 본인 역할, 사용 기술, 결과 수치를 순서대로 준비하세요."
                        ),
                        new InterviewPreviewResponse.Question(
                                "Spring Boot API 설계나 장애 대응 경험을 기술적으로 설명해 주세요.",
                                "technical",
                                "설계 선택 이유, 트레이드오프, 테스트 방식, 운영 결과를 함께 말하세요."
                        ),
                        new InterviewPreviewResponse.Question(
                                "일정 압박이나 요구사항 변경이 있었을 때 어떻게 협업했나요?",
                                "behavioral",
                                "상황, 소통 방식, 우선순위 조정, 배운 점을 짧게 정리하세요."
                        )
                ),
                "경험 질문은 STAR 구조로, 기술 질문은 의사결정 근거와 검증 방법 중심으로 준비하세요.",
                "이력서의 핵심 프로젝트를 직무 맥락에 맞춰 말할 수 있도록 질문을 구성했습니다."
        );
    }

    private String normalized(String value) {
        return value == null ? null : value.trim();
    }
}
