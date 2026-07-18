package com.jdsnack.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.jdsnack.common.ApiResponse;
import com.jdsnack.common.ErrorCode;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

@Component
public class AuthenticationFilter extends OncePerRequestFilter {

    private static final String API_PREFIX = "/api/";
    private static final String GOOGLE_START_PATH = "/api/auth/google/start";
    private static final String GOOGLE_CALLBACK_PATH = "/api/auth/google/callback";
    private static final String SESSION_PATH = "/api/auth/session";
    private static final String HEALTH_PATH = "/api/health";

    private final ObjectMapper objectMapper;

    public AuthenticationFilter(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String contextPath = request.getContextPath();
        String path = request.getRequestURI().substring(contextPath.length());

        return !path.startsWith(API_PREFIX)
                || GOOGLE_START_PATH.equals(path)
                || GOOGLE_CALLBACK_PATH.equals(path)
                || SESSION_PATH.equals(path)
                || HEALTH_PATH.equals(path)
                || "OPTIONS".equalsIgnoreCase(request.getMethod());
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute(GoogleAuthService.SESSION_USER_ID) == null) {
            writeAuthenticationRequired(response);
            return;
        }

        filterChain.doFilter(request, response);
    }

    private void writeAuthenticationRequired(HttpServletResponse response) throws IOException {
        ErrorCode errorCode = ErrorCode.AUTHENTICATION_REQUIRED;
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        objectMapper.writeValue(response.getWriter(), ApiResponse.failure(errorCode.toDetail()));
    }
}
