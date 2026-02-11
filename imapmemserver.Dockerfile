FROM --platform=$BUILDPLATFORM golang:1.26@sha256:75ca321c953ce0572c709fa186cff872a510a22d6dad515291c6eb29edb9c849 AS builder

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

FROM gcr.io/distroless/static:nonroot@sha256:f9f84bd968430d7d35e8e6d55c40efb0b980829ec42920a49e60e65eac0d83fc
WORKDIR /
COPY --from=builder /workspace/imapmemserver .
USER 65532:65532

ENTRYPOINT ["/imapmemserver"]
