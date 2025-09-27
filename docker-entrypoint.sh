#!/usr/bin/env sh
set -e

# --- 1. Set PUID/PGID with defaults ---
# Default to 1001 if PUID or PGID environment variables aren't set.
PUID=${PUID:-1001}
PGID=${PGID:-1001}
# Username for imapfilter user.
USER_NAME="imapfilter"

printf ">>> Setting up user with PUID/PGID: %s/%s\n" "$PUID" "$PGID"

# --- 2. Create/Recreate Group based on PGID ---
# check if group exists.
if getent group "$USER_NAME" >/dev/null; then
    # Get the current GID of the 'imapfilter' group
    CURRENT_GID=$(getent group "$USER_NAME" | cut -d: -f3)

    if [ "$CURRENT_GID" != "$PGID" ]; then
        # Group exists but with the wrong GID, so we delete and re-create it
        printf "Group '%s' exists (GID %s) but doesn't match target PGID %s. Re-creating.\n" "$USER_NAME" "$CURRENT_GID" "$PGID"
        delgroup "$USER_NAME"
        addgroup -g "$PGID" "$USER_NAME"
    else
        printf "Group '%s' already has the target GID %s, skipping creation.\n" "$USER_NAME" "$PGID"
    fi
else
    # Group doesn't exist, so create it
    printf "Creating group '%s' with GID %s.\n" "$USER_NAME" "$PGID"
    addgroup -g "$PGID" "$USER_NAME"
fi

# --- 3. Create/Recreate User based on PUID and the (now-corrected) Group ---
# Check if the user exists
if getent passwd "$USER_NAME" >/dev/null; then
    # User exists, now check its ID and its primary GID
    CURRENT_UID=$(getent passwd "$USER_NAME" | cut -d: -f3)
    CURRENT_USER_GID=$(getent passwd "$USER_NAME" | cut -d: -f4) # New: Get the user's primary GID

    if [ "$CURRENT_UID" != "$PUID" ] || [ "$CURRENT_USER_GID" != "$PGID" ]; then
        # User exists but either the UID or the primary GID is wrong, so we delete and re-create it
        printf "User '%s' needs update (UID/GID: %s/%s vs target %s/%s). Re-creating.\n" "$USER_NAME" "$CURRENT_UID" "$CURRENT_USER_GID" "$PUID" "$PGID"
        deluser "$USER_NAME"
        adduser -D -u "$PUID" -G "$USER_NAME" "$USER_NAME" # Re-create with the guaranteed-correct group name
    else
        printf "User '%s' already has the target UID %s and GID %s, skipping creation.\n" "$USER_NAME" "$PUID" "$PGID"
    fi
else
    # User doesn't exist, so create it
    printf "Creating user '%s' with UID %s and GID %s.\n" "$USER_NAME" "$PUID" "$PGID"
    adduser -D -u "$PUID" -G "$USER_NAME" "$USER_NAME"
fi

# --- 4. Fix Permissions ---
# Change ownership of key directories to the new user/group
printf "Changing ownership of /opt/imapfilter/config and /home/%s\n" "$USER_NAME"
# Use the numeric IDs to ensure correctness even if a name conflict occurred
chown -R "$PUID":"$PGID" /opt/imapfilter/config /home/"$USER_NAME"

# --- 5. Execute Original Application Runner ---
# Switch to the new non-root user and execute the application runner script.
printf "Switching user to '%s' and executing /run-imapfilter.sh\n" "$USER_NAME"
exec su "$USER_NAME" -c /run-imapfilter.sh "$@"