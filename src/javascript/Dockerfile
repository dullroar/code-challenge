# Container image for the Node.js entry. Run it with: sandbox/container/run-image.sh src/javascript
# The whole program is one file, timecards.mjs, run by Node 24 (node:sqlite is built in; there is no npm and no package).
# Add --tty to the run-image.sh command to see the DEMO ONLY line pulse. check.sh is for your own machine.
FROM cc-rt-node:local
COPY timecards.mjs /app/
ENV CC_RUN="node /app/timecards.mjs"
