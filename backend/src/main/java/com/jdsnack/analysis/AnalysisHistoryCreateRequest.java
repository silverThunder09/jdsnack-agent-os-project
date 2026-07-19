package com.jdsnack.analysis;

public record AnalysisHistoryCreateRequest(
        String resumeText,
        JdInput jd
) {

    public record JdInput(
            String inputType,
            String text,
            String sourceUrl,
            String sourceSite
    ) {
    }
}
