package com.jdsnack.analysis;

import java.time.Instant;

public record AnalysisFeedbackResponse(
        String historyId,
        AnalysisFeedbackRating rating,
        String comment,
        Instant updatedAt
) {
}
