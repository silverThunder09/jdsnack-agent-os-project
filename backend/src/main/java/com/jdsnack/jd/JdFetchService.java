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
        String jdUrl = validateUrl(request);

        try {
            HttpRequest httpRequest = HttpRequest.newBuilder()
                    .uri(URI.create(jdUrl))
                    .timeout(Duration.ofSeconds(15))
                    .header("User-Agent", "JDSnack/1.0")
                    .header("Accept", "text/html,application/xhtml+xml")
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
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

    private String validateUrl(JdFetchRequest request) {
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

            return jdUrl;
        } catch (URISyntaxException exception) {
            throw new ApiException(ErrorCode.INVALID_JD_URL);
        }
    }
}
