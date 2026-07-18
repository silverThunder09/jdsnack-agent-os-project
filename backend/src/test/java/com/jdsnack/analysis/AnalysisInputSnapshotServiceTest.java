package com.jdsnack.analysis;

import com.jdsnack.common.ApiException;
import com.jdsnack.diagnose.ResumeExtractionService;
import com.jdsnack.diagnose.TextNormalizer;
import com.jdsnack.jd.JdFetchRequest;
import com.jdsnack.jd.JdFetchResponse;
import com.jdsnack.jd.JdFetchService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AnalysisInputSnapshotServiceTest {

    private static final String USER_ID = "user-1";
    private static final String RESUME_TEXT = "Spring Boot API 개발과 테스트 자동화 경험이 있으며 배포 운영도 다뤘습니다. 프로젝트 성과를 수치로 정리했습니다.";
    private static final String JD_TEXT = "Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화와 배포 경험을 요구합니다. 협업과 장애 대응 경험도 중요합니다.";

    @Mock
    private AnalysisInputSnapshotRepository repository;

    @Mock
    private ResumeExtractionService resumeExtractionService;

    @Mock
    private JdFetchService jdFetchService;

    @Test
    void textInputIsNormalizedAndSavedWithoutFileMetadata() {
        AnalysisInputSnapshotService service = service();
        when(repository.save(any(AnalysisInputSnapshot.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        AnalysisInputSnapshot snapshot = service.saveTextInput(
                USER_ID,
                "  Spring   Boot API 개발과 테스트 자동화 경험이 있으며 배포 운영도 다뤘습니다. 프로젝트 성과를 수치로 정리했습니다.  ",
                "  Spring Boot 기반 REST API 개발과 운영 경험, 테스트 자동화와 배포 경험을 요구합니다. 협업과 장애 대응 경험도 중요합니다.  "
        );

        assertThat(snapshot.userId()).isEqualTo(USER_ID);
        assertThat(snapshot.resumeText()).isEqualTo(RESUME_TEXT);
        assertThat(snapshot.jdText()).isEqualTo(JD_TEXT);
        assertThat(snapshot.jdInputType()).isEqualTo(JdInputType.TEXT);
        assertThat(snapshot.sourceUrl()).isNull();
        assertThat(snapshot.sourceSite()).isNull();
        assertThat(snapshot.fetchMode()).isNull();
        assertThat(snapshot.id()).isNotBlank();
        assertThat(snapshot.createdAt()).isNotNull();
    }

    @Test
    void fileInputStoresExtractedTextOnly() {
        AnalysisInputSnapshotService service = service();
        MockMultipartFile file = new MockMultipartFile(
                "resumeFile",
                "resume.pdf",
                "application/pdf",
                "private original bytes".getBytes()
        );
        when(resumeExtractionService.extractText(file)).thenReturn(RESUME_TEXT);
        when(repository.save(any(AnalysisInputSnapshot.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        AnalysisInputSnapshot snapshot = service.saveFileInput(USER_ID, file, JD_TEXT);

        assertThat(snapshot.resumeText()).isEqualTo(RESUME_TEXT);
        assertThat(snapshot.jdText()).isEqualTo(JD_TEXT);
        verify(resumeExtractionService).extractText(file);
        verify(repository).save(any(AnalysisInputSnapshot.class));
    }

    @Test
    void saraminUrlInputUsesFetchBoundaryAndStoresFetchedSnapshot() {
        AnalysisInputSnapshotService service = service();
        JdFetchResponse fetched = new JdFetchResponse(
                JD_TEXT,
                "https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=123",
                "백엔드 개발자",
                "static-html",
                "saramin"
        );
        when(jdFetchService.fetch(any(JdFetchRequest.class))).thenReturn(fetched);
        when(repository.save(any(AnalysisInputSnapshot.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        AnalysisInputSnapshot snapshot = service.saveSaraminUrlInput(
                USER_ID,
                RESUME_TEXT,
                fetched.sourceUrl()
        );

        assertThat(snapshot.jdInputType()).isEqualTo(JdInputType.SARAMIN_URL);
        assertThat(snapshot.jdText()).isEqualTo(JD_TEXT);
        assertThat(snapshot.sourceUrl()).isEqualTo(fetched.sourceUrl());
        assertThat(snapshot.sourceSite()).isEqualTo("saramin");
        assertThat(snapshot.fetchMode()).isEqualTo("static-html");

        ArgumentCaptor<JdFetchRequest> requestCaptor = ArgumentCaptor.forClass(JdFetchRequest.class);
        verify(jdFetchService).fetch(requestCaptor.capture());
        assertThat(requestCaptor.getValue().jdUrl()).isEqualTo(fetched.sourceUrl());
    }

    @Test
    void failedJdFetchDoesNotPersistInput() {
        AnalysisInputSnapshotService service = service();
        when(jdFetchService.fetch(any(JdFetchRequest.class)))
                .thenThrow(new ApiException(com.jdsnack.common.ErrorCode.JD_FETCH_FAILED));

        assertThatThrownBy(() -> service.saveSaraminUrlInput(
                USER_ID,
                RESUME_TEXT,
                "https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=123"
        ))
                .isInstanceOf(ApiException.class)
                .extracting("errorCode")
                .isEqualTo(com.jdsnack.common.ErrorCode.JD_FETCH_FAILED);

        verify(repository, never()).save(any(AnalysisInputSnapshot.class));
    }

    @Test
    void invalidInputIsRejectedBeforePersistence() {
        AnalysisInputSnapshotService service = service();

        assertThatThrownBy(() -> service.saveTextInput(USER_ID, "too short", JD_TEXT))
                .isInstanceOf(ApiException.class)
                .extracting("errorCode")
                .isEqualTo(com.jdsnack.common.ErrorCode.TEXT_TOO_SHORT);

        verify(repository, never()).save(any(AnalysisInputSnapshot.class));
    }

    private AnalysisInputSnapshotService service() {
        return new AnalysisInputSnapshotService(
                repository,
                resumeExtractionService,
                jdFetchService,
                new TextNormalizer()
        );
    }
}
