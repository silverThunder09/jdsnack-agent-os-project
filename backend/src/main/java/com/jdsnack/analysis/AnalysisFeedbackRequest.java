package com.jdsnack.analysis;

public record AnalysisFeedbackRequest(
        String rating,
        String comment
) {
}
