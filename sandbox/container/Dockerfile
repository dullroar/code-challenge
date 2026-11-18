# Runtime bases for the per-entry images: just enough to RUN an entry and show what it did.
#
# Trusted side of the gate, like ../linux/Dockerfile: built by a maintainer from master, never
# from a pull request, and changed only by maintainers. This is the only place packages are
# installed (it needs network, once, at build time). An entry's own Dockerfile then builds with
# NO network (docker build --network none), so it can only FROM one of these bases and COPY
# files into it; see ../dockerfile-lint.sh for the rules.
#
# One parameterised target, built several times by build-bases.sh:
#   cc-rt-sqlite   sqlite3 only        (anything that ships its own interpreter or binary)
#   cc-rt-gforth   + gforth
#   cc-rt-gtk      + Xvfb, scrot, GTK 4 runtime (GUI entries on a virtual display)
#   cc-rt-pytk     + Python 3 with Tk, Xvfb, scrot (Python/Tk GUI entries)
#   cc-rt-java     + OpenJDK 25 JRE (with AWT), Xvfb, scrot (Java and Kotlin Swing entries)
#   cc-rt-sbcl, -m4, -tcl, -awk   Common Lisp, GNU m4, Tcl/Tk + tcl sqlite3 + Xvfb, GNU awk
#   cc-rt-ed, -nvi, -node         GNU ed, nvi (a POSIX ex/vi), Node.js 24 LTS (pinned upstream tarball)
#   ...            (the list lives in build-bases.sh)
#
# What is deliberately NOT here: a compiler, curl, git, pip, an editor (except the ed and nvi bases,
# which exist because the editor IS the entry), or a package manager
# (strip.sh removes apt and dpkg, and every setuid bit). What remains besides each entry's own
# runtime is the Ubuntu userland, because several entries shell out to `sh` and sqlite3.

ARG UBUNTU=ubuntu:24.04@sha256:2198e4c65076e9cb0b3d695219df667c0e3b0072da64ca3c2648aca17dcecaf5
FROM ${UBUNTU} AS runtime
ARG DEBIAN_FRONTEND=noninteractive
ARG PACKAGES=""
COPY strip.sh /tmp/strip.sh
# One layer for install and strip, so what strip.sh deletes is really gone from the image size.
RUN apt-get update \
 && apt-get install -y --no-install-recommends sqlite3 ${PACKAGES} \
 && rm -rf /var/lib/apt/lists/* \
 && sh /tmp/strip.sh && rm /tmp/strip.sh
COPY entrypoint.sh /usr/local/bin/cc-entrypoint
RUN chmod 0555 /usr/local/bin/cc-entrypoint
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
USER 65534:65534
WORKDIR /work
ENTRYPOINT ["/usr/local/bin/cc-entrypoint"]

# Build base for Go entries (an official image pinned by digest, as the Ubuntu base is). It holds a
# Go toolchain and nothing the final image keeps: entries copy their compiled binary out of it.
FROM golang:1.27-bookworm@sha256:4fa7c968ba93f1635670522dbb01a2c78150443e1385746924566079f36570ea AS build-go

# Build base for Rust entries: Ubuntu's own cargo/rustc (the entry's locked dependencies are tested
# with Ubuntu 24.04's Rust 1.75) and the GTK 4 and SQLite development files. Crates are downloaded
# at build time, so Rust entries need run-image.sh --online-build; Cargo.lock pins and checksums them.
FROM ${UBUNTU} AS build-rust
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates build-essential pkg-config cargo rustc libgtk-4-dev libsqlite3-dev \
 && rm -rf /var/lib/apt/lists/*

# Build base for Java and Kotlin entries: Ubuntu's OpenJDK 25 (the entries' build.gradle asks for Java 25),
# with Gradle itself coming from each entry's wrapper. The Gradle distribution and the Maven dependencies are
# downloaded at build time, so these entries need run-image.sh --online-build.
FROM ${UBUNTU} AS build-java
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates openjdk-25-jdk-headless \
 && rm -rf /var/lib/apt/lists/*

# Node.js, for the javascript and javascript-weird entries. Ubuntu 24.04 ships Node 18, which has no
# node:sqlite, so this is the upstream Node 24 LTS ("Krypton") tarball, pinned by SHA-256 (hashes copied from
# https://nodejs.org/dist/v24.22.3/SHASUMS256.txt on 2026-11-17, and the x64 one re-checked by hand). npm, corepack and
# the headers are deleted: an entry only needs the `node` binary. The result is cc-rt-node:local.
FROM ${UBUNTU} AS fetch-node
ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_VERSION=24.22.3
ARG NODE_SHA256_X64=4f2b175a6d53a5c617a80dba2676238a0688cef28c6da4eba35c7d844e66fcfb
ARG NODE_SHA256_ARM64=6e51a2ada00f0011cc266f65d98922b403d7ad88f809ca2aa615a5fe1ce6e86c
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl xz-utils \
 && rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
        amd64) arch=x64;   sha=$NODE_SHA256_X64 ;; \
        arm64) arch=arm64; sha=$NODE_SHA256_ARM64 ;; \
        *) echo "no Node build pinned for this CPU" >&2; exit 1 ;; \
    esac; \
    cd /tmp; \
    curl -fsSLo node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${arch}.tar.xz"; \
    echo "${sha}  node.tar.xz" | sha256sum -c -; \
    mkdir -p /opt/node && tar xJf node.tar.xz -C /opt/node --strip-components=1; \
    rm -rf /opt/node/lib /opt/node/include /opt/node/share /opt/node/CHANGELOG.md /opt/node/README.md; \
    /opt/node/bin/node --version

FROM runtime AS runtime-node
COPY --from=fetch-node /opt/node /opt/node
ENV PATH=/opt/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# nvi, for the ex-weird entry. nvi will not start unless it can write its crash-recovery files to /var/tmp/vi.recover,
# and the sandbox runs with a read-only root and a writable /tmp. So that directory is a link to /tmp. The result is
# cc-rt-nvi:local (build-bases.sh passes PACKAGES=nvi).
FROM runtime AS runtime-nvi
USER root
RUN rm -rf /var/tmp/vi.recover && ln -s /tmp /var/tmp/vi.recover
USER 65534:65534
