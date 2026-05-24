package com.jdsnack.jd;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class JdFetchControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private JdFetchService jdFetchService;

    @Test
    void validRequestReturnsFetchedJdContent() throws Exception {
        given(jdFetchService.fetch(any()))
                .willReturn(new JdFetchResponse(
                        "Spring Boot 기반 REST API 개발과 운영 경험이 필요합니다. 테스트 자동화와 배포 경험이 있으면 좋습니다.",
                        "https://example.com/jobs/backend",
                        "Backend Engineer",
                        "static-html",
                        "saramin"
                ));

        mockMvc.perform(post("/api/jd/fetch")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "jdUrl": "https://example.com/jobs/backend"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.jdText").isString())
                .andExpect(jsonPath("$.data.sourceUrl").value("https://example.com/jobs/backend"))
                .andExpect(jsonPath("$.data.title").value("Backend Engineer"))
                .andExpect(jsonPath("$.data.fetchMode").value("static-html"))
                .andExpect(jsonPath("$.data.sourceSite").value("saramin"));
    }

    @Test
    void invalidUrlReturnsBadRequest() throws Exception {
        given(jdFetchService.fetch(any()))
                .willThrow(new ApiException(ErrorCode.INVALID_JD_URL));

        mockMvc.perform(post("/api/jd/fetch")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "jdUrl": "not-a-url"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_JD_URL"));
    }

    @Test
    void emptyContentReturnsUnprocessableEntity() throws Exception {
        given(jdFetchService.fetch(any()))
                .willThrow(new ApiException(ErrorCode.JD_FETCH_EMPTY_CONTENT));

        mockMvc.perform(post("/api/jd/fetch")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "jdUrl": "https://example.com/jobs/backend"
                                }
                                """))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("JD_FETCH_EMPTY_CONTENT"));
    }

    @Test
    void unsupportedSourceReturnsUnprocessableEntity() throws Exception {
        given(jdFetchService.fetch(any()))
                .willThrow(new ApiException(ErrorCode.JD_FETCH_UNSUPPORTED_SOURCE));

        mockMvc.perform(post("/api/jd/fetch")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "jdUrl": "https://example.com/jobs/backend"
                                }
                                """))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("JD_FETCH_UNSUPPORTED_SOURCE"));
    }

    @Test
    void fetchFailureReturnsBadGateway() throws Exception {
        given(jdFetchService.fetch(any()))
                .willThrow(new ApiException(ErrorCode.JD_FETCH_FAILED));

        mockMvc.perform(post("/api/jd/fetch")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "jdUrl": "https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=123456"
                                }
                                """))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.error.code").value("JD_FETCH_FAILED"));
    }
}
