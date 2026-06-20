package com.jdsnack.jd;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
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
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

@Service
public class JdFetchService {

    private static final int MAX_RESPONSE_BODY_LENGTH = 1_000_000;
    private static final int MAX_IMAGE_BODY_LENGTH = 8 * 1024 * 1024;
    private static final int MAX_IMAGE_REDIRECTS = 3;
    private static final String IMAGE_OCR_FETCH_MODE = "image-ocr";
    private static final List<String> IMAGE_CONTAINER_SELECTORS = List.of(
            ".user_content",
            ".wrap_jv_cont",
            ".jv_cont"
    );
    private final HttpClient httpClient;
    private final HttpClient imageHttpClient;
    private final JdHtmlExtractor jdHtmlExtractor;
    private final JdImageOcr jdImageOcr;

    @Autowired
    public JdFetchService(JdHtmlExtractor jdHtmlExtractor, JdImageOcr jdImageOcr) {
        this(
                HttpClient.newBuilder()
                        .connectTimeout(Duration.ofSeconds(10))
                        .followRedirects(HttpClient.Redirect.NORMAL)
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
        this.jdImageOcr = jdImageOcr;
    }

    public JdFetchResponse fetch(JdFetchRequest request) {
        URI uri = validateUrl(request);
        String jdUrl = uri.toString();
        List<FetchedHtml> fetchedPages = new ArrayList<>();

        try {
            FetchedHtml page = fetchHtml(buildPageRequest(uri));
            fetchedPages.add(page);
            try {
                return jdHtmlExtractor.extract(page.html(), jdUrl);
            } catch (ApiException exception) {
                if (!shouldTrySaraminAjaxFallback(exception, uri)) {
                    Optional<JdFetchResponse> ocrResponse = tryImageOcr(fetchedPages, jdUrl);
                    if (ocrResponse.isPresent()) {
                        return ocrResponse.get();
                    }
                    throw exception;
                }
                try {
                    return fetchSaraminFallback(uri, jdUrl, exception, fetchedPages);
                } catch (ApiException fallbackException) {
                    Optional<JdFetchResponse> ocrResponse = tryImageOcr(fetchedPages, jdUrl);
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
        HttpResponse<String> response = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new ApiException(ErrorCode.JD_FETCH_FAILED);
        }
        if (response.body() == null || response.body().length() > MAX_RESPONSE_BODY_LENGTH) {
            throw new ApiException(ErrorCode.JD_FETCH_FAILED);
        }
        URI responseUri = response.uri() == null ? httpRequest.uri() : response.uri();
        return new FetchedHtml(responseUri, response.body());
    }

    private Optional<JdFetchResponse> tryImageOcr(List<FetchedHtml> fetchedPages, String jdUrl) {
        if (!jdImageOcr.isAvailable()) {
            return Optional.empty();
        }

        Optional<ImageCandidate> candidate = findImageCandidate(fetchedPages);
        if (candidate.isEmpty()) {
            return Optional.empty();
        }

        try {
            Optional<DownloadedImage> image = downloadImage(candidate.get().uri());
            if (image.isEmpty()) {
                return Optional.empty();
            }

            String jdText = jdHtmlExtractor.normalizeOcrText(
                    jdImageOcr.extractText(image.get().bytes(), image.get().mimeType())
            );
            if (!jdHtmlExtractor.isValidOcrText(jdText)) {
                return Optional.empty();
            }

            return Optional.of(new JdFetchResponse(
                    jdText,
                    jdUrl,
                    candidate.get().title(),
                    IMAGE_OCR_FETCH_MODE,
                    "saramin"
            ));
        } catch (IOException | RuntimeException exception) {
            return Optional.empty();
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return Optional.empty();
        }
    }

    private Optional<ImageCandidate> findImageCandidate(List<FetchedHtml> fetchedPages) {
        List<ImageCandidate> candidates = new ArrayList<>();
        for (int pageIndex = 0; pageIndex < fetchedPages.size(); pageIndex++) {
            FetchedHtml page = fetchedPages.get(pageIndex);
            int candidatePageIndex = pageIndex;
            Document document = Jsoup.parse(page.html(), page.uri().toString());
            String title = extractPageTitle(document);
            for (String selector : IMAGE_CONTAINER_SELECTORS) {
                for (Element image : document.select(selector + " img[src]")) {
                    resolveImageUri(page.uri(), image.attr("src")).ifPresent(uri -> candidates.add(
                            new ImageCandidate(uri, title, imageScore(image, candidatePageIndex))
                    ));
                }
            }
        }

        return candidates.stream()
                .max(Comparator.comparingLong(ImageCandidate::score));
    }

    private Optional<URI> resolveImageUri(URI pageUri, String source) {
        String trimmedSource = source == null ? "" : source.trim();
        if (trimmedSource.isBlank() || trimmedSource.toLowerCase(Locale.ROOT).startsWith("data:")) {
            return Optional.empty();
        }

        try {
            URI resolved = pageUri.resolve(trimmedSource);
            String scheme = resolved.getScheme();
            if (scheme == null || resolved.getHost() == null || resolved.getUserInfo() != null) {
                return Optional.empty();
            }
            String normalizedScheme = scheme.toLowerCase(Locale.ROOT);
            if (!"http".equals(normalizedScheme) && !"https".equals(normalizedScheme)) {
                return Optional.empty();
            }
            return Optional.of(resolved);
        } catch (IllegalArgumentException exception) {
            return Optional.empty();
        }
    }

    private long imageScore(Element image, int pageIndex) {
        long width = positiveDimension(image, "width");
        long height = positiveDimension(image, "height");
        long area = width * height;
        return area + (long) pageIndex * MAX_IMAGE_BODY_LENGTH;
    }

    private long positiveDimension(Element image, String attribute) {
        String value = image.attr(attribute).replaceAll("[^0-9]", "");
        if (value.isBlank()) {
            return 1;
        }
        try {
            return Math.min(100_000, Math.max(1, Long.parseLong(value)));
        } catch (NumberFormatException exception) {
            return 1;
        }
    }

    private Optional<DownloadedImage> downloadImage(URI imageUri) throws IOException, InterruptedException {
        if (!isTrustedImageUri(imageUri)) {
            return Optional.empty();
        }

        URI currentUri = imageUri;
        HttpResponse<InputStream> response = null;
        for (int redirectCount = 0; redirectCount <= MAX_IMAGE_REDIRECTS; redirectCount++) {
            if (!isTrustedImageUri(currentUri)) {
                return Optional.empty();
            }
            response = imageHttpClient.send(buildImageRequest(currentUri), HttpResponse.BodyHandlers.ofInputStream());
            if (!isRedirect(response.statusCode())) {
                break;
            }

            Optional<String> location = response.headers().firstValue("Location");
            closeQuietly(response.body());
            if (redirectCount == MAX_IMAGE_REDIRECTS || location.isEmpty()) {
                return Optional.empty();
            }
            Optional<URI> redirectedUri = resolveImageUri(currentUri, location.get());
            if (redirectedUri.isEmpty() || !isTrustedImageUri(redirectedUri.get())) {
                return Optional.empty();
            }
            currentUri = redirectedUri.get();
            response = null;
        }

        if (response == null) {
            return Optional.empty();
        }
        URI finalUri = response.uri() == null ? currentUri : response.uri();
        if (response.statusCode() < 200 || response.statusCode() >= 300 || !isTrustedImageUri(finalUri)) {
            closeQuietly(response.body());
            return Optional.empty();
        }

        String mimeType = response.headers()
                .firstValue("Content-Type")
                .map(value -> value.split(";", 2)[0].trim().toLowerCase(Locale.ROOT))
                .orElse("");
        if (!mimeType.startsWith("image/")) {
            closeQuietly(response.body());
            return Optional.empty();
        }

        Optional<String> contentLength = response.headers().firstValue("Content-Length");
        if (contentLength.isPresent() && exceedsImageLimit(contentLength.get())) {
            closeQuietly(response.body());
            return Optional.empty();
        }

        try (InputStream body = response.body()) {
            if (body == null) {
                return Optional.empty();
            }
            byte[] bytes = body.readNBytes(MAX_IMAGE_BODY_LENGTH + 1);
            if (bytes.length > MAX_IMAGE_BODY_LENGTH) {
                return Optional.empty();
            }
            return Optional.of(new DownloadedImage(bytes, mimeType));
        }
    }

    private HttpRequest buildImageRequest(URI imageUri) {
        return HttpRequest.newBuilder()
                .uri(imageUri)
                .timeout(Duration.ofSeconds(15))
                .header("User-Agent", "Mozilla/5.0 (compatible; JDSnack/1.0)")
                .header("Accept", "image/*")
                .GET()
                .build();
    }

    private boolean isRedirect(int statusCode) {
        return statusCode >= 300 && statusCode < 400;
    }

    private boolean exceedsImageLimit(String contentLength) {
        try {
            return Long.parseLong(contentLength) > MAX_IMAGE_BODY_LENGTH;
        } catch (NumberFormatException exception) {
            return true;
        }
    }

    private void closeQuietly(InputStream inputStream) {
        if (inputStream == null) {
            return;
        }
        try {
            inputStream.close();
        } catch (IOException ignored) {
            // A rejected response is already being discarded.
        }
    }

    private boolean isTrustedImageUri(URI uri) {
        String scheme = uri.getScheme();
        String host = uri.getHost();
        if (scheme == null || host == null || uri.getUserInfo() != null) {
            return false;
        }
        String normalizedScheme = scheme.toLowerCase(Locale.ROOT);
        return ("http".equals(normalizedScheme) || "https".equals(normalizedScheme))
                && !isUnsafeHost(host)
                && isTrustedImageHost(host);
    }

    private boolean isTrustedImageHost(String host) {
        String normalizedHost = host.toLowerCase(Locale.ROOT);
        return normalizedHost.equals("saramin.co.kr")
                || normalizedHost.endsWith(".saramin.co.kr")
                || normalizedHost.equals("saraminimage.co.kr")
                || normalizedHost.endsWith(".saraminimage.co.kr");
    }

    private String extractPageTitle(Document document) {
        String title = normalize(document.title());
        if (!title.isBlank()) {
            return title;
        }
        Element heading = document.selectFirst("h1");
        return heading == null || normalize(heading.text()).isBlank() ? "채용공고" : normalize(heading.text());
    }

    private String normalize(String value) {
        return value == null ? "" : value.replaceAll("\\s+", " ").trim();
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

    private record FetchedHtml(URI uri, String html) {
    }

    private record ImageCandidate(URI uri, String title, long score) {
    }

    private record DownloadedImage(byte[] bytes, String mimeType) {
    }
}
