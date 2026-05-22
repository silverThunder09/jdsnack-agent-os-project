package com.jdsnack.diagnose;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class DiagnoseService {

    static final ErrorCode NOT_ENABLED = ErrorCode.AI_ANALYSIS_NOT_ENABLED;

    private static final int MIN_RESUME_LENGTH = 50;
    private static final int MAX_RESUME_LENGTH = 10_000;

    private final DiagnosisProvider stubDiagnosisProvider;
    private final DiagnosisProvider fixtureDiagnosisProvider;
    private final ResumeExtractionService resumeExtractionService;
    private final DiagnosisMode diagnosisMode;

    public DiagnoseService(
            StubDiagnosisProvider stubDiagnosisProvider,
            FixtureDiagnosisProvider fixtureDiagnosisProvider,
            ResumeExtractionService resumeExtractionService,
            @Value("${jdsnack.diagnosis.mode:stub}") String diagnosisMode
    ) {
        this.stubDiagnosisProvider = stubDiagnosisProvider;
        this.fixtureDiagnosisProvider = fixtureDiagnosisProvider;
        this.resumeExtractionService = resumeExtractionService;
        this.diagnosisMode = DiagnosisMode.from(diagnosisMode);
    }

    public DiagnosisResultResponse diagnose(DiagnoseRequest request) {
        String resumeText = validate(request);
        return selectProvider().diagnose(UploadedResumeType.TEXT, resumeText);
    }

    public DiagnosisResultResponse diagnoseFile(MultipartFile resumeFile) {
        String extractedText = resumeExtractionService.extractText(resumeFile);
        String validatedText = validate(extractedText);
        return selectProvider().diagnose(
                UploadedResumeType.fromMultipartFile(resumeFile),
                validatedText
        );
    }

    public String validate(DiagnoseRequest request) {
        if (request == null) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }

        return validate(request.resumeText());
    }

    public String validate(String resumeText) {
        if (resumeText == null || resumeText.trim().isEmpty()) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }

        String trimmedResumeText = resumeText.trim();
        int length = trimmedResumeText.length();

        if (length < MIN_RESUME_LENGTH) {
            throw new ApiException(ErrorCode.TEXT_TOO_SHORT);
        }

        if (length > MAX_RESUME_LENGTH) {
            throw new ApiException(ErrorCode.TEXT_TOO_LONG);
        }

        return trimmedResumeText;
    }

    private DiagnosisProvider selectProvider() {
        return switch (diagnosisMode) {
            case STUB -> stubDiagnosisProvider;
            case FIXTURE -> fixtureDiagnosisProvider;
        };
    }
}
