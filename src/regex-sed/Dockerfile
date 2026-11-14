# Container image for the sed regex entry. Run it with: sandbox/container/run-image.sh src/regex-sed
# GNU sed, bash and coreutils ship in the Ubuntu base; the base adds sqlite3 only.
FROM cc-rt-sqlite:local
COPY timecards.sh timecards.sed /app/
ENV CC_RUN="bash /app/timecards.sh"
