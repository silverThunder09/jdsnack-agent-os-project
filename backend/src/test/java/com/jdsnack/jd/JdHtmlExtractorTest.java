package com.jdsnack.jd;

import com.jdsnack.common.ApiException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class JdHtmlExtractorTest {

    private final JdHtmlExtractor extractor = new JdHtmlExtractor();

    @Test
    void extractsArticleContent() {
        String html = """
                <html>
                  <head><title>Backend Engineer</title></head>
                  <body>
                    <article>
                      <h1>Backend Engineer</h1>
                      <p>Spring Boot 기반 REST API 개발과 운영 경험이 필요합니다.</p>
                      <p>테스트 자동화와 배포 경험이 있으면 좋습니다.</p>
                    </article>
                  </body>
                </html>
                """;

        JdFetchResponse response = extractor.extract(html, "https://example.com/jobs/backend");

        assertEquals("Backend Engineer", response.title());
        assertEquals("static-html", response.fetchMode());
        assertEquals(
                "Backend Engineer Spring Boot 기반 REST API 개발과 운영 경험이 필요합니다. 테스트 자동화와 배포 경험이 있으면 좋습니다.",
                response.jdText()
        );
    }

    @Test
    void emptyCandidateThrowsEmptyContent() {
        String html = """
                <html>
                  <head><title>JD</title></head>
                  <body>
                    <article><p>짧음</p></article>
                  </body>
                </html>
                """;

        ApiException exception = assertThrows(ApiException.class,
                () -> extractor.extract(html, "https://example.com/jobs/backend"));

        assertEquals("JD_FETCH_EMPTY_CONTENT", exception.errorCode().name());
    }

    @Test
    void noCandidateThrowsUnsupportedSource() {
        String html = """
                <html>
                  <body>
                    <nav>menu</nav>
                    <footer>footer</footer>
                  </body>
                </html>
                """;

        ApiException exception = assertThrows(ApiException.class,
                () -> extractor.extract(html, "https://example.com/jobs/backend"));

        assertEquals("JD_FETCH_UNSUPPORTED_SOURCE", exception.errorCode().name());
    }
}
