package com.jdsnack.jd;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Locale;

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
            HttpRequest httpRequest = HttpRequest.newBuilder()
                    .uri(uri)
                    .timeout(Duration.ofSeconds(15))
                    .header("User-Agent", "JDSnack/1.0")
                    .header("Accept", "text/html,application/xhtml+xml")
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new ApiException(ErrorCode.JD_FETCH_FAILED);
            }
            if (response.body() == null || response.body().length() > MAX_RESPONSE_BODY_LENGTH) {
                throw new ApiException(ErrorCode.JD_FETCH_FAILED);
            }

            return jdHtmlExtractor.extract(response.body(), jdUrl);
        } catch (ApiException exception) {
            throw exception;
        } catch (IOException exception) {
            throw new ApiException(ErrorCode.JD_FETCH_FAILED, exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new ApiException(ErrorCode.JD_FETCH_FAILED, exception);
        }
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
