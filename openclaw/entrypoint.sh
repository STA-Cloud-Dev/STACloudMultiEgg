#!/bin/bash
set -e

cd /home/container || exit 1

mkdir -p \
  /home/container/.openclaw \
  /home/container/.openclaw/workspace \
  /home/container/.openclaw/skills

printf "\033[1m\033[33mstacloud@ai~ \033[0mopenclaw --version\n"
openclaw --version

DEFAULT_STARTUP='openclaw gateway --port ${OPENCLAW_PORT:-18789}'
RAW_STARTUP="${STARTUP:-$DEFAULT_STARTUP}"
PARSED=$(printf '%s' "$RAW_STARTUP" | sed -E 's/\{\{([A-Za-z_][A-Za-z0-9_]*)\}\}/${\1}/g')

printf "\033[1m\033[33mstacloud@ai~ \033[0m%s\n" "$PARSED"
exec /bin/bash -c "$PARSED"
