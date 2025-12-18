FROM alpine@sha256:865b95f46d98cf867a156fe4a135ad3fe50d2056aa3f25ed31662dff6da4eb62 AS builder

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

FROM alpine@sha256:865b95f46d98cf867a156fe4a135ad3fe50d2056aa3f25ed31662dff6da4eb62

# create an empty config.lua to prevent an error when running imapfilter directly
RUN adduser -D -u 1001 imapfilter \
    && mkdir -p /home/imapfilter/.imapfilter && touch /home/imapfilter/.imapfilter/config.lua \
    && mkdir -p /opt/imapfilter/config \
    && chown imapfilter: /opt/imapfilter

COPY --from=builder /usr/local/bin/imapfilter /usr/local/bin/imapfilter
COPY --from=builder /usr/local/share/imapfilter /usr/local/share/imapfilter
COPY --from=builder /usr/local/man /usr/local/man

RUN apk --no-cache add lua lua-dev openssl pcre git

COPY --chown=imapfilter: --chmod=a+x entrypoint.sh /entrypoint.sh

USER imapfilter
ENTRYPOINT ["/entrypoint.sh"]
