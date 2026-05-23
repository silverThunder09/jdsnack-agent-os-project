package com.jdsnack.jd;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;
import org.springframework.stereotype.Component;

import java.util.Comparator;
import java.util.List;

@Component
public class JdHtmlExtractor {

    private static final int MIN_CONTENT_LENGTH = 50;
    private static final int DIV_CANDIDATE_MIN_LENGTH = 120;
    private static final String FETCH_MODE = "static-html";

    public JdFetchResponse extract(String html, String sourceUrl) {
        Document document = Jsoup.parse(html, sourceUrl);
        sanitize(document);

        Element candidate = findCandidate(document);
        if (candidate == null) {
            throw new ApiException(ErrorCode.JD_FETCH_UNSUPPORTED_SOURCE);
        }

        String jdText = normalize(candidate.text());
        if (jdText.length() < MIN_CONTENT_LENGTH) {
            throw new ApiException(ErrorCode.JD_FETCH_EMPTY_CONTENT);
        }

        return new JdFetchResponse(
                jdText,
                sourceUrl,
                extractTitle(document),
                FETCH_MODE
        );
    }

    private void sanitize(Document document) {
        document.select("script, style, noscript, nav, footer, header, form, button, svg, aside").remove();
    }

    private Element findCandidate(Document document) {
        for (String selector : List.of("article", "main", "section")) {
            Element candidate = document.select(selector).stream()
                    .max(Comparator.comparingInt(element -> normalize(element.text()).length()))
                    .orElse(null);

            if (candidate != null) {
                return candidate;
            }
        }

        Elements divs = document.select("div");
        return divs.stream()
                .filter(div -> normalize(div.text()).length() >= DIV_CANDIDATE_MIN_LENGTH)
                .max(Comparator.comparingInt(div -> normalize(div.text()).length()))
                .orElse(null);
    }

    private String extractTitle(Document document) {
        String title = normalize(document.title());
        if (!title.isBlank()) {
            return title;
        }

        Element h1 = document.selectFirst("h1");
        if (h1 != null) {
            String heading = normalize(h1.text());
            if (!heading.isBlank()) {
                return heading;
            }
        }

        return "채용공고";
    }

    private String normalize(String value) {
        return value == null ? "" : value.replace('\u00A0', ' ').replaceAll("\\s+", " ").trim();
    }
}
