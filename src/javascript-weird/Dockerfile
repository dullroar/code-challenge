# Container image for the Node.js closure entry. Run it with: sandbox/container/run-image.sh src/javascript-weird
# The program is two files: core.mjs (three closures, no I/O) and timecards.mjs (the database, the clock, the screen).
# Node 24 has node:sqlite and iterator helpers built in; there is no npm and no package.
# Add --tty to the run-image.sh command to see the DEMO ONLY line pulse. check.sh and check.mjs are for your own machine.
FROM cc-rt-node:local
COPY core.mjs timecards.mjs /app/
ENV CC_RUN="node /app/timecards.mjs"
