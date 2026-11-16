# Container image for the m4 entry. Run it with: sandbox/container/run-image.sh src/m4
# Nothing to build: m4 interprets the file. The runtime base has GNU m4 and sqlite3, and sh for the
# entry's one syscmd; no compiler or package manager.
FROM cc-rt-m4:local
COPY timecards.m4 /app/timecards.m4
ENV CC_RUN="m4 /app/timecards.m4"
