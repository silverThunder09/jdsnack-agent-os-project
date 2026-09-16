package com.jdsnack.analysis;

import java.time.OffsetDateTime;

public record AiUsageReservation(
        String usageId,
        boolean reserved,
        int limit,
        int used,
        int remaining,
        OffsetDateTime resetAt,
        long retryAfterSeconds
) {
}
