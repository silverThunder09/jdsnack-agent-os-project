package com.jdsnack.match;

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
class MatchPreviewAiLocalModeControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private GeminiMatchPreviewProvider geminiMatchPreviewProvider;

    @Test
    void validPreviewRequestReturnsAiMatchResult() throws Exception {
        given(geminiMatchPreviewProvider.preview(any()))
                .willReturn(new MatchPreviewResponse(
                        82,
                        "Spring Boot와 테스트 자동화 경험은 잘 맞지만 배포 근거를 조금 더 보강하면 좋습니다.",
                        List.of("Spring Boot 경험이 JD 요구사항과 직접 맞닿습니다.", "테스트 자동화 경험이 확인됩니다."),
                        List.of("배포 경험을 더 구체적으로 드러내는 편이 좋습니다.", "운영 지표를 수치로 보강하면 좋습니다."),
                        List.of("배포 경험이 있다면 프로젝트 맥락과 결과를 함께 적어 보세요.", "운영 성과를 숫자로 보강해 보세요.")
                ));

        mockMvc.perform(post("/api/match/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.matchingScore").value(82))
                .andExpect(jsonPath("$.data.gaps[0]").value("배포 경험을 더 구체적으로 드러내는 편이 좋습니다."));
    }

    @Test
    void missingGeminiApiKeyReturnsServiceUnavailable() throws Exception {
        given(geminiMatchPreviewProvider.preview(any()))
                .willThrow(new GeminiApiException(ErrorCode.GEMINI_API_KEY_MISSING));

        mockMvc.perform(post("/api/match/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.error.code").value("GEMINI_API_KEY_MISSING"));
    }

    @Test
    void invalidGeminiResponseReturnsBadGateway() throws Exception {
        given(geminiMatchPreviewProvider.preview(any()))
                .willThrow(new GeminiApiException(ErrorCode.GEMINI_API_RESPONSE_INVALID));

        mockMvc.perform(post("/api/match/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.error.code").value("GEMINI_API_RESPONSE_INVALID"));
    }

    @Test
    void geminiRequestFailureReturnsBadGateway() throws Exception {
        given(geminiMatchPreviewProvider.preview(any()))
                .willThrow(new GeminiApiException(ErrorCode.GEMINI_API_REQUEST_FAILED));

        mockMvc.perform(post("/api/match/preview")
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
                    "value": "Spring Boot API 개발과 테스트 자동화 경험이 있으며 배포 운영도 다뤘고 협업 문서화를 지속했습니다."
                  },
                  "jdText": "Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화, 배포 경험을 요구합니다.",
                  "jdUrl": "https://example.com/jobs/backend"
                }
                """;
    }
}
