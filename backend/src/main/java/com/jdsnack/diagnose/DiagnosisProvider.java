package com.jdsnack.diagnose;

import com.jdsnack.common.ProviderMetadata;

public interface DiagnosisProvider {

    DiagnosisResultResponse diagnose(UploadedResumeType inputType, String resumeText);

    ProviderMetadata providerMetadata();
}
