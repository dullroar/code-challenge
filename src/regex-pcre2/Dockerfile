# Container image for the PCRE2 entry. Run it with: sandbox/container/run-image.sh src/regex-pcre2
# Build stage: the C host is compiled against libpcre2-dev. Runtime stage: the binary on a base
# with only the shared libpcre2 library, with no compiler or headers.
FROM code-challenge-sandbox:local AS build
USER root
WORKDIR /build
COPY Makefile timecards.c ./
RUN make timecards

FROM cc-rt-pcre2:local
COPY --from=build /build/timecards /app/timecards
ENV CC_RUN=/app/timecards
