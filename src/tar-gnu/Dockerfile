# Container image for the GNU tar entry. Run it with: sandbox/container/run-image.sh src/tar-gnu
# The program is a tar archive; GNU tar (from the Ubuntu base) walks it and calls dispatch.sh once per member.
# The base adds sqlite3 only. check.sh is for your own machine; the image runs the demo.
FROM cc-rt-sqlite:local
COPY build-archive.sh inspect.sh interpret.sh dispatch.sh timecards.sh /app/
ENV CC_RUN="sh /app/timecards.sh"
