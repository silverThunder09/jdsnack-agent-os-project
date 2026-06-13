package com.jdsnack.interview;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.jdsnack.common.ErrorCode;
import com.jdsnack.diagnose.GeminiApiException;
import org.junit.jupiter.api.Test;

import java.net.http.HttpClient;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

class GeminiInterviewPreviewProviderTest {

    private final GeminiInterviewPreviewProvider provider = new GeminiInterviewPreviewProvider(
            new ObjectMapper(),
            HttpClient.newHttpClient(),
            "test-api-key",
            "gemini-test"
    );

    @Test
    void invalidQuestionSchemaReturnsInterviewGenerationFailure() {
        GeminiApiException exception = assertThrows(
                GeminiApiException.class,
                () -> provider.parseResponse(geminiResponse("""
                        {
                          "questions": [],
                          "strategy": "경험과 기술 의사결정을 중심으로 준비하세요.",
                          "summary": "질문 생성 결과입니다."
                        }
                        """))
        );

        assertThat(exception.errorCode()).isEqualTo(ErrorCode.INTERVIEW_QUESTION_GENERATION_FAILED);
    }

    private String geminiResponse(String text) {
        return """
                {
                  "candidates": [
                    {
                      "content": {
                        "parts": [
                          {
                            "text": %s
                          }
                        ]
                      }
                    }
                  ]
                }
                """.formatted(new ObjectMapper().valueToTree(text).toString());
    }
}
