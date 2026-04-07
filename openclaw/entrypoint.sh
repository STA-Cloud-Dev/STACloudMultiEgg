#!/bin/bash
set -e

cd /home/container || exit 1

STATE_DIR="${OPENCLAW_STATE_DIR:-/home/container/.openclaw}"
CONFIG_FILE="${OPENCLAW_CONFIG_PATH:-${STATE_DIR}/openclaw.json}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/home/container/.config}"
XDG_OPENCLAW_DIR="${XDG_CONFIG_HOME}/openclaw"
XDG_CONFIG_FILE="${XDG_OPENCLAW_DIR}/config.json5"
RUNTIME_ROOT="${OPENCLAW_RUNTIME_ROOT:-${STATE_DIR}/runtime}"
RUNTIME_PREFIX="${RUNTIME_ROOT}/npm-global"
RUNTIME_CACHE="${RUNTIME_ROOT}/npm-cache"
RUNTIME_BIN="${RUNTIME_PREFIX}/bin/openclaw"
IMAGE_OPENCLAW_BIN="$(command -v openclaw || true)"
ACTIVE_OPENCLAW_BIN="${IMAGE_OPENCLAW_BIN}"
OPENCLAW_PACKAGE_TARGET="${OPENCLAW_UPDATE_OPENCLAW_VERSION:-${OPENCLAW_UPDATE_CHANNEL:-latest}}"

mkdir -p "$STATE_DIR" "$RUNTIME_ROOT" "$RUNTIME_PREFIX" "$RUNTIME_CACHE" "$XDG_OPENCLAW_DIR"

openclaw_version_of() {
  local bin_path="$1"
  if [ -x "$bin_path" ]; then
    "$bin_path" --version 2>/dev/null | head -n 1 | tr -d '\r'
  fi
}

install_openclaw_runtime() {
  NPM_CONFIG_PREFIX="$RUNTIME_PREFIX" \
  NPM_CONFIG_CACHE="$RUNTIME_CACHE" \
  npm install -g "openclaw@${OPENCLAW_PACKAGE_TARGET}"
}

# Set Node.js memory limit
if [ -n "${NODE_OPTIONS_MAX_OLD_SPACE:-}" ]; then
  export NODE_OPTIONS="--max-old-space-size=${NODE_OPTIONS_MAX_OLD_SPACE}"
fi

mkdir -p \
  "$STATE_DIR" \
  "${STATE_DIR}/workspace" \
  "${STATE_DIR}/skills" \
  "$RUNTIME_ROOT"

if [ "${OPENCLAW_AUTO_UPDATE:-true}" = "true" ]; then
  printf "\033[1m\033[33mstacloud@ai~ \033[0mChecking OpenClaw updates from npm (%s)\n" "${OPENCLAW_PACKAGE_TARGET}"
  LATEST_OPENCLAW_VERSION="$(npm view "openclaw@${OPENCLAW_PACKAGE_TARGET}" version --silent 2>/dev/null | tail -n 1 | tr -d '\r')"
  CURRENT_RUNTIME_VERSION="$(openclaw_version_of "$RUNTIME_BIN")"

  if [ -n "${LATEST_OPENCLAW_VERSION:-}" ]; then
    if [ "$CURRENT_RUNTIME_VERSION" != "$LATEST_OPENCLAW_VERSION" ]; then
      printf "\033[1m\033[33mstacloud@ai~ \033[0mUpdating OpenClaw runtime %s -> %s\n" "${CURRENT_RUNTIME_VERSION:-none}" "$LATEST_OPENCLAW_VERSION"
      install_openclaw_runtime
      hash -r
    else
      printf "\033[1m\033[33mstacloud@ai~ \033[0mOpenClaw runtime already at %s\n" "$CURRENT_RUNTIME_VERSION"
    fi
  elif [ -x "$RUNTIME_BIN" ]; then
    printf "\033[1m\033[33mstacloud@ai~ \033[0mCould not reach npm, using cached OpenClaw runtime %s\n" "${CURRENT_RUNTIME_VERSION:-unknown}"
  else
    printf "\033[1m\033[33mstacloud@ai~ \033[0mCould not reach npm and no cached runtime found; using bundled OpenClaw\n"
  fi
fi

if [ -x "$RUNTIME_BIN" ]; then
  export NPM_CONFIG_PREFIX="$RUNTIME_PREFIX"
  export NPM_CONFIG_CACHE="$RUNTIME_CACHE"
  export PATH="$RUNTIME_PREFIX/bin:$PATH"
  ACTIVE_OPENCLAW_BIN="$RUNTIME_BIN"
fi

