# Container image for the COBOL entry. Run it with: sandbox/container/run-image.sh src/cobol
# Build stage: GnuCOBOL's cobc compiles the program (through C) to one binary. Runtime stage: that
# binary on a base with sqlite3 and GnuCOBOL's runtime library (libcob), with no compiler in it.
FROM code-challenge-sandbox:local AS build
USER root
WORKDIR /build
COPY timecards.cob .
RUN cobc -x -o timecards timecards.cob

FROM cc-rt-cobol:local
COPY --from=build /build/timecards /app/timecards
ENV CC_RUN=/app/timecards
