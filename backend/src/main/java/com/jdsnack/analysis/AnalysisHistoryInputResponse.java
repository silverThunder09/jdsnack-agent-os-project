package com.jdsnack.analysis;

public record AnalysisHistoryInputResponse(
        String resumeText,
        JdInputType jdInputType,
        String jdText,
        String sourceUrl,
        String sourceSite
) {
}
