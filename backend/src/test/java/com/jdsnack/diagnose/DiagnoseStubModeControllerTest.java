package com.jdsnack.diagnose;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
@TestPropertySource(properties = "jdsnack.diagnosis.mode=stub")
class DiagnoseStubModeControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void missingResumeTextReturnsEmptyResume() throws Exception {
        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("EMPTY_RESUME"));
    }

    @Test
    void shortResumeTextReturnsTextTooShort() throws Exception {
        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonWithResumeText("a".repeat(49))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("TEXT_TOO_SHORT"));
    }

    @Test
    void validResumeTextReturnsNotEnabled() throws Exception {
        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonWithResumeText("a".repeat(100))))
                .andExpect(status().isNotImplemented())
                .andExpect(jsonPath("$.error.code").value("AI_ANALYSIS_NOT_ENABLED"));
    }

    @Test
    void fileUploadInStubModeReturnsNotEnabled() throws Exception {
        MockMultipartFile resumeFile = new MockMultipartFile(
                "resumeFile",
                "resume.pdf",
                MediaType.APPLICATION_PDF_VALUE,
                TestResumeSamples.createPdfBytes(TestResumeSamples.FIXTURE_RESUME_TEXT)
        );

        mockMvc.perform(multipart("/api/diagnose/file").file(resumeFile))
                .andExpect(status().isNotImplemented())
                .andExpect(jsonPath("$.error.code").value("AI_ANALYSIS_NOT_ENABLED"));
    }

    private String jsonWithResumeText(String resumeText) {
        return "{\"resumeText\":\"" + resumeText + "\"}";
    }
}
