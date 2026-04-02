#!/bin/bash
set -e

cd /home/container || exit 1

# Set Node.js memory limit
if [ -n "${NODE_OPTIONS_MAX_OLD_SPACE:-}" ]; then
  export NODE_OPTIONS="--max-old-space-size=${NODE_OPTIONS_MAX_OLD_SPACE}"
fi

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
  '$gw + $cui + $custom + {trustedProxies:["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","fc00::/7"]} | .controlUi += {dangerouslyDisableDeviceAuth:true}')

# --- Channels config ---
_CHANNELS="{}"
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
  _TG_POLICY="${TELEGRAM_DM_POLICY:-open}"
  _CHANNELS=$(jq -n \
    --arg token "${TELEGRAM_BOT_TOKEN}" \
    --arg dm "$_TG_POLICY" \
    '{telegram:{token:$token,dmPolicy:$dm}}')
fi
if [ -n "${DISCORD_BOT_TOKEN:-}" ]; then
  _CHANNELS=$(jq -n --argjson ch "$_CHANNELS" --arg token "${DISCORD_BOT_TOKEN}" '$ch + {discord:{token:$token}}')
fi
if [ -n "${SLACK_BOT_TOKEN:-}" ]; then
  _SLACK='{token:$token}'
  if [ -n "${SLACK_SIGNING_SECRET:-}" ]; then
    _CHANNELS=$(jq -n --argjson ch "$_CHANNELS" --arg token "${SLACK_BOT_TOKEN}" --arg secret "${SLACK_SIGNING_SECRET}" '$ch + {slack:{token:$token,signingSecret:$secret}}')
  else
    _CHANNELS=$(jq -n --argjson ch "$_CHANNELS" --arg token "${SLACK_BOT_TOKEN}" '$ch + {slack:{token:$token}}')
  fi
fi
if [ -n "${ZALO_BOT_TOKEN:-}" ]; then
  _CHANNELS=$(jq -n --argjson ch "$_CHANNELS" --arg token "${ZALO_BOT_TOKEN}" '$ch + {zalo:{token:$token}}')
fi
if [ -n "${MSTEAMS_APP_ID:-}" ] && [ -n "${MSTEAMS_APP_PASSWORD:-}" ]; then
  _CHANNELS=$(jq -n --argjson ch "$_CHANNELS" --arg id "${MSTEAMS_APP_ID}" --arg pw "${MSTEAMS_APP_PASSWORD}" '$ch + {msteams:{appId:$id,appPassword:$pw}}')
fi
if [ -n "${MATRIX_HOMESERVER:-}" ] && [ -n "${MATRIX_ACCESS_TOKEN:-}" ]; then
  _CHANNELS=$(jq -n --argjson ch "$_CHANNELS" --arg hs "${MATRIX_HOMESERVER}" --arg token "${MATRIX_ACCESS_TOKEN}" '$ch + {matrix:{homeserver:$hs,accessToken:$token}}')
fi
if [ -n "${LINE_CHANNEL_SECRET:-}" ] && [ -n "${LINE_CHANNEL_ACCESS_TOKEN:-}" ]; then
  _CHANNELS=$(jq -n --argjson ch "$_CHANNELS" --arg secret "${LINE_CHANNEL_SECRET}" --arg token "${LINE_CHANNEL_ACCESS_TOKEN}" '$ch + {line:{channelSecret:$secret,channelAccessToken:$token}}')
fi
if [ -n "${WHATSAPP_SESSION:-}" ]; then
  _CHANNELS=$(jq -n --argjson ch "$_CHANNELS" --arg session "${WHATSAPP_SESSION}" '$ch + {whatsapp:{session:$session}}')
fi

OUR_CONFIG=$(jq -n \
  --argjson gw "$OUR_GATEWAY" \
  --argjson ch "$_CHANNELS" \
  '{commands:{native:"auto",nativeSkills:"auto",restart:true,ownerDisplay:"raw"},gateway:$gw,channels:$ch}')

# --- Ensure env vars are set ---
export HOME=/home/container
export OPENCLAW_HOME=/home/container
export XDG_CONFIG_HOME=/home/container/.config

# Write config (overwrite, but preserve meta from existing if present)
CONFIG_FILE="/home/container/.openclaw/openclaw.json"
mkdir -p /home/container/.openclaw

if [ -f "$CONFIG_FILE" ]; then
  # Only preserve meta from existing config; gateway settings fully replaced by ours
  MERGED=$(jq -s '
    .[0] as $existing |
    .[1] as $ours |
    $ours + (if $existing.meta then {meta: $existing.meta} else {} end)
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
exec /bin/bash -c "$CMD"
