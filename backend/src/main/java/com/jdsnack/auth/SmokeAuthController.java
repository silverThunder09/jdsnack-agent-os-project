package com.jdsnack.auth;

import jakarta.servlet.http.HttpSession;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@ConditionalOnProperty(name = "jdsnack.auth.smoke.enabled", havingValue = "true")
public class SmokeAuthController {

    private static final String SMOKE_PROVIDER_SUBJECT = "jdsnack-smoke-provider-subject";

    private final UserService userService;

    public SmokeAuthController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping("/internal/test-auth/session")
    public ResponseEntity<Void> createSmokeSession(HttpSession session) {
        UserRecord user = userService.upsertGoogleUser(new GoogleUserProfile(
                SMOKE_PROVIDER_SUBJECT,
                "smoke-test@jdsnack.local",
                "JDSnack Smoke Test"
        ));
        session.setAttribute(GoogleAuthService.SESSION_USER_ID, user.id());
        return ResponseEntity.noContent().build();
    }
}
