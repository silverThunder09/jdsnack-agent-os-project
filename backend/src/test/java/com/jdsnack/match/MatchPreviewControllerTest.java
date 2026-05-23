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
    void validPreviewRequestReturnsNotEnabled() throws Exception {
        mockMvc.perform(post("/api/match/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isNotImplemented())
                .andExpect(jsonPath("$.error.code").value("JD_MATCH_PREVIEW_NOT_ENABLED"));
    }

    @Test
    void emptyJdReturnsError() throws Exception {
        mockMvc.perform(post("/api/match/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "resumeSource": {
                                    "type": "TEXT",
                                    "value": "validated resume source"
                                  },
                                  "jdText": "   ",
                                  "jdUrl": ""
                                }
                                """))
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
                                    "value": "validated resume source"
                                  },
                                  "jdText": "짧은 JD",
                                  "jdUrl": ""
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("JD_TEXT_TOO_SHORT"));
    }

    @Test
    void invalidJdUrlReturnsError() throws Exception {
        mockMvc.perform(post("/api/match/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "resumeSource": {
                                    "type": "TEXT",
                                    "value": "validated resume source"
                                  },
                                  "jdText": "%s",
                                  "jdUrl": "not-a-url"
                                }
                                """.formatted("a".repeat(80))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_JD_URL"));
    }

    private String validRequest() {
        return """
                {
                  "resumeSource": {
                    "type": "TEXT",
                    "value": "%s"
                  },
                  "jdText": "%s",
                  "jdUrl": "https://example.com/jobs/backend"
                }
                """.formatted("a".repeat(120), "b".repeat(120));
    }
}
