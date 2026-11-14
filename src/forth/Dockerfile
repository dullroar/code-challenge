# Container image for the Forth entry. Run it with: sandbox/container/run-image.sh src/forth
# Nothing to build: Gforth interprets the script. The runtime base has gforth and sqlite3 (the
# entry pipes its SQL to sqlite3 through sh), and no compiler or package manager.
FROM cc-rt-gforth:local
COPY timecards.fs /app/timecards.fs
ENV CC_RUN="gforth /app/timecards.fs"
