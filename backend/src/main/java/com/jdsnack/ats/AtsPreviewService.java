package com.jdsnack.ats;

import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@Service
public class AtsPreviewService {

    private static final int MIN_TEXT_LENGTH = 50;
    private static final int MAX_TEXT_LENGTH = 10_000;
    private static final int MAX_KEYWORDS = 8;
    private static final Pattern EMAIL_PATTERN = Pattern.compile("[\\w.+-]+@[\\w-]+(?:\\.[\\w-]+)+");
    private static final Pattern PHONE_PATTERN = Pattern.compile("(?:02|0\\d{2})[- .]?\\d{3,4}[- .]?\\d{4}");
    private static final Pattern NUMBER_PATTERN = Pattern.compile("\\d+(?:[.,]\\d+)?(?:%|건|명|개월|년|배)?");
    private static final Set<String> STOP_WORDS = Set.of(
            "and", "the", "with", "for", "from", "that", "this", "have", "will", "into", "your",
            "about", "using", "through", "then", "than", "able", "합니다", "및", "경험", "이상",
            "지원", "업무", "관련", "우대", "필수", "기반", "역량", "기술", "능력", "이해", "보유",
            "활용", "개발", "운영", "프로젝트", "저는", "있는", "위한", "대한"
    );

    public AtsPreviewResponse preview(AtsPreviewRequest request) {
        validateRequest(request);

        String resume = request.resumeSource().value().trim();
        String jd = request.jdText().trim();
        List<String> jdKeywords = extractKeywords(jd);
        List<String> resumeKeywords = extractKeywords(resume);
        List<String> matchedKeywords = jdKeywords.stream().filter(resumeKeywords::contains).toList();
        List<String> missingKeywords = jdKeywords.stream().filter(keyword -> !resumeKeywords.contains(keyword)).toList();
        List<AtsPreviewResponse.FormatCheck> formatChecks = formatChecks(resume);

        int keywordScore = jdKeywords.isEmpty() ? 0 : Math.round((float) matchedKeywords.size() / jdKeywords.size() * 45);
        int sectionScore = Math.min(sectionCount(resume) * 7, 28);
        int evidenceScore = NUMBER_PATTERN.matcher(resume).find() ? 17 : 5;
        int contactScore = hasContactSignal(resume) ? 7 : 0;
        int bulletScore = hasBulletStructure(resume) ? 3 : 0;
        int score = Math.min(100, keywordScore + sectionScore + evidenceScore + contactScore + bulletScore);

        List<String> strengths = new ArrayList<>();
        List<String> risks = new ArrayList<>();
        List<String> suggestions = new ArrayList<>();
        if (!matchedKeywords.isEmpty()) {
            strengths.add("JD 핵심 키워드가 이력서에서 확인됩니다: " + join(matchedKeywords));
        }
        if (hasContactSignal(resume)) {
            strengths.add("연락처 단서가 확인되어 기본 파싱 가능성이 높습니다.");
        }
        if (NUMBER_PATTERN.matcher(resume).find()) {
            strengths.add("숫자·성과 단서가 포함되어 경험의 결과를 파악할 수 있습니다.");
        }
        if (missingKeywords.isEmpty()) {
            risks.add("현재 추출된 JD 핵심 키워드에서 큰 누락이 보이지 않습니다.");
        } else {
            risks.add("JD 핵심 키워드 일부가 이력서에서 확인되지 않습니다: " + join(missingKeywords));
            suggestions.add("실제 경험이 있는 누락 키워드는 프로젝트 역할과 성과 근거를 함께 추가해 보세요.");
        }
        formatChecks.stream()
                .filter(check -> !check.passed())
                .forEach(check -> suggestions.add(check.message()));
        if (suggestions.isEmpty()) {
            suggestions.add("각 경력 bullet에 담당 역할과 측정 가능한 결과를 한 줄씩 보강해 보세요.");
        }

        return new AtsPreviewResponse(
                score,
                buildSummary(score),
                limit(strengths, "연락처·섹션·성과 단서가 더해지면 ATS가 읽을 수 있는 신호가 늘어납니다."),
                limit(risks, "추출된 텍스트 기준으로 확인된 보완 포인트입니다."),
                limit(suggestions, "실제 경험과 일치하는 항목만 반영하세요."),
                matchedKeywords,
                missingKeywords,
                formatChecks
        );
    }

    private void validateRequest(AtsPreviewRequest request) {
        if (request == null || request.resumeSource() == null) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }

