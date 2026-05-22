package com.jdsnack.diagnose;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.springframework.stereotype.Component;

@Component
public class FixtureDiagnosisProvider implements DiagnosisProvider {

    private final FixtureAnalysisRepository fixtureAnalysisRepository;
    private final TextNormalizer textNormalizer;
    private final TextHashGenerator textHashGenerator;

    public FixtureDiagnosisProvider(
            FixtureAnalysisRepository fixtureAnalysisRepository,
            TextNormalizer textNormalizer,
            TextHashGenerator textHashGenerator
    ) {
        this.fixtureAnalysisRepository = fixtureAnalysisRepository;
        this.textNormalizer = textNormalizer;
        this.textHashGenerator = textHashGenerator;
    }

    @Override
    public DiagnosisResultResponse diagnose(UploadedResumeType inputType, String resumeText) {
        String normalizedResumeText = textNormalizer.normalize(resumeText);
        String matchValue = textHashGenerator.sha256(normalizedResumeText);

        FixtureAnalysis analysis = fixtureAnalysisRepository.findByInputTypeAndMatchValue(
                        inputType,
                        matchValue
                )
                .orElseThrow(() -> new ApiException(ErrorCode.FIXTURE_NOT_FOUND));

        return analysis.toResponse();
    }
}
