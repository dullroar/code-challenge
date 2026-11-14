#!/bin/sh
# The one entrypoint every entry image shares. It lives in the trusted runtime bases, not in
# an entry's folder, so an entry can only choose WHAT to run (the CC_* variables below).
#
#   CC_RUN       command to run (required), e.g. /app/timecards or "gforth /app/timecards.fs"
#   CC_WORKDIR   where it runs (default /work, a tmpfs); CC_COPY_APP=1 copies /app there first
#   CC_SERVE     1 = the entry serves a page on loopback and waits for /closed (the Go entry):
#                fetch the page with busybox wget, then "close" it, then wait for the program
#   CC_XVFB      1 = a GUI entry: start a virtual display (Xvfb), run the entry on it, take a
#                screenshot (screenshot.png) after CC_GUI_SECONDS (default 6), then close it with SIGTERM
#   CC_TIMEOUT   seconds before the entry is killed (default 120)
#
# After the run it prints an INSPECT section: every file the entry wrote, with SQLite databases
# opened read-only and shown table by table. If a folder is mounted at /out (opt-in, see
# run-image.sh --out) the interesting files are copied there.
set -u
: "${CC_RUN:?this image has no CC_RUN}"
work=${CC_WORKDIR:-/work}
export HOME=/work/home XDG_DATA_HOME=/work/xdg
mkdir -p "$HOME" "$XDG_DATA_HOME" "$work"
[ "${CC_COPY_APP:-0}" = 1 ] && cp -r /app/. "$work"/
cd "$work" || exit 2
log=/work/run.log
: > "$log"

echo "=== RUN  ($CC_RUN)"
if [ "${CC_XVFB:-0}" = 1 ]; then
    export DISPLAY=:99 GDK_BACKEND=x11 GSK_RENDERER=cairo GTK_A11Y=none NO_AT_BRIDGE=1 LIBGL_ALWAYS_SOFTWARE=1
    Xvfb :99 -screen 0 "${CC_SCREEN:-1024x768x24}" -nolisten tcp > /work/xvfb.log 2>&1 &
    xpid=$!
    i=0; while [ $i -lt 50 ] && [ ! -e /tmp/.X11-unix/X99 ]; do sleep 0.1; i=$((i + 1)); done
    echo "virtual display $DISPLAY up (Xvfb ${CC_SCREEN:-1024x768x24}); no host display is involved"
    timeout -k 5 "${CC_TIMEOUT:-120}" sh -c "$CC_RUN" > "$log" 2>&1 &
    pid=$!
    sleep "${CC_GUI_SECONDS:-6}"
    if kill -0 "$pid" 2>/dev/null; then
        scrot /work/screenshot.png 2>>"$log" && echo "window on screen after ${CC_GUI_SECONDS:-6}s; screenshot.png saved ($(wc -c < /work/screenshot.png) bytes)"
        kill -TERM "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
        echo "closed by the harness (SIGTERM)"; rc=0
    else
        wait "$pid"; rc=$?
        echo "the entry exited on its own before the screenshot"
    fi
    kill "$xpid" 2>/dev/null
    cat "$log"
elif [ "${CC_SERVE:-0}" = 1 ]; then
    timeout -k 5 "${CC_TIMEOUT:-120}" sh -c "$CC_RUN" > "$log" 2>&1 &
    pid=$!
    url= i=0
    while [ $i -lt 150 ] && [ -z "$url" ]; do
        url=$(sed -n 's#.*\(http://127\.0\.0\.1:[0-9]*/\).*#\1#p' "$log" | head -n 1)
        [ -z "$url" ] && { sleep 0.2; i=$((i + 1)); }
    done
    if [ -n "$url" ]; then
        echo "served at $url (inside the container; fetched over loopback with wget)"
        busybox wget -q -O /work/page.html "$url" && echo "page: $(wc -c < /work/page.html) bytes saved as page.html"
        busybox wget -q -O /dev/null "${url}closed"
    else
        echo "the entry never announced a loopback URL"
    fi
    wait "$pid"; rc=$?
    cat "$log"
else
    # tee would hide the entry's exit status, so it is written to a file and read back.
    { timeout -k 5 "${CC_TIMEOUT:-120}" sh -c "$CC_RUN" 2>&1; echo $? > /work/rc; } | tee "$log"
    rc=$(cat /work/rc)
fi
echo "=== EXIT $rc"

echo
echo "=== INSPECT  (what the entry left behind; read-only view)"
find /work -type f ! -path '/work/home/*' ! -name run.log ! -name rc -exec ls -l {} + 2>/dev/null | sed 's#^#  #'
for db in $(find /work -type f \( -name '*.db' -o -name '*.sqlite' \) ! -path '/work/home/*'); do
    echo
    echo "--- SQLite $db"
    for t in $(sqlite3 -readonly "$db" "select name from sqlite_master where type='table' and name not like 'sqlite_%'"); do
        n=$(sqlite3 -readonly "$db" "select count(*) from \"$t\"")
        echo "table $t: $n row(s), newest 25 shown"
        sqlite3 -readonly -header -column "$db" "select * from \"$t\" order by rowid desc limit 25"
    done
done
for f in $(find /work -type f \( -name '*.tsv' -o -name '*.csv' -o -name '*.txt' -o -name 'page.html' \) ! -path '/work/home/*'); do
    echo
    echo "--- $f (first 40 lines)"
    head -n 40 "$f"
done

if [ -d /out ] && [ -w /out ]; then
    cd /work && find . -type f ! -path './home/*' -exec cp --parents {} /out/ \;
    echo
    echo "=== copied the files above to the folder you mounted as /out"
fi
exit "$rc"
