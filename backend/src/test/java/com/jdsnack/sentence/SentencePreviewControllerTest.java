package com.jdsnack.sentence;

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
@TestPropertySource(properties = "jdsnack.diagnosis.mode=stub")
class SentencePreviewControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void validRequestReturnsSentenceEdits() throws Exception {
        mockMvc.perform(post("/api/sentence/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.edits").isArray())
                .andExpect(jsonPath("$.data.edits[0].original").isString())
                .andExpect(jsonPath("$.data.edits[0].improved").isString())
                .andExpect(jsonPath("$.data.edits[0].reason").isString());
    }

    @Test
    void invalidInputsReuseMatchValidationErrors() throws Exception {
        mockMvc.perform(post("/api/sentence/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request("짧음", "충분한 JD 본문 ".repeat(10), "")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("TEXT_TOO_SHORT"));

        mockMvc.perform(post("/api/sentence/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request("충분한 이력서 본문 ".repeat(10), "짧은 JD", "")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("JD_TEXT_TOO_SHORT"));

        mockMvc.perform(post("/api/sentence/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request("충분한 이력서 본문 ".repeat(10), "충분한 JD 본문 ".repeat(10), "not-a-url")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_JD_URL"));
    }

    private String validRequest() {
        return request(
                "Spring Boot 기반 API 개발과 테스트 자동화, 배포 운영 및 협업 개선 경험을 구체적으로 작성한 이력서입니다.",
                "Spring Boot REST API 설계와 테스트 자동화, 배포 운영 및 협업 문서화 경험을 요구하는 백엔드 채용 공고입니다.",
                "https://example.com/jobs/backend"
        );
    }

    private String request(String resume, String jd, String url) {
        return """
                {
                  "resumeSource": { "type": "TEXT", "value": "%s" },
                  "jdText": "%s",
                  "jdUrl": "%s"
                }
                """.formatted(resume, jd, url);
    }
}
