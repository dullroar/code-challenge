#!/usr/bin/env bash
# A deliberately hostile "entry". It tries what a malicious submission would try, and it
# PASSES only if the sandbox blocks every attempt. It lives under sandbox/selftest, not src/,
# and is never listed as a real entry. Run it with sandbox/selftest.sh, not by hand on a host.
set -u
escaped=0
probe() {
    local what=$1; shift
    if "$@" >/dev/null 2>&1; then echo "ESCAPED  $what"; escaped=$((escaped + 1))
    else echo "blocked  $what"; fi
}

echo "--- network"
probe "DNS lookup of github.com"             getent hosts github.com
probe "TCP connect to 1.1.1.1:443"           timeout 5 bash -c 'exec 3<>/dev/tcp/1.1.1.1/443'
probe "TCP connect to 8.8.8.8:53"            timeout 5 bash -c 'exec 3<>/dev/tcp/8.8.8.8/53'
probe "HTTPS request with curl"              timeout 10 curl -fsS -o /dev/null https://github.com
probe "any network interface besides lo"     bash -c 'ls /sys/class/net | grep -vxq lo'

echo "--- filesystem"
probe "write into the mounted entry"         touch /entry/pwned
probe "write to /"                           touch /pwned
probe "write to /usr/bin"                    touch /usr/bin/pwned
probe "append to /etc/passwd"                sh -c 'echo x >> /etc/passwd'
probe "Windows drives visible (/mnt/c)"      test -e /mnt/c
probe "Docker socket visible"                test -e /var/run/docker.sock
probe "any mount besides entry/tmpfs/system" bash -c 'awk "{print \$2}" /proc/mounts | grep -Evq "^(/|/entry|/work|/tmp|/proc.*|/sys.*|/dev.*|/etc/(hosts|hostname|resolv.conf))$"'

echo "--- privilege"
probe "running as root"                      test "$(id -u)" = 0
probe "sudo installed"                       bash -c 'command -v sudo'
probe "any effective capability"             bash -c '[[ $(awk "/^CapEff/{print \$2}" /proc/self/status) != 0000000000000000 ]]'
probe "no_new_privs is off"                  bash -c '! grep -Eq "^NoNewPrivs:[[:space:]]+1" /proc/self/status'

echo "--- secrets"
probe "CI or cloud credentials in env"       bash -c 'env | grep -Eiq "^(GITHUB_|ACTIONS_|RUNNER_|AWS_|AZURE_|GH_|[A-Z_]*TOKEN|[A-Z_]*SECRET)"'

echo "--- resources"
# 400 processes against a 256-process limit. Perl, because bash retries failed forks for ages.
probe "start 400 processes"                  perl -e '
    my @kids; for (1..400) { my $p = fork; last unless defined $p; if (!$p) { sleep 30; exit } push @kids, $p }
    kill 9, @kids; waitpid($_, 0) for @kids; exit(@kids >= 400 ? 0 : 1)'
probe "allocate 3 GiB of memory"             perl -e '$x = "a" x (3 * 1024**3); exit 0'

echo
if (( escaped == 0 )); then echo "hostile: every probe was blocked"; exit 0; fi
echo "hostile: $escaped probe(s) ESCAPED"; exit 1
