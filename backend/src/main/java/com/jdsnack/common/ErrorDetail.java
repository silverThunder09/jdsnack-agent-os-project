package com.jdsnack.common;

import java.util.Map;

public record ErrorDetail(
        String code,
        String message,
        Map<String, Object> metadata
) {

    public ErrorDetail(String code, String message) {
        this(code, message, null);
    }
}
