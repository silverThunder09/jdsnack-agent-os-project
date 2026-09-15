package com.jdsnack.auth;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class AuthLogoutControllerTest {

    @Autowired
    private MockMvc mockMvc;

    /** 로그아웃하면 내부 세션이 무효화된다. */
    @Test
    void logoutInvalidatesTheSession() throws Exception {
        MockHttpSession session = authenticatedSession();

        mockMvc.perform(post("/api/auth/logout").session(session))
                .andExpect(status().isNoContent());

        assertThat(session.isInvalid()).isTrue();
    }

    /**
     * 로그아웃 응답은 브라우저의 세션 쿠키도 만료시킨다.
     *
     * <p>{@code session.invalidate()}는 서버 쪽 세션만 폐기한다. 그것만으로는 브라우저에
     * JSESSIONID가 그대로 남아, 공용 PC에서 개발자도구나 쿠키 목록에 값이 계속 보인다.
     * 서버가 이미 무효화했으므로 탈취 위험은 없지만, 사용자가 "로그아웃했는데 쿠키가 남아 있다"고
     * 인지하는 상태 자체를 없앤다.
     */
    @Test
    void logoutExpiresTheSessionCookieInTheBrowser() throws Exception {
        MockHttpSession session = authenticatedSession();

        MvcResult result = mockMvc.perform(post("/api/auth/logout").session(session))
                .andExpect(status().isNoContent())
                .andReturn();

        String setCookie = result.getResponse().getHeader(HttpHeaders.SET_COOKIE);

        assertThat(setCookie)
                .as("로그아웃 응답의 Set-Cookie 헤더")
                .isNotNull();
        assertThat(setCookie).contains("JSESSIONID=");
        assertThat(setCookie.toLowerCase()).contains("max-age=0");
    }

    /** 로그아웃 후 보호 API는 인증 오류를 반환한다. */
    @Test
    void protectedApiIsBlockedAfterLogout() throws Exception {
        MockHttpSession session = authenticatedSession();

        mockMvc.perform(get("/api/analysis-histories").session(session))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/auth/logout").session(session))
                .andExpect(status().isNoContent());

        // 무효화된 세션을 그대로 다시 보내면 서버는 인증 정보를 찾지 못한다.
        mockMvc.perform(get("/api/analysis-histories").session(session))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("AUTHENTICATION_REQUIRED"));
    }

    /** 로그아웃 후 세션 조회는 비인증 상태를 반환한다. */
    @Test
    void sessionLookupReportsUnauthenticatedAfterLogout() throws Exception {
        MockHttpSession session = authenticatedSession();

        mockMvc.perform(post("/api/auth/logout").session(session))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/auth/session").session(new MockHttpSession()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.authenticated").value(false));
    }

    /** 로그아웃은 보호 대상이다. 비인증 요청은 차단된다. */
    @Test
    void logoutRequiresAuthentication() throws Exception {
        mockMvc.perform(post("/api/auth/logout").contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("AUTHENTICATION_REQUIRED"));
    }

    private MockHttpSession authenticatedSession() {
        MockHttpSession session = new MockHttpSession();
        session.setAttribute(GoogleAuthService.SESSION_USER_ID, "logout-test-user");
        return session;
    }
}
