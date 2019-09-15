#!/usr/bin/env sh

config_in_vcs() {
    [ -n "$GIT_USER" ] && [ -n "$GIT_TOKEN" ] && [ -n "$GIT_TARGET" ]
}

config_target_prefix="/opt/imapfilter/config"
if config_in_vcs; then
    config_target="$config_target_prefix/$IMAPFILTER_CONFIG"
else
    config_target="$IMAPFILTER_CONFIG"
fi

pull_config() {
    if [ ! -d "$config_target_prefix" ]; then
        printf ">>> Config has not been cloned yet, cloning\n"
        mkdir -p "$config_target_prefix"
        git clone "https://$GIT_USER:$(cat $GIT_TOKEN)@$GIT_TARGET" "$config_target_prefix"
    else
        cd "$config_target_prefix"
        printf ">>> Pulling config\n"
        git pull
        cd -
    fi
}

config_in_vcs && pull_config

if [ ! -f "$config_target" ]; then
    printf "Config file '%s' does not exist\n" "$config_target"
    exit 1
fi

while true; do
    if config_in_vcs; then
        printf ">>> Updating config\n"
        if ! pull_config; then
            printf ">>> Pulling config failed\n"
        fi
    fi

    printf ">>> Running imapfilter\n"
    imapfilter -c "$config_target"

    printf ">>> Sleeping\n"
    sleep "${IMAPFILTER_SLEEP:-30}"
done