        String type = normalized(request.resumeSource().type());
        String resume = normalized(request.resumeSource().value());
        if (!("TEXT".equals(type) || "FILE".equals(type)) || resume == null || resume.isBlank()) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }
        validateLength(resume, ErrorCode.TEXT_TOO_SHORT, ErrorCode.TEXT_TOO_LONG);

        String jd = normalized(request.jdText());
        if (jd == null || jd.isBlank()) {
            throw new ApiException(ErrorCode.EMPTY_JD);
        }
        validateLength(jd, ErrorCode.JD_TEXT_TOO_SHORT, ErrorCode.JD_TEXT_TOO_LONG);
        validateUrl(request.jdUrl());
    }

    private void validateLength(String value, ErrorCode tooShort, ErrorCode tooLong) {
        if (value.length() < MIN_TEXT_LENGTH) {
            throw new ApiException(tooShort);
        }
        if (value.length() > MAX_TEXT_LENGTH) {
            throw new ApiException(tooLong);
        }
    }

    private void validateUrl(String value) {
        String url = normalized(value);
        if (url == null || url.isBlank()) {
            return;
        }
        try {
            URI uri = new URI(url);
            String scheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
            if (uri.getHost() == null || !("http".equals(scheme) || "https".equals(scheme))) {
                throw new ApiException(ErrorCode.INVALID_JD_URL);
            }
        } catch (URISyntaxException exception) {
            throw new ApiException(ErrorCode.INVALID_JD_URL);
        }
    }

    private List<String> extractKeywords(String text) {
        return Arrays.stream(text.toLowerCase(Locale.ROOT).split("[^\\p{L}\\p{N}]+"))
                .map(String::trim)
                .filter(token -> token.length() >= 2)
                .filter(token -> !STOP_WORDS.contains(token))
                .collect(Collectors.toCollection(LinkedHashSet::new))
                .stream()
                .limit(MAX_KEYWORDS)
                .toList();
    }

    private List<AtsPreviewResponse.FormatCheck> formatChecks(String resume) {
        return List.of(
                new AtsPreviewResponse.FormatCheck(
                        "연락처 단서",
                        hasContactSignal(resume),
                        "이메일 또는 전화번호 단서를 이력서 상단에 명확히 배치해 보세요."
                ),
                new AtsPreviewResponse.FormatCheck(
                        "표준 섹션",
                        sectionCount(resume) >= 2,
                        "경력, 기술, 프로젝트처럼 역할이 분명한 섹션 제목을 사용해 보세요."
                ),
                new AtsPreviewResponse.FormatCheck(
                        "목록 구조",
                        hasBulletStructure(resume),
                        "긴 문단보다 한 줄에 하나의 성과를 담은 bullet 구조를 사용해 보세요."
                ),
                new AtsPreviewResponse.FormatCheck(
                        "성과 수치",
                        NUMBER_PATTERN.matcher(resume).find(),
                        "가능하면 기간, 비율, 건수, 사용자 수 등 측정 가능한 결과를 추가해 보세요."
                )
        );
    }

    private int sectionCount(String resume) {
        String lower = resume.toLowerCase(Locale.ROOT);
        String[] sections = {"경력", "기술", "스킬", "프로젝트", "학력", "experience", "skills", "projects", "education"};
        return (int) Arrays.stream(sections).filter(lower::contains).distinct().count();
    }

    private boolean hasContactSignal(String resume) {
        return EMAIL_PATTERN.matcher(resume).find() || PHONE_PATTERN.matcher(resume).find();
    }

    private boolean hasBulletStructure(String resume) {
        return Arrays.stream(resume.split("\\R"))
                .map(String::trim)
                .anyMatch(line -> line.matches("(?:[-*•]|\\d+[.)]).+"));
    }

    private List<String> limit(List<String> items, String fallback) {
        return items.isEmpty() ? List.of(fallback) : items.stream().limit(3).toList();
    }

    private String buildSummary(int score) {
        if (score >= 80) {
            return "핵심 키워드와 구조화된 이력서 신호가 비교적 잘 갖춰져 있습니다.";
        }
        if (score >= 60) {
            return "기본적인 ATS 신호는 확인되지만 키워드와 성과 근거를 더 보강할 필요가 있습니다.";
        }
        return "ATS가 읽을 수 있는 기본 신호가 부족합니다. 섹션·키워드·성과 수치를 우선 정리해 보세요.";
    }

    private String join(List<String> values) {
        return String.join(", ", values);
    }

    private String normalized(String value) {
        return value == null ? null : value.trim();
    }
}
