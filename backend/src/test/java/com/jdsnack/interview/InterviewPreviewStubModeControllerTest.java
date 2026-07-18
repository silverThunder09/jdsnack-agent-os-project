package com.jdsnack.interview;

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
class InterviewPreviewStubModeControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void validRequestReturnsNotEnabled() throws Exception {
        mockMvc.perform(post("/api/interview/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "resumeSource": {
                                    "type": "TEXT",
                                    "value": "Spring Boot 기반 API 개발과 테스트 자동화 경험이 있으며 배포 운영도 다뤘습니다. 장애 대응과 협업 경험을 프로젝트 중심으로 정리했습니다."
                                  }
                                }
                                """))
                .andExpect(status().isNotImplemented())
                .andExpect(jsonPath("$.error.code").value("MOCK_INTERVIEW_NOT_ENABLED"));
    }
}
