#!/usr/bin/env sh

vcs_token() {
    if [ -n "$GIT_TOKEN_RAW" ]; then
        echo "$GIT_TOKEN_RAW"
        return
    fi

    if [ -n "$GIT_TOKEN" ]; then
        cat "${GIT_TOKEN}"
    fi

    return 1
}

vcs_target_protocol() {
    # https://a.b.c/
    # -> https
    echo "${GIT_TARGET%%://*}"
}

vcs_target_base() {
    # https://a.b.c/
    # -> a.b.c/
    echo "${GIT_TARGET##*://}"
}

vcs_uri() {
    s="$(vcs_target_protocol)://"
    if [ -n "$GIT_USER" ]; then
        # https://user
        s="${s}${GIT_USER}"
    fi

    token="$(vcs_token)"

    # no user -         https://
    # no user - token   https://user:
    # user - no token   https://user
    if [ -n "$GIT_USER" ] && [ -n "$token" ]; then
        s="${s}:"
    fi

    # no user - token   https://user:token
    # user - no token   https://user
    if [ -n "$token" ]; then
        s="${s}${token}"
    fi

    # no user - no token https://
    # no user - token    https://user:token@
    # user - no token    https://user@
    if [ -n "$GIT_USER" ] || [ -n "$token" ]; then
        s="${s}@"
    fi

    # no user - no token https://target
    # no user - token    https://user:token@target
    # user - no token    https://user@target
    echo "${s}$(vcs_target_base)"
}

config_in_vcs() {
    [ -n "$(vcs_token)" ] && [ -n "$GIT_TARGET" ]
}

config_target_base="${IMAPFILTER_CONFIG_BASE:-/opt/imapfilter/config}"
config_target="${IMAPFILTER_CONFIG}"

# If config_target is an absolute path strip the base.
# Originally IMAPFILTER_CONFIG was allowed to be absolute and relative,
# this handles the former absolute path (as long as
# IMAPFILTER_CONFIG_BASE is correctly used).
case "$config_target" in
    (/*) config_target="${config_target#${config_target_base}/}";;
esac

pull_config() {
    config_in_vcs || return

    printf ">>> Updating config\n"
    if [ ! -d "$config_target_base/.git" ]; then
        printf ">>> Config has not been cloned yet, cloning\n"
        mkdir -p "$config_target_base"
        git clone "$(vcs_uri)" "$config_target_base"
        return
    else
        cd "$config_target_base"
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
        if ! [ -d "$config_target_base" ]; then
            echo "The directory '$config_target_base' does not exist, exiting"
            echo "Please validate IMAPFILTER_CONFIG_BASE"
            exit 1
        fi

        # Enter the basedir of the config. Required to allow relative
        # includes in the lua scripts.
        cd "$config_target_base"

        log_parameter=
        if [ -n "$IMAPFILTER_LOGFILE" ]; then
                log_parameter="-l $IMAPFILTER_LOGFILE"
        fi

        if ! [ -f "$config_target" ]; then
            echo "The file '$config_target' does not exist relative to '$config_target_base', exiting"
            echo "Please validate IMAPFILTER_CONFIG"
            exit 1
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
if [ "$IMAPFILTER_DAEMON" = "yes" ]; then
    loop_daemon
else
    loop_no_daemon
fi
