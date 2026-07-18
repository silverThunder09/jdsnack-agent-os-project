package com.jdsnack.auth;

public record AuthSessionResponse(
        boolean authenticated,
        AuthenticatedUserResponse user
) {

    public static AuthSessionResponse unauthenticated() {
        return new AuthSessionResponse(false, null);
    }

    public static AuthSessionResponse authenticated(UserRecord user) {
        return new AuthSessionResponse(true, AuthenticatedUserResponse.from(user));
    }
}
