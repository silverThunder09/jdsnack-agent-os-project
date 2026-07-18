package com.jdsnack.sentence;

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
@AutoConfigureMockMvc(addFilters = false)
@TestPropertySource(properties = "jdsnack.diagnosis.mode=ai-local")
class SentencePreviewAiLocalModeControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private GeminiSentencePreviewProvider geminiProvider;

    @Test
    void aiLocalModeReturnsGeminiEdits() throws Exception {
        given(geminiProvider.preview(any())).willReturn(new SentencePreviewResponse(List.of(
                new SentenceEdit("기존 문장", "개선 문장", "개선 사유")
        )));

        mockMvc.perform(post("/api/sentence/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.edits[0].improved").value("개선 문장"));
    }

    @Test
    void geminiFailuresUseExistingErrorCodes() throws Exception {
        given(geminiProvider.preview(any()))
                .willThrow(new GeminiApiException(ErrorCode.GEMINI_API_KEY_MISSING));

        mockMvc.perform(post("/api/sentence/preview")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.error.code").value("GEMINI_API_KEY_MISSING"));
    }

    private String validRequest() {
        return """
                {
                  "resumeSource": { "type": "TEXT", "value": "Spring Boot 기반 API 개발과 테스트 자동화, 배포 운영 및 협업 개선 경험을 구체적으로 작성한 이력서입니다." },
                  "jdText": "Spring Boot REST API 설계와 테스트 자동화, 배포 운영 및 협업 문서화 경험을 요구하는 백엔드 채용 공고입니다.",
                  "jdUrl": ""
                }
                """;
    }
}
