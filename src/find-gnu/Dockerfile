# Container image for the GNU find entry. Run it with: sandbox/container/run-image.sh src/find-gnu
# The whole program is one GNU `find` (findutils, from the Ubuntu base) plus mkdir and mktemp (coreutils);
# the base adds sqlite3 only. check.sh and build-line.py are for your own machine; the image runs the demo.
FROM cc-rt-sqlite:local
COPY timecards.sh /app/
ENV CC_RUN="sh /app/timecards.sh"
