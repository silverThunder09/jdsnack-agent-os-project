package com.jdsnack.auth;

public interface GoogleOAuthClient {
    GoogleUserProfile authenticate(String code);
}
