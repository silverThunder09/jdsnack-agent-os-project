package com.jdsnack.jd;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Element;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

@Service
public class JdFetchService {

    private static final int MAX_RESPONSE_BODY_LENGTH = 1_000_000;
    private final HttpClient httpClient;
    private final JdHtmlExtractor jdHtmlExtractor;

    @Autowired
    public JdFetchService(JdHtmlExtractor jdHtmlExtractor) {
        this(
                HttpClient.newBuilder()
                        .connectTimeout(Duration.ofSeconds(10))
                        .followRedirects(HttpClient.Redirect.NORMAL)
                        .build(),
                jdHtmlExtractor
        );
    }

    JdFetchService(HttpClient httpClient, JdHtmlExtractor jdHtmlExtractor) {
        this.httpClient = httpClient;
        this.jdHtmlExtractor = jdHtmlExtractor;
    }

    public JdFetchResponse fetch(JdFetchRequest request) {
        URI uri = validateUrl(request);
        String jdUrl = uri.toString();

        try {
            String html = fetchHtml(buildPageRequest(uri));
            try {
                return jdHtmlExtractor.extract(html, jdUrl);
            } catch (ApiException exception) {
                if (!shouldTrySaraminAjaxFallback(exception, uri)) {
                    throw exception;
                }
                String ajaxHtml = fetchHtml(buildSaraminAjaxRequest(uri));
                String detailUrl = extractSaraminDetailIframeUrl(ajaxHtml, uri);
                if (!detailUrl.isBlank()) {
                    String detailHtml = fetchHtml(buildDetailRequest(URI.create(detailUrl), uri));
                    return jdHtmlExtractor.extract(detailHtml, jdUrl);
                }
                return jdHtmlExtractor.extract(ajaxHtml, jdUrl);
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

    private String fetchHtml(HttpRequest httpRequest) throws IOException, InterruptedException {
        HttpResponse<String> response = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new ApiException(ErrorCode.JD_FETCH_FAILED);
        }
        if (response.body() == null || response.body().length() > MAX_RESPONSE_BODY_LENGTH) {
            throw new ApiException(ErrorCode.JD_FETCH_FAILED);
        }
        return response.body();
    }

    private boolean shouldTrySaraminAjaxFallback(ApiException exception, URI uri) {
        return (exception.errorCode() == ErrorCode.JD_FETCH_EMPTY_CONTENT
                || exception.errorCode() == ErrorCode.JD_FETCH_UNSUPPORTED_SOURCE)
                && isSaraminRelayView(uri)
                && !queryParamOrDefault(uri, "rec_idx", "").isBlank();
    }

    private boolean isSaraminRelayView(URI uri) {
        String path = uri.getPath() == null ? "" : uri.getPath();
        return isSupportedHost(uri.getHost()) && path.equals("/zf_user/jobs/relay/view");
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
        if (!isSupportedHost(detailUri.getHost()) || !"/zf_user/jobs/relay/view-detail".equals(detailUri.getPath())) {
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

            if (isUnsafeHost(host)) {
                throw new ApiException(ErrorCode.INVALID_JD_URL);
            }
            if (!isSupportedHost(host)) {
                throw new ApiException(ErrorCode.JD_FETCH_UNSUPPORTED_SOURCE);
            }

            return uri;
        } catch (URISyntaxException exception) {
            throw new ApiException(ErrorCode.INVALID_JD_URL);
        }
    }

    private boolean isSupportedHost(String host) {
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
