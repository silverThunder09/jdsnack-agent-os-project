package com.jdsnack.analysis;

import java.time.Instant;

public record AnalysisHistory(
        String id,
        String userId,
        String snapshotId,
        String idempotencyKey,
        AnalysisHistoryStatus status,
        String diagnosisJson,
        String diagnosisModelName,
        String diagnosisPromptVersion,
        String matchJson,
        String matchModelName,
        String matchPromptVersion,
        String failureCode,
        String failureMessage,
        Instant createdAt,
        Instant updatedAt
) {
}
