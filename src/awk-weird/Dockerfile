# Container image for the AWK "weird" entry. Run it with: sandbox/container/run-image.sh src/awk-weird
# Nothing to build: gawk interprets the script (it needs GNU awk: RT and a regular-expression RS).
# The runtime base has gawk and sqlite3, and no compiler or package manager.
FROM cc-rt-awk:local
COPY timecards.awk /app/timecards.awk
ENV CC_RUN="gawk -f /app/timecards.awk"
