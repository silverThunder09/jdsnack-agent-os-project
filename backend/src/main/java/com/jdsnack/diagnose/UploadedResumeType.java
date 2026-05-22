package com.jdsnack.diagnose;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.springframework.web.multipart.MultipartFile;

import java.util.Locale;

public enum UploadedResumeType {
    TEXT,
    PDF,
    DOCX;

    public static UploadedResumeType fromMultipartFile(MultipartFile resumeFile) {
        if (resumeFile == null || resumeFile.isEmpty()) {
            throw new ApiException(ErrorCode.FILE_TEXT_EXTRACTION_FAILED);
        }

        String filename = resumeFile.getOriginalFilename();
        if (filename == null || filename.isBlank()) {
            throw new ApiException(ErrorCode.UNSUPPORTED_FILE_TYPE);
        }

        String lowercaseName = filename.toLowerCase(Locale.ROOT);
        if (lowercaseName.endsWith(".pdf")) {
            return PDF;
        }
        if (lowercaseName.endsWith(".docx")) {
            return DOCX;
        }

        throw new ApiException(ErrorCode.UNSUPPORTED_FILE_TYPE);
    }
}
