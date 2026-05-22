package com.jdsnack.health;

public record HealthResponse(
        String status,
        String service,
        String version
) {
}
