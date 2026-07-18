package com.jdsnack.analysis;

import java.time.Instant;

public record AnalysisInputSnapshot(
        String id,
        String userId,
        String resumeText,
        JdInputType jdInputType,
        String jdText,
        String sourceUrl,
        String sourceSite,
        String fetchMode,
        Instant createdAt
) {
}
