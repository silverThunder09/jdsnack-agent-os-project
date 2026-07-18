package com.jdsnack.auth;

public record AuthenticatedUserResponse(
        String id,
        String email,
        String displayName
) {

    public static AuthenticatedUserResponse from(UserRecord user) {
        return new AuthenticatedUserResponse(user.id(), user.email(), user.displayName());
    }
}
