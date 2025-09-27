FROM alpine@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1 AS builder

# imapfilter_spec can be a specific commit or a version tag
ARG imapfilter_spec=master

# Original from simbelmas:
# https://github.com/simbelmas/dockerfiles/tree/master/imapfilter

WORKDIR /imapfilter_build

RUN apk --no-cache add lua openssl pcre git \
    && apk --no-cache add -t dev_tools lua-dev openssl-dev make gcc libc-dev pcre-dev pcre2-dev \
    && git clone https://github.com/lefcha/imapfilter.git . \
    && git checkout "${imapfilter_spec}" \
    && make && make install

FROM alpine@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1

# Install runtime dependencies for imapfilter and the required tools for user management (shadow for 'su').
RUN apk --no-cache add lua lua-dev openssl pcre git shadow \
    && mkdir -p /opt/imapfilter/config \
    && mkdir -p /home/imapfilter/.imapfilter && touch /home/imapfilter/.imapfilter/config.lua 

COPY --from=builder /usr/local/bin/imapfilter /usr/local/bin/imapfilter
COPY --from=builder /usr/local/share/imapfilter /usr/local/share/imapfilter
COPY --from=builder /usr/local/man /usr/local/man

# Copy the application logic script
COPY --chmod=a+x run-imapfilter.sh /run-imapfilter.sh
# Copy the entrypoint script
COPY --chmod=a+x docker-entrypoint.sh /docker-entrypoint.sh

# The primary ENTRYPOINT is the user setup script.
ENTRYPOINT ["/docker-entrypoint.sh"]
