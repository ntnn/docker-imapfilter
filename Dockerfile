FROM alpine as builder

# imapfilter_spec can be a specific commit or a version tag
ARG imapfilter_spec=master

# Original from simbelmas:
# https://github.com/simbelmas/dockerfiles/tree/master/imapfilter

RUN apk --no-cache add lua openssl pcre git \
    && apk --no-cache add -t dev_tools lua-dev openssl-dev make gcc libc-dev pcre-dev pcre2-dev \
    && git clone https://github.com/lefcha/imapfilter.git /imapfilter_build \
    && cd /imapfilter_build \
    && git checkout "${imapfilter_spec}" \
    && make && make install

FROM alpine

COPY --from=builder /usr/local/bin/imapfilter /usr/local/bin/imapfilter
COPY --from=builder /usr/local/share/imapfilter /usr/local/share/imapfilter
COPY --from=builder /usr/local/man /usr/local/man

COPY entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh && apk --no-cache add lua lua-dev openssl pcre git \
    && adduser -D -u 1001 imapfilter \
    && mkdir /opt/imapfilter \
    && chown imapfilter: /opt/imapfilter

USER imapfilter

ENTRYPOINT /entrypoint.sh
