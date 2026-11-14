# Container image for the Rust/GTK 4 entry. Run it with: sandbox/container/run-image.sh --online-build src/RustChallenge1
# (--online-build because the build downloads the locked crates; Cargo.lock pins and checksums them. The run has no network.)
# Build stage: Ubuntu's cargo and the GTK 4 headers compile the program. Runtime stage: that one
# binary on a base with the GTK 4 runtime library, a virtual display (Xvfb) and a screenshot tool,
# and no Rust, headers or compiler. The window opens on the virtual display inside the container; the
# entrypoint screenshots it after a few seconds, then closes it. Use --out DIR to get screenshot.png.
FROM cc-build-rust:local AS build
WORKDIR /build
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release --locked

FROM cc-rt-gtk:local
COPY --from=build /build/target/release/rust-challenge1 /app/rust-challenge1
ENV CC_RUN=/app/rust-challenge1 CC_XVFB=1 CC_SCREEN=640x400x24
