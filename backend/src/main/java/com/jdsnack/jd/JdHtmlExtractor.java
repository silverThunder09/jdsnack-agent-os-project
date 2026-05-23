package com.jdsnack.jd;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
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
    private static final Set<String> PROMOTIONAL_HINTS = Set.of(
            "join us", "why you should join", "build the future", "grow with us", "our mission",
            "our culture", "our values", "we are hiring", "apply now", "learn more",
            "discount", "offering a", "special offer", "promotion", "promo", "benefit",
            "limited time", "save ", "coupon", "deal",
            "함께 성장", "미래를 만듭", "우리 팀", "우리 문화", "지원하세요", "합류", "채용 중",
            "할인", "혜택", "프로모션", "이벤트", "특가", "쿠폰"
    );
    private static final Set<String> JD_CONTENT_HINTS = Set.of(
            "api", "backend", "spring", "java", "kotlin", "python", "mysql", "postgresql",
            "kafka", "system", "service", "platform", "architecture", "testing", "deployment",
            "experience", "responsibility", "requirement", "qualification", "stack", "operate",
            "개발", "설계", "운영", "경험", "필요", "우대", "자격", "요건", "책임", "역할",
            "서비스", "플랫폼", "백엔드", "테스트", "배포", "장애", "협업", "구현", "분석"
    );
    private static final List<String> NOISE_SELECTORS = List.of(
            "[hidden]",
            "[aria-hidden=true]",
            "[role=dialog]",
            "[role=alert]",
            "[role=navigation]",
            "[class*=sticky]",
            "[class*=share]",
            "[class*=social]",
            "[class*=recommend]",
            "[class*=related]",
            "[class*=sidebar]",
            "[class*=toolbar]",
            "[class*=cta]",
            "[class*=apply]",
            "[class*=benefit]",
            "[class*=location]",
            "[class*=job-meta]",
            "[class*=newsletter]",
            "[class*=footer]",
            "[class*=header]",
            "[id*=share]",
            "[id*=social]",
            "[id*=recommend]",
            "[id*=related]",
            "[id*=sidebar]",
            "[id*=cta]",
            "[id*=apply]"
    );

    public JdFetchResponse extract(String html, String sourceUrl) {
        Document document = Jsoup.parse(html, sourceUrl);
        sanitize(document);

        Element candidate = findCandidate(document);
        if (candidate == null) {
            throw new ApiException(ErrorCode.JD_FETCH_UNSUPPORTED_SOURCE);
        }

        String title = extractTitle(document);
        String jdText = trimDuplicatedTitlePrefix(extractCandidateText(candidate, title), title);
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
        for (String selector : NOISE_SELECTORS) {
            document.select(selector).remove();
        }
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
            if (containsHint(source, hint)) {
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

    private String extractCandidateText(Element candidate, String title) {
        Element sanitizedCandidate = candidate.clone();
        removeNestedNoise(sanitizedCandidate);
        removeDuplicatedHeadings(sanitizedCandidate, title);

        List<String> paragraphParts = new ArrayList<>();
        List<String> parts = new ArrayList<>();
        for (Element block : sanitizedCandidate.select("p, li")) {
            String text = normalize(block.text());
            if (text.isBlank()) {
                continue;
            }
            paragraphParts.add(text);
            if (isLikelyNoiseText(text)) {
                continue;
            }
            parts.add(text);
        }

        if (!parts.isEmpty()) {
            List<String> refinedParts = trimPromotionalLead(parts);
            return normalize(String.join(" ", refinedParts));
        }

        if (!paragraphParts.isEmpty()) {
            return normalize(String.join(" ", trimPromotionalLead(paragraphParts)));
        }

        return normalize(sanitizedCandidate.text());
    }

    private void removeNestedNoise(Element candidate) {
        for (String selector : NOISE_SELECTORS) {
            candidate.select(selector).remove();
        }
        candidate.select("[class], [id]").removeIf(this::isNoiseContainer);
    }

    private void removeDuplicatedHeadings(Element candidate, String title) {
        if (title.isBlank()) {
            return;
        }

        candidate.select("h1, h2").removeIf(element -> normalize(element.text()).equalsIgnoreCase(title));
    }

    private boolean isLikelyNoiseText(String text) {
        String normalized = text.toLowerCase(Locale.ROOT);
        if (normalized.length() <= 4) {
            return true;
        }

        int separatorCount = normalized.split("[|·/]").length - 1;
        if (separatorCount >= 3 && normalized.length() < 80) {
            return true;
        }

        for (String hint : NOISE_HINTS) {
            if (normalized.contains(hint) && normalized.length() < 120) {
                return true;
            }
        }

        int promotionalMatches = 0;
        for (String hint : PROMOTIONAL_HINTS) {
            if (containsHint(normalized, hint)) {
                promotionalMatches++;
            }
        }
        if (promotionalMatches >= 1 && normalized.length() < 160) {
            return true;
        }

        return false;
    }

    private List<String> trimPromotionalLead(List<String> parts) {
        if (parts.size() < 2) {
            return parts;
        }

        int firstContentIndex = findFirstContentIndex(parts);
        if (firstContentIndex <= 0) {
            return parts;
        }

        List<String> trimmed = new ArrayList<>();
        for (int i = 0; i < parts.size(); i++) {
            String text = parts.get(i);
            if (i < firstContentIndex && looksPromotionalLead(text)) {
                continue;
            }
            trimmed.add(text);
        }
        return trimmed.isEmpty() ? parts : trimmed;
    }

    private int findFirstContentIndex(List<String> parts) {
        for (int i = 0; i < parts.size(); i++) {
            if (hasJdContentHint(parts.get(i))) {
                return i;
            }
        }
        return -1;
    }

    private boolean looksPromotionalLead(String text) {
        String normalized = text.toLowerCase(Locale.ROOT);
        if (hasJdContentHint(normalized)) {
            return false;
        }

        int promotionalMatches = 0;
        for (String hint : PROMOTIONAL_HINTS) {
            if (containsHint(normalized, hint)) {
                promotionalMatches++;
            }
        }

        if (promotionalMatches > 0) {
            return true;
        }

        int englishLetters = countEnglishLetters(normalized);
        int koreanLetters = countKoreanLetters(normalized);

        return englishLetters > koreanLetters
                && normalized.length() < 180
                && !normalized.contains("experience")
                && !normalized.contains("requirement");
    }

    private boolean hasJdContentHint(String text) {
        String normalized = text.toLowerCase(Locale.ROOT);
        for (String hint : JD_CONTENT_HINTS) {
            if (containsHint(normalized, hint)) {
                return true;
            }
        }
        return false;
    }

    private boolean containsHint(String source, String hint) {
        if (hint.chars().allMatch(ch -> ch < 128 && Character.isLetterOrDigit(ch))) {
            String[] tokens = source.split("[^a-z0-9]+");
            for (String token : tokens) {
                if (token.equals(hint)) {
                    return true;
                }
            }
            return false;
        }

        return source.contains(hint);
    }

    private int countEnglishLetters(String text) {
        int count = 0;
        for (int i = 0; i < text.length(); i++) {
            char ch = text.charAt(i);
            if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
                count++;
            }
        }
        return count;
    }

    private int countKoreanLetters(String text) {
        int count = 0;
        for (int i = 0; i < text.length(); i++) {
            char ch = text.charAt(i);
            if (ch >= 0xAC00 && ch <= 0xD7A3) {
                count++;
            }
        }
        return count;
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
