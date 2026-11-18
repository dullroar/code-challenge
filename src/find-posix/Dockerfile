# Container image for the portable find entry. Run it with: sandbox/container/run-image.sh src/find-posix
# The whole program is one `find` (GNU findutils, from the Ubuntu base) plus printf, mkdir, mktemp and date
# (coreutils); the base adds sqlite3 only. check.sh, build-line.py and the other find implementations
# (bfs, busybox) are for your own machine; the image runs just the demo.
FROM cc-rt-sqlite:local
COPY timecards.sh /app/
ENV CC_RUN="sh /app/timecards.sh"
