# Container image for the Go entry. Run it with: sandbox/container/run-image.sh --online-build src/GoChallenge1
# (--online-build because the build downloads the SQLite module, checked against go.sum; the run itself has no network.)
# Build stage: a static binary. Runtime stage: that binary, sqlite3 for the inspect step and a tiny
# wget. The entry serves its page on loopback inside the container; the entrypoint fetches it
# from there, then "closes" it, so no port is ever published and nothing leaves the container.
FROM cc-build-go:local AS build
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 go build -trimpath -o /build/gochallenge .

FROM cc-rt-go:local
COPY --from=build /build/gochallenge /app/gochallenge
ENV CC_RUN=/app/gochallenge CC_SERVE=1
