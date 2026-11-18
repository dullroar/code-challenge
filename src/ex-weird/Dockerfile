# Container image for the Ex entry. Run it with: sandbox/container/run-image.sh src/ex-weird
# The whole computation is nvi (a POSIX ex/vi) reading timecards.ex. The base adds nvi and sqlite3 on a minimal Ubuntu.
# check.sh is for your own machine; the image runs the demo.
FROM cc-rt-nvi:local
COPY timecards.ex timecards.sh /app/
ENV CC_RUN="sh /app/timecards.sh"
