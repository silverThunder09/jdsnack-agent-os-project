package com.jdsnack.diagnose;

import com.jdsnack.common.ErrorCode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "jdsnack.diagnosis.mode=ai-local")
class DiagnoseAiLocalModeControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private GeminiDiagnosisProvider geminiDiagnosisProvider;

    @Test
    void validResumeTextReturnsAiAnalysis() throws Exception {
        given(geminiDiagnosisProvider.diagnose(eq(UploadedResumeType.TEXT), any()))
                .willReturn(sampleResponse("a".repeat(120)));

        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                .content(jsonWithResumeText("a".repeat(120))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.score").value(84))
                .andExpect(jsonPath("$.data.summary").value("백엔드 중심 역량은 분명하지만 성과 수치가 더 보강되면 좋습니다."))
                .andExpect(jsonPath("$.data.sourceText").value("a".repeat(120)));
    }

    @Test
    void validPdfUploadReturnsAiAnalysis() throws Exception {
        given(geminiDiagnosisProvider.diagnose(eq(UploadedResumeType.PDF), any()))
                .willReturn(sampleResponse(TestResumeSamples.FIXTURE_RESUME_TEXT));

        MockMultipartFile resumeFile = new MockMultipartFile(
                "resumeFile",
                "resume.pdf",
                MediaType.APPLICATION_PDF_VALUE,
                TestResumeSamples.createPdfBytes(TestResumeSamples.FIXTURE_RESUME_TEXT)
        );

        mockMvc.perform(multipart("/api/diagnose/file").file(resumeFile))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.score").value(84));
    }

    @Test
    void missingGeminiApiKeyReturnsServiceUnavailable() throws Exception {
        given(geminiDiagnosisProvider.diagnose(eq(UploadedResumeType.TEXT), any()))
                .willThrow(new GeminiApiException(ErrorCode.GEMINI_API_KEY_MISSING));

        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonWithResumeText("a".repeat(120))))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.error.code").value("GEMINI_API_KEY_MISSING"));
    }

    @Test
    void invalidGeminiResponseReturnsBadGateway() throws Exception {
        given(geminiDiagnosisProvider.diagnose(eq(UploadedResumeType.TEXT), any()))
                .willThrow(new GeminiApiException(ErrorCode.GEMINI_API_RESPONSE_INVALID));

        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonWithResumeText("a".repeat(120))))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.error.code").value("GEMINI_API_RESPONSE_INVALID"));
    }

    @Test
    void geminiRequestFailureReturnsBadGateway() throws Exception {
        given(geminiDiagnosisProvider.diagnose(eq(UploadedResumeType.TEXT), any()))
                .willThrow(new GeminiApiException(ErrorCode.GEMINI_API_REQUEST_FAILED));

        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonWithResumeText("a".repeat(120))))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.error.code").value("GEMINI_API_REQUEST_FAILED"));
    }

    private DiagnosisResultResponse sampleResponse(String sourceText) {
        return new DiagnosisResultResponse(
                84,
                "백엔드 중심 역량은 분명하지만 성과 수치가 더 보강되면 좋습니다.",
                List.of("Spring Boot API 설계 경험이 잘 드러납니다."),
                List.of("프로젝트 결과를 수치로 보강해 주세요."),
                sourceText
        );
    }

    private String jsonWithResumeText(String resumeText) {
        return "{\"resumeText\":\"" + resumeText + "\"}";
    }
}
