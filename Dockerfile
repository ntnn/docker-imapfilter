FROM alpine@sha256:5b02b42e375f7426f8d65c3af331ca05d9878f9989230354504e0b9dfd431f60 AS builder

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

FROM alpine@sha256:5b02b42e375f7426f8d65c3af331ca05d9878f9989230354504e0b9dfd431f60

# create an empty config.lua to prevent an error when running imapfilter directly
RUN adduser -D -u 1001 imapfilter \
    && mkdir -p /home/imapfilter/.imapfilter && touch /home/imapfilter/.imapfilter/config.lua \
    && mkdir -p /opt/imapfilter/config \
    && chown -R imapfilter: /opt/imapfilter

COPY --from=builder /usr/local/bin/imapfilter /usr/local/bin/imapfilter
COPY --from=builder /usr/local/share/imapfilter /usr/local/share/imapfilter
COPY --from=builder /usr/local/man /usr/local/man

RUN apk --no-cache add lua lua-dev openssl pcre git

COPY --chown=imapfilter: --chmod=a+x entrypoint.sh /entrypoint.sh

USER imapfilter
ENTRYPOINT ["/entrypoint.sh"]
