package com.jdsnack.common;

import java.time.OffsetDateTime;
import java.time.ZoneId;

public record ApiResponse<T>(
        boolean success,
        T data,
        ErrorDetail error,
        String timestamp
) {

    private static final ZoneId SERVICE_ZONE = ZoneId.of("Asia/Seoul");

    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(true, data, null, now());
    }

    public static ApiResponse<Void> failure(ErrorDetail error) {
        return new ApiResponse<>(false, null, error, now());
    }

    private static String now() {
        return OffsetDateTime.now(SERVICE_ZONE).toString();
    }
}
