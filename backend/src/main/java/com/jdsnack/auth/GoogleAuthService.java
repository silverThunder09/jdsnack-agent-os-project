package com.jdsnack.auth;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Service;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;

@Service
public class GoogleAuthService {

    static final String SESSION_STATE = GoogleAuthService.class.getName() + ".oauth-state";
    public static final String SESSION_USER_ID = GoogleAuthService.class.getName() + ".user-id";

    private final GoogleAuthProperties properties;
    private final GoogleOAuthClient googleOAuthClient;
    private final UserService userService;
    private final SecureRandom secureRandom;

    public GoogleAuthService(
            GoogleAuthProperties properties,
            GoogleOAuthClient googleOAuthClient,
            UserService userService
    ) {
        this.properties = properties;
        this.googleOAuthClient = googleOAuthClient;
        this.userService = userService;
        this.secureRandom = new SecureRandom();
    }

    public URI start(HttpSession session) {
        if (!properties.isConfigured()) {
            throw new ApiException(ErrorCode.OAUTH_NOT_CONFIGURED);
        }

        String state = createState();
        session.setAttribute(SESSION_STATE, state);

        return UriComponentsBuilder.fromUriString(properties.authorizationUri())
                .queryParam("client_id", properties.clientId())
                .queryParam("redirect_uri", properties.redirectUri())
                .queryParam("response_type", "code")
                .queryParam("scope", String.join(" ", properties.scopes()))
                .queryParam("state", state)
                .build()
                .toUri();
    }

    public URI callback(String code, String state, HttpSession session) {
        String expectedState = (String) session.getAttribute(SESSION_STATE);
        session.removeAttribute(SESSION_STATE);

        if (!matches(expectedState, state)) {
            return redirectToFailure(ErrorCode.OAUTH_STATE_INVALID);
        }
        if (code == null || code.isBlank()) {
            return redirectToFailure(ErrorCode.OAUTH_CALLBACK_FAILED);
        }

        try {
            UserRecord user = userService.upsertGoogleUser(googleOAuthClient.authenticate(code));
            session.setAttribute(SESSION_USER_ID, user.id());
            return redirectTo(properties.frontendSuccessRedirectUri(), "auth", "success", null);
        } catch (ApiException exception) {
            return redirectToFailure(exception.errorCode());
        } catch (RuntimeException exception) {
            return redirectToFailure(ErrorCode.OAUTH_CALLBACK_FAILED);
        }
    }

    public AuthSessionResponse session(HttpSession session) {
        String userId = (String) session.getAttribute(SESSION_USER_ID);
        if (userId == null) {
            return AuthSessionResponse.unauthenticated();
        }

        return userService.findById(userId)
                .map(AuthSessionResponse::authenticated)
                .orElseGet(() -> {
                    session.removeAttribute(SESSION_USER_ID);
                    return AuthSessionResponse.unauthenticated();
                });
    }

    /**
     * 내부 세션을 통째로 무효화한다. 사용자 식별자만 지우면 OAuth state 같은 잔여 속성이
     * 남으므로, 공용 PC에서 다음 사용자에게 세션이 이어지지 않도록 세션 자체를 버린다.
     */
    public void logout(HttpSession session) {
        session.invalidate();
    }

    private URI redirectToFailure(ErrorCode errorCode) {
        return redirectTo(properties.frontendFailureRedirectUri(), "auth", "error", errorCode.name());
    }

    private URI redirectTo(String baseUri, String key, String value, String code) {
        var builder = UriComponentsBuilder.fromUriString(baseUri)
                .queryParam(key, value);
        if (code != null) {
            builder.queryParam("code", code);
        }
        return builder.build().toUri();
    }

    private String createState() {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private boolean matches(String expected, String actual) {
        if (expected == null || actual == null) {
            return false;
        }
        return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.US_ASCII),
                actual.getBytes(StandardCharsets.US_ASCII)
        );
    }
}
