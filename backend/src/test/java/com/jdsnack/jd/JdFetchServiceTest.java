package com.jdsnack.jd;

import com.jdsnack.common.ApiException;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpHeaders;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Optional;

import javax.net.ssl.SSLSession;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class JdFetchServiceTest {

    @Test
    void supportedSaraminUrlReturnsFetchedResponse() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdHtmlExtractor extractor = new JdHtmlExtractor();
        JdFetchService service = new JdFetchService(httpClient, extractor);

        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(200, """
                        <html>
                          <head><title>백엔드 엔지니어 채용</title></head>
                          <body>
                            <section class="job-description">
                              <p>Spring Boot 기반 API 설계와 운영을 담당합니다.</p>
                              <p>MySQL 운영 경험이 필요합니다.</p>
                            </section>
                          </body>
                        </html>
                        """));

        JdFetchResponse response = service.fetch(new JdFetchRequest("https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=123456"));

        assertEquals("saramin", response.sourceSite());
        assertEquals("static-html", response.fetchMode());
    }

    @Test
    void localhostUrlIsRejected() {
        JdFetchService service = new JdFetchService(mock(HttpClient.class), new JdHtmlExtractor());

        ApiException exception = assertThrows(ApiException.class,
                () -> service.fetch(new JdFetchRequest("http://localhost:8080/internal")));

        assertEquals("INVALID_JD_URL", exception.errorCode().name());
    }

    @Test
    void privateIpUrlIsRejected() {
        JdFetchService service = new JdFetchService(mock(HttpClient.class), new JdHtmlExtractor());

        ApiException exception = assertThrows(ApiException.class,
                () -> service.fetch(new JdFetchRequest("https://192.168.0.10/job")));

        assertEquals("INVALID_JD_URL", exception.errorCode().name());
    }

    @Test
    void metadataIpUrlIsRejected() {
        JdFetchService service = new JdFetchService(mock(HttpClient.class), new JdHtmlExtractor());

        ApiException exception = assertThrows(ApiException.class,
                () -> service.fetch(new JdFetchRequest("http://169.254.169.254/latest/meta-data")));

        assertEquals("INVALID_JD_URL", exception.errorCode().name());
    }

    @Test
    void unsupportedDomainReturnsUnsupportedSource() {
        JdFetchService service = new JdFetchService(mock(HttpClient.class), new JdHtmlExtractor());

        ApiException exception = assertThrows(ApiException.class,
                () -> service.fetch(new JdFetchRequest("https://jobs.ashbyhq.com/company/backend")));

        assertEquals("JD_FETCH_UNSUPPORTED_SOURCE", exception.errorCode().name());
    }

    @Test
    void fetchIoFailureReturnsBadGateway() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdFetchService service = new JdFetchService(httpClient, new JdHtmlExtractor());
        doThrow(new IOException("timeout"))
                .when(httpClient)
                .send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));

        ApiException exception = assertThrows(ApiException.class,
                () -> service.fetch(new JdFetchRequest("https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=123456")));

        assertEquals("JD_FETCH_FAILED", exception.errorCode().name());
    }

    @Test
    void interruptedFetchReturnsBadGateway() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdFetchService service = new JdFetchService(httpClient, new JdHtmlExtractor());
        doThrow(new InterruptedException("interrupted"))
                .when(httpClient)
                .send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));

        ApiException exception = assertThrows(ApiException.class,
                () -> service.fetch(new JdFetchRequest("https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=123456")));

        assertEquals("JD_FETCH_FAILED", exception.errorCode().name());
    }

    @Test
    void nonSuccessfulHttpStatusReturnsBadGateway() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdFetchService service = new JdFetchService(httpClient, new JdHtmlExtractor());
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(302, "<html><body>redirect</body></html>"));

        ApiException exception = assertThrows(ApiException.class,
                () -> service.fetch(new JdFetchRequest("https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=123456")));

        assertEquals("JD_FETCH_FAILED", exception.errorCode().name());
    }

    @Test
    void oversizedResponseReturnsBadGateway() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdFetchService service = new JdFetchService(httpClient, new JdHtmlExtractor());
        String body = "a".repeat(1_000_001);
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(200, body));

        ApiException exception = assertThrows(ApiException.class,
                () -> service.fetch(new JdFetchRequest("https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=123456")));

        assertEquals("JD_FETCH_FAILED", exception.errorCode().name());
    }

    private HttpResponse<String> response(int statusCode, String body) {
        return new HttpResponse<>() {
            @Override
            public int statusCode() {
                return statusCode;
            }

            @Override
            public HttpRequest request() {
                return HttpRequest.newBuilder().uri(URI.create("https://www.saramin.co.kr")).build();
            }

            @Override
            public Optional<HttpResponse<String>> previousResponse() {
                return Optional.empty();
            }

            @Override
            public HttpHeaders headers() {
                return HttpHeaders.of(java.util.Map.of(), (a, b) -> true);
            }

            @Override
            public String body() {
                return body;
            }

            @Override
            public Optional<SSLSession> sslSession() {
                return Optional.empty();
            }

            @Override
            public URI uri() {
                return URI.create("https://www.saramin.co.kr");
            }

            @Override
            public HttpClient.Version version() {
                return HttpClient.Version.HTTP_1_1;
            }
        };
    }
}
