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
# imapfilter user and group IDs for use at build time for non root user
ARG imapfilter_UID=1001
ARG imapfilter_GID=1001
# Set IMAPFILTER_HOME to so a location that is not defined by the UID running the process
# This allows for --user flag to be run in docker run.
ENV IMAPFILTER_HOME=/opt/imapfilter

# Copy built files first
COPY --from=builder /usr/local/bin/imapfilter /usr/local/bin/imapfilter
COPY --from=builder /usr/local/share/imapfilter /usr/local/share/imapfilter
COPY --from=builder /usr/local/man /usr/local/man

# Setup user, group, home, config, and permissions in one step
# Set permissions to allow --user flag in docker, this required making the
# imapfilter folders to world readable
# the only really annoying part was the /opt/imapfilter to be world writable
# but since anything running as the user reading it and anything run through
# docker exec all run as the user specified below, it should be fine.
RUN apk --no-cache add lua lua-dev openssl pcre git \
    && addgroup -g ${imapfilter_GID} imapfilter \
    && adduser -u ${imapfilter_UID} -G imapfilter -D imapfilter \
    && mkdir -p /opt/imapfilter \
    && touch /opt/imapfilter/config.lua \
    && chown -R imapfilter:imapfilter /opt/imapfilter \
    && chmod 777 /opt/imapfilter \
    && chmod 666 /opt/imapfilter/config.lua \
    && chmod 755 /usr/local/bin/imapfilter \
    && chmod -R 755 /usr/local/share/imapfilter

COPY --chmod=a+x entrypoint.sh /entrypoint.sh

# Now drop root and set user for entrypoint.
USER imapfilter
ENTRYPOINT ["/entrypoint.sh"]