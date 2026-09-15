package com.jdsnack.auth;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import static org.assertj.core.api.Assertions.assertThat;

/** Flyway 전용 non-web 컨텍스트에서도 인증 컨트롤러가 애플리케이션 기동을 막지 않는지 검증한다. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
class AuthControllerNonWebContextTest {

    @Autowired
    private AuthController authController;

    @Test
    void loadsWithoutServletServerPropertiesBean() {
        assertThat(authController).isNotNull();
    }
}
