#!/bin/bash
# Runs INSIDE an entry's runtime image (see selftest.sh "container"), as the entry would run:
# every probe must be blocked. Prints "blocked: ..." or "OPEN: ..." per probe; exits 1 if any is open.
open=0
blocked() { echo "blocked: $1"; }
OPEN()    { echo "OPEN: $1"; open=1; }

for t in apt apt-get dpkg gcc cc g++ make curl wget git python3 pip pip3 ssh scp nc ncat telnet ftp sudo su; do
    if command -v "$t" >/dev/null 2>&1; then OPEN "tool present: $t"; fi
done
[[ $open == 0 ]] && blocked "no package manager, compiler, fetch tool, scripting extras or privilege tools on PATH"

for f in /app/x /etc/x /usr/bin/x /usr/local/bin/x /opt/x /root/x /x; do
    if ( : > "$f" ) 2>/dev/null; then OPEN "could write $f"; fi
done
blocked "app, system and root folders are not writable (only the /work and /tmp tmpfs are)"

if ( exec 3<>/dev/tcp/1.1.1.1/53 ) 2>/dev/null; then OPEN "outbound TCP connect worked"; else blocked "outbound network (1.1.1.1:53)"; fi
if ( exec 3<>/dev/tcp/127.0.0.1/9 ) 2>/dev/null; then :; fi   # loopback exists on purpose (the Go entry serves on it)

[[ $(id -u) == 65534 ]] && blocked "running as nobody (65534)" || OPEN "running as uid $(id -u)"
suid=$(find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | head -3)
[[ -z $suid ]] && blocked "no setuid/setgid binaries" || OPEN "setuid/setgid: $suid"
caps=$(grep ^CapEff /proc/self/status | awk '{print $2}')
[[ $caps == 0000000000000000 ]] && blocked "no capabilities" || OPEN "capabilities: $caps"
[[ -w /proc/sys ]] && OPEN "/proc/sys writable" || blocked "/proc/sys read-only"
[[ -e /var/run/docker.sock ]] && OPEN "docker socket visible" || blocked "no docker socket"
mounted=
for d in /mnt /host /out /media; do [[ -d $d && -n $(ls -A "$d" 2>/dev/null) ]] && mounted+=" $d"; done
[[ -z $mounted ]] && blocked "no host folders mounted" || OPEN "something is mounted under:$mounted"
exit $open
