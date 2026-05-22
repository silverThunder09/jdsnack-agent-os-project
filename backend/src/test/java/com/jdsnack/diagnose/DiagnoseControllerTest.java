package com.jdsnack.diagnose;

import com.jdsnack.common.GlobalExceptionHandler;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(DiagnoseController.class)
@Import({DiagnoseService.class, GlobalExceptionHandler.class})
class DiagnoseControllerTest {

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
    void nullResumeTextReturnsEmptyResume() throws Exception {
        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"resumeText\":null}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("EMPTY_RESUME"));
    }

    @Test
    void emptyResumeTextReturnsEmptyResume() throws Exception {
        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"resumeText\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("EMPTY_RESUME"));
    }

    @Test
    void blankResumeTextReturnsEmptyResume() throws Exception {
        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"resumeText\":\"   \\n\\t  \"}"))
                .andExpect(status().isBadRequest())
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
    void longResumeTextReturnsTextTooLong() throws Exception {
        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonWithResumeText("a".repeat(10_001))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("TEXT_TOO_LONG"));
    }

    @Test
    void exactMinimumLengthReturnsNotEnabled() throws Exception {
        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonWithResumeText("a".repeat(50))))
                .andExpect(status().isNotImplemented())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("AI_ANALYSIS_NOT_ENABLED"));
    }

    @Test
    void exactMaximumLengthReturnsNotEnabled() throws Exception {
        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonWithResumeText("a".repeat(10_000))))
                .andExpect(status().isNotImplemented())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("AI_ANALYSIS_NOT_ENABLED"));
    }

    @Test
    void validResumeTextReturnsNotEnabled() throws Exception {
        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonWithResumeText("a".repeat(100))))
                .andExpect(status().isNotImplemented())
                .andExpect(jsonPath("$.error.code").value("AI_ANALYSIS_NOT_ENABLED"));
    }

    private String jsonWithResumeText(String resumeText) {
        return "{\"resumeText\":\"" + resumeText + "\"}";
    }
}
