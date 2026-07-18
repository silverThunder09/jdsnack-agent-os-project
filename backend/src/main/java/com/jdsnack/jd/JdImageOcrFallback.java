package com.jdsnack.jd;

import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;

import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

/**
 * Optional Saramin image fallback. It owns image candidate discovery, redirect
 * handling, byte limits, and OCR validation so {@link JdFetchService} remains
 * responsible for the primary HTML and Saramin relay flow.
 */
final class JdImageOcrFallback {

    private static final int MAX_IMAGE_BODY_LENGTH = 8 * 1024 * 1024;
    private static final int MAX_IMAGE_REDIRECTS = 3;
    private static final String IMAGE_OCR_FETCH_MODE = "image-ocr";
    private static final List<String> IMAGE_CONTAINER_SELECTORS = List.of(
            ".user_content",
            ".wrap_jv_cont",
            ".jv_cont"
    );

    private final HttpClient httpClient;
    private final JdHtmlExtractor htmlExtractor;
    private final JdImageOcr imageOcr;

    JdImageOcrFallback(HttpClient httpClient, JdHtmlExtractor htmlExtractor, JdImageOcr imageOcr) {
        this.httpClient = httpClient;
        this.htmlExtractor = htmlExtractor;
        this.imageOcr = imageOcr;
    }

    Optional<JdFetchResponse> tryExtract(List<FetchedHtml> fetchedPages, String jdUrl) {
        if (!imageOcr.isAvailable()) {
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

            String jdText = htmlExtractor.normalizeOcrText(
                    imageOcr.extractText(image.get().bytes(), image.get().mimeType())
            );
            if (!htmlExtractor.isValidOcrText(jdText)) {
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
        return candidates.stream().max(Comparator.comparingLong(ImageCandidate::score));
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
        long area = positiveDimension(image, "width") * positiveDimension(image, "height");
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
            response = httpClient.send(buildImageRequest(currentUri), HttpResponse.BodyHandlers.ofInputStream());
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

        String mimeType = response.headers().firstValue("Content-Type")
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

    private boolean isUnsafeHost(String host) {
        String normalizedHost = host.toLowerCase(Locale.ROOT);
        if ("localhost".equals(normalizedHost) || normalizedHost.endsWith(".localhost")) {
            return true;
        }
        if (normalizedHost.matches("\\d+\\.\\d+\\.\\d+\\.\\d+")) {
            String[] parts = normalizedHost.split("\\.");
            if (parts.length != 4) {
                return true;
            }
            int[] octets = new int[4];
            for (int index = 0; index < 4; index++) {
                int value = Integer.parseInt(parts[index]);
                if (value < 0 || value > 255) {
                    return true;
                }
                octets[index] = value;
            }
            return octets[0] == 127 || octets[0] == 10
                    || (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31)
                    || (octets[0] == 192 && octets[1] == 168)
                    || (octets[0] == 169 && octets[1] == 254) || octets[0] == 0;
        }
        if (normalizedHost.startsWith("[") && normalizedHost.endsWith("]")) {
            String ipv6 = normalizedHost.substring(1, normalizedHost.length() - 1);
            return ipv6.equals("::1") || ipv6.startsWith("fc") || ipv6.startsWith("fd") || ipv6.startsWith("fe80");
        }
        return false;
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

    private record ImageCandidate(URI uri, String title, long score) {
    }

    private record DownloadedImage(byte[] bytes, String mimeType) {
    }
}
