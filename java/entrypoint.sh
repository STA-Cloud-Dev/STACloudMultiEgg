#!/bin/bash

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Best-effort internal IP detection. Some minimal images do not ship `ip`.
if command -v ip >/dev/null 2>&1; then
    INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}')
elif command -v hostname >/dev/null 2>&1; then
    INTERNAL_IP=$(hostname -I 2>/dev/null | awk '{print $1; exit}')
fi

INTERNAL_IP=${INTERNAL_IP:-127.0.0.1}
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

# Print Java version
printf "\033[1m\033[33mstacloud@deverlopment~ \033[0mjava -version\n"
java -version

# Convert "{{VARIABLE}}" into "${VARIABLE}". Bash will expand the variables when
# executing the command, so this still works even if `envsubst` is not installed.
PARSED=$(printf '%s' "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')

# Display the command we're running in the output, and then execute it with the env
# from the container itself.
printf "\033[1m\033[33mstacloud@deverlopment~ \033[0m%s\n" "$PARSED"
# shellcheck disable=SC2086
exec /bin/bash -c "${PARSED}"
