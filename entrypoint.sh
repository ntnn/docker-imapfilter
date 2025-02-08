#!/usr/bin/env sh

vcs_token() {
    if [ -n "$GIT_TOKEN_RAW" ]; then
        echo "$GIT_TOKEN_RAW"
        return
    fi

    cat "${GIT_TOKEN}"
}

vcs_uri() {
    s="https://"
    if [ -n "$GIT_USER" ]; then
        # https://user:
        s="${s}${GIT_USER}:"
    fi

    # https://user:token@"
    token="$(vcs_token)"
    if [ -n "$token" ]; then
        s="${s}${token}@"
    fi

    # https://user:token@target
    echo "${s}${GIT_TARGET}"
}

config_in_vcs() {
    [ -n "$(vcs_token)" ] && [ -n "$GIT_TARGET" ]
}

config_target_prefix="/opt/imapfilter/config"
if config_in_vcs; then
    config_target="$config_target_prefix/$IMAPFILTER_CONFIG"
else
    config_target="$IMAPFILTER_CONFIG"
fi

pull_config() {
    config_in_vcs || return

    printf ">>> Updating config\n"
    if [ ! -d "$config_target_prefix" ]; then
        printf ">>> Config has not been cloned yet, cloning\n"
        mkdir -p "$config_target_prefix"
        git clone "$(vcs_uri)" "$config_target_prefix"
        return
    else
        cd "$config_target_prefix"
        printf ">>> Pulling config\n"
        git remote update
        if [ "$(git rev-parse HEAD)" != "$(git rev-parse FETCH_HEAD)" ]; then
            git pull
            return
        fi
        cd -
    fi
    return 1
}

start_imapfilter() {
    # enter a subshell to not affect the pwd of the running process
    (
        # Enter the basedir of the config. Required to allow relative
        # includes in the lua scripts.
        if config_in_vcs; then
            cd "$config_target_prefix"
        elif [ -n "$IMAPFILTER_CONFIG_BASE" ]; then
            cd "$IMAPFILTER_CONFIG_BASE"
        else
            cd "${config_target%/*}"
        fi

        log_parameter=
        if [ -n "$IMAPFILTER_LOGFILE" ]; then
                log_parameter="-l $IMAPFILTER_LOGFILE"
        fi
        imapfilter -c "$config_target" $log_parameter
    )
}

imapfilter_pid=
imapfilter_restart_daemon() {
    if [ -n "$imapfilter_pid" ]; then
        kill -TERM "$imapfilter_pid"
        wait "$imapfilter_pid"
    fi
    start_imapfilter &
    imapfilter_pid="$(jobs -p)"
}

loop_no_daemon() {
    while true; do
        pull_config

        printf ">>> Running imapfilter\n"
        if ! start_imapfilter; then
            printf ">>> imapfilter failed\n"
            exit 1
        fi

        printf ">>> Sleeping\n"
        sleep "${IMAPFILTER_SLEEP:-30}"
    done
}

loop_daemon() {
    imapfilter_restart_daemon
    while true; do
        if pull_config; then
            printf ">>> Update in VCS, restarting imapfilter daemon\n"
            imapfilter_restart_daemon
        fi

        printf ">>> Sleeping\n"
        sleep "${IMAPFILTER_SLEEP:-30}"

        if ! kill -0 "$imapfilter_pid" 2>/dev/null; then
            printf ">>> imapfilter daemon died, exiting\n"
            exit 1
        fi
    done
}

pull_config
if [ ! -f "$config_target" ]; then
    printf "Config file '%s' does not exist\n" "$config_target"
    exit 1
fi

if [ "$IMAPFILTER_DAEMON" = "yes" ]; then
    loop_daemon
else
    loop_no_daemon
fi
