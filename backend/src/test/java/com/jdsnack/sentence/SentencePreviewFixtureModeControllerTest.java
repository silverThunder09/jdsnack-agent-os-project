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
@TestPropertySource(properties = "jdsnack.diagnosis.mode=fixture")
class SentencePreviewFixtureModeControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void fixtureModeReturnsDeterministicEdits() throws Exception {
        mockMvc.perform(post("/api/sentence/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.edits.length()").value(2))
                .andExpect(jsonPath("$.data.edits[0].original").value("Spring Boot 기반 API를 개발했습니다."));
    }

    private String validRequest() {
        return """
                {
                  "resumeSource": { "type": "FILE", "value": "Spring Boot 기반 API 개발과 테스트 자동화, 배포 운영 및 협업 개선 경험을 구체적으로 작성한 이력서입니다." },
                  "jdText": "Spring Boot REST API 설계와 테스트 자동화, 배포 운영 및 협업 문서화 경험을 요구하는 백엔드 채용 공고입니다.",
                  "jdUrl": ""
                }
                """;
    }
}
