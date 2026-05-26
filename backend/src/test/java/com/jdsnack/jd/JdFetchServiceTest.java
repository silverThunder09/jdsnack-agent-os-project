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
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentCaptor.forClass;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
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
    void saraminRelayViewFallsBackToAjaxWhenStaticPageHasNoJobDetail() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdFetchService service = new JdFetchService(httpClient, new JdHtmlExtractor());

        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(200, """
                        <html>
                          <head><title>[(주)테스트] 백엔드 개발자 채용 - 사람인</title></head>
                          <body>
                            <div class="jview_wing">사람인 인공지능 기술 기반으로 맞춤 공고를 추천해드리는 서비스입니다.</div>
                          </body>
                        </html>
                        """))
                .thenReturn(response(200, """
                        <div class="wrap_jv_cont">
                          <h1 class="tit_job">백엔드 개발자 채용</h1>
                          <div class="jv_cont jv_summary">
                            <div class="cont">
                              <dl><dt>담당업무</dt><dd>Spring Boot 기반 API 설계와 Java 서비스 개발을 담당합니다.</dd></dl>
                              <dl><dt>자격요건</dt><dd>MySQL 운영 경험과 REST API 구현 경험이 필요합니다.</dd></dl>
                              <dl><dt>우대사항</dt><dd>테스트 자동화와 배포 경험을 우대합니다.</dd></dl>
                            </div>
                          </div>
                        </div>
                        """));

        JdFetchResponse response = service.fetch(new JdFetchRequest(
                "https://www.saramin.co.kr/zf_user/jobs/relay/view?view_type=search&rec_idx=53864907&t_ref=search&t_ref_content=generic"
        ));

        assertEquals("saramin", response.sourceSite());
        assertEquals("static-html", response.fetchMode());
        assertTrue(response.jdText().contains("Spring Boot 기반 API 설계"));

        var requestCaptor = forClass(HttpRequest.class);
        verify(httpClient, times(2)).send(requestCaptor.capture(), any(HttpResponse.BodyHandler.class));
        HttpRequest ajaxRequest = requestCaptor.getAllValues().get(1);
        assertEquals("POST", ajaxRequest.method());
        assertEquals("/zf_user/jobs/relay/view-ajax", ajaxRequest.uri().getPath());
    }

    @Test
    void saraminRelayViewLoadsDetailIframeWhenAjaxUsesIframeContent() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdFetchService service = new JdFetchService(httpClient, new JdHtmlExtractor());

        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(200, """
                        <html>
                          <head><title>[(주)테스트] 자바 클라이언트 개발 - 사람인</title></head>
                          <body>
                            <div class="jview_wing">사람인 인공지능 기술 기반으로 맞춤 공고를 추천해드리는 서비스입니다.</div>
                          </body>
                        </html>
                        """))
                .thenReturn(response(200, """
                        <div class="wrap_jv_cont">
                          <div class="jv_cont jv_detail">
                            <iframe class="iframe_content" src="/zf_user/jobs/relay/view-detail?rec_idx=53815724&rec_seq=0&t_ref=search"></iframe>
                          </div>
                        </div>
                        """))
                .thenReturn(response(200, """
                        <html>
                          <body>
                            <div class="user_content">
                              <h3>주요업무</h3>
                              <pre>LG U+ 기업메시징 자바 클라이언트 아키텍처 설계 및 개발을 담당합니다.</pre>
                              <h3>자격요건</h3>
                              <pre>Java 17, Spring Boot 3, Gradle 기반 상용 서비스 개발 및 운영 경험이 필요합니다.</pre>
                              <h3>우대사항</h3>
                              <pre>JUnit5 테스트 자동화와 Pull Request 기반 코드리뷰 경험을 우대합니다.</pre>
                            </div>
                          </body>
                        </html>
                        """));

        JdFetchResponse response = service.fetch(new JdFetchRequest(
                "https://www.saramin.co.kr/zf_user/jobs/relay/view?view_type=search&rec_idx=53815724&t_ref=search&t_ref_content=generic"
        ));

        assertEquals("saramin", response.sourceSite());
        assertTrue(response.jdText().contains("기업메시징 자바 클라이언트"));
        assertTrue(response.jdText().contains("Spring Boot 3"));

        var requestCaptor = forClass(HttpRequest.class);
        verify(httpClient, times(3)).send(requestCaptor.capture(), any(HttpResponse.BodyHandler.class));
        assertEquals("/zf_user/jobs/relay/view-detail", requestCaptor.getAllValues().get(2).uri().getPath());
    }

    @Test
    void saraminRelayViewLoadsDirectDetailWhenAjaxHasNoJobDetail() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdFetchService service = new JdFetchService(httpClient, new JdHtmlExtractor());

        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(200, """
                        <html>
                          <head><title>[(주)이노시스컴퍼니] JAVA 신입/경력 개발자 모집 - 사람인</title></head>
                          <body>
                            <div class="jview_wing">사람인 인공지능 기술 기반으로 맞춤 공고를 추천해드리는 서비스입니다.</div>
                            <footer>개인정보 보호 채용 절차 안내</footer>
                          </body>
                        </html>
                        """))
                .thenReturn(response(200, """
                        <div class="relay-empty">
                          <p>개인정보 보호 채용 절차 안내와 AI매치 추천공고만 표시됩니다.</p>
                        </div>
                        """))
                .thenReturn(response(200, """
                        <html>
                          <body>
                            <div class="user_content">
                              <h3>주요업무</h3>
                              <pre>JAVA 기반 기업 메시징 서비스 클라이언트와 서버 API를 개발합니다.</pre>
                              <h3>자격요건</h3>
                              <pre>Java, Spring Framework, SQL 기반 웹 서비스 개발 경험이 필요합니다.</pre>
                              <h3>우대사항</h3>
                              <pre>운영 환경 장애 대응과 Git 기반 협업 경험을 우대합니다.</pre>
                            </div>
                          </body>
                        </html>
                        """));

        JdFetchResponse response = service.fetch(new JdFetchRequest(
                "https://www.saramin.co.kr/zf_user/jobs/relay/view?view_type=search&rec_idx=53815724&location=ts&searchword=%EC%9E%90%EB%B0%94&searchType=recently&paid_fl=n&search_uuid=ffa67e8c-4ae8-4f89-94ea-2dd1cedaa968&t_ref=search&t_ref_content=generic#seq=0"
        ));

        assertEquals("saramin", response.sourceSite());
        assertTrue(response.jdText().contains("기업 메시징 서비스"));
        assertTrue(response.jdText().contains("Spring Framework"));

        var requestCaptor = forClass(HttpRequest.class);
        verify(httpClient, times(3)).send(requestCaptor.capture(), any(HttpResponse.BodyHandler.class));
        HttpRequest detailRequest = requestCaptor.getAllValues().get(2);
        assertEquals("GET", detailRequest.method());
        assertEquals("/zf_user/jobs/relay/view-detail", detailRequest.uri().getPath());
        assertEquals("rec_idx=53815724&rec_seq=0&t_ref=search&t_ref_content=generic", detailRequest.uri().getQuery());
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
