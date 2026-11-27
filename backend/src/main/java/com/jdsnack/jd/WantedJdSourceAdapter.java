package com.jdsnack.jd;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.MissingNode;
import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Extracts the job description from Wanted's server-rendered detail article or
 * the same page's embedded Next.js data. Never reads recommendations or app chrome.
 */
final class WantedJdSourceAdapter {

    private static final ObjectMapper JSON = new ObjectMapper();
    private static final String ARTICLE_SELECTOR = "main article[class*=JobDescription], "
            + "section[class*=descriptionWrapper] article";
    private static final String SECTION_SELECTOR = "div[class*=JobDescription__paragraph__]:not([class*=wrapper])";

    void verifyAvailable(String html) {
        Document document = Jsoup.parse(html);
        JsonNode data = initialData(document);
        if (data.isMissingNode()
                || !"active".equalsIgnoreCase(data.path("status").asText(""))
                || data.path("hidden").asBoolean(false)
                || data.path("is_private").asBoolean(false)) {
            throw new ApiException(ErrorCode.JD_FETCH_UNSUPPORTED_SOURCE);
        }
        Element description = document.selectFirst("meta[name=description]");
        if (description != null && description.attr("content").contains("마감되었습니다")) {
            throw new ApiException(ErrorCode.JD_FETCH_UNSUPPORTED_SOURCE);
        }
    }

    JdFetchResponse extract(String html, String sourceUrl, JdHtmlExtractor qualityValidator) {
        Document document = Jsoup.parse(html, sourceUrl);
        verifyAvailable(html);
        String title = JdHtmlExtractor.normalize(document.title());
        if (title.isBlank()) {
            Element heading = document.selectFirst("h1");
            title = heading == null ? "채용공고" : JdHtmlExtractor.normalize(heading.text());
        }

        String text = fromArticle(document);
        if (!isUsable(text, qualityValidator)) {
            text = fromEmbeddedData(initialData(document));
        }
        if (text.isBlank()) {
            throw new ApiException(ErrorCode.JD_FETCH_EMPTY_CONTENT);
        }
        if (!isUsable(text, qualityValidator)) {
            throw new ApiException(ErrorCode.JD_FETCH_UNSUPPORTED_SOURCE);
        }
        return new JdFetchResponse(text, sourceUrl, title, "static-html", "wanted");
    }

    static boolean hasJobSections(String text) {
        String lower = text.toLowerCase(Locale.ROOT);
        return lower.contains("주요업무") || lower.contains("담당업무")
                || lower.contains("자격요건") || lower.contains("우대사항")
                || lower.contains("필수요건")
                || lower.contains("responsibilities") || lower.contains("requirements");
    }

    private boolean isUsable(String text, JdHtmlExtractor qualityValidator) {
        return hasJobSections(text) && qualityValidator.isValidOcrText(text);
    }

    private String fromArticle(Document document) {
        Element article = document.selectFirst(ARTICLE_SELECTOR);
        if (article == null) {
            return "";
        }
        article = article.clone();
        article.select("script, style, nav, aside, footer, button, [class*=recommend], [class*=apply]").remove();
        List<String> sections = new ArrayList<>();
        for (Element paragraph : article.select(SECTION_SELECTOR)) {
            String text = JdHtmlExtractor.normalize(paragraph.text());
            if (!text.isBlank()) {
                sections.add(text);
            }
        }
        if (!sections.isEmpty()) {
            return JdHtmlExtractor.normalize(String.join(" ", sections));
        }
        return JdHtmlExtractor.normalize(article.text());
    }

    private String fromEmbeddedData(JsonNode data) {
        if (data.isMissingNode()) {
            return "";
        }
        List<String> sections = new ArrayList<>();
        appendSection(sections, "주요업무", data.path("main_tasks").asText(""));
        appendSection(sections, "자격요건", data.path("requirements").asText(""));
        appendSection(sections, "우대사항", data.path("preferred_points").asText(""));
        return JdHtmlExtractor.normalize(String.join(" ", sections));
    }

    private void appendSection(List<String> sections, String name, String value) {
        if (!value.isBlank()) {
            sections.add(name + " " + value);
        }
    }

    private JsonNode initialData(Document document) {
        Element script = document.selectFirst("script#__NEXT_DATA__");
        if (script == null) {
            return MissingNode.getInstance();
        }
        try {
            return JSON.readTree(script.data()).path("props").path("pageProps").path("initialData");
        } catch (IOException | IllegalArgumentException exception) {
            return MissingNode.getInstance();
        }
    }
}
