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

jq -n \
  --argjson gw "$_CONFIG_GATEWAY" \
  --argjson cui "$_CUI" \
  --argjson custom "$_CUSTOM" \
  '{commands:{native:"auto",nativeSkills:"auto",restart:true,ownerDisplay:"raw"},gateway:($gw + $cui + $custom)}' \
  > /home/container/.openclaw/openclaw.json

printf "\033[1m\033[33mstacloud@ai~ \033[0mGenerated openclaw.json:\n"
cat /home/container/.openclaw/openclaw.json
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
