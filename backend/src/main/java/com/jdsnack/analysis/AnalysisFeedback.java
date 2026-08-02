package com.jdsnack.analysis;

import java.time.Instant;

public record AnalysisFeedback(
        String id,
        String historyId,
        String userId,
        AnalysisFeedbackRating rating,
        String comment,
        Instant createdAt,
        Instant updatedAt
) {
    public static final int COMMENT_MAX_LENGTH = 500;
}
