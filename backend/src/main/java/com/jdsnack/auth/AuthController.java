package com.jdsnack.auth;

import com.jdsnack.common.ApiResponse;
import jakarta.servlet.http.HttpSession;
import org.springframework.boot.autoconfigure.web.ServerProperties;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import java.net.URI;

@RestController
public class AuthController {

    private static final String DEFAULT_SESSION_COOKIE_NAME = "JSESSIONID";

    private final GoogleAuthService googleAuthService;
    private final ServerProperties serverProperties;

    public AuthController(GoogleAuthService googleAuthService, ServerProperties serverProperties) {
        this.googleAuthService = googleAuthService;
        this.serverProperties = serverProperties;
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

    @PostMapping("/api/auth/logout")
    public ResponseEntity<Void> logout(HttpSession session) {
        googleAuthService.logout(session);
        return ResponseEntity.noContent()
                .header(HttpHeaders.SET_COOKIE, expiredSessionCookie().toString())
                .build();
    }

    /**
     * 브라우저에 남은 세션 쿠키를 즉시 만료시킨다.
     *
     * <p>{@code session.invalidate()}는 서버 쪽 세션만 폐기하므로, 그것만으로는 브라우저에
     * 쿠키 값이 그대로 남는다. 서버가 이미 무효화해 탈취 위험은 없지만 "로그아웃했는데 쿠키가
     * 남아 있는" 상태가 되므로, 응답에서 같은 이름의 쿠키를 빈 값·Max-Age 0으로 덮어쓴다.
     *
     * <p>속성은 실제 세션 쿠키 설정을 따라간다. 이름·path·http-only·same-site가 어긋나면
     * 브라우저가 다른 쿠키로 보고 원본을 지우지 않는다.
     */
    private ResponseCookie expiredSessionCookie() {
        var cookie = serverProperties.getServlet().getSession().getCookie();
        String name = cookie.getName() != null ? cookie.getName() : DEFAULT_SESSION_COOKIE_NAME;
        String path = cookie.getPath() != null ? cookie.getPath() : "/";
        boolean httpOnly = Boolean.TRUE.equals(cookie.getHttpOnly());
        boolean secure = Boolean.TRUE.equals(cookie.getSecure());
        String sameSite = cookie.getSameSite() != null ? cookie.getSameSite().attributeValue() : "Lax";

        return ResponseCookie.from(name, "")
                .path(path)
                .maxAge(0)
                .httpOnly(httpOnly)
                .secure(secure)
                .sameSite(sameSite)
                .build();
    }

    private ResponseEntity<Void> redirect(URI location) {
        return ResponseEntity.status(302).location(location).build();
    }
}
