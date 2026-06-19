package com.jdsnack.sentence;

import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class StubSentencePreviewProvider implements SentencePreviewProvider {

    @Override
    public SentencePreviewResponse preview(SentencePreviewRequest request) {
        String original = summarize(request.resumeSource().value());
        return new SentencePreviewResponse(List.of(new SentenceEdit(
                original,
                original + " JD 핵심 역량과 연결되는 역할 및 성과를 구체적인 수치로 보강했습니다.",
                "JD 요구사항과 이력서 경험의 연결 근거를 명확하게 드러내기 위한 첨삭입니다."
        )));
    }

    private String summarize(String value) {
        String normalized = value.trim().replaceAll("\\s+", " ");
        return normalized.length() <= 120 ? normalized : normalized.substring(0, 120);
    }
}