printf "\033[1m\033[33mstacloud@ai~ \033[0m%s --version\n" "$ACTIVE_OPENCLAW_BIN"
"$ACTIVE_OPENCLAW_BIN" --version

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
    # open: allow everyone | pairing: empty (device pairing check) | allowlist: restrict
    if [ "$_TG_DM" = "open" ]; then
      _TG_ALLOW='["*"]'
    else
      _TG_ALLOW='[]'
    fi
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
    '{telegram:{enabled:true,dmPolicy:$dm,allowFrom:$af,groupPolicy:$gp,groups:$gaf,actions:{reactions:true,sendMessage:true},mediaMaxMb:100}}')
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

# --- Resolve agent model ---
_RESOLVED_MODEL="${OPENCLAW_AGENT_MODEL:-}"
if [ -z "$_RESOLVED_MODEL" ]; then
  if [ -n "${XAI_API_KEY:-}" ]; then
    _RESOLVED_MODEL="xai/grok-4.20-0309-non-reasoning"
  elif [ -n "${OPENAI_API_KEY:-}" ]; then
    _RESOLVED_MODEL="openai/gpt-4o-mini"
  elif [ -n "${GEMINI_API_KEY:-}" ]; then
    _RESOLVED_MODEL="google/gemini-2.0-flash"
  elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    _RESOLVED_MODEL="anthropic/claude-opus-4-6"
  fi
fi

# Build agents block with model if resolved
_AGENTS="{}"
if [ -n "${_RESOLVED_MODEL:-}" ]; then
  _AGENTS=$(jq -n --arg m "$_RESOLVED_MODEL" --arg workspace "${STATE_DIR}/workspace" '{defaults:{model:$m,workspace:$workspace,mediaMaxMb:100}}')
else
  _AGENTS=$(jq -n --arg workspace "${STATE_DIR}/workspace" '{defaults:{workspace:$workspace,mediaMaxMb:100}}')
fi

OUR_CONFIG=$(jq -n \
  --argjson gw "$OUR_GATEWAY" \
  --argjson ch "$_CHANNELS" \
  --argjson ag "$_AGENTS" \
  '{meta:{},commands:{native:"auto",nativeSkills:"auto",restart:true,ownerDisplay:"raw",bash:true,config:true},gateway:$gw,channels:$ch,tools:{profile:"full",elevated:{enabled:true}},agents:$ag}')

# --- Ensure env vars are set ---
export HOME=/home/container
export OPENCLAW_HOME="$STATE_DIR"
export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_CONFIG_PATH="$CONFIG_FILE"
export XDG_CONFIG_HOME="$XDG_CONFIG_HOME"

# --- Write auth-profiles.json for agent (only if env vars provided) ---
AUTH_DIR="${STATE_DIR}/agents/main/agent"
AUTH_FILE="$AUTH_DIR/auth-profiles.json"
mkdir -p "$AUTH_DIR"

_AUTH="{}"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  _AUTH=$(jq -n --argjson a "$_AUTH" --arg k "${ANTHROPIC_API_KEY}" '$a + {anthropic:{apiKey:$k}}')
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

# Only write if we have at least one key from env vars; otherwise keep existing file intact
if [ "$_AUTH" != "{}" ]; then
  if [ -f "$AUTH_FILE" ]; then
    # Merge: env vars override existing, existing keys not in env vars are preserved
    MERGED_AUTH=$(jq -s '.[0] + .[1]' "$AUTH_FILE" - <<< "$_AUTH")
    printf '%s\n' "$MERGED_AUTH" > "$AUTH_FILE"
  else
    printf '%s\n' "$_AUTH" > "$AUTH_FILE"
  fi
fi

# Write config (overwrite, but preserve meta from existing if present)
mkdir -p "$STATE_DIR" "$XDG_OPENCLAW_DIR"

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

# Mirror to the XDG config location as a symlink for builds that prefer ~/.config/openclaw/config.json5.
ln -sfn "$CONFIG_FILE" "$XDG_CONFIG_FILE"

printf "\033[1m\033[33mstacloud@ai~ \033[0mUsing OPENCLAW_STATE_DIR=%s\n" "$OPENCLAW_STATE_DIR"
printf "\033[1m\033[33mstacloud@ai~ \033[0mUsing OPENCLAW_CONFIG_PATH=%s\n" "$OPENCLAW_CONFIG_PATH"
printf "\033[1m\033[33mstacloud@ai~ \033[0mMirrored XDG config=%s -> %s\n" "$XDG_CONFIG_FILE" "$CONFIG_FILE"
printf "\033[1m\033[33mstacloud@ai~ \033[0mFinal %s:\n" "$CONFIG_FILE"
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

CMD="${ACTIVE_OPENCLAW_BIN} gateway --allow-unconfigured --bind ${OPENCLAW_BIND:-lan} --port ${SERVER_PORT}${EXTRA_ARGS:+ $EXTRA_ARGS}"
printf "\033[1m\033[33mstacloud@ai~ \033[0m%s\n" "$CMD"
exec /bin/bash -c "$CMD"
