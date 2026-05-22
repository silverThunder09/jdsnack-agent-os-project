package com.jdsnack.diagnose;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.apache.poi.xwpf.usermodel.XWPFDocument;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

@Service
public class ResumeExtractionService {

    public String extractText(MultipartFile resumeFile) {
        UploadedResumeType uploadedResumeType = UploadedResumeType.fromMultipartFile(resumeFile);

        try {
            return switch (uploadedResumeType) {
                case PDF -> extractPdfText(resumeFile);
                case DOCX -> extractDocxText(resumeFile);
                case TEXT -> throw new ApiException(ErrorCode.UNSUPPORTED_FILE_TYPE);
            };
        } catch (IOException exception) {
            throw new ApiException(ErrorCode.FILE_TEXT_EXTRACTION_FAILED);
        }
    }

    private String extractPdfText(MultipartFile resumeFile) throws IOException {
        try (PDDocument document = Loader.loadPDF(resumeFile.getBytes())) {
            return new PDFTextStripper().getText(document);
        }
    }

    private String extractDocxText(MultipartFile resumeFile) throws IOException {
        try (XWPFDocument document = new XWPFDocument(resumeFile.getInputStream())) {
            return document.getParagraphs().stream()
                    .map(paragraph -> paragraph.getText())
                    .filter(text -> text != null && !text.isBlank())
                    .reduce((left, right) -> left + "\n" + right)
                    .orElse("");
        }
    }
}
