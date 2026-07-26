package com.jdsnack.diagnose;

import com.jdsnack.analysis.AnalysisExecutionVersion;

public interface DiagnosisProvider {

    DiagnosisResultResponse diagnose(UploadedResumeType inputType, String resumeText);

    AnalysisExecutionVersion executionVersion();
}
