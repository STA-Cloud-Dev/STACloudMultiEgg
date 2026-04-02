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

OUR_GATEWAY=$(jq -n \
  --argjson gw "$_CONFIG_GATEWAY" \
  --argjson cui "$_CUI" \
  --argjson custom "$_CUSTOM" \
  '$gw + $cui + $custom + {trustedProxies:["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","fc00::/7"],pairing:{autoApprove:true,required:false}}')

OUR_CONFIG=$(jq -n \
  --argjson gw "$OUR_GATEWAY" \
  '{commands:{native:"auto",nativeSkills:"auto",restart:true,ownerDisplay:"raw"},gateway:$gw}')

# --- Ensure env vars are set ---
export HOME=/home/container
export OPENCLAW_HOME=/home/container
export XDG_CONFIG_HOME=/home/container/.config

# Merge into existing config (preserve OpenClaw's own fields like meta, auth token)
CONFIG_FILE="/home/container/.openclaw/openclaw.json"
mkdir -p /home/container/.openclaw

if [ -f "$CONFIG_FILE" ]; then
  # Deep merge: existing config + our overrides (our gateway settings win)
  MERGED=$(jq -s '
    .[0] as $existing |
    .[1] as $ours |
    ($existing // {}) * $ours |
    .gateway = (($existing.gateway // {}) * $ours.gateway)
  ' "$CONFIG_FILE" - <<< "$OUR_CONFIG")
  printf '%s\n' "$MERGED" > "$CONFIG_FILE"
else
  printf '%s\n' "$OUR_CONFIG" > "$CONFIG_FILE"
fi

printf "\033[1m\033[33mstacloud@ai~ \033[0mFinal /home/container/.openclaw/openclaw.json:\n"
cat "$CONFIG_FILE"
echo

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

# Start gateway in background, auto-pair, then wait
/bin/bash -c "$CMD" &
GW_PID=$!

# Wait for gateway to be ready
for i in $(seq 1 30); do
  if curl -s -o /dev/null -w '' "http://127.0.0.1:${SERVER_PORT}/__openclaw__/canvas/" 2>/dev/null; then
    break
  fi
  sleep 0.5
done

# Auto-approve pairing for this gateway
if command -v openclaw >/dev/null 2>&1; then
  printf "\033[1m\033[33mstacloud@ai~ \033[0mAuto-pairing...\n"
  openclaw pairing --token "${OPENCLAW_GATEWAY_TOKEN}" --approve-all 2>&1 || \
  openclaw pairing approve --all 2>&1 || \
  openclaw pairing --help 2>&1 || \
  printf "\033[1m\033[33mstacloud@ai~ \033[0mPairing auto-approve not available\n"
fi

# Wait for gateway process
wait $GW_PID
