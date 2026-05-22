package com.jdsnack.diagnose;

public interface DiagnosisProvider {

    DiagnosisResultResponse diagnose(UploadedResumeType inputType, String resumeText);
}
