# Container image for the AWK entry. Run it with: sandbox/container/run-image.sh src/awk
# Nothing to build: awk interprets the script. The runtime base has gawk, the system mawk and sqlite3;
# the entry is portable, so it runs here under mawk (the weird one needs gawk). No compiler or package manager.
FROM cc-rt-awk:local
COPY timecards.awk /app/timecards.awk
ENV CC_RUN="mawk -f /app/timecards.awk"
