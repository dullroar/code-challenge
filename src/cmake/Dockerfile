# Container image for the CMake entry. Run it with: sandbox/container/run-image.sh src/cmake
# CMake is the program's interpreter, so it stays; the base has cmake and sqlite3 only (no compiler, no make).
FROM cc-rt-cmake:local
COPY timecards.cmake /app/timecards.cmake
ENV CC_RUN="cmake -P /app/timecards.cmake"
