package com.jdsnack.jd;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;
import org.springframework.stereotype.Component;

import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

@Component
public class JdHtmlExtractor {

    private static final int MIN_CONTENT_LENGTH = 50;
    private static final String FETCH_MODE = "static-html";
    private static final List<String> CANDIDATE_SELECTORS = List.of(
            "article",
            "main",
            "section",
            "[data-job-description]",
            "[data-testid*=job]",
            "[data-testid*=description]",
            "[class*=job]",
            "[class*=description]",
            "[class*=detail]",
            "[id*=job]",
            "[id*=description]",
            "[id*=detail]",
            "div"
    );
    private static final Set<String> PRIORITY_HINTS = Set.of(
            "job", "description", "detail", "posting", "position", "role", "opening", "hiring",
            "jd", "requirement", "qualification", "responsibility", "about", "overview",
            "채용", "공고", "모집", "포지션", "직무", "업무", "상세", "자격", "요건", "우대"
    );
    private static final Set<String> NOISE_HINTS = Set.of(
            "related", "recommend", "similar", "share", "social", "comment", "footer", "header",
            "nav", "menu", "banner", "breadcrumb", "popup", "modal", "login", "signup",
            "추천", "관련", "공유", "메뉴", "배너", "댓글", "푸터", "헤더"
    );

    public JdFetchResponse extract(String html, String sourceUrl) {
        Document document = Jsoup.parse(html, sourceUrl);
        sanitize(document);

        Element candidate = findCandidate(document);
        if (candidate == null) {
            throw new ApiException(ErrorCode.JD_FETCH_UNSUPPORTED_SOURCE);
        }

        String title = extractTitle(document);
        String jdText = trimDuplicatedTitlePrefix(normalize(candidate.text()), title);
        if (jdText.length() < MIN_CONTENT_LENGTH) {
            throw new ApiException(ErrorCode.JD_FETCH_EMPTY_CONTENT);
        }

        return new JdFetchResponse(
                jdText,
                sourceUrl,
                title,
                FETCH_MODE
        );
    }

    private void sanitize(Document document) {
        document.select("script, style, noscript, nav, footer, header, form, button, svg, aside").remove();
        document.select("[class], [id]").removeIf(this::isNoiseContainer);
    }

    private Element findCandidate(Document document) {
        Elements candidates = new Elements();
        Set<Element> seen = new LinkedHashSet<>();

        for (String selector : CANDIDATE_SELECTORS) {
            for (Element element : document.select(selector)) {
                if (seen.add(element)) {
                    candidates.add(element);
                }
            }
        }

        return candidates.stream()
                .filter(this::hasMeaningfulText)
                .max(Comparator.comparingInt(this::scoreCandidate))
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

    private boolean hasMeaningfulText(Element element) {
        return !normalize(element.text()).isBlank();
    }

    private int scoreCandidate(Element element) {
        String text = normalize(element.text());
        String attributes = normalize((element.className() + " " + element.id()).toLowerCase(Locale.ROOT));

        int score = text.length();
        score += semanticTagBonus(element);
        score += keywordBonus(attributes, PRIORITY_HINTS, 180);
        score -= keywordBonus(attributes, NOISE_HINTS, 220);
        score += Math.min(element.select("p").size() * 25, 125);
        score += Math.min(element.select("li").size() * 12, 72);
        score -= Math.min(element.select("a").size() * 10, 80);

        return score;
    }

    private int semanticTagBonus(Element element) {
        return switch (element.tagName()) {
            case "article" -> 220;
            case "main" -> 180;
            case "section" -> 120;
            default -> 0;
        };
    }

    private int keywordBonus(String source, Set<String> hints, int weight) {
        int matches = 0;
        for (String hint : hints) {
            if (source.contains(hint)) {
                matches++;
            }
        }
        return matches * weight;
    }

    private boolean isNoiseContainer(Element element) {
        String attributes = normalize((element.className() + " " + element.id()).toLowerCase(Locale.ROOT));
        if (attributes.isBlank()) {
            return false;
        }

        for (String hint : NOISE_HINTS) {
            if (attributes.contains(hint)) {
                return true;
            }
        }
        return false;
    }

    private String trimDuplicatedTitlePrefix(String text, String title) {
        if (title.isBlank() || text.isBlank()) {
            return text;
        }

        String prefix = title + " ";
        if (text.startsWith(prefix)) {
            String trimmed = text.substring(prefix.length()).trim();
            if (trimmed.length() >= MIN_CONTENT_LENGTH) {
                return trimmed;
            }
        }
        return text;
    }
}
