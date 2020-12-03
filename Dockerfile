FROM alpine

# imapfilter_spec can be a specific commit or a version tag
ARG imapfilter_spec=master

# Original from simbelmas:
# https://github.com/simbelmas/dockerfiles/tree/master/imapfilter

RUN apk --no-cache add lua openssl pcre git \
    && apk --no-cache add -t dev_tools lua-dev openssl-dev make gcc libc-dev pcre-dev pcre2-dev \
    && git clone https://github.com/lefcha/imapfilter.git /imapfilter_build \
    && cd /imapfilter_build \
    && git checkout "${imapfilter_spec}" \
    && make && make install \
    && cd && rm -rf /imapfilter_build \
    && apk --no-cache del dev_tools

COPY entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh

ENTRYPOINT /entrypoint.sh
