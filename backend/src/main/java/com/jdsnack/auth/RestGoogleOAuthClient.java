package com.jdsnack.auth;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.jdsnack.common.ApiException;
import com.jdsnack.common.ErrorCode;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;

@Component
public class RestGoogleOAuthClient implements GoogleOAuthClient {

    private final RestClient restClient;
    private final GoogleAuthProperties properties;

    public RestGoogleOAuthClient(RestClient.Builder restClientBuilder, GoogleAuthProperties properties) {
        this.restClient = restClientBuilder.build();
        this.properties = properties;
    }

    @Override
    public GoogleUserProfile authenticate(String code) {
        if (!properties.isConfigured()) {
            throw new ApiException(ErrorCode.OAUTH_NOT_CONFIGURED);
        }

        GoogleTokenResponse token = requestToken(code);
        GoogleProfileResponse profile = requestProfile(token.accessToken());

        if (profile == null || isBlank(profile.sub()) || isBlank(profile.email())) {
            throw new ApiException(ErrorCode.OAUTH_PROVIDER_FAILED);
        }

        return new GoogleUserProfile(profile.sub(), profile.email(), profile.name());
    }

    private GoogleTokenResponse requestToken(String code) {
        try {
            MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
            form.add("code", code);
            form.add("client_id", properties.clientId());
            form.add("client_secret", properties.clientSecret());
            form.add("redirect_uri", properties.redirectUri());
            form.add("grant_type", "authorization_code");

            GoogleTokenResponse response = restClient.post()
                    .uri(properties.tokenUri())
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(form)
                    .retrieve()
                    .body(GoogleTokenResponse.class);

            if (response == null || isBlank(response.accessToken())) {
                throw new ApiException(ErrorCode.OAUTH_PROVIDER_FAILED);
            }
            return response;
        } catch (ApiException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            throw new ApiException(ErrorCode.OAUTH_PROVIDER_FAILED, exception);
        }
    }

    private GoogleProfileResponse requestProfile(String accessToken) {
        try {
            return restClient.get()
                    .uri(properties.userInfoUri())
                    .headers(headers -> headers.setBearerAuth(accessToken))
                    .retrieve()
                    .body(GoogleProfileResponse.class);
        } catch (RuntimeException exception) {
            throw new ApiException(ErrorCode.OAUTH_PROVIDER_FAILED, exception);
        }
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private record GoogleTokenResponse(
            @JsonProperty("access_token") String accessToken
    ) {
    }

    private record GoogleProfileResponse(
            String sub,
            String email,
            String name
    ) {
    }
}
