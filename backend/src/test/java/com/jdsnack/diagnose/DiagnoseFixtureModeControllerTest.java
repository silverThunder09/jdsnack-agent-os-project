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
@AutoConfigureMockMvc
@TestPropertySource(properties = "jdsnack.diagnosis.mode=fixture")
class DiagnoseFixtureModeControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void matchingTextReturnsFixtureAnalysis() throws Exception {
        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonWithResumeText(TestResumeSamples.FIXTURE_RESUME_TEXT)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.score").value(78))
                .andExpect(jsonPath("$.data.summary").value("백엔드 중심 경험은 분명하지만 성과 수치가 더 필요합니다."))
                .andExpect(jsonPath("$.data.strengths[0]").value("Spring Boot API 구현 경험이 보입니다."))
                .andExpect(jsonPath("$.data.improvements[0]").value("프로젝트 결과를 수치로 보강해 주세요."));
    }

    @Test
    void unknownResumeTextReturnsFixtureNotFound() throws Exception {
        mockMvc.perform(post("/api/diagnose")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonWithResumeText(TestResumeSamples.UNKNOWN_RESUME_TEXT)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("FIXTURE_NOT_FOUND"));
    }

    @Test
    void pdfUploadReturnsFixtureAnalysis() throws Exception {
        MockMultipartFile resumeFile = new MockMultipartFile(
                "resumeFile",
                "resume.pdf",
                MediaType.APPLICATION_PDF_VALUE,
                TestResumeSamples.createPdfBytes(TestResumeSamples.FIXTURE_RESUME_TEXT)
        );

        mockMvc.perform(multipart("/api/diagnose/file").file(resumeFile))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.score").value(78));
    }

    @Test
    void docxUploadReturnsFixtureAnalysis() throws Exception {
        MockMultipartFile resumeFile = new MockMultipartFile(
                "resumeFile",
                "resume.docx",
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                TestResumeSamples.createDocxBytes(TestResumeSamples.FIXTURE_RESUME_TEXT)
        );

        mockMvc.perform(multipart("/api/diagnose/file").file(resumeFile))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.score").value(78));
    }

    @Test
    void unsupportedFileReturnsError() throws Exception {
        MockMultipartFile resumeFile = new MockMultipartFile(
                "resumeFile",
                "resume.txt",
                MediaType.TEXT_PLAIN_VALUE,
                TestResumeSamples.FIXTURE_RESUME_TEXT.getBytes()
        );

        mockMvc.perform(multipart("/api/diagnose/file").file(resumeFile))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("UNSUPPORTED_FILE_TYPE"));
    }

    @Test
    void extractionFailureReturnsError() throws Exception {
        MockMultipartFile resumeFile = new MockMultipartFile(
                "resumeFile",
                "broken.pdf",
                MediaType.APPLICATION_PDF_VALUE,
                "not-a-pdf".getBytes()
        );

        mockMvc.perform(multipart("/api/diagnose/file").file(resumeFile))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("FILE_TEXT_EXTRACTION_FAILED"));
    }

    @Test
    void fixtureMissingForUploadedFileReturnsError() throws Exception {
        MockMultipartFile resumeFile = new MockMultipartFile(
                "resumeFile",
                "resume.docx",
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                TestResumeSamples.createDocxBytes(TestResumeSamples.UNKNOWN_RESUME_TEXT)
        );

        mockMvc.perform(multipart("/api/diagnose/file").file(resumeFile))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("FIXTURE_NOT_FOUND"));
    }

    private String jsonWithResumeText(String resumeText) {
        return "{\"resumeText\":\"" + resumeText + "\"}";
    }
}
