package com.jdsnack.jd;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Element;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

@Service
public class JdFetchService {

    private static final int MAX_RESPONSE_BODY_LENGTH = 1_000_000;
    private static final int MAX_PAGE_REDIRECTS = 3;
    private final HttpClient httpClient;
    private final HttpClient imageHttpClient;
    private final JdHtmlExtractor jdHtmlExtractor;
    private final JdImageOcrFallback imageOcrFallback;
    private final WantedJdSourceAdapter wantedAdapter = new WantedJdSourceAdapter();

    @Autowired
    public JdFetchService(JdHtmlExtractor jdHtmlExtractor, JdImageOcr jdImageOcr) {
        this(
                HttpClient.newBuilder()
                        .connectTimeout(Duration.ofSeconds(10))
                        .followRedirects(HttpClient.Redirect.NEVER)
                        .build(),
                HttpClient.newBuilder()
                        .connectTimeout(Duration.ofSeconds(10))
                        .followRedirects(HttpClient.Redirect.NEVER)
                        .build(),
                jdHtmlExtractor,
                jdImageOcr
        );
    }

    JdFetchService(HttpClient httpClient, JdHtmlExtractor jdHtmlExtractor) {
        this(httpClient, jdHtmlExtractor, new JdImageOcr() {
            @Override
            public boolean isAvailable() {
                return false;
            }

            @Override
            public String extractText(byte[] imageBytes, String mimeType) {
                return "";
            }
        });
    }

    JdFetchService(HttpClient httpClient, JdHtmlExtractor jdHtmlExtractor, JdImageOcr jdImageOcr) {
        this(httpClient, httpClient, jdHtmlExtractor, jdImageOcr);
    }

    JdFetchService(
            HttpClient httpClient,
            HttpClient imageHttpClient,
            JdHtmlExtractor jdHtmlExtractor,
            JdImageOcr jdImageOcr
    ) {
        this.httpClient = httpClient;
        this.imageHttpClient = imageHttpClient;
        this.jdHtmlExtractor = jdHtmlExtractor;
        this.imageOcrFallback = new JdImageOcrFallback(imageHttpClient, jdHtmlExtractor, jdImageOcr);
    }

