# Container image for the Tcl entry. Run it with: sandbox/container/run-image.sh src/tcl-weird
# Nothing to build: tclsh runs the script. The runtime base has Tcl/Tk, the Tcl sqlite3 package,
# Xvfb and scrot (the harness starts the virtual display and takes a screenshot of the window),
# and no compiler or package manager. The window closes itself when the harness stops it.
FROM cc-rt-tcl:local
COPY timecards.tcl /app/timecards.tcl
ENV CC_XVFB=1
ENV CC_GUI_SECONDS=4
ENV CC_RUN="tclsh8.6 /app/timecards.tcl --gui"
