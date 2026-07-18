package com.jdsnack.jd;

import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;

import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;

/** Selects the most likely job-description container after removing page noise. */
final class JdCandidateSelector {

    void sanitize(Document document, String sourceSite) {
        document.select("script, style, noscript, nav, footer, header, form, button, svg, aside").remove();
        for (String selector : JdHtmlExtractor.NOISE_SELECTORS) {
            document.select(selector).remove();
        }
        if ("saramin".equals(sourceSite)) {
            for (String selector : JdHtmlExtractor.SARAMIN_NOISE_SELECTORS) {
                document.select(selector).remove();
            }
        }
        document.select("[class], [id]").removeIf(this::isNoiseContainer);
    }

    Element findCandidate(Document document, String sourceSite) {
        if ("saramin".equals(sourceSite)) {
            Element saraminCandidate = findSiteSpecificCandidate(document, JdHtmlExtractor.SARAMIN_CANDIDATE_SELECTORS);
            if (saraminCandidate != null) {
                return saraminCandidate;
            }
        }
        return selectBestCandidate(document, JdHtmlExtractor.CANDIDATE_SELECTORS);
    }

    void removeNestedNoise(Element candidate) {
        for (String selector : JdHtmlExtractor.NOISE_SELECTORS) {
            candidate.select(selector).remove();
        }
        candidate.select("[class], [id]").removeIf(this::isNoiseContainer);
    }

    private Element findSiteSpecificCandidate(Document document, Iterable<String> selectors) {
        return selectBestCandidate(document, selectors);
    }

    private Element selectBestCandidate(Document document, Iterable<String> selectors) {
        Elements candidates = new Elements();
        Set<Element> seen = new LinkedHashSet<>();
        for (String selector : selectors) {
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

    private boolean hasMeaningfulText(Element element) {
        return !JdHtmlExtractor.normalize(element.text()).isBlank();
    }

    private int scoreCandidate(Element element) {
        String text = JdHtmlExtractor.normalize(element.text());
        String attributes = JdHtmlExtractor.normalize((element.className() + " " + element.id()).toLowerCase(Locale.ROOT));
        int score = text.length();
        score += semanticTagBonus(element);
        score += keywordBonus(attributes, JdHtmlExtractor.PRIORITY_HINTS, 180);
        score -= keywordBonus(attributes, JdHtmlExtractor.NOISE_HINTS, 220);
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
            if (JdHtmlExtractor.containsHint(source, hint)) {
                matches++;
            }
        }
        return matches * weight;
    }

    private boolean isNoiseContainer(Element element) {
        String attributes = JdHtmlExtractor.normalize((element.className() + " " + element.id()).toLowerCase(Locale.ROOT));
        if (attributes.isBlank()) {
            return false;
        }
        return containsAny(attributes, JdHtmlExtractor.NOISE_HINTS)
                || containsAny(attributes, JdHtmlExtractor.SARAMIN_NOISE_HINTS);
    }

    private boolean containsAny(String source, Set<String> hints) {
        for (String hint : hints) {
            if (source.contains(hint)) {
                return true;
            }
        }
        return false;
    }
}
