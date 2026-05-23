package com.jdsnack.match;

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
import java.util.stream.Collectors;

@Service
public class MatchPreviewService {

    private static final int MIN_JD_LENGTH = 50;
    private static final int MAX_JD_LENGTH = 10_000;
    private static final int MAX_KEYWORDS = 8;
    private static final Set<String> STOP_WORDS = Set.of(
            "and", "the", "with", "for", "from", "that", "this", "have", "will",
            "into", "your", "about", "using", "through", "then", "than", "able",
            "합니다", "및", "경험", "이상", "지원", "업무", "관련", "우대", "필수", "기반",
            "역량", "기술", "능력", "이해", "보유", "활용", "개발", "운영", "프로젝트"
    );

    public MatchPreviewResponse preview(MatchPreviewRequest request) {
        validateRequest(request);
        return buildPreview(request);
    }

    private void validateRequest(MatchPreviewRequest request) {
        if (request == null || request.resumeSource() == null) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }

        validateResumeSource(request.resumeSource());
        validateJdText(request.jdText());
        validateJdUrl(request.jdUrl());
    }

    private void validateResumeSource(MatchPreviewRequest.ResumeSource resumeSource) {
        String type = normalized(resumeSource.type());
        String value = normalized(resumeSource.value());

        if (value == null || value.isBlank()) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }

        if (!"TEXT".equals(type) && !"FILE".equals(type)) {
            throw new ApiException(ErrorCode.EMPTY_RESUME);
        }
    }

    private void validateJdText(String jdText) {
        String normalizedText = normalized(jdText);

        if (normalizedText == null || normalizedText.isBlank()) {
            throw new ApiException(ErrorCode.EMPTY_JD);
        }

        int length = normalizedText.length();
        if (length < MIN_JD_LENGTH) {
            throw new ApiException(ErrorCode.JD_TEXT_TOO_SHORT);
        }

        if (length > MAX_JD_LENGTH) {
            throw new ApiException(ErrorCode.JD_TEXT_TOO_LONG);
        }
    }

    private void validateJdUrl(String jdUrl) {
        String normalizedUrl = normalized(jdUrl);
        if (normalizedUrl == null || normalizedUrl.isBlank()) {
            return;
        }

        try {
            URI uri = new URI(normalizedUrl);
            String scheme = uri.getScheme();
            String host = uri.getHost();

            if (scheme == null || host == null) {
                throw new ApiException(ErrorCode.INVALID_JD_URL);
            }

            String lowerScheme = scheme.toLowerCase(Locale.ROOT);
            if (!"http".equals(lowerScheme) && !"https".equals(lowerScheme)) {
                throw new ApiException(ErrorCode.INVALID_JD_URL);
            }
        } catch (URISyntaxException exception) {
            throw new ApiException(ErrorCode.INVALID_JD_URL);
        }
    }

    private MatchPreviewResponse buildPreview(MatchPreviewRequest request) {
        List<String> resumeKeywords = extractKeywords(request.resumeSource().value());
        List<String> jdKeywords = extractKeywords(request.jdText());
        List<String> matched = jdKeywords.stream()
                .filter(resumeKeywords::contains)
                .distinct()
                .limit(3)
                .toList();
        List<String> gaps = jdKeywords.stream()
                .filter(keyword -> !resumeKeywords.contains(keyword))
                .distinct()
                .limit(3)
                .toList();

        int score = calculateScore(jdKeywords, matched);

        return new MatchPreviewResponse(
                score,
                buildSummary(score, matched, gaps),
                buildStrengths(matched, request.resumeSource().type()),
                buildGaps(gaps),
                buildSuggestions(gaps)
        );
    }

    private List<String> extractKeywords(String text) {
        if (text == null) {
            return List.of();
        }

        Set<String> ordered = Arrays.stream(text.toLowerCase(Locale.ROOT).split("[^\\p{L}\\p{N}]+"))
                .map(String::trim)
                .filter(token -> token.length() >= 2)
                .filter(token -> !STOP_WORDS.contains(token))
                .collect(Collectors.toCollection(LinkedHashSet::new));

        return ordered.stream().limit(MAX_KEYWORDS).toList();
    }

    private int calculateScore(List<String> jdKeywords, List<String> matched) {
        if (jdKeywords.isEmpty()) {
            return 0;
        }

        double ratio = (double) matched.size() / jdKeywords.size();
        int score = (int) Math.round(ratio * 100);
        return Math.max(score, matched.isEmpty() ? 28 : 45);
    }

    private String buildSummary(int score, List<String> matched, List<String> gaps) {
        if (matched.isEmpty()) {
            return "JD 핵심 키워드와 직접 겹치는 이력서 표현이 적습니다. 프로젝트 성과와 기술 키워드를 더 명확히 드러내는 보강이 필요합니다.";
        }

        if (gaps.isEmpty()) {
            return "JD 핵심 키워드가 이력서에 고르게 반영되어 있습니다. 경험 근거와 성과 수치를 보강하면 설득력이 더 올라갑니다.";
        }

        return String.format(
                Locale.KOREA,
                "JD 핵심 키워드 중 %s는 이력서에서 확인되지만, %s 관련 근거는 더 보강하는 편이 좋습니다. 현재 미리보기 점수는 %d점입니다.",
                joinKeywords(matched),
                joinKeywords(gaps),
                score
        );
    }

    private List<String> buildStrengths(List<String> matched, String resumeSourceType) {
        List<String> strengths = new ArrayList<>();

        if (!matched.isEmpty()) {
            strengths.add("JD 핵심 키워드와 겹치는 이력서 표현이 있습니다: " + joinKeywords(matched));
        }

        strengths.add(
                "FILE".equals(normalized(resumeSourceType))
                        ? "업로드 이력서에서 추출한 본문 기준으로 비교 미리보기를 생성했습니다."
                        : "현재 입력한 이력서 텍스트 기준으로 비교 미리보기를 생성했습니다."
        );

        strengths.add("실제 AI 분석 전에도 JD와 이력서의 키워드 겹침 정도를 빠르게 확인할 수 있습니다.");
        return strengths.stream().limit(3).toList();
    }

    private List<String> buildGaps(List<String> gaps) {
        if (gaps.isEmpty()) {
            return List.of("현재 JD 핵심 키워드 기준으로 눈에 띄는 누락 항목이 크지 않습니다.");
        }

        return gaps.stream()
                .map(keyword -> keyword + " 관련 경험 또는 성과 근거가 이력서에서 약하게 보입니다.")
                .toList();
    }

    private List<String> buildSuggestions(List<String> gaps) {
        if (gaps.isEmpty()) {
            return List.of(
                    "핵심 프로젝트마다 성과 수치와 담당 역할을 한 줄씩 더 추가해 보세요.",
                    "JD와 직접 맞닿는 기술 키워드를 경력 bullet 앞쪽에 배치해 보세요."
            );
        }

        return gaps.stream()
                .map(keyword -> keyword + " 경험이 있다면 프로젝트 맥락, 사용 기술, 결과를 함께 적어 보세요.")
                .toList();
    }

    private String joinKeywords(List<String> keywords) {
        return String.join(", ", keywords);
    }

    private String normalized(String value) {
        return value == null ? null : value.trim();
    }
}
