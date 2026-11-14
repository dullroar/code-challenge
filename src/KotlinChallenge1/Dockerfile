# Container image for the Kotlin entry. Run it with: sandbox/container/run-image.sh --online-build --out ./results src/KotlinChallenge1
# (--online-build because the build downloads Gradle (from this entry's wrapper) and the Maven dependencies; the
# run has no network.) Build stage: OpenJDK 25 and Gradle build one Spring Boot jar. Runtime stage: that jar on a
# base with the OpenJDK 25 JRE (with AWT), a virtual display (Xvfb) and a screenshot tool: no JDK, Gradle or
# compiler. The Swing window opens on the virtual display inside the container; the entrypoint screenshots it
# after the JVM has started, then closes it. The program creates data/ in its working directory (/work, a tmpfs).
FROM cc-build-java:local AS build
WORKDIR /build
COPY . .
RUN sh gradlew --no-daemon -q bootJar \
 && cp "$(ls build/libs/*.jar | grep -v -- -plain | head -n 1)" /build/app.jar

FROM cc-rt-java:local
COPY --from=build /build/app.jar /app/app.jar
ENV CC_RUN="java --enable-native-access=ALL-UNNAMED -jar /app/app.jar" CC_XVFB=1 CC_GUI_SECONDS=20 CC_SCREEN=800x500x24
