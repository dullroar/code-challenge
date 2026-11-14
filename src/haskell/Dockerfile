# Container image for the Haskell entry. Run it with: sandbox/container/run-image.sh src/haskell
# Build stage: GHC compiles the script to one binary. Runtime stage: that binary on a base with
# sqlite3 and the two shared libraries it needs, with no GHC in it.
FROM code-challenge-sandbox:local AS build
USER root
WORKDIR /build
COPY timecards.hs .
RUN ghc -O1 -o timecards timecards.hs

FROM cc-rt-haskell:local
COPY --from=build /build/timecards /app/timecards
ENV CC_RUN=/app/timecards
