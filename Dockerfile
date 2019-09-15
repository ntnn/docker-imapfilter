FROM alpine

# Original from simbelmas:
# https://github.com/simbelmas/dockerfiles/tree/master/imapfilter

RUN apk --no-cache add \
    lua openssl pcre \
    git -t dev_tools lua-dev openssl-dev make gcc libc-dev pcre-dev

RUN git clone https://github.com/lefcha/imapfilter.git /imapfilter_build \
    && cd /imapfilter_build && make && make install \
    && cd && rm -rf /imapfilter_build

COPY entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh

ENTRYPOINT /entrypoint.sh
