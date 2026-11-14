# Container image for the APL entry. Run it with: sandbox/container/run-image.sh src/apl
# GNU APL is not packaged by Ubuntu: the toolchain image builds it from a SHA-256-pinned gnu.org
# tarball (see sandbox/linux/Dockerfile), and this image takes only the finished /opt/apl from it.
FROM code-challenge-sandbox:local AS build

FROM cc-rt-apl:local
COPY --from=build /opt/apl /opt/apl
COPY timecards.apl /app/timecards.apl
ENV CC_RUN="/opt/apl/bin/apl --script -f /app/timecards.apl"
