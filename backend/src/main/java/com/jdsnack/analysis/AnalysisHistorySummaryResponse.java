package com.jdsnack.analysis;

import java.time.Instant;

public record AnalysisHistorySummaryResponse(
        String id,
        AnalysisHistoryStatus status,
        Instant createdAt,
        String jdLabel,
        String jdSourceUrl,
        String summary
) {
}
