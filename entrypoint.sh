#!/usr/bin/env sh

config_in_vcs() {
    [ -n "$GIT_TOKEN" ] && [ -n "$GIT_TARGET" ]
}

config_target_prefix="/opt/imapfilter/config"
if config_in_vcs; then
    config_target="$config_target_prefix/$IMAPFILTER_CONFIG"
else
    config_target="$IMAPFILTER_CONFIG"
fi

log_parameter=
if [ -n "$IMAPFILTER_LOGFILE" ]; then
	log_parameter="-l $IMAPFILTER_LOGFILE"
fi

updated_config=no
pull_config() {
    updated_config=no
    if [ ! -d "$config_target_prefix" ]; then
        printf ">>> Config has not been cloned yet, cloning\n"
        mkdir -p "$config_target_prefix"
        updated_config=yes
        git clone "https://$GIT_USER:$(cat $GIT_TOKEN)@$GIT_TARGET" "$config_target_prefix"
    else
        cd "$config_target_prefix"
        printf ">>> Pulling config\n"
        git remote update
        if [ "$(git rev-parse HEAD)" != "$(git rev-parse FETCH_HEAD)" ]; then
            updated_config=yes
            git pull
        fi
        cd -
    fi
}

if config_in_vcs; then
    pull_config
    cd "$config_target_prefix"
elif [ -n "$IMAPFILTER_CONFIG_BASE" ]; then
    cd "$IMAPFILTER_CONFIG_BASE"
else
    cd "${config_target%/*}"
fi

if [ ! -f "$config_target" ]; then
    printf "Config file '%s' does not exist\n" "$config_target"
    exit 1
fi

imapfilter_pid=
imapfilter_update() {
    if [ -n "$imapfilter_pid" ]; then
        kill -TERM "$imapfilter_pid"
        wait "$imapfilter_pid"
    fi
    imapfilter -c "$config_target" $log_parameter &
    imapfilter_pid="$(jobs -p)"
}

if [ "$IMAPFILTER_DAEMON" = "yes" ]; then
    imapfilter_update
fi

while true; do
    if config_in_vcs; then
        printf ">>> Updating config\n"
        if ! pull_config; then
            printf ">>> Pulling config failed\n"
        fi
    fi

    if [ "$IMAPFILTER_DAEMON" = "yes" ]; then
        if [ "$updated_config" = "yes" ]; then
            printf ">>> Restarting imapfilter daemon\n"
            imapfilter_update
        fi
    else
        printf ">>> Running imapfilter\n"
        imapfilter -c "$config_target" $log_parameter
    fi

    printf ">>> Sleeping\n"
    sleep "${IMAPFILTER_SLEEP:-30}"
done
