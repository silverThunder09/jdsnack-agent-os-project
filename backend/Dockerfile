FROM gradle:9.4.1-jdk17 AS build

WORKDIR /workspace

COPY settings.gradle build.gradle ./
COPY src ./src

RUN gradle --no-daemon clean bootJar

FROM eclipse-temurin:17-jre

WORKDIR /app

COPY --from=build /workspace/build/libs/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]

