FROM --platform=$BUILDPLATFORM golang:1.26@sha256:fcdb3e42c5544e9682a635771eac76a698b66de79b1b50ec5b9ce5c5f14ad775 AS builder

WORKDIR /workspace

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download && go mod verify

RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 \
    GOCACHE=/root/.cache/go-build \
    GOOS=$TARGETOS \
    GOARCH=$TARGETARCH \
    go build -o imapmemserver github.com/emersion/go-imap/v2/cmd/imapmemserver

FROM gcr.io/distroless/static:nonroot@sha256:e3f945647ffb95b5839c07038d64f9811adf17308b9121d8a2b87b6a22a80a39
WORKDIR /
COPY --from=builder /workspace/imapmemserver .
USER 65532:65532

ENTRYPOINT ["/imapmemserver"]
