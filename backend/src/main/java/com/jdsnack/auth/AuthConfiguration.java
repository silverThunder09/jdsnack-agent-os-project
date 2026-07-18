package com.jdsnack.auth;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(GoogleAuthProperties.class)
public class AuthConfiguration {
}
