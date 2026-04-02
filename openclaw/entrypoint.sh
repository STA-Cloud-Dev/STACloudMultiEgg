#!/bin/bash
set -e

cd /home/container || exit 1

mkdir -p \
  /home/container/.openclaw \
  /home/container/.openclaw/workspace \
  /home/container/.openclaw/skills

printf "\033[1m\033[33mstacloud@ai~ \033[0mopenclaw --version\n"
openclaw --version

# --- Generate openclaw.json config ---
IFS=',' read -ra _ORIGINS_ARR <<< "${OPENCLAW_ALLOWED_ORIGINS:-}"
_ORIGINS_JSON="[]"
_FILTERED_ORIGINS="[]"
_IDX=0
for _O in "${_ORIGINS_ARR[@]}"; do
  _O="$(printf '%s' "$_O" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -n "$_O" ]; then
    if [ $_IDX -eq 0 ]; then
      _FILTERED_ORIGINS="[\"$_O\"]"
    else
      _FILTERED_ORIGINS="$(printf '%s' "$_FILTERED_ORIGINS" | sed 's/]$//')","\"$_O\"]"
    fi
    _IDX=$((_IDX + 1))
  fi
done

_CONFIG_GATEWAY="{}"

# auth block
if [ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
  _CONFIG_GATEWAY=$(jq -n \
    --arg mode "token" \
    --arg token "${OPENCLAW_GATEWAY_TOKEN}" \
    '{auth:{mode:$mode,token:$token}}')
fi

# controlUi block
if [ $_IDX -gt 0 ]; then
  _ORIGINS_ARG="${OPENCLAW_ALLOWED_ORIGINS}"
  _CUI=$(jq -n --arg origins "$_ORIGINS_ARG" \
    '{controlUi:{allowedOrigins:($origins | split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length>0)))}}')
else
  _FALLBACK="${OPENCLAW_ALLOW_HOST_HEADER_ORIGIN_FALLBACK:-false}"
  _CUI=$(jq -n --argjson fb "$([ "$_FALLBACK" = "true" ] && echo true || echo false)" \
    '{controlUi:{dangerouslyAllowHostHeaderOriginFallback:$fb}}')
fi

# customBindHost block
_CUSTOM="{}"
if [ "${OPENCLAW_BIND:-lan}" = "custom" ] && [ -n "${OPENCLAW_CUSTOM_BIND_HOST:-}" ]; then
  _CUSTOM=$(jq -n --arg h "${OPENCLAW_CUSTOM_BIND_HOST}" '{customBindHost:$h}')
fi

CONFIG_JSON=$(jq -n \
  --argjson gw "$_CONFIG_GATEWAY" \
  --argjson cui "$_CUI" \
  --argjson custom "$_CUSTOM" \
  '{commands:{native:"auto",nativeSkills:"auto",restart:true,ownerDisplay:"raw"},gateway:($gw + $cui + $custom)}')

# --- Ensure env vars are set ---
export HOME=/home/container
export OPENCLAW_HOME=/home/container/.openclaw
export XDG_CONFIG_HOME=/home/container/.config

# Write config to all possible lookup paths
for _DIR in \
  /home/container/.openclaw \
  /home/container/.config/openclaw \
  /home/container/.config/open-claw; do
  mkdir -p "$_DIR"
  printf '%s\n' "$CONFIG_JSON" > "$_DIR/openclaw.json"
  printf '%s\n' "$CONFIG_JSON" > "$_DIR/config.json"
done

printf "\033[1m\033[33mstacloud@ai~ \033[0mGenerated openclaw.json:\n"
printf '%s\n' "$CONFIG_JSON"
echo
printf "\033[1m\033[33mstacloud@ai~ \033[0mConfig written to ~/.openclaw/ ~/.config/openclaw/ ~/.config/open-claw/\n"

# Debug: find all openclaw config files
printf "\033[1m\033[33mstacloud@ai~ \033[0mAll openclaw config files:\n"
find /home/container -name "*.json" -path "*claw*" 2>/dev/null | while read -r f; do
  printf "=== %s ===\n" "$f"
  cat "$f"
  echo
done

# --- Build gateway args ---
EXTRA_ARGS="${OPENCLAW_ARGS:-}"
if [ "${OPENCLAW_VERBOSE:-false}" = "true" ]; then
  EXTRA_ARGS="${EXTRA_ARGS} --verbose"
fi
if [ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
  EXTRA_ARGS="${EXTRA_ARGS} --token ${OPENCLAW_GATEWAY_TOKEN}"
fi

CMD="openclaw gateway --allow-unconfigured --bind ${OPENCLAW_BIND:-lan} --port ${SERVER_PORT}${EXTRA_ARGS:+ $EXTRA_ARGS}"
printf "\033[1m\033[33mstacloud@ai~ \033[0m%s\n" "$CMD"

# Run without exec so we can debug after failure
/bin/bash -c "$CMD"
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  printf "\033[1m\033[31mstacloud@ai~ \033[0mGateway exited with code %d. Checking config files AFTER run:\n" "$EXIT_CODE"
  find /home/container -name "*.json" -path "*claw*" 2>/dev/null | while read -r f; do
    printf "=== %s ===\n" "$f"
    cat "$f"
    echo
  done
  printf "\033[1m\033[31mstacloud@ai~ \033[0mENV check: HOME=%s OPENCLAW_HOME=%s XDG_CONFIG_HOME=%s\n" "$HOME" "$OPENCLAW_HOME" "$XDG_CONFIG_HOME"
  
  # Also check npm global location for default config
  printf "\033[1m\033[33mstacloud@ai~ \033[0mChecking npm/openclaw paths:\n"
  which openclaw 2>/dev/null || true
  ls -la "$(which openclaw 2>/dev/null | xargs dirname 2>/dev/null)/../lib/node_modules/openclaw/" 2>/dev/null | head -5 || true
  
  # Check if there's a .openclaw in working directory
  ls -la /home/container/.openclaw/ 2>/dev/null || true
fi

exit $EXIT_CODE
