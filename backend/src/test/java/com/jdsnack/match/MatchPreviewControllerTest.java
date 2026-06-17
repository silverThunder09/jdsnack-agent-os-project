package com.jdsnack.match;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class MatchPreviewControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void validPreviewRequestReturnsPreviewResult() throws Exception {
        mockMvc.perform(post("/api/match/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.matchingScore").isNumber())
                .andExpect(jsonPath("$.data.summary").isString())
                .andExpect(jsonPath("$.data.strengths").isArray())
                .andExpect(jsonPath("$.data.gaps").isArray())
                .andExpect(jsonPath("$.data.suggestions").isArray());
    }

    @Test
    void emptyJdReturnsError() throws Exception {
        mockMvc.perform(post("/api/match/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "resumeSource": {
                                    "type": "TEXT",
                                    "value": "%s"
                                  },
                                  "jdText": "   ",
                                  "jdUrl": ""
                                }
                                """.formatted(validResumeSource())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("EMPTY_JD"));
    }

    @Test
    void shortJdReturnsError() throws Exception {
        mockMvc.perform(post("/api/match/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "resumeSource": {
                                    "type": "TEXT",
                                    "value": "%s"
                                  },
                                  "jdText": "짧은 JD",
                                  "jdUrl": ""
                                }
                                """.formatted(validResumeSource())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("JD_TEXT_TOO_SHORT"));
    }

    @Test
    void shortResumeSourceReturnsTextTooShort() throws Exception {
        mockMvc.perform(post("/api/match/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "resumeSource": {
                                    "type": "TEXT",
                                    "value": "짧은 이력서"
                                  },
                                  "jdText": "%s",
                                  "jdUrl": ""
                                }
                                """.formatted("a".repeat(80))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("TEXT_TOO_SHORT"));
    }

    @Test
    void invalidJdUrlReturnsError() throws Exception {
        mockMvc.perform(post("/api/match/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "resumeSource": {
                                    "type": "TEXT",
                                    "value": "%s"
                                  },
                                  "jdText": "%s",
                                  "jdUrl": "not-a-url"
                                }
                                """.formatted(validResumeSource(), "a".repeat(80))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_JD_URL"));
    }

    @Test
    void longResumeSourceReturnsTextTooLong() throws Exception {
        mockMvc.perform(post("/api/match/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "resumeSource": {
                                    "type": "TEXT",
                                    "value": "%s"
                                  },
                                  "jdText": "%s",
                                  "jdUrl": ""
                                }
                                """.formatted("a".repeat(10_001), "b".repeat(80))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("TEXT_TOO_LONG"));
    }

    private String validRequest() {
        return """
                {
                  "resumeSource": {
                    "type": "TEXT",
                    "value": "%s"
                  },
                  "jdText": "Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화, 배포 경험을 요구합니다.",
                  "jdUrl": "https://example.com/jobs/backend"
                }
                """.formatted(validResumeSource());
    }

    private String validResumeSource() {
        return "Spring Boot API 개발과 테스트 자동화 경험이 있으며 배포 운영도 다뤘고 협업 문서화를 지속했습니다.";
    }
}
