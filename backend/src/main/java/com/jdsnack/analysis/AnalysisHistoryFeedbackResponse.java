package com.jdsnack.analysis;

import java.time.Instant;

public record AnalysisHistoryFeedbackResponse(
        AnalysisFeedbackRating rating,
        String comment,
        Instant updatedAt
) {
}
