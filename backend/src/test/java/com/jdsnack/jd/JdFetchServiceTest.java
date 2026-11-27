package com.jdsnack.jd;

import com.jdsnack.common.ApiException;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.InputStream;
import java.io.ByteArrayInputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpHeaders;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.Optional;

import javax.net.ssl.SSLSession;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentCaptor.forClass;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
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
    void supportedJobKoreaUrlReturnsFetchedResponse() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdFetchService service = new JdFetchService(httpClient, new JdHtmlExtractor());
        String jobKoreaUrl = "https://www.jobkorea.co.kr/Recruit/GI_Read/123456";

        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(
                        200,
                        fixture("jd/fixtures/jobkorea-backend-engineer.html"),
                        URI.create(jobKoreaUrl)
                ));

        JdFetchResponse fetched = service.fetch(new JdFetchRequest(jobKoreaUrl));

        assertEquals("jobkorea", fetched.sourceSite());
        assertEquals("static-html", fetched.fetchMode());
        assertEquals(jobKoreaUrl, fetched.sourceUrl());
        assertTrue(fetched.jdText().contains("Spring Boot 기반 백엔드 API"));
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
    void saraminAjaxTemporaryAndPermanentRedirectsPreservePostAndFormBody() throws Exception {
        String url = "https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=123456";
        URI ajaxUri = URI.create("https://www.saramin.co.kr/zf_user/jobs/relay/view-ajax");
        for (int status : new int[]{307, 308}) {
            HttpClient client = mock(HttpClient.class);
            when(client.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                    .thenReturn(response(200, """
                            <html><body><div>추천공고만 표시되는 페이지입니다.</div></body></html>
                            """, URI.create(url)))
                    .thenReturn(response(status, "", ajaxUri, java.util.Map.of(
                            "Location", java.util.List.of("/zf_user/jobs/relay/view-ajax?redirected=1")
                    )))
                    .thenReturn(response(200, """
                            <div class="wrap_jv_cont"><div class="jv_cont jv_summary"><div class="cont">
                            <dl><dt>담당업무</dt><dd>Spring Boot 기반 API 설계와 Java 서비스 개발을 담당합니다.</dd></dl>
                            <dl><dt>자격요건</dt><dd>MySQL 운영 경험과 REST API 구현 경험이 필요합니다.</dd></dl>
                            <dl><dt>우대사항</dt><dd>테스트 자동화와 배포 경험을 우대합니다.</dd></dl>
                            </div></div></div>
                            """, URI.create("https://www.saramin.co.kr/zf_user/jobs/relay/view-ajax?redirected=1")));

            JdFetchResponse result = new JdFetchService(client, new JdHtmlExtractor())
                    .fetch(new JdFetchRequest(url));
            assertEquals("saramin", result.sourceSite());
            assertTrue(result.jdText().contains("Spring Boot 기반 API"));

            var requests = forClass(HttpRequest.class);
            verify(client, times(3)).send(requests.capture(), any(HttpResponse.BodyHandler.class));
            HttpRequest originalAjax = requests.getAllValues().get(1);
            HttpRequest redirectedAjax = requests.getAllValues().get(2);
            assertEquals("POST", originalAjax.method());
            assertEquals("POST", redirectedAjax.method(), "HTTP " + status);
            assertEquals("redirected=1", redirectedAjax.uri().getQuery());
            assertEquals(originalAjax.bodyPublisher().orElseThrow(),
                    redirectedAjax.bodyPublisher().orElseThrow(), "form body must be replayed");
            assertTrue(redirectedAjax.bodyPublisher().orElseThrow().contentLength() > 0);
            assertEquals("application/x-www-form-urlencoded; charset=UTF-8",
                    redirectedAjax.headers().firstValue("Content-Type").orElseThrow());
        }
    }

    @Test
    void saraminAjaxSeeOtherRedirectUsesGet() throws Exception {
        String url = "https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=123456";
        HttpClient client = mock(HttpClient.class);
        when(client.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(200, "<div>추천공고 목록</div>", URI.create(url)))
                .thenReturn(response(303, "",
                        URI.create("https://www.saramin.co.kr/zf_user/jobs/relay/view-ajax"),
                        java.util.Map.of("Location", java.util.List.of("/zf_user/jobs/relay/view-detail?rec_idx=123456"))))
                .thenReturn(response(200, """
                        <div class="user_content">
                        <h3>주요업무</h3><p>Java Spring Boot API 개발을 담당합니다.</p>
                        <h3>자격요건</h3><p>SQL과 백엔드 서비스 운영 경험을 요구합니다.</p>
                        <h3>우대사항</h3><p>테스트 자동화 경험을 우대합니다.</p></div>
                        """, URI.create("https://www.saramin.co.kr/zf_user/jobs/relay/view-detail?rec_idx=123456")));
        JdFetchResponse result = new JdFetchService(client, new JdHtmlExtractor())
                .fetch(new JdFetchRequest(url));
        assertEquals("saramin", result.sourceSite());
        var requests = forClass(HttpRequest.class);
        verify(client, times(3)).send(requests.capture(), any(HttpResponse.BodyHandler.class));
        HttpRequest redirected = requests.getAllValues().get(2);
        assertEquals("GET", redirected.method());
        assertTrue(redirected.bodyPublisher().isEmpty());
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
    void unsupportedDomainReturnsUnsupportedSource() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdFetchService service = new JdFetchService(httpClient, new JdHtmlExtractor());

        ApiException exception = assertThrows(ApiException.class,
                () -> service.fetch(new JdFetchRequest("https://jobs.ashbyhq.com/company/backend")));

        assertEquals("JD_FETCH_UNSUPPORTED_SOURCE", exception.errorCode().name());
        verify(httpClient, never()).send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));
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

    @Test
    void missingHtmlContentTypeIsRejectedWithoutParsingBody() throws Exception {
        String url = "https://www.wanted.co.kr/wd/400228";
        HttpClient client = mock(HttpClient.class);
        when(client.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(200, fixture("jd/fixtures/wanted-static.html"),
                        URI.create(url), java.util.Map.of()));

        ApiException error = assertThrows(ApiException.class, () ->
                new JdFetchService(client, new JdHtmlExtractor()).fetch(new JdFetchRequest(url)));
        assertEquals("JD_FETCH_FAILED", error.errorCode().name());
        verify(client, times(1)).send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));
    }

    @Test
    void redirectOutsideAllowlistReturnsBadGateway() throws Exception {
        HttpClient httpClient = mock(HttpClient.class);
        JdFetchService service = new JdFetchService(httpClient, new JdHtmlExtractor());
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(
                        200,
                        fixture("jd/fixtures/jobkorea-backend-engineer.html"),
                        URI.create("https://example.com/jobs/redirected")
                ));

        ApiException exception = assertThrows(ApiException.class,
                () -> service.fetch(new JdFetchRequest("https://jobkorea.co.kr/Recruit/GI_Read/123456")));

        assertEquals("JD_FETCH_FAILED", exception.errorCode().name());
    }

    @Test
    void wantedStaticHtmlReturnsJobDescriptionWithoutRecommendationNoise() throws Exception {
        String url = "https://www.wanted.co.kr/wd/400228";
        HttpClient http = mock(HttpClient.class);
        when(http.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(200, fixture("jd/fixtures/wanted-static.html"), URI.create(url)));

        JdFetchResponse result = new JdFetchService(http, new JdHtmlExtractor())
                .fetch(new JdFetchRequest(url));

        assertEquals("wanted", result.sourceSite());
        assertEquals("static-html", result.fetchMode());
        assertEquals(url, result.sourceUrl());
        assertTrue(result.jdText().contains("Spring Boot 기반 REST API"));
        assertTrue(result.jdText().contains("MySQL 데이터베이스 설계"));
        assertTrue(!result.jdText().contains("추천 채용공고"));
        assertTrue(!result.jdText().contains("예비 텍스트"));
    }

    @Test
    void wantedNextDataExtractsActualJobSectionsWithoutRenderedArticle() throws Exception {
        String url = "https://www.wanted.co.kr/wd/400228?ref=bookmark";
        HttpClient http = mock(HttpClient.class);
        when(http.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(200, fixture("jd/fixtures/wanted-next-data.html"), URI.create(url)));

        JdFetchResponse result = new JdFetchService(http, new JdHtmlExtractor())
                .fetch(new JdFetchRequest(url));

        assertEquals("wanted", result.sourceSite());
        assertEquals("static-html", result.fetchMode());
        assertTrue(result.jdText().contains("Spring Boot를 사용하여 서버 API"));
        assertTrue(result.jdText().contains("클라우드 서비스 운영 경험"));
        assertTrue(!result.jdText().contains("맞춤 공고 추천"));
    }

    @Test
    void wantedClosedPostingIsNeverReportedAsSuccessful() throws Exception {
        String url = "https://www.wanted.co.kr/wd/400228";
        HttpClient http = mock(HttpClient.class);
        when(http.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(200, fixture("jd/fixtures/wanted-closed.html"), URI.create(url)));

        ApiException error = assertThrows(ApiException.class, () ->
                new JdFetchService(http, new JdHtmlExtractor()).fetch(new JdFetchRequest(url)));
        assertEquals("JD_FETCH_UNSUPPORTED_SOURCE", error.errorCode().name());
    }

    @Test
    void wantedRecommendationOnlyIsNotAcceptedAsJd() throws Exception {
        String url = "https://www.wanted.co.kr/wd/400228";
        HttpClient http = mock(HttpClient.class);
        when(http.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(200,
                        "<html><body><main>원티드 채용 공고를 추천해드리는 서비스입니다. "
                                + "지원하기 추천 포지션을 확인하세요.</main></body></html>", URI.create(url)));

        ApiException error = assertThrows(ApiException.class, () ->
                new JdFetchService(http, new JdHtmlExtractor()).fetch(new JdFetchRequest(url)));
        assertEquals("JD_FETCH_UNSUPPORTED_SOURCE", error.errorCode().name());
    }

    @Test
    void wantedPostingWithoutVerifiedActiveStatusIsRejected() throws Exception {
        String url = "https://www.wanted.co.kr/wd/400228";
        HttpClient client = mock(HttpClient.class);
        String html = fixture("jd/fixtures/wanted-static.html")
                .replace("\"status\":\"active\"", "\"status\":\"\"");
        when(client.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(200, html, URI.create(url)));
        ApiException error = assertThrows(ApiException.class, () ->
                new JdFetchService(client, new JdHtmlExtractor()).fetch(new JdFetchRequest(url)));
        assertEquals("JD_FETCH_UNSUPPORTED_SOURCE", error.errorCode().name());
    }

    @Test
    void wantedOnlyAcceptsNumericPostingPathsAndExactHosts() throws Exception {
        HttpClient http = mock(HttpClient.class);
        JdFetchService service = new JdFetchService(http, new JdHtmlExtractor());
        for (String url : java.util.List.of(
                "https://www.wanted.co.kr/jobs",
                "https://www.wanted.co.kr/wd/not-a-number",
                "https://wanted.co.kr.evil.example/wd/400228",
                "https://www.wanted.co.kr:8443/wd/400228",
                "https://127.0.0.1/wd/400228"
        )) {
            assertThrows(ApiException.class, () -> service.fetch(new JdFetchRequest(url)), url);
        }
        verify(http, never()).send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));
    }

    @Test
    void wantedHtmlRedirectToPrivateOrExternalUrlIsBlockedBeforeSecondRequest() throws Exception {
        String url = "https://www.wanted.co.kr/wd/400228";
        for (String destination : java.util.List.of("http://127.0.0.1/private", "https://evil.example.com/jd")) {
            HttpClient http = mock(HttpClient.class);
            when(http.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                    .thenReturn(new HttpResponse<InputStream>() {
                        public int statusCode() { return 302; }
                        public InputStream body() { return new ByteArrayInputStream(new byte[0]); }
                        public HttpRequest request() { return HttpRequest.newBuilder().uri(URI.create(url)).build(); }
                        public Optional<HttpResponse<InputStream>> previousResponse() { return Optional.empty(); }
                        public HttpHeaders headers() { return HttpHeaders.of(java.util.Map.of("Location", java.util.List.of(destination)), (a, b) -> true); }
                        public Optional<SSLSession> sslSession() { return Optional.empty(); }
                        public URI uri() { return URI.create(url); }
                        public HttpClient.Version version() { return HttpClient.Version.HTTP_1_1; }
                    });
            ApiException error = assertThrows(ApiException.class, () ->
                    new JdFetchService(http, new JdHtmlExtractor()).fetch(new JdFetchRequest(url)));
            assertEquals("JD_FETCH_FAILED", error.errorCode().name());
            verify(http, times(1)).send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));
        }
    }

    @Test
    void wantedRedirectAllowsTrailingSlashNormalizationForSamePosting() throws Exception {
        String original = "https://www.wanted.co.kr/wd/400228";
        for (String from : java.util.List.of(original, original + "/")) {
            String to = from.endsWith("/") ? original : original + "/";
            URI source = URI.create(from);
            URI destination = URI.create(to);
            HttpClient http = mock(HttpClient.class);
            when(http.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                    .thenReturn(response(301, "", source, java.util.Map.of(
                            "Location", java.util.List.of(to)
                    )))
                    .thenReturn(response(200, fixture("jd/fixtures/wanted-static.html"), destination));

            JdFetchResponse result = new JdFetchService(http, new JdHtmlExtractor())
                    .fetch(new JdFetchRequest(from));

            assertEquals("wanted", result.sourceSite());
            assertEquals(from, result.sourceUrl());
            assertTrue(result.jdText().contains("Spring Boot 기반 REST API"));
            var requests = forClass(HttpRequest.class);
            verify(http, times(2)).send(requests.capture(), any(HttpResponse.BodyHandler.class));
            assertEquals(destination, requests.getAllValues().get(1).uri());
        }
    }

    @Test
    void wantedRedirectToDifferentPostingIdIsRejectedBeforeSecondRequest() throws Exception {
        String original = "https://www.wanted.co.kr/wd/400228/";
        HttpClient http = mock(HttpClient.class);
        when(http.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(response(302, "", URI.create(original), java.util.Map.of(
                        "Location", java.util.List.of("/wd/400229")
                )));

        ApiException error = assertThrows(ApiException.class, () ->
                new JdFetchService(http, new JdHtmlExtractor()).fetch(new JdFetchRequest(original)));
        assertEquals("JD_FETCH_FAILED", error.errorCode().name());
        verify(http, times(1)).send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));
    }

    private HttpResponse<InputStream> response(int statusCode, String body) {
        return response(statusCode, body, URI.create("https://www.saramin.co.kr"));
    }

    @Test
    void rejectsOversizedHtmlWhileReadingAndClosesResponseBody() throws Exception {
        HttpClient client = mock(HttpClient.class);
        String url = "https://www.wanted.co.kr/wd/400228";
        java.io.InputStream largeBody = new java.io.InputStream() {
            private int readCount;
            private boolean closed;

            @Override
            public int read() {
                if (closed) {
                    throw new IllegalStateException("body already closed");
                }
                readCount++;
                if (readCount > 1_000_001) {
                    throw new IllegalStateException("read exceeded bound");
                }
                return 'x';
            }

            @Override
            public void close() {
                closed = true;
            }
        };
        HttpResponse<InputStream> response = new HttpResponse<>() {
            public int statusCode() { return 200; }
            public HttpRequest request() { return HttpRequest.newBuilder(URI.create(url)).build(); }
            public Optional<HttpResponse<InputStream>> previousResponse() { return Optional.empty(); }
            public HttpHeaders headers() { return HttpHeaders.of(java.util.Map.of("Content-Type", java.util.List.of("text/html")), (a, b) -> true); }
            public InputStream body() { return largeBody; }
            public Optional<SSLSession> sslSession() { return Optional.empty(); }
            public URI uri() { return URI.create(url); }
            public HttpClient.Version version() { return HttpClient.Version.HTTP_1_1; }
        };
        when(client.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(response);
        ApiException error = assertThrows(ApiException.class, () ->
                new JdFetchService(client, new JdHtmlExtractor()).fetch(new JdFetchRequest(url)));
        assertEquals("JD_FETCH_FAILED", error.errorCode().name());
        assertThrows(IllegalStateException.class, largeBody::read);
    }

    private HttpResponse<InputStream> response(int statusCode, String body, URI responseUri) {
        return response(statusCode, body, responseUri,
                java.util.Map.of("Content-Type", java.util.List.of("text/html; charset=UTF-8")));
    }

    private HttpResponse<InputStream> response(int statusCode, String body, URI responseUri,
                                                java.util.Map<String, java.util.List<String>> headers) {
        return new HttpResponse<>() {
            @Override
            public int statusCode() {
                return statusCode;
            }

            @Override
            public HttpRequest request() {
                return HttpRequest.newBuilder().uri(responseUri).build();
            }

            @Override
            public Optional<HttpResponse<InputStream>> previousResponse() {
                return Optional.empty();
            }

            @Override
            public HttpHeaders headers() {
                return HttpHeaders.of(headers, (a, b) -> true);
            }

            @Override
            public InputStream body() {
                return new ByteArrayInputStream(body.getBytes(StandardCharsets.UTF_8));
            }

            @Override
            public Optional<SSLSession> sslSession() {
                return Optional.empty();
            }

            @Override
            public URI uri() {
                return responseUri;
            }

            @Override
            public HttpClient.Version version() {
                return HttpClient.Version.HTTP_1_1;
            }
        };
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
