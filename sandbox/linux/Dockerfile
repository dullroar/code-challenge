# The Linux sandbox image: every toolchain the Linux entries need, and nothing else.
#
# This file is part of the trusted side of the gate. It is built from master, never from a
# pull request, and a PR that touches it is rejected by sandbox/scope-check.sh. A new entry
# that needs a new interpreter gets it here, in a separate commit by a maintainer, from a
# known distribution and pinned (apt package, or an upstream tarball checked by SHA-256).
#
# Everything an entry needs must be in the image: entries run with no network at all.

FROM ubuntu:24.04@sha256:2198e4c65076e9cb0b3d695219df667c0e3b0072da64ca3c2648aca17dcecaf5

ARG DEBIAN_FRONTEND=noninteractive

# Distribution toolchains.
#   sqlite3            every entry's scratch database
#   perl               regex-perl
#   libpcre2-dev       regex-pcre2 (the C host links the system PCRE2)
#   make, cmake        make-gnu, cmake (Ubuntu 24.04's cmake is 3.28; the entry needs 3.19+)
#   gforth             forth, forth-weird
#   ghc                haskell, haskell-weird (runghc, with GHC's own boot packages only)
#   dotnet-sdk-10.0    regex-dotnet (plain net10.0, no NuGet packages)
#   gnucobol           cobol, cobol-weird (cobc 3.1.2; it compiles through C with build-essential)
#   sbcl               lisp, lisp-weird (Steel Bank Common Lisp, run as a script)
#   m4                 m4 (GNU m4; the macro processor does the whole computation)
#   tcl, tk, libsqlite3-tcl   tcl, tcl-weird (tclsh with its sqlite3 package; Tk for --gui)
#   xvfb, xauth        a virtual display, so check.sh can run Tk windows headless (xvfb-run)
#   gawk, original-awk, busybox-static   awk, awk-weird (gawk; the portable entry is also checked under
#                      the one-true-awk and busybox awk, next to Ubuntu's default mawk)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates curl bzip2 build-essential pkg-config \
        sqlite3 perl libpcre2-dev make cmake gforth ghc dotnet-sdk-10.0 gnucobol \
        sbcl m4 tcl tk libsqlite3-tcl xvfb xauth gawk original-awk busybox-static \
 && rm -rf /var/lib/apt/lists/*

# Upstream builds, each pinned by SHA-256. Hashes recorded 2026-11-14 from the URLs below.

# pcre2grep with callout scripts (Ubuntu's is built without them), for regex-pcre2grep.
# Installed under /opt/pcre2 so it never shadows the system libpcre2 that regex-pcre2 links.
ARG PCRE2_VERSION=10.49
ARG PCRE2_SHA256=53c156e1ba416a20da8e65395daa132da0d80e76910424caca3fcdae7831d384
RUN set -eux; cd /tmp; \
    curl -fsSLo pcre2.tar.bz2 "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.bz2"; \
    echo "${PCRE2_SHA256}  pcre2.tar.bz2" | sha256sum -c -; \
    tar xjf pcre2.tar.bz2; cd "pcre2-${PCRE2_VERSION}"; \
    ./configure --prefix=/opt/pcre2 --disable-shared \
        --enable-pcre2grep-callout --enable-pcre2grep-callout-fork; \
    make -j"$(nproc)"; make install; \
    /opt/pcre2/bin/pcre2grep --help | grep -q 'All callout scripts in patterns are supported'; \
    cd /tmp; rm -rf pcre2*

# GNU APL, for apl and apl-weird. Not packaged by Ubuntu, so built from gnu.org.
ARG APL_VERSION=2.0
ARG APL_SHA256=24bbb744fce47e62837234a053bdeecee51b9ea61c82c79f7cc191bc6a54c0a1
RUN set -eux; cd /tmp; \
    curl -fsSLo apl.tar.gz "https://ftp.gnu.org/gnu/apl/apl-${APL_VERSION}.tar.gz"; \
    echo "${APL_SHA256}  apl.tar.gz" | sha256sum -c -; \
    mkdir apl && tar xzf apl.tar.gz -C apl --strip-components=1; cd apl; \
    ./configure --prefix=/opt/apl; \
    make -j"$(nproc)"; make install; \
    cd /tmp; rm -rf apl apl.tar.gz

# Editors and Node.js, for tar-gnu, tar-gnu-weird, ed-weird, ex-weird, javascript and javascript-weird. These are
# a separate layer on purpose, so adding them did not rebuild the layers above.
#   tar                already in the Ubuntu base: GNU tar 1.35 (the tar entries need GNU-only options)
#   ed                 GNU ed (ed-weird); the "other" ed is checked with busybox ed, from busybox-static above
#   nvi                a 4.4BSD-lineage POSIX ex/vi (ex-weird); Ubuntu's ex/vi alternatives point at Vim, not at this
#   node 24 LTS        upstream tarball pinned by SHA-256 (Ubuntu 24.04's Node 18 has no node:sqlite)
RUN apt-get update \
 && apt-get install -y --no-install-recommends ed nvi xz-utils \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /var/tmp/vi.recover && ln -s /tmp /var/tmp/vi.recover
# ^ nvi refuses to start unless it can write its crash-recovery files to /var/tmp/vi.recover. The sandbox runs with a
#   read-only root and a writable /tmp, so the directory is a link to /tmp (the same in cc-rt-nvi, see container/Dockerfile).
ARG NODE_VERSION=24.22.3
ARG NODE_SHA256_X64=4f2b175a6d53a5c617a80dba2676238a0688cef28c6da4eba35c7d844e66fcfb
ARG NODE_SHA256_ARM64=6e51a2ada00f0011cc266f65d98922b403d7ad88f809ca2aa615a5fe1ce6e86c
RUN set -eux; cd /tmp; \
    case "$(dpkg --print-architecture)" in \
        amd64) arch=x64;   sha=$NODE_SHA256_X64 ;; \
        arm64) arch=arm64; sha=$NODE_SHA256_ARM64 ;; \
        *) echo "no Node build pinned for this CPU" >&2; exit 1 ;; \
    esac; \
    curl -fsSLo node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${arch}.tar.xz"; \
    echo "${sha}  node.tar.xz" | sha256sum -c -; \
    mkdir -p /opt/node && tar xJf node.tar.xz -C /opt/node --strip-components=1; \
    rm -rf /tmp/node.tar.xz /opt/node/include /opt/node/share; \
    /opt/node/bin/node --version

# UTF-8 locale: the APL checks grep for glyphs like ⍣ and →, which a C locale reads as bytes.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/opt/node/bin:/opt/apl/bin:/opt/pcre2/bin:$PATH \
    PCRE2GREP=/opt/pcre2/bin/pcre2grep \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

# Entries run as nobody (run.sh also passes --user), with HOME on a tmpfs that run.sh mounts.
USER 65534:65534
WORKDIR /work
