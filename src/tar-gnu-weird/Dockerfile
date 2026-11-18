# Container image for the tar checkpoint-clock entry. Run it with: sandbox/container/run-image.sh src/tar-gnu-weird
# GNU tar (from the Ubuntu base) writes an archive, and its checkpoints run tick.sh. The base adds sqlite3 only.
# check.sh is for your own machine; the image runs the demo.
FROM cc-rt-sqlite:local
COPY machine.sql tick.sql tick.sh layout.sh run-clock.sh timecards.sh /app/
ENV CC_RUN="sh /app/timecards.sh"
