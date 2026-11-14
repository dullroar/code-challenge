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
#   ...            (the list lives in build-bases.sh)
#
# What is deliberately NOT here: a compiler, curl, git, pip, an editor, or a package manager
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
