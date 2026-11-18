# Container image for the ed entry. Run it with: sandbox/container/run-image.sh src/ed-weird
# The whole computation is GNU ed reading timecards.ed. The base adds ed and sqlite3 on a minimal Ubuntu.
# check.sh is for your own machine; the image runs the demo.
FROM cc-rt-ed:local
COPY timecards.ed timecards.sh /app/
ENV CC_RUN="sh /app/timecards.sh"
