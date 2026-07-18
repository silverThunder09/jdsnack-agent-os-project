package com.jdsnack.match;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
@TestPropertySource(properties = "jdsnack.diagnosis.mode=fixture")
class MatchPreviewFixtureModeControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void validPreviewRequestReturnsRuleBasedPreviewInFixtureMode() throws Exception {
        mockMvc.perform(post("/api/match/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.matchingScore").isNumber())
                .andExpect(jsonPath("$.data.summary").isString())
                .andExpect(jsonPath("$.data.strengths[0]").isString())
                .andExpect(jsonPath("$.data.gaps[0]").isString())
                .andExpect(jsonPath("$.data.suggestions[0]").isString())
                .andExpect(jsonPath("$.data.matchedKeywords").isArray())
                .andExpect(jsonPath("$.data.partialKeywords").isArray())
                .andExpect(jsonPath("$.data.missingKeywords").isArray());
    }

    private String validRequest() {
        return """
                {
                  "resumeSource": {
                    "type": "TEXT",
                    "value": "Spring Boot API 개발과 테스트 자동화 경험이 있으며 배포 운영도 다뤘고 협업 문서화를 지속했습니다."
                  },
                  "jdText": "Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화, 배포 경험을 요구합니다.",
                  "jdUrl": "https://example.com/jobs/backend"
                }
                """;
    }
}
