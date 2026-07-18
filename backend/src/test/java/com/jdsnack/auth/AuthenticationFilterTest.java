package com.jdsnack.auth;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class AuthenticationFilterTest {

    @Autowired
    private MockMvc mockMvc;

    @ParameterizedTest
    @ValueSource(strings = {
            "/api/diagnose",
            "/api/match/preview",
            "/api/sentence/preview",
            "/api/jd/fetch",
            "/api/interview/preview",
            "/api/analysis-histories",
            "/api/analysis-histories/history-1",
            "/api/analysis-histories/history-1/retry"
    })
    void unauthenticatedProtectedRequestReturns401BeforeControllerExecution(String path) throws Exception {
        mockMvc.perform(MockMvcRequestBuilders.get(path)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"resumeText\":\"유효한 본문이지만 로그인하지 않은 요청입니다.\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("AUTHENTICATION_REQUIRED"));
    }

    @Test
    void protectedRequestWithContextPathStillReturns401() throws Exception {
        mockMvc.perform(MockMvcRequestBuilders.get("/jdsnack/api/diagnose")
                        .contextPath("/jdsnack")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("AUTHENTICATION_REQUIRED"));
    }

    @Test
    void authenticatedProtectedRequestPassesThroughToController() throws Exception {
        MockHttpSession session = authenticatedSession();

        mockMvc.perform(MockMvcRequestBuilders.post("/api/diagnose")
                        .session(session)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"resumeText\":\"짧은 본문\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("TEXT_TOO_SHORT"));
    }

    @Test
    void authSessionEndpointRemainsPublic() throws Exception {
        mockMvc.perform(MockMvcRequestBuilders.get("/api/auth/session"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.authenticated").value(false));
    }

    @Test
    void smokeSessionEndpointIsDisabledByDefault() throws Exception {
        mockMvc.perform(MockMvcRequestBuilders.post("/internal/test-auth/session"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
    }

    private MockHttpSession authenticatedSession() {
        MockHttpSession session = new MockHttpSession();
        session.setAttribute(GoogleAuthService.SESSION_USER_ID, "test-user");
        return session;
    }
}
