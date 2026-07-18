package com.jdsnack.auth;

public record UserRecord(
        String id,
        String provider,
        String providerSubject,
        String email,
        String displayName
) {
}
