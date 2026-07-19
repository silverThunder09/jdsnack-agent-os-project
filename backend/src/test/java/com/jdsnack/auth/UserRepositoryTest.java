package com.jdsnack.auth;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.JdbcTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.assertj.core.api.Assertions.assertThat;

@JdbcTest
@Import(UserRepository.class)
class UserRepositoryTest {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void savesOneUserAndUpdatesTheExistingGoogleAccount() {
        UserRecord first = userRepository.saveGoogleUser(profile("first@example.com"));
        UserRecord updated = userRepository.saveGoogleUser(profile("updated@example.com"));

        assertThat(updated.id()).isEqualTo(first.id());
        assertThat(updated.email()).isEqualTo("updated@example.com");
        assertThat(jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM app_user WHERE provider_subject = ?",
                Integer.class,
                "google-subject-1"
        )).isEqualTo(1);
    }

    @Test
    void concurrentGoogleCallbacksReuseOneUserWhenInsertRaces() throws Exception {
        int workerCount = 8;
        ExecutorService executor = Executors.newFixedThreadPool(workerCount);
        CountDownLatch ready = new CountDownLatch(workerCount);
        CountDownLatch start = new CountDownLatch(1);
        List<Future<UserRecord>> futures = new ArrayList<>();

        try {
            for (int index = 0; index < workerCount; index++) {
                futures.add(executor.submit(() -> {
                    ready.countDown();
                    start.await();
                    return userRepository.saveGoogleUser(profile("user@example.com"));
                }));
            }

            ready.await();
            start.countDown();

            List<UserRecord> users = new ArrayList<>();
            for (Future<UserRecord> future : futures) {
                users.add(future.get());
            }

            assertThat(users).extracting(UserRecord::id).containsOnly(users.get(0).id());
            assertThat(jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM app_user WHERE provider_subject = ?",
                    Integer.class,
                    "google-subject-1"
            )).isEqualTo(1);
        } finally {
            executor.shutdownNow();
        }
    }

    private GoogleUserProfile profile(String email) {
        return new GoogleUserProfile("google-subject-1", email, "테스트 사용자");
    }
}
