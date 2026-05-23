package com.jdsnack.jd;

import com.jdsnack.common.ApiException;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

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
                "Spring Boot 기반 REST API 개발과 운영 경험이 필요합니다. 테스트 자동화와 배포 경험이 있으면 좋습니다.",
                response.jdText()
        );
    }

    @Test
    void prefersSemanticJobDescriptionOverLongerNoiseBlock() {
        String html = """
                <html>
                  <head><title>Platform Backend Engineer</title></head>
                  <body>
                    <div class="company-story related-jobs">
                      관련 공고, 추천 포지션, 복지 소개, 회사 홍보 문구가 길게 반복됩니다.
                      관련 공고, 추천 포지션, 복지 소개, 회사 홍보 문구가 길게 반복됩니다.
                      관련 공고, 추천 포지션, 복지 소개, 회사 홍보 문구가 길게 반복됩니다.
                    </div>
                    <div class="job-description">
                      <h1>Platform Backend Engineer</h1>
                      <p>Spring Boot 기반 API 설계와 운영 경험이 필요합니다.</p>
                      <p>대용량 트래픽 대응, 테스트 자동화, 배포 파이프라인 경험을 우대합니다.</p>
                    </div>
                  </body>
                </html>
                """;

        JdFetchResponse response = extractor.extract(html, "https://example.com/jobs/platform");

        assertEquals(
                "Spring Boot 기반 API 설계와 운영 경험이 필요합니다. 대용량 트래픽 대응, 테스트 자동화, 배포 파이프라인 경험을 우대합니다.",
                response.jdText()
        );
    }

    @Test
    void stripsPromotionalLeadFromStaticCareerFixture() throws IOException {
        String html = fixture("jd/fixtures/telktia-careers-backend-engineer.html");

        JdFetchResponse response = extractor.extract(html, "https://www.telktia.com/careers/backend-engineer");

        assertEquals("Backend Engineer | Telktia Careers", response.title());
        assertEquals(
                "플랫폼 백엔드 API를 설계하고 운영합니다. Spring Boot와 MySQL 기반 서비스 개발 경험이 필요합니다. 테스트 자동화와 배포 파이프라인 개선 경험을 우대합니다. 장애를 빠르게 분석하고 재발 방지까지 연결할 수 있어야 합니다.",
                response.jdText()
        );
    }

    @Test
    void trimsUnknownEnglishPromotionalLeadBeforeKoreanJdContent() {
        String html = """
                <html>
                  <head><title>Backend Engineer | Example Careers</title></head>
                  <body>
                    <section class="job-description">
                      <p>Build a meaningful future with a product-led team shaping the next generation of workflow tools.</p>
                      <p>백엔드 API를 설계하고 운영합니다.</p>
                      <p>Spring Boot와 데이터베이스 운영 경험이 필요합니다.</p>
                    </section>
                  </body>
                </html>
                """;

        JdFetchResponse response = extractor.extract(html, "https://example.com/careers/backend-engineer");

        assertEquals(
                "백엔드 API를 설계하고 운영합니다. Spring Boot와 데이터베이스 운영 경험이 필요합니다.",
                response.jdText()
        );
    }

    @Test
    void trimsDiscountPromotionalLeadBeforeJdContent() {
        String html = """
                <html>
                  <head><title>Backend Engineer | Example Careers</title></head>
                  <body>
                    <section class="job-description">
                      <p>We are currently offering a 20% discount to customers who upgrade this month.</p>
                      <p>백엔드 서비스 API를 설계하고 운영합니다.</p>
                      <p>Spring Boot와 MySQL 운영 경험이 필요합니다.</p>
                    </section>
                  </body>
                </html>
                """;

        JdFetchResponse response = extractor.extract(html, "https://example.com/careers/backend-engineer");

        assertEquals(
                "백엔드 서비스 API를 설계하고 운영합니다. Spring Boot와 MySQL 운영 경험이 필요합니다.",
                response.jdText()
        );
    }

    @Test
    void removesStickyApplyAndShareNoiseFromRealisticCareerFixture() throws IOException {
        String html = fixture("jd/fixtures/productive-careers-backend-engineer.html");

        JdFetchResponse response = extractor.extract(html, "https://productive.io/careers/backend-engineer/");

        assertEquals("Senior Backend Engineer - Productive", response.title());
        assertEquals(
                "분산 환경에서 안정적인 백엔드 서비스를 설계하고 운영합니다. Kafka, PostgreSQL, 관측성 도구를 활용한 장애 대응 경험이 필요합니다. 제품 팀과 협업하며 요구사항을 서비스 구조로 구체화할 수 있어야 합니다.",
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

    private String fixture(String path) throws IOException {
        try (InputStream inputStream = getClass().getClassLoader().getResourceAsStream(path)) {
            if (inputStream == null) {
                throw new IOException("Fixture not found: " + path);
            }
            return new String(inputStream.readAllBytes(), StandardCharsets.UTF_8);
        }
    }
}
