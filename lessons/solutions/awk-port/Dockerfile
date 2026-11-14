# Reference answer for exercise D. Run it with: sandbox/container/run-image.sh lessons/solutions/awk-port
# (the folder's name picks the image name, so this builds cc-entry-awk-port:local.)
FROM cc-rt-sqlite:local
COPY timecards.awk /app/timecards.awk
ENV CC_RUN="seq 5 | awk -f /app/timecards.awk"
