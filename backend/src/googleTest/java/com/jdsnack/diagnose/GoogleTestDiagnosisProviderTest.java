package com.jdsnack.diagnose;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class GoogleTestDiagnosisProviderTest {

    @Test
    void geminiApiReturnsDiagnosisShape() {
        GoogleTestDiagnosisProvider provider = new GoogleTestDiagnosisProvider(
                new ObjectMapper(),
                System.getenv("GEMINI_API_KEY"),
                System.getenv("GEMINI_MODEL")
        );

        DiagnosisResultResponse response = provider.diagnose(
                UploadedResumeType.TEXT,
                "Spring Boot REST API 개발, 입력 검증, 테스트 자동화, Docker 기반 배포 검증을 수행한 백엔드 개발자 이력서입니다."
        );

        assertThat(response.score()).isBetween(0, 100);
        assertThat(response.summary()).isNotBlank();
        assertThat(response.strengths()).isNotEmpty();
        assertThat(response.improvements()).isNotEmpty();
    }
}
