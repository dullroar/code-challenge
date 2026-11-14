# Container image for the GNU Make entry. Run it with: sandbox/container/run-image.sh src/make-gnu
# Make is the program (it re-executes itself as the loop), so it stays; the base has make and sqlite3
# only. The Makefile is run from a private folder that starts out holding nothing else.
FROM cc-rt-make:local
COPY Makefile /app/Makefile
ENV CC_RUN=make CC_WORKDIR=/work/run CC_COPY_APP=1
