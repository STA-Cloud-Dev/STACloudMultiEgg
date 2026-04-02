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
  '$gw + $cui + $custom + {trustedProxies:["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","fc00::/7"]} | .controlUi += {dangerouslyDisableDeviceAuth:true,dangerouslyAllowHostHeaderOriginFallback:true}')

# --- Channels config (only dmPolicy, tokens via env vars) ---
_CHANNELS="{}"
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
  _TG_DM="${TELEGRAM_DM_POLICY:-open}"
  _TG_GROUP_POLICY="${TELEGRAM_GROUP_POLICY:-open}"
  # Build dmAllowFrom array
  if [ -n "${TELEGRAM_ALLOW_FROM:-}" ]; then
    _TG_ALLOW=$(jq -n --arg v "${TELEGRAM_ALLOW_FROM}" '[$v | split(",") | .[] | gsub("^\\s+|\\s+$";"") | select(length>0)]')
  else
    _TG_ALLOW='["*"]'
  fi
  # Build groups object {"id": {}}
  if [ "$_TG_GROUP_POLICY" = "allowlist" ] && [ -n "${TELEGRAM_GROUP_ALLOW_FROM:-}" ]; then
    _TG_GROUP_ALLOW=$(jq -n --arg v "${TELEGRAM_GROUP_ALLOW_FROM}" '[$v | split(",") | .[] | gsub("^\\s+|\\s+$";"") | select(length>0)] | map({(.): {}}) | add // {}')
  else
    _TG_GROUP_ALLOW='{}'
  fi
  _CHANNELS=$(jq -n \
    --arg dm "$_TG_DM" \
    --arg gp "$_TG_GROUP_POLICY" \
    --argjson af "$_TG_ALLOW" \
    --argjson gaf "$_TG_GROUP_ALLOW" \
    '{telegram:{enabled:true,dmPolicy:$dm,allowFrom:$af,groupPolicy:$gp,groups:$gaf}}')
fi
if [ -n "${DISCORD_BOT_TOKEN:-}" ]; then
  _CHANNELS=$(jq -n --argjson ch "$_CHANNELS" '$ch + {discord:{enabled:true,dmPolicy:"open",allowFrom:["*"]}}')
fi
if [ -n "${SLACK_BOT_TOKEN:-}" ]; then
  _CHANNELS=$(jq -n --argjson ch "$_CHANNELS" '$ch + {slack:{enabled:true,dmPolicy:"open",allowFrom:["*"]}}')
fi
if [ -n "${ZALO_BOT_TOKEN:-}" ]; then
  _CHANNELS=$(jq -n --argjson ch "$_CHANNELS" '$ch + {zalo:{enabled:true,dmPolicy:"open",allowFrom:["*"]}}')
fi
if [ -n "${WHATSAPP_SESSION:-}" ]; then
  _CHANNELS=$(jq -n --argjson ch "$_CHANNELS" --arg session "${WHATSAPP_SESSION}" '$ch + {whatsapp:{session:$session}}')
fi

OUR_CONFIG=$(jq -n \
  --argjson gw "$OUR_GATEWAY" \
  --argjson ch "$_CHANNELS" \
  '{meta:{},commands:{native:"auto",nativeSkills:"auto",restart:true,ownerDisplay:"raw"},gateway:$gw,channels:$ch}')

# --- Ensure env vars are set ---
export HOME=/home/container
export OPENCLAW_HOME=/home/container
export XDG_CONFIG_HOME=/home/container/.config

# --- Write auth-profiles.json for agent ---
AUTH_DIR="/home/container/.openclaw/agents/main/agent"
AUTH_FILE="$AUTH_DIR/auth-profiles.json"
mkdir -p "$AUTH_DIR"

_AUTH="{}"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  _AUTH=$(jq -n --arg k "${ANTHROPIC_API_KEY}" '{anthropic:{apiKey:$k}}')
fi
if [ -n "${OPENAI_API_KEY:-}" ]; then
  _AUTH=$(jq -n --argjson a "$_AUTH" --arg k "${OPENAI_API_KEY}" '$a + {openai:{apiKey:$k}}')
fi
if [ -n "${GEMINI_API_KEY:-}" ]; then
  _AUTH=$(jq -n --argjson a "$_AUTH" --arg k "${GEMINI_API_KEY}" '$a + {google:{apiKey:$k}}')
fi
if [ -n "${GROQ_API_KEY:-}" ]; then
  _AUTH=$(jq -n --argjson a "$_AUTH" --arg k "${GROQ_API_KEY}" '$a + {groq:{apiKey:$k}}')
fi
if [ -n "${XAI_API_KEY:-}" ]; then
  _AUTH=$(jq -n --argjson a "$_AUTH" --arg k "${XAI_API_KEY}" '$a + {xai:{apiKey:$k}}')
fi
if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
  _AUTH=$(jq -n --argjson a "$_AUTH" --arg k "${DEEPSEEK_API_KEY}" '$a + {deepseek:{apiKey:$k}}')
fi
printf '%s\n' "$_AUTH" > "$AUTH_FILE"

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
