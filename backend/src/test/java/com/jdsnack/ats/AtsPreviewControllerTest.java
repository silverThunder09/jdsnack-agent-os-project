package com.jdsnack.ats;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.lessThanOrEqualTo;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
class AtsPreviewControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void validRequestReturnsDeterministicAtsSignals() throws Exception {
        String request = validRequest();

        mockMvc.perform(post("/api/ats/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.atsScore", greaterThanOrEqualTo(0)))
                .andExpect(jsonPath("$.data.atsScore", lessThanOrEqualTo(100)))
                .andExpect(jsonPath("$.data.summary").isString())
                .andExpect(jsonPath("$.data.strengths").isArray())
                .andExpect(jsonPath("$.data.risks").isArray())
                .andExpect(jsonPath("$.data.suggestions").isArray())
                .andExpect(jsonPath("$.data.matchedKeywords", hasItem("spring")))
                .andExpect(jsonPath("$.data.missingKeywords").isArray())
                .andExpect(jsonPath("$.data.formatChecks[0].label").value("연락처 단서"));

        AtsPreviewService service = new AtsPreviewService();
        AtsPreviewRequest deterministicRequest = new AtsPreviewRequest(
                new AtsPreviewRequest.ResumeSource(
                        "TEXT",
                        "홍길동\nhello@example.com\n경력\n- Spring Boot API 개발과 테스트 자동화로 응답 시간을 30% 개선했습니다."
                ),
                "Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화와 Kubernetes 배포 경험을 요구합니다.",
                "https://example.com/jobs/backend"
        );
        assertThat(service.preview(deterministicRequest)).isEqualTo(service.preview(deterministicRequest));
    }

    @Test
    void invalidInputsReturnExistingValidationCodes() throws Exception {
        mockMvc.perform(post("/api/ats/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "resumeSource": {"type": "TEXT", "value": "짧은 이력서"},
                                  "jdText": "충분히 긴 JD 본문입니다. Spring Boot API 운영 경험과 테스트 자동화를 요구합니다.",
                                  "jdUrl": ""
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("TEXT_TOO_SHORT"));
    }

    @Test
    void invalidJdUrlReturnsExistingValidationCode() throws Exception {
        mockMvc.perform(post("/api/ats/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest().replace("https://example.com/jobs/backend", "not-a-url")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_JD_URL"));
    }

    private String validRequest() {
        return """
                {
                  "resumeSource": {
                    "type": "TEXT",
                    "value": "홍길동\\nhello@example.com\\n경력\\n- Spring Boot API 개발과 테스트 자동화로 응답 시간을 30% 개선했습니다."
                  },
                  "jdText": "Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화와 Kubernetes 배포 경험을 요구합니다.",
                  "jdUrl": "https://example.com/jobs/backend"
                }
                """;
    }
}
