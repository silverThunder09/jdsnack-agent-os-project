package com.jdsnack.analysis;

import java.time.Instant;

public record AnalysisHistory(
        String id,
        String userId,
        String snapshotId,
        AnalysisHistoryStatus status,
        String diagnosisJson,
        String matchJson,
        String failureCode,
        String failureMessage,
        Instant createdAt,
        Instant updatedAt
) {
}
