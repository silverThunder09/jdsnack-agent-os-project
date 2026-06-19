package com.jdsnack.sentence;

import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class FixtureSentencePreviewProvider implements SentencePreviewProvider {

    @Override
    public SentencePreviewResponse preview(SentencePreviewRequest request) {
        return new SentencePreviewResponse(List.of(
                new SentenceEdit(
                        "Spring Boot 기반 API를 개발했습니다.",
                        "Spring Boot 기반 REST API를 설계하고 테스트 자동화를 적용해 배포 안정성을 높였습니다.",
                        "JD의 API 설계와 테스트 자동화 요구를 구체적인 행동과 결과로 연결했습니다."
                ),
                new SentenceEdit(
                        "팀원들과 협업했습니다.",
                        "백엔드 팀과 API 계약을 문서화하고 코드 리뷰 기준을 정립해 협업 비용을 줄였습니다.",
                        "막연한 협업 표현을 역할과 개선 결과가 드러나는 문장으로 바꿨습니다."
                )
        ));
    }
}
