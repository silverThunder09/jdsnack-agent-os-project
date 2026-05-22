package com.jdsnack.health;

public record RootResponse(
        String service,
        String status,
        String healthPath,
        String diagnosePath
) {
}
