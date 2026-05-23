package com.jdsnack.diagnose;

public enum DiagnosisMode {
    STUB,
    FIXTURE,
    AI_LOCAL;

    public static DiagnosisMode from(String rawMode) {
        if (rawMode == null || rawMode.isBlank()) {
            return STUB;
        }

        return valueOf(rawMode.trim().toUpperCase().replace('-', '_'));
    }
}
