# Container image for the Common Lisp entry. Run it with: sandbox/container/run-image.sh src/lisp-weird
# Nothing to build: SBCL runs the script. The runtime base has sbcl and sqlite3 (the entry pipes SQL
# to sqlite3), and no compiler or package manager.
FROM cc-rt-sbcl:local
COPY timecards.lisp /app/timecards.lisp
ENV CC_RUN="sbcl --script /app/timecards.lisp"
