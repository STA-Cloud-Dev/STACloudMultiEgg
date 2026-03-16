#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_BASE_URL="${SCRIPT_BASE_URL:-https://raw.githubusercontent.com/STA-Cloud-Dev/STACloudMultiEgg/main/docker-premium}"

if [[ -t 1 && "${NO_COLOR:-0}" != "1" ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_PINK=$'\033[38;5;213m'
  C_PURPLE=$'\033[38;5;141m'
  C_BLUE=$'\033[38;5;75m'
  C_CYAN=$'\033[38;5;87m'
  C_GREEN=$'\033[38;5;120m'
  C_INFO=$'\033[38;5;81m'
else
  C_RESET=""
  C_BOLD=""
  C_PINK=""
  C_PURPLE=""
  C_BLUE=""
  C_CYAN=""
  C_GREEN=""
  C_INFO=""
fi

display() {
  echo -e "\033c"
  echo
  echo -e "${C_PURPLE}╔══════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "${C_PINK}${C_BOLD}  ███████╗████████╗ █████╗                                    ${C_RESET}"
  echo -e "${C_PURPLE}${C_BOLD}  ██╔════╝╚══██╔══╝██╔══██╗                                   ${C_RESET}"
  echo -e "${C_BLUE}${C_BOLD}  ███████╗   ██║   ███████║                                   ${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}  ╚════██║   ██║   ██╔══██║                                   ${C_RESET}"
  echo -e "${C_GREEN}${C_BOLD}  ███████║   ██║   ██║  ██║                                   ${C_RESET}"
  echo -e "${C_GREEN}${C_BOLD}  ╚══════╝   ╚═╝   ╚═╝  ╚═╝                                   ${C_RESET}"
  echo -e "${C_CYAN}                   STACloud Multi-Egg Launcher                ${C_RESET}"
  echo -e "${C_PURPLE}╚══════════════════════════════════════════════════════════════╝${C_RESET}"
}

log() {
  echo -e "${C_INFO}[INFO]${C_RESET} $*"
}

to_lower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

is_truthy() {
  case "$(to_lower "${1:-}")" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

run_script() {
  local script_name="$1"
  local local_path="${SCRIPT_DIR}/${script_name}"
  local script_url="${SCRIPT_BASE_URL}/${script_name}"

  if [[ -f "${local_path}" ]]; then
    bash "${local_path}"
    return
  fi

  log "Không tìm thấy local script, fallback remote: ${script_url}"
  bash <(curl -fsSL "${script_url}")
}

display
sleep 1

server_flavor_raw="${SERVER_FLAVOR:-${SERVER_TYPE:-java}}"
auto_selected="0"
server_jar="${SERVER_JARFILE:-server.jar}"
proxy_jar="${PROXY_JARFILE:-proxy.jar}"
pmmp_phar="${PMMP_PHAR_FILE:-PocketMine-MP.phar}"

if [[ -z "${SERVER_FLAVOR:-}" && -z "${SERVER_TYPE:-}" ]]; then
  if [[ -f "./bedrock_server" ]]; then
    chmod +x ./bedrock_server 2>/dev/null || true
    server_flavor_raw="bedrock"
    export BEDROCK_SERVER_TYPE="${BEDROCK_SERVER_TYPE:-bds}"
    auto_selected="1"
    log "Đã phát hiện bedrock_server, tự chạy Bedrock."
  elif [[ -f "./${pmmp_phar}" ]]; then
    server_flavor_raw="bedrock"
    export BEDROCK_SERVER_TYPE="${BEDROCK_SERVER_TYPE:-pocketmine}"
    auto_selected="1"
    log "Đã phát hiện ${pmmp_phar}, tự chạy PocketMine-MP."
  elif [[ -f "./${server_jar}" ]]; then
    server_flavor_raw="java"
    auto_selected="1"
    log "Đã phát hiện ${server_jar}, tự chạy Java server."
  elif [[ -f "./${proxy_jar}" ]]; then
    server_flavor_raw="proxy"
    auto_selected="1"
    log "Đã phát hiện ${proxy_jar}, tự chạy Proxy."
  fi
fi

if is_truthy "${MULTIEGG_INTERACTIVE:-1}" && [[ "${auto_selected}" != "1" ]]; then
  echo
  echo -e "${C_INFO}[INFO]${C_RESET} Select the Server Genre:"
  echo "1) Minecraft: Java Edition"
  echo "2) Minecraft: Bedrock Edition"
  echo "3) Minecraft: Proxy"
  echo "4) Exit"

  if ! read -r -p "Input [1-4, default 1]: " flavor_choice; then
    flavor_choice="1"
  fi

  case "${flavor_choice:-1}" in
    1) server_flavor_raw="java" ;;
    2) server_flavor_raw="bedrock" ;;
    3) server_flavor_raw="proxy" ;;
    4)
      log "Đã dừng server."
      exit 0
      ;;
    *)
      log "Lựa chọn không hợp lệ, fallback về java."
      server_flavor_raw="java"
      ;;
  esac
fi

server_flavor="$(to_lower "${server_flavor_raw}")"

case "${server_flavor}" in
  java|minecraft-java|minecraft_java)
    run_script "mc-java.sh"
    ;;
  bedrock|minecraft-bedrock|minecraft_bedrock)
    run_script "mc-bedrock.sh"
    ;;
  proxy|minecraft-proxy|minecraft_proxy)
    run_script "mc-proxy.sh"
    ;;
  *)
    log "SERVER_FLAVOR không hợp lệ (${server_flavor_raw}), fallback về java."
    run_script "mc-java.sh"
    ;;
esac
