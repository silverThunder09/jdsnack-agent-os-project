package com.jdsnack.diagnose;

import com.jdsnack.analysis.AnalysisExecutionVersion;
import com.jdsnack.common.ApiException;
import org.springframework.stereotype.Component;

@Component
public class StubDiagnosisProvider implements DiagnosisProvider {

    private static final AnalysisExecutionVersion EXECUTION_VERSION =
            new AnalysisExecutionVersion("stub", "diagnosis-stub-v1");

    @Override
    public DiagnosisResultResponse diagnose(UploadedResumeType inputType, String resumeText) {
        throw new ApiException(DiagnoseService.NOT_ENABLED);
    }

    @Override
    public AnalysisExecutionVersion executionVersion() {
        return EXECUTION_VERSION;
    }
}
