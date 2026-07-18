package com.jdsnack.auth;

import com.jdsnack.common.ApiResponse;
import jakarta.servlet.http.HttpSession;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import java.net.URI;

@RestController
public class AuthController {

    private final GoogleAuthService googleAuthService;

    public AuthController(GoogleAuthService googleAuthService) {
        this.googleAuthService = googleAuthService;
    }

    @GetMapping("/api/auth/google/start")
    public ResponseEntity<Void> startGoogleLogin(HttpSession session) {
        return redirect(googleAuthService.start(session));
    }

    @GetMapping("/api/auth/google/callback")
    public ResponseEntity<Void> googleCallback(
            @RequestParam(required = false) String code,
            @RequestParam(required = false) String state,
            HttpSession session
    ) {
        return redirect(googleAuthService.callback(code, state, session));
    }

    @GetMapping("/api/auth/session")
    public ApiResponse<AuthSessionResponse> session(HttpSession session) {
        return ApiResponse.success(googleAuthService.session(session));
    }

    private ResponseEntity<Void> redirect(URI location) {
        return ResponseEntity.status(302).location(location).build();
    }
}
