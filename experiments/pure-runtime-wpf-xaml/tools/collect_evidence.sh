#!/usr/bin/env bash
# Runs each composition on the net10 host (twice) and the net11 host (once) in fresh isolated dirs,
# then copies traces, DB dumps, XML output and screenshots into evidence/. Re-runnable: wipes evidence/runs first.
set -u
cd "$(dirname "$0")/.."
H10="$PWD/artifacts/host/Host.exe"
H11="$PWD/artifacts/net11/host11/Host.exe"
STAMP=$(date -u +%Y%m%dT%H%M%S)
OUT=evidence/runs
rm -rf "$OUT" && mkdir -p "$OUT"
declare -A PROG=( [strict]=strict-built-in/program.xaml [pkg]=package-backed-pure/program.xaml [ef]=package-backed-ef/program.xaml )
run() { # tfm tag grade host
  local d="artifacts/final/$STAMP-$1-$2-$3"
  mkdir -p "$d/artifacts/pkg-run" "$d/artifacts/strict-run" "$d/artifacts/ef-run"
  cp "${PROG[$3]}" "$d/program.xaml"
  ( cd "$d" && HOST_PNG="$PWD/shot.png" timeout 120 "$4" program.xaml 700 > trace.txt 2>&1 )
  local o="$OUT/$1-$2-$3"; mkdir -p "$o"
  cp "$d/trace.txt" "$o/trace.txt"; cp "$d/shot.png" "$o/screenshot.png" 2>/dev/null
  sha256sum "$d/program.xaml" | cut -d' ' -f1 > "$o/program.sha256"
  case $3 in
    strict) cp "$d/artifacts/strict-run/demo-timecards.xml" "$o/" 2>/dev/null; sha256sum "$o/demo-timecards.xml" | cut -d' ' -f1 > "$o/output.sha256" ;;
    pkg) sqlite3 "$d/artifacts/pkg-run/demo-timecards.db" ".headers on" ".schema DemoTimeCards" "select * from DemoTimeCards" > "$o/db-dump.txt" ;;
    ef)  sqlite3 "$d/artifacts/ef-run/demo-timecards.db" ".headers on" ".schema TimeCards" "select * from TimeCards" > "$o/db-dump.txt" ;;
  esac
}
for g in strict pkg ef; do
  run net10 a $g "$H10"; run net10 b $g "$H10"; run net11 a $g "$H11"
done
echo "collected into $OUT"
