package com.jdsnack.auth;

import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Import(GoogleAuthControllerTest.FakeOAuthConfiguration.class)
@TestPropertySource(properties = {
        "jdsnack.auth.google.client-id=test-client-id",
        "jdsnack.auth.google.client-secret=test-client-secret",
        "jdsnack.auth.google.redirect-uri=http://localhost:8080/api/auth/google/callback",
        "jdsnack.auth.google.frontend-success-redirect-uri=http://localhost:5173/",
        "jdsnack.auth.google.frontend-failure-redirect-uri=http://localhost:5173/"
})
class GoogleAuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeGoogleOAuthClient fakeOAuthClient;

    @BeforeEach
    void resetFakeProvider() {
        fakeOAuthClient.reset();
    }

    @Test
    void startRedirectsToGoogleWithOneTimeStateWithoutSecret() throws Exception {
        MvcResult result = mockMvc.perform(get("/api/auth/google/start"))
                .andExpect(status().is3xxRedirection())
                .andExpect(header().string("Location", org.hamcrest.Matchers.containsString("accounts.google.com")))
                .andReturn();

        String location = result.getResponse().getHeader("Location");
        assertThat(location).doesNotContain("test-client-secret");

        var query = UriComponentsBuilder.fromUri(URI.create(location)).build().getQueryParams();
        assertThat(query.getFirst("client_id")).isEqualTo("test-client-id");
        assertThat(query.getFirst("response_type")).isEqualTo("code");
        assertThat(query.getFirst("scope")).contains("openid", "email", "profile");
        assertThat(query.getFirst("state")).isNotBlank();
        assertThat(result.getRequest().getSession(false)).isNotNull();
    }

    @Test
    void callbackCreatesInternalSessionAndRedirectsWithoutProviderToken() throws Exception {
        fakeOAuthClient.setProfile(new GoogleUserProfile(
                "google-subject-1",
                "user@example.com",
                "테스트 사용자"
        ));

        MvcResult start = mockMvc.perform(get("/api/auth/google/start")).andReturn();
        MockHttpSession session = (MockHttpSession) start.getRequest().getSession(false);
        String state = UriComponentsBuilder.fromUri(URI.create(start.getResponse().getHeader("Location")))
                .build()
                .getQueryParams()
                .getFirst("state");

        MvcResult callback = mockMvc.perform(get("/api/auth/google/callback")
                        .param("code", "fake-code")
                        .param("state", state)
                        .session(session))
                .andExpect(status().is3xxRedirection())
                .andExpect(header().string("Location", "http://localhost:5173/?auth=success"))
                .andReturn();

        assertThat(callback.getResponse().getContentAsString())
                .doesNotContain("access-token", "test-client-secret");

        mockMvc.perform(get("/api/auth/session").session(session))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.success").value(true))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.authenticated").value(true))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.data.user.email").value("user@example.com"));

        assertThat(fakeOAuthClient.lastCode()).isEqualTo("fake-code");
    }

    @Test
    void callbackWithUnexpectedStateDoesNotCallProvider() throws Exception {
        MvcResult start = mockMvc.perform(get("/api/auth/google/start")).andReturn();
        MockHttpSession session = (MockHttpSession) start.getRequest().getSession(false);

        mockMvc.perform(get("/api/auth/google/callback")
                        .param("code", "fake-code")
                        .param("state", "unexpected-state")
                        .session(session))
                .andExpect(status().is3xxRedirection())
                .andExpect(header().string("Location", "http://localhost:5173/?auth=error&code=OAUTH_STATE_INVALID"));

        assertThat(fakeOAuthClient.lastCode()).isNull();
    }

    @TestConfiguration
    static class FakeOAuthConfiguration {
        @Bean
        @Primary
        FakeGoogleOAuthClient fakeGoogleOAuthClient() {
            return new FakeGoogleOAuthClient();
        }
    }

    static class FakeGoogleOAuthClient implements GoogleOAuthClient {
        private GoogleUserProfile profile;
        private String lastCode;

        @Override
        public GoogleUserProfile authenticate(String code) {
            this.lastCode = code;
            return profile;
        }

        void setProfile(GoogleUserProfile profile) {
            this.profile = profile;
        }

        String lastCode() {
            return lastCode;
        }

        void reset() {
            profile = null;
            lastCode = null;
        }
    }
}
