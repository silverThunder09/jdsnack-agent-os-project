package com.jdsnack.auth;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

@ConfigurationProperties(prefix = "jdsnack.auth.google")
public record GoogleAuthProperties(
        String authorizationUri,
        String tokenUri,
        String userInfoUri,
        String clientId,
        String clientSecret,
        String redirectUri,
        String frontendSuccessRedirectUri,
        String frontendFailureRedirectUri,
        List<String> scopes
) {

    public GoogleAuthProperties {
        scopes = scopes == null || scopes.isEmpty()
                ? List.of("openid", "email", "profile")
                : List.copyOf(scopes);
    }

    public boolean isConfigured() {
        return notBlank(clientId)
                && notBlank(clientSecret)
                && notBlank(redirectUri)
                && notBlank(authorizationUri)
                && notBlank(tokenUri)
                && notBlank(userInfoUri);
    }

    private boolean notBlank(String value) {
        return value != null && !value.isBlank();
    }
}