    public JdFetchResponse fetch(JdFetchRequest request) {
        URI uri = validateUrl(request);
        String jdUrl = uri.toString();
        String sourceSite = sourceSiteFor(uri);
        List<FetchedHtml> fetchedPages = new ArrayList<>();

        try {
            FetchedHtml page = fetchHtml(buildPageRequest(uri));
            fetchedPages.add(page);
            if ("wanted".equals(sourceSite)) {
                wantedAdapter.verifyAvailable(page.html());
            }
            try {
                return jdHtmlExtractor.extract(page.html(), jdUrl);
            } catch (ApiException exception) {
                if (!shouldTrySaraminAjaxFallback(exception, uri)) {
                    Optional<JdFetchResponse> ocrResponse = imageOcrFallback.tryExtract(fetchedPages, jdUrl, sourceSite);
                    if (ocrResponse.isPresent()) {
                        return ocrResponse.get();
                    }
                    throw exception;
                }
                try {
                    return fetchSaraminFallback(uri, jdUrl, exception, fetchedPages);
                } catch (ApiException fallbackException) {
                    Optional<JdFetchResponse> ocrResponse = imageOcrFallback.tryExtract(fetchedPages, jdUrl, sourceSite);
                    if (ocrResponse.isPresent()) {
                        return ocrResponse.get();
                    }
                    throw fallbackException;
                }
            }
        } catch (ApiException exception) {
            throw exception;
        } catch (IOException exception) {
            throw new ApiException(ErrorCode.JD_FETCH_FAILED, exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new ApiException(ErrorCode.JD_FETCH_FAILED, exception);
        }
    }

    private HttpRequest buildPageRequest(URI uri) {
        return HttpRequest.newBuilder()
                .uri(uri)
                .timeout(Duration.ofSeconds(15))
                .header("User-Agent", "Mozilla/5.0 (compatible; JDSnack/1.0)")
                .header("Accept", "text/html,application/xhtml+xml")
                .header("Accept-Language", "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7")
                .GET()
                .build();
    }

    private JdFetchResponse fetchSaraminFallback(
            URI uri,
            String jdUrl,
            ApiException originalException,
            List<FetchedHtml> fetchedPages
    )
            throws IOException, InterruptedException {
        ApiException lastException = originalException;

        try {
            FetchedHtml ajaxPage = fetchHtml(buildSaraminAjaxRequest(uri));
            fetchedPages.add(ajaxPage);
            String detailUrl = extractSaraminDetailIframeUrl(ajaxPage.html(), uri);
            if (!detailUrl.isBlank()) {
                FetchedHtml detailPage = fetchHtml(buildDetailRequest(URI.create(detailUrl), uri));
                fetchedPages.add(detailPage);
                return jdHtmlExtractor.extract(detailPage.html(), jdUrl);
            }
            return jdHtmlExtractor.extract(ajaxPage.html(), jdUrl);
        } catch (ApiException exception) {
            lastException = exception;
            if (!isSaraminFallbackable(exception)) {
                throw exception;
            }
        }

        try {
            FetchedHtml detailPage = fetchHtml(buildDetailRequest(buildSaraminDirectDetailUri(uri), uri));
            fetchedPages.add(detailPage);
            return jdHtmlExtractor.extract(detailPage.html(), jdUrl);
        } catch (ApiException exception) {
            if (!isSaraminFallbackable(exception)) {
                throw exception;
            }
            throw lastException;
        }
    }

    private boolean isSaraminFallbackable(ApiException exception) {
        return exception.errorCode() == ErrorCode.JD_FETCH_EMPTY_CONTENT
                || exception.errorCode() == ErrorCode.JD_FETCH_UNSUPPORTED_SOURCE
                || exception.errorCode() == ErrorCode.JD_FETCH_FAILED;
    }

    private URI buildSaraminDirectDetailUri(URI uri) {
        Map<String, String> query = new LinkedHashMap<>();
        query.put("rec_idx", requireQueryParam(uri, "rec_idx"));
        query.put("rec_seq", "0");
        query.put("t_ref", queryParamOrDefault(uri, "t_ref", "search"));
        query.put("t_ref_content", queryParamOrDefault(uri, "t_ref_content", "generic"));

        String encodedQuery = encodeForm(query);
        return URI.create(uri.getScheme() + "://" + uri.getHost() + "/zf_user/jobs/relay/view-detail?" + encodedQuery);
    }

    private HttpRequest buildSaraminAjaxRequest(URI uri) {
        URI ajaxUri = URI.create(uri.getScheme() + "://" + uri.getHost() + "/zf_user/jobs/relay/view-ajax");
        Map<String, String> form = new LinkedHashMap<>();
        form.put("rec_idx", requireQueryParam(uri, "rec_idx"));
        form.put("rec_seq", "0");
        form.put("view_type", queryParamOrDefault(uri, "view_type", "search"));
        form.put("t_ref", queryParamOrDefault(uri, "t_ref", "search"));
        form.put("t_ref_content", queryParamOrDefault(uri, "t_ref_content", "generic"));
        form.put("search_uuid", queryParamOrDefault(uri, "search_uuid", ""));
        form.put("searchType", queryParamOrDefault(uri, "searchType", ""));
        form.put("searchword", queryParamOrDefault(uri, "searchword", ""));

        return HttpRequest.newBuilder()
                .uri(ajaxUri)
                .timeout(Duration.ofSeconds(15))
                .header("User-Agent", "Mozilla/5.0 (compatible; JDSnack/1.0)")
                .header("Accept", "text/html, */*; q=0.01")
                .header("Accept-Language", "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7")
                .header("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
                .header("X-Requested-With", "XMLHttpRequest")
                .header("Referer", uri.toString())
                .POST(HttpRequest.BodyPublishers.ofString(encodeForm(form)))
                .build();
    }

    private HttpRequest buildDetailRequest(URI uri, URI refererUri) {
        return HttpRequest.newBuilder()
                .uri(uri)
                .timeout(Duration.ofSeconds(15))
                .header("User-Agent", "Mozilla/5.0 (compatible; JDSnack/1.0)")
                .header("Accept", "text/html,application/xhtml+xml")
                .header("Accept-Language", "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7")
                .header("Referer", refererUri.toString())
                .GET()
                .build();
    }

    private FetchedHtml fetchHtml(HttpRequest httpRequest) throws IOException, InterruptedException {
        HttpRequest currentRequest = httpRequest;
        for (int redirects = 0; redirects <= MAX_PAGE_REDIRECTS; redirects++) {
            HttpResponse<InputStream> response = httpClient.send(currentRequest, HttpResponse.BodyHandlers.ofInputStream());
            URI responseUri = response.uri() == null ? currentRequest.uri() : response.uri();
            if (!isAllowedPageUri(responseUri, httpRequest.uri())) {
                closeResponseBody(response);
                throw new ApiException(ErrorCode.JD_FETCH_FAILED);
            }
            if (response.statusCode() >= 300 && response.statusCode() < 400) {
                closeResponseBody(response);
                if (redirects == MAX_PAGE_REDIRECTS) {
                    throw new ApiException(ErrorCode.JD_FETCH_FAILED);
                }
                String location = response.headers().firstValue("Location")
                        .orElseThrow(() -> new ApiException(ErrorCode.JD_FETCH_FAILED));
                URI nextUri;
                try {
                    nextUri = responseUri.resolve(location);
                } catch (IllegalArgumentException exception) {
                    throw new ApiException(ErrorCode.JD_FETCH_FAILED);
                }
                if (!isAllowedPageUri(nextUri, httpRequest.uri())) {
                    throw new ApiException(ErrorCode.JD_FETCH_FAILED);
                }
                currentRequest = buildPageRequest(nextUri);
                continue;
            }
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                closeResponseBody(response);
                throw new ApiException(ErrorCode.JD_FETCH_FAILED);
            }
            String contentType = response.headers().firstValue("Content-Type")
                    .orElse("").toLowerCase(Locale.ROOT);
            if (!contentType.isBlank() && !contentType.startsWith("text/html")
                    && !contentType.startsWith("application/xhtml+xml")) {
                closeResponseBody(response);
                throw new ApiException(ErrorCode.JD_FETCH_FAILED);
            }
            if (response.headers().firstValueAsLong("Content-Length")
                    .orElse(0) > MAX_RESPONSE_BODY_LENGTH) {
                closeResponseBody(response);
                throw new ApiException(ErrorCode.JD_FETCH_FAILED);
            }
            try (InputStream body = response.body()) {
                if (body == null) {
                    throw new ApiException(ErrorCode.JD_FETCH_FAILED);
                }
                byte[] bytes = body.readNBytes(MAX_RESPONSE_BODY_LENGTH + 1);
                if (bytes.length > MAX_RESPONSE_BODY_LENGTH) {
                    throw new ApiException(ErrorCode.JD_FETCH_FAILED);
                }
                return new FetchedHtml(responseUri, new String(bytes, StandardCharsets.UTF_8));
            }
        }
        throw new ApiException(ErrorCode.JD_FETCH_FAILED);
    }

    private void closeResponseBody(HttpResponse<InputStream> response) {
        if (response.body() != null) {
            try {
                response.body().close();
            } catch (IOException ignored) {
                // Discard the rejected response while preserving its original error.
            }
        }
    }

    private boolean isAllowedPageUri(URI uri, URI origin) {
        if (uri == null || uri.getScheme() == null || uri.getHost() == null
                || uri.getUserInfo() != null || uri.getPort() != -1) {
            return false;
        }
        String scheme = uri.getScheme().toLowerCase(Locale.ROOT);
        if (!"https".equals(scheme) && !"http".equals(scheme)) {
            return false;
        }
        if (isUnsafeHost(uri.getHost()) || !isSupportedHost(uri.getHost())
                || !sourceSiteFor(uri).equals(sourceSiteFor(origin))) {
            return false;
        }
        return !"wanted".equals(sourceSiteFor(origin))
                || isWantedPostingPath(uri) && uri.getPath().equals(origin.getPath());
    }

    private boolean shouldTrySaraminAjaxFallback(ApiException exception, URI uri) {
        return (exception.errorCode() == ErrorCode.JD_FETCH_EMPTY_CONTENT
                || exception.errorCode() == ErrorCode.JD_FETCH_UNSUPPORTED_SOURCE)
                && isSaraminRelayView(uri)
                && !queryParamOrDefault(uri, "rec_idx", "").isBlank();
    }

    private boolean isSaraminRelayView(URI uri) {
        String path = uri.getPath() == null ? "" : uri.getPath();
        return isSaraminHost(uri.getHost()) && path.equals("/zf_user/jobs/relay/view");
    }

    private String requireQueryParam(URI uri, String name) {
        String value = queryParamOrDefault(uri, name, "");
        if (value.isBlank()) {
            throw new ApiException(ErrorCode.INVALID_JD_URL);
        }
        return value;
    }

    private String queryParamOrDefault(URI uri, String name, String defaultValue) {
        String rawQuery = uri.getRawQuery();
        if (rawQuery == null || rawQuery.isBlank()) {
            return defaultValue;
        }

        for (String pair : rawQuery.split("&")) {
            int separatorIndex = pair.indexOf('=');
            String key = separatorIndex >= 0 ? pair.substring(0, separatorIndex) : pair;
            if (!key.equals(name)) {
                continue;
            }
            return separatorIndex >= 0 ? pair.substring(separatorIndex + 1) : "";
        }
        return defaultValue;
    }

    private String encodeForm(Map<String, String> form) {
        StringBuilder builder = new StringBuilder();
        for (Map.Entry<String, String> entry : form.entrySet()) {
            if (builder.length() > 0) {
                builder.append('&');
            }
            builder.append(URLEncoder.encode(entry.getKey(), StandardCharsets.UTF_8));
            builder.append('=');
            builder.append(URLEncoder.encode(entry.getValue(), StandardCharsets.UTF_8));
        }
        return builder.toString();
    }

    private String extractSaraminDetailIframeUrl(String html, URI pageUri) {
        Element iframe = Jsoup.parse(html, pageUri.toString()).selectFirst("iframe.iframe_content[src*=/zf_user/jobs/relay/view-detail]");
        if (iframe == null) {
            return "";
        }

        String src = iframe.attr("src").trim();
        if (src.isBlank()) {
            return "";
        }

        URI detailUri = pageUri.resolve(src);
        if (!isSaraminHost(detailUri.getHost()) || !"/zf_user/jobs/relay/view-detail".equals(detailUri.getPath())) {
            return "";
        }

        return detailUri.toString();
    }

    private URI validateUrl(JdFetchRequest request) {
        String jdUrl = request == null || request.jdUrl() == null ? "" : request.jdUrl().trim();
        if (jdUrl.isBlank()) {
            throw new ApiException(ErrorCode.INVALID_JD_URL);
        }

        try {
            URI uri = new URI(jdUrl);
            String scheme = uri.getScheme();
            String host = uri.getHost();
            if (scheme == null || host == null) {
                throw new ApiException(ErrorCode.INVALID_JD_URL);
            }

            String lowerScheme = scheme.toLowerCase(Locale.ROOT);
            if (!"http".equals(lowerScheme) && !"https".equals(lowerScheme)) {
                throw new ApiException(ErrorCode.INVALID_JD_URL);
            }

            if (isUnsafeHost(host) || uri.getRawUserInfo() != null || uri.getPort() != -1) {
                throw new ApiException(ErrorCode.INVALID_JD_URL);
            }
            if (!isSupportedHost(host)) {
                throw new ApiException(ErrorCode.JD_FETCH_UNSUPPORTED_SOURCE);
            }
            if (isWantedHost(host) && !isWantedPostingPath(uri)) {
                throw new ApiException(ErrorCode.INVALID_JD_URL);
            }

            return uri;
        } catch (URISyntaxException exception) {
            throw new ApiException(ErrorCode.INVALID_JD_URL);
        }
    }

    private boolean isSupportedHost(String host) {
        if (host == null) {
            return false;
        }

        String normalizedHost = host.toLowerCase(Locale.ROOT);
        return isSaraminHost(normalizedHost)
                || normalizedHost.equals("www.jobkorea.co.kr")
                || normalizedHost.equals("jobkorea.co.kr")
                || isWantedHost(normalizedHost);
    }

    private String sourceSiteFor(URI uri) {
        if (isSaraminHost(uri.getHost())) {
            return "saramin";
        }
        String normalizedHost = uri.getHost() == null ? "" : uri.getHost().toLowerCase(Locale.ROOT);
        if (normalizedHost.equals("www.jobkorea.co.kr") || normalizedHost.equals("jobkorea.co.kr")) {
            return "jobkorea";
        }
        if (isWantedHost(normalizedHost)) {
            return "wanted";
        }
        return "";
    }

    private boolean isWantedHost(String host) {
        if (host == null) {
            return false;
        }
        String normalized = host.toLowerCase(Locale.ROOT);
        return normalized.equals("www.wanted.co.kr") || normalized.equals("wanted.co.kr");
    }

    private boolean isWantedPostingPath(URI uri) {
        return uri.getPath() != null && uri.getPath().matches("/wd/[1-9]\\d*/?");
    }

    private boolean isSaraminHost(String host) {
        if (host == null) {
            return false;
        }

        String normalizedHost = host.toLowerCase(Locale.ROOT);
        return normalizedHost.equals("www.saramin.co.kr") || normalizedHost.equals("saramin.co.kr");
    }

    private boolean isUnsafeHost(String host) {
        String normalizedHost = host.toLowerCase(Locale.ROOT);
        if ("localhost".equals(normalizedHost) || normalizedHost.endsWith(".localhost")) {
            return true;
        }

        if (isIpv4Literal(normalizedHost)) {
            return isUnsafeIpv4(normalizedHost);
        }

        if (normalizedHost.startsWith("[") && normalizedHost.endsWith("]")) {
            String ipv6 = normalizedHost.substring(1, normalizedHost.length() - 1);
            return isUnsafeIpv6(ipv6);
        }

        return false;
    }

    private boolean isIpv4Literal(String host) {
        return host.matches("\\d+\\.\\d+\\.\\d+\\.\\d+");
    }

    private boolean isUnsafeIpv4(String host) {
        String[] parts = host.split("\\.");
        if (parts.length != 4) {
            return true;
        }

        int[] octets = new int[4];
        for (int i = 0; i < 4; i++) {
            int value = Integer.parseInt(parts[i]);
            if (value < 0 || value > 255) {
                return true;
            }
            octets[i] = value;
        }

        return octets[0] == 127
                || octets[0] == 10
                || (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31)
                || (octets[0] == 192 && octets[1] == 168)
                || (octets[0] == 169 && octets[1] == 254)
                || octets[0] == 0;
    }

    private boolean isUnsafeIpv6(String host) {
        String normalized = host.toLowerCase(Locale.ROOT);
        return normalized.equals("::1")
                || normalized.startsWith("fc")
                || normalized.startsWith("fd")
                || normalized.startsWith("fe80");
    }

}
