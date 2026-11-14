# Container image for the pcre2grep entry. Run it with: sandbox/container/run-image.sh src/regex-pcre2grep
# Ubuntu's pcre2grep is built without callout scripts, so the toolchain image builds one from a
# SHA-256-pinned PCRE2 release (see sandbox/linux/Dockerfile); this image takes only that static binary.
FROM code-challenge-sandbox:local AS build

FROM cc-rt-sqlite:local
COPY --from=build /opt/pcre2/bin/pcre2grep /usr/local/bin/pcre2grep
COPY timecards.sh /app/timecards.sh
ENV CC_RUN="bash /app/timecards.sh"
