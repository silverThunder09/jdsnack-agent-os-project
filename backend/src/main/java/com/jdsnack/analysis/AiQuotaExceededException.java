package com.jdsnack.analysis;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;

import java.util.Map;

public class AiQuotaExceededException extends ApiException {

    public AiQuotaExceededException(AiUsageReservation reservation) {
        super(ErrorCode.AI_QUOTA_EXCEEDED, Map.of(
                "retryAfter", reservation.retryAfterSeconds(),
                "limit", reservation.limit(),
                "remaining", reservation.remaining(),
                "resetAt", reservation.resetAt().toString()
        ));
    }
}
