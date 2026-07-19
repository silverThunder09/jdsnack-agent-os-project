package com.jdsnack.analysis;

import com.jdsnack.common.ErrorDetail;

import java.time.Instant;

public record AnalysisHistoryResponse(
        String id,
        AnalysisHistoryStatus status,
        Instant createdAt,
        AnalysisHistoryInputResponse input,
        AnalysisHistoryResult result,
        ErrorDetail failure
) {
}
