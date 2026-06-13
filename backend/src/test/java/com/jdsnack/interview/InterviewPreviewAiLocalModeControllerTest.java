package com.jdsnack.interview;

import com.jdsnack.common.ErrorCode;
import com.jdsnack.diagnose.GeminiApiException;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "jdsnack.diagnosis.mode=ai-local")
class InterviewPreviewAiLocalModeControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private GeminiInterviewPreviewProvider geminiInterviewPreviewProvider;

    @Test
    void validRequestReturnsAiInterviewQuestions() throws Exception {
        given(geminiInterviewPreviewProvider.preview(any()))
                .willReturn(new InterviewPreviewResponse(
                        List.of(new InterviewPreviewResponse.Question(
                                "Spring Boot API 설계 경험을 설명해 주세요.",
                                "technical",
                                "설계 이유, 테스트, 운영 결과를 함께 말하세요."
                        )),
                        "기술 의사결정과 검증 과정을 중심으로 답변하세요.",
                        "백엔드 직무 질문을 생성했습니다."
                ));

        mockMvc.perform(post("/api/interview/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.questions[0].category").value("technical"))
                .andExpect(jsonPath("$.data.strategy").value("기술 의사결정과 검증 과정을 중심으로 답변하세요."));
    }

    @Test
    void missingGeminiApiKeyReturnsServiceUnavailable() throws Exception {
        given(geminiInterviewPreviewProvider.preview(any()))
                .willThrow(new GeminiApiException(ErrorCode.GEMINI_API_KEY_MISSING));

        mockMvc.perform(post("/api/interview/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.error.code").value("GEMINI_API_KEY_MISSING"));
    }

    @Test
    void geminiRequestFailureReturnsBadGateway() throws Exception {
        given(geminiInterviewPreviewProvider.preview(any()))
                .willThrow(new GeminiApiException(ErrorCode.GEMINI_API_REQUEST_FAILED));

        mockMvc.perform(post("/api/interview/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.error.code").value("GEMINI_API_REQUEST_FAILED"));
    }

    private String validRequest() {
        return """
                {
                  "resumeSource": {
                    "type": "TEXT",
                    "value": "Spring Boot 기반 API 개발과 테스트 자동화 경험이 있으며 배포 운영도 다뤘습니다. 장애 대응과 협업 경험을 프로젝트 중심으로 정리했습니다."
                  },
                  "jobTitle": "백엔드 개발자",
                  "jdText": "Spring Boot API 개발, MySQL 운영, 테스트 자동화 경험을 요구합니다."
                }
                """;
    }
}
