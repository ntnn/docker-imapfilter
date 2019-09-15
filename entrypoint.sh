#!/usr/bin/env sh

if [ ! -f "$IMAPFILTER_CONFIG" ]; then
    printf "Config file '%s' does not exit" "$IMAPFILTER_CONFIG"
    exit 1
fi

while true; do
    imapfilter -c "$IMAPFILTER_CONFIG"
    sleep "${IMAPFILTER_SLEEP:-30}"
done
