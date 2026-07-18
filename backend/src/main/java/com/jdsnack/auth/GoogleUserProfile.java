package com.jdsnack.auth;

public record GoogleUserProfile(
        String providerSubject,
        String email,
        String displayName
) {
}
