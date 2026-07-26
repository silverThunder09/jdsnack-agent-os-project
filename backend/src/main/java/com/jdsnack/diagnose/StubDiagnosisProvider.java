package com.jdsnack.diagnose;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ProviderMetadata;
import org.springframework.stereotype.Component;

@Component
public class StubDiagnosisProvider implements DiagnosisProvider {

    @Override
    public DiagnosisResultResponse diagnose(UploadedResumeType inputType, String resumeText) {
        throw new ApiException(DiagnoseService.NOT_ENABLED);
    }

    @Override
    public ProviderMetadata providerMetadata() {
        return new ProviderMetadata("stub", "stub-v1");
    }
}
