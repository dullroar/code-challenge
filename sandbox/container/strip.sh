#!/bin/sh
# Takes the package manager and every setuid/setgid bit out of the image being built, so what
# is left can run the entry and show its results but cannot install, upgrade or escalate.
# Runs once, as root, at the end of the runtime base (see Dockerfile).
set -eu
rm -f /usr/bin/apt /usr/bin/apt-* /usr/bin/add-apt-repository /usr/bin/dpkg /usr/bin/dpkg-* \
      /usr/sbin/dpkg-* /usr/bin/update-alternatives /usr/sbin/update-alternatives /usr/bin/su 2>/dev/null || true
rm -rf /var/lib/apt /var/cache/apt /var/log/apt /var/log/dpkg.log /var/log/alternatives.log /usr/share/doc /usr/share/man /usr/share/info
# Weight that only matters for printing, PDF, GL and icon themes: nothing an entry here uses.
# (GTK entries are rendered with the cairo renderer on a virtual display, see entrypoint.sh.)
rm -rf /usr/lib/x86_64-linux-gnu/libLLVM* /usr/lib/x86_64-linux-gnu/libgs.so* /usr/lib/x86_64-linux-gnu/dri \n       /usr/lib/x86_64-linux-gnu/libgallium* /usr/share/poppler /usr/share/icons /usr/share/fonts/type1 /usr/share/ghostscript
find / -xdev -type f \( -perm -4000 -o -perm -2000 \) -exec chmod a-s {} + 2>/dev/null || true
