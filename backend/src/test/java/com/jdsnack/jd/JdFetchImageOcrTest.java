package com.jdsnack.jd;

import com.jdsnack.common.ApiException;
import org.junit.jupiter.api.Test;

import javax.net.ssl.SSLSession;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpHeaders;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class JdFetchImageOcrTest {

    private static final String JOB_URL = "https://www.saramin.co.kr/zf_user/jobs/view?rec_idx=123";
    private static final String IMAGE_HTML = """
            <html><head><title>백엔드 개발자 채용</title></head><body>
              <div class="user_content"><img src="/images/jd.png" width="1200" height="2400"></div>
            </body></html>
            """;
    private static final String OCR_TEXT =
            "주요업무 Java Spring Boot 기반 API를 개발하고 운영합니다. 자격요건 테스트 자동화와 장애 대응 경험이 필요합니다.";

    @Test
    void textExtractionSuccessDoesNotInvokeOcr() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdImageOcr ocr = mock(JdImageOcr.class);
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(htmlResponse("""
                        <section class="job-description">
                          <h2>주요업무</h2>
                          <p>Java와 Spring Boot 기반 백엔드 API를 설계하고 운영 서비스를 개발합니다.</p>
                          <h2>자격요건</h2>
                          <p>MySQL 데이터베이스 운영, 테스트 자동화, 배포 및 장애 대응 경험이 필요합니다.</p>
                          <h2>우대사항</h2>
                          <p>협업을 통한 플랫폼 아키텍처 개선 경험을 우대합니다.</p>
                        </section>
                        """, URI.create(JOB_URL)));
        JdFetchService service = new JdFetchService(httpClient, new JdHtmlExtractor(), ocr);

        JdFetchResponse result = service.fetch(new JdFetchRequest(JOB_URL));

        assertThat(result.fetchMode()).isEqualTo("static-html");
        verify(ocr, never()).isAvailable();
        verify(ocr, never()).extractText(any(), any());
    }

    @Test
    void imageOnlyPostingUsesRelativeImageAndReturnsImageOcrMode() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdImageOcr ocr = mock(JdImageOcr.class);
        when(ocr.isAvailable()).thenReturn(true);
        when(ocr.extractText(any(), any())).thenReturn(OCR_TEXT);
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenAnswer(invocation -> responseFor(invocation.getArgument(0), "image/png", new byte[]{1, 2, 3}));
        JdFetchService service = new JdFetchService(httpClient, new JdHtmlExtractor(), ocr);

        JdFetchResponse result = service.fetch(new JdFetchRequest(JOB_URL));

        assertThat(result.fetchMode()).isEqualTo("image-ocr");
        assertThat(result.sourceSite()).isEqualTo("saramin");
        assertThat(result.jdText()).isEqualTo(OCR_TEXT);
        verify(ocr).extractText(new byte[]{1, 2, 3}, "image/png");
        var requestCaptor = org.mockito.ArgumentCaptor.forClass(HttpRequest.class);
        verify(httpClient, times(2)).send(requestCaptor.capture(), any(HttpResponse.BodyHandler.class));
        assertThat(requestCaptor.getAllValues().get(1).uri())
                .isEqualTo(URI.create("https://www.saramin.co.kr/images/jd.png"));
    }

    @Test
    void relayFallbackReusesDetailHtmlAndSelectsLargestImage() throws Exception {
        String relayUrl = "https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=123";
        String detailHtml = """
                <div class="wrap_jv_cont"><div class="user_content">
                  <img src="/images/logo.png" width="100" height="50">
                  <img src="/images/full-jd.png" width="1200" height="2400">
                </div></div>
                """;
        HttpClient httpClient = mock(HttpClient.class);
        JdImageOcr ocr = mock(JdImageOcr.class);
        when(ocr.isAvailable()).thenReturn(true);
        when(ocr.extractText(any(), any())).thenReturn(OCR_TEXT);
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenAnswer(invocation -> {
                    HttpRequest request = invocation.getArgument(0);
                    return switch (request.uri().getPath()) {
                        case "/zf_user/jobs/relay/view" -> htmlResponse(
                                "<div class=\"jview_wing\">추천 공고 안내</div>",
                                URI.create(relayUrl)
                        );
                        case "/zf_user/jobs/relay/view-ajax" -> htmlResponse(
                                "<div class=\"relay-empty\">채용 절차 안내</div>",
                                request.uri()
                        );
                        case "/zf_user/jobs/relay/view-detail" -> htmlResponse(detailHtml, request.uri());
                        case "/images/full-jd.png" -> imageResponse("image/png", new byte[]{4, 5, 6}, request.uri());
                        default -> throw new AssertionError("unexpected request: " + request.uri());
                    };
                });

        JdFetchResponse result = new JdFetchService(httpClient, new JdHtmlExtractor(), ocr)
                .fetch(new JdFetchRequest(relayUrl));

        assertThat(result.fetchMode()).isEqualTo("image-ocr");
        verify(ocr).extractText(new byte[]{4, 5, 6}, "image/png");
    }

    @Test
    void unsafeAndUntrustedImageHostsAreNeverDownloaded() throws Exception {
        for (String imageUrl : List.of(
                "http://127.0.0.1/private.png",
                "https://evil.example.com/jd.png"
        )) {
            HttpClient httpClient = mock(HttpClient.class);
            JdImageOcr ocr = availableOcr();
            when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                    .thenReturn(htmlResponse(imageHtml(imageUrl), URI.create(JOB_URL)));
            JdFetchService service = new JdFetchService(httpClient, new JdHtmlExtractor(), ocr);

            assertThrows(ApiException.class, () -> service.fetch(new JdFetchRequest(JOB_URL)));
            verify(httpClient).send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));
            verify(ocr, never()).extractText(any(), any());
        }
    }

    @Test
    void missingOrDataImagesSkipOcr() throws Exception {
        for (String html : List.of(
                "<div class=\"user_content\"></div>",
                "<div class=\"user_content\"><img src=\"data:image/png;base64,AQID\"></div>"
        )) {
            HttpClient httpClient = mock(HttpClient.class);
            JdImageOcr ocr = availableOcr();
            when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                    .thenReturn(htmlResponse(html, URI.create(JOB_URL)));

            assertThrows(ApiException.class, () ->
                    new JdFetchService(httpClient, new JdHtmlExtractor(), ocr).fetch(new JdFetchRequest(JOB_URL)));
            verify(ocr, never()).extractText(any(), any());
        }
    }

    @Test
    void invalidContentTypeAndOversizedImagesFallBackToOriginalError() throws Exception {
        assertRejectedImage("text/html", new byte[]{1, 2, 3});
        assertRejectedImage("image/png", new byte[8 * 1024 * 1024 + 1]);
    }

    @Test
    void missingKeyOrOcrFailurePreservesOriginalError() throws Exception {
        HttpClient unavailableClient = mock(HttpClient.class);
        JdImageOcr unavailableOcr = mock(JdImageOcr.class);
        when(unavailableOcr.isAvailable()).thenReturn(false);
        when(unavailableClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(htmlResponse(IMAGE_HTML, URI.create(JOB_URL)));

        ApiException unavailableError = assertThrows(ApiException.class, () ->
                new JdFetchService(unavailableClient, new JdHtmlExtractor(), unavailableOcr)
                        .fetch(new JdFetchRequest(JOB_URL)));
        assertThat(unavailableError.errorCode().name()).isEqualTo("JD_FETCH_UNSUPPORTED_SOURCE");
        verify(unavailableClient).send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));

        HttpClient failingClient = mock(HttpClient.class);
        JdImageOcr failingOcr = availableOcr();
        when(failingOcr.extractText(any(), any())).thenThrow(new IllegalStateException("ocr failed"));
        when(failingClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenAnswer(invocation -> responseFor(invocation.getArgument(0), "image/png", new byte[]{1}));

        ApiException failedError = assertThrows(ApiException.class, () ->
                new JdFetchService(failingClient, new JdHtmlExtractor(), failingOcr)
                        .fetch(new JdFetchRequest(JOB_URL)));
        assertThat(failedError.errorCode().name()).isEqualTo("JD_FETCH_UNSUPPORTED_SOURCE");
    }

    @Test
    void redirectedImageMustStillEndOnTrustedHost() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdImageOcr ocr = availableOcr();
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenAnswer(invocation -> {
                    HttpRequest request = invocation.getArgument(0);
                    if (!request.uri().getPath().endsWith(".png")) {
                        return htmlResponse(IMAGE_HTML, URI.create(JOB_URL));
                    }
                    return imageResponse("image/png", new byte[]{1}, URI.create("https://evil.example.com/jd.png"));
                });

        assertThrows(ApiException.class, () ->
                new JdFetchService(httpClient, new JdHtmlExtractor(), ocr).fetch(new JdFetchRequest(JOB_URL)));
        verify(ocr, never()).extractText(any(), any());
    }

    @Test
    void untrustedRedirectIsRejectedBeforeFollowingLocation() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdImageOcr ocr = availableOcr();
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenAnswer(invocation -> {
                    HttpRequest request = invocation.getArgument(0);
                    if (!request.uri().getPath().endsWith(".png")) {
                        return htmlResponse(IMAGE_HTML, URI.create(JOB_URL));
                    }
                    return new TestResponse<>(
                            302,
                            new ByteArrayInputStream(new byte[0]),
                            request.uri(),
                            Map.of("Location", List.of("http://127.0.0.1/private.png"))
                    );
                });

        assertThrows(ApiException.class, () ->
                new JdFetchService(httpClient, new JdHtmlExtractor(), ocr).fetch(new JdFetchRequest(JOB_URL)));
        verify(httpClient, times(2)).send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));
        verify(ocr, never()).extractText(any(), any());
    }

    @Test
    void trustedRedirectIsFollowedAfterValidation() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdImageOcr ocr = mock(JdImageOcr.class);
        when(ocr.isAvailable()).thenReturn(true);
        when(ocr.extractText(any(), any())).thenReturn(OCR_TEXT);
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenAnswer(invocation -> {
                    HttpRequest request = invocation.getArgument(0);
                    if (!request.uri().getPath().endsWith(".png")) {
                        return htmlResponse(IMAGE_HTML, URI.create(JOB_URL));
                    }
                    if (request.uri().getHost().equals("www.saramin.co.kr")) {
                        return new TestResponse<>(
                                302,
                                new ByteArrayInputStream(new byte[0]),
                                request.uri(),
                                Map.of("Location", List.of("https://cdn.saramin.co.kr/final.png"))
                        );
                    }
                    return imageResponse("image/png", new byte[]{7, 8}, request.uri());
                });

        JdFetchResponse result = new JdFetchService(httpClient, new JdHtmlExtractor(), ocr)
                .fetch(new JdFetchRequest(JOB_URL));

        assertThat(result.fetchMode()).isEqualTo("image-ocr");
        verify(ocr).extractText(new byte[]{7, 8}, "image/png");
    }

    private void assertRejectedImage(String mimeType, byte[] bytes) throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdImageOcr ocr = availableOcr();
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenAnswer(invocation -> responseFor(invocation.getArgument(0), mimeType, bytes));

        assertThrows(ApiException.class, () ->
                new JdFetchService(httpClient, new JdHtmlExtractor(), ocr).fetch(new JdFetchRequest(JOB_URL)));
        verify(ocr, never()).extractText(any(), any());
    }

    private JdImageOcr availableOcr() {
        JdImageOcr ocr = mock(JdImageOcr.class);
        when(ocr.isAvailable()).thenReturn(true);
        return ocr;
    }

    private Object responseFor(HttpRequest request, String mimeType, byte[] bytes) {
        if (request.uri().getPath().endsWith(".png")) {
            return imageResponse(mimeType, bytes, request.uri());
        }
        return htmlResponse(IMAGE_HTML, URI.create(JOB_URL));
    }

    private String imageHtml(String source) {
        return "<div class=\"user_content\"><img src=\"" + source + "\"></div>";
    }

    private HttpResponse<String> htmlResponse(String body, URI uri) {
        return new TestResponse<>(200, body, uri, Map.of());
    }

    private HttpResponse<InputStream> imageResponse(String mimeType, byte[] bytes, URI uri) {
        return new TestResponse<>(
                200,
                new ByteArrayInputStream(bytes),
                uri,
                Map.of("Content-Type", List.of(mimeType))
        );
    }

    private record TestResponse<T>(
            int statusCode,
            T body,
            URI uri,
            Map<String, List<String>> headerValues
    ) implements HttpResponse<T> {
        @Override
        public HttpRequest request() {
            return HttpRequest.newBuilder().uri(uri).build();
        }

        @Override
        public Optional<HttpResponse<T>> previousResponse() {
            return Optional.empty();
        }

        @Override
        public HttpHeaders headers() {
            return HttpHeaders.of(headerValues, (a, b) -> true);
        }

        @Override
        public Optional<SSLSession> sslSession() {
            return Optional.empty();
        }

        @Override
        public HttpClient.Version version() {
            return HttpClient.Version.HTTP_1_1;
        }
    }
}
