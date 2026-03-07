#!/usr/bin/env bash

set -euo pipefail

cd /home/container 2>/dev/null || true

RUNTIME_ROOT="${RUNTIME_ROOT:-/home/container/.local/share/stacloud/runtime}"
PHP_RUNTIME_DIR="${PHP_RUNTIME_DIR:-${RUNTIME_ROOT}/php}"
BEDROCK_VERSIONS_BASE_URL="${BEDROCK_VERSIONS_BASE_URL:-https://raw.githubusercontent.com/Bedrock-OSS/BDS-Versions/main}"
PMMP_PHP_BINARIES_API="${PMMP_PHP_BINARIES_API:-https://api.github.com/repos/pmmp/PHP-Binaries/releases/latest}"

if [[ -t 1 && "${NO_COLOR:-0}" != "1" ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_INFO=$'\033[38;5;81m'
  C_TITLE=$'\033[38;5;141m'
  C_OPTION=$'\033[38;5;87m'
else
  C_RESET=""
  C_BOLD=""
  C_INFO=""
  C_TITLE=""
  C_OPTION=""
fi

log() {
  echo -e "${C_INFO}[INFO]${C_RESET} $*" >&2
}

resolve_arch() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    *)
      log "Kiến trúc ${arch} chưa được hỗ trợ cho PocketMine-MP."
      exit 1
      ;;
  esac
}

discover_php_bin() {
  local candidate
  candidate="$(find "${PHP_RUNTIME_DIR}" -type f -name php 2>/dev/null | head -n 1 || true)"

  if [[ -n "${candidate}" ]]; then
    chmod +x "${candidate}" 2>/dev/null || true
    if "${candidate}" -v >/dev/null 2>&1; then
      echo "${candidate}"
      return
    fi
  fi

  echo ""
}

ensure_php_for_pmmp() {
  local php_bin
  local arch
  local tmp_archive
  local tmp_extract
  local extracted_root
  local custom_url
  local url
  local resolved_url

  if command -v php >/dev/null 2>&1; then
    command -v php
    return
  fi

  php_bin="$(discover_php_bin)"
  if [[ -n "${php_bin}" ]]; then
    echo "${php_bin}"
    return
  fi

  arch="$(resolve_arch)"
  custom_url="${PMMP_PHP_DOWNLOAD_URL:-}"

  mkdir -p "${PHP_RUNTIME_DIR}"
  tmp_archive="${PHP_RUNTIME_DIR}/pmmp-php.tar.gz"
  tmp_extract="${PHP_RUNTIME_DIR}/.extract-php-$$"

  download_and_extract() {
    local source_url="$1"

    log "Đang tải PHP runtime cho PocketMine-MP: ${source_url}"
    rm -f "${tmp_archive}"
    rm -rf "${tmp_extract}"

    curl -fsSL -o "${tmp_archive}" "${source_url}" || return 1

    mkdir -p "${tmp_extract}"
    tar -xzf "${tmp_archive}" -C "${tmp_extract}" || return 1

    extracted_root="$(find "${tmp_extract}" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
    rm -rf "${PHP_RUNTIME_DIR}/bin"
    mkdir -p "${PHP_RUNTIME_DIR}/bin"

    if [[ -n "${extracted_root}" ]]; then
      cp -a "${extracted_root}/." "${PHP_RUNTIME_DIR}/bin/"
    else
      cp -a "${tmp_extract}/." "${PHP_RUNTIME_DIR}/bin/"
    fi

    rm -f "${tmp_archive}"
    rm -rf "${tmp_extract}"
    return 0
  }

  resolve_pmmp_php_url() {
    local target_arch="$1"
    local arch_regex
    local release_json
    local found_url

    case "${target_arch}" in
      x86_64) arch_regex="x86_64|amd64|x64" ;;
      aarch64) arch_regex="aarch64|arm64" ;;
      *) arch_regex="${target_arch}" ;;
    esac

    release_json="$(curl -fsSL -H 'User-Agent: STACloud-MultiEgg' "${PMMP_PHP_BINARIES_API}")"
    found_url="$(echo "${release_json}" | jq -r --arg re "${arch_regex}" '
      [
        .assets[]?
        | select(.name | test("^PHP-[0-9]+\\.[0-9]+-Linux-(" + $re + ")(?:-PM5)?\\.tar\\.gz$"))
        | .browser_download_url
      ][0] // empty
    ')"

    echo "${found_url}"
  }

  if [[ -n "${custom_url}" ]]; then
    if ! download_and_extract "${custom_url}"; then
      log "Không thể tải PHP từ PMMP_PHP_DOWNLOAD_URL."
      exit 1
    fi
  else
    resolved_url="$(resolve_pmmp_php_url "${arch}")"

    if [[ -n "${resolved_url}" ]]; then
      download_and_extract "${resolved_url}" || true
    fi

    if [[ -z "${resolved_url}" || -z "$(discover_php_bin)" ]]; then
      for url in \
        "https://github.com/pmmp/PHP-Binaries/releases/latest/download/PHP-8.4-Linux-${arch}-PM5.tar.gz" \
        "https://github.com/pmmp/PHP-Binaries/releases/latest/download/PHP-8.3-Linux-${arch}-PM5.tar.gz" \
        "https://github.com/pmmp/PHP-Binaries/releases/latest/download/PHP-8.2-Linux-${arch}-PM5.tar.gz" \
        "https://github.com/pmmp/PHP-Binaries/releases/latest/download/PHP-8.3-Linux-${arch}.tar.gz" \
        "https://github.com/pmmp/PHP-Binaries/releases/latest/download/PHP-8.2-Linux-${arch}.tar.gz" \
        "https://github.com/pmmp/PHP-Binaries/releases/latest/download/php-8.3-linux-${arch}.tar.gz"; do
        if download_and_extract "${url}"; then
          break
        fi
      done
    fi
  fi

  php_bin="$(discover_php_bin)"
  if [[ -z "${php_bin}" ]]; then
    log "Tải xong nhưng không tìm thấy binary php hợp lệ."
    log "Bạn có thể đặt PMMP_PHP_DOWNLOAD_URL tới gói PHP binaries phù hợp."
    exit 1
  fi

  echo "${php_bin}"
}

fetch_bedrock_versions_json() {
  curl -fsSL "${BEDROCK_VERSIONS_BASE_URL}/versions.json"
}

ensure_unzip() {
  if command -v unzip >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$(id -u)" -ne 0 ]]; then
    log "Thiếu lệnh unzip và không có quyền root để cài tự động."
    return 1
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    log "Thiếu lệnh unzip và không có apt-get để cài tự động."
    return 1
  fi

  log "Đang cài unzip tự động..."
  if ! apt-get update || ! apt-get install -y --no-install-recommends unzip; then
    log "Không thể cài unzip tự động."
    return 1
  fi

  apt-get clean >/dev/null 2>&1 || true
  rm -rf /var/lib/apt/lists/* >/dev/null 2>&1 || true

  if ! command -v unzip >/dev/null 2>&1; then
    log "Cài unzip xong nhưng vẫn không tìm thấy lệnh unzip."
    return 1
  fi

  return 0
}

select_bedrock_version() {
  local versions_json
  local stable_version
  local preview_version
  local requested_version
  local selected_version
  local version_choice
  local version_input

  versions_json="$(fetch_bedrock_versions_json)"
  stable_version="$(echo "${versions_json}" | jq -r '.linux.stable // empty')"
  preview_version="$(echo "${versions_json}" | jq -r '.linux.preview // empty')"

  requested_version="${BEDROCK_VERSION:-latest}"

  if [[ -z "${BEDROCK_VERSION:-}" ]]; then
    echo
    echo -e "${C_TITLE}${C_BOLD}Chọn phiên bản Minecraft Bedrock:${C_RESET}"
    echo -e "  ${C_OPTION}1) Stable (${stable_version:-N/A})${C_RESET}"
    echo -e "  ${C_OPTION}2) Preview (${preview_version:-N/A})${C_RESET}"
    echo -e "  ${C_OPTION}3) Nhập tay${C_RESET}"
    if ! read -r -p "Nhập lựa chọn (mặc định 1): " version_choice; then
      version_choice="1"
    fi

    case "${version_choice:-1}" in
      1)
        requested_version="stable"
        ;;
      2)
        requested_version="preview"
        ;;
      3)
        if ! read -r -p "Nhập phiên bản Bedrock (ví dụ 1.26.2.1, latest): " version_input; then
          version_input="latest"
        fi
        requested_version="${version_input:-latest}"
        ;;
      *)
        log "Lựa chọn không hợp lệ, chuyển sang stable."
        requested_version="stable"
        ;;
    esac
  fi

  case "${requested_version}" in
    ""|latest|stable)
      selected_version="${stable_version}"
      ;;
    preview)
      selected_version="${preview_version}"
      ;;
    *)
      if echo "${versions_json}" | jq -e --arg v "${requested_version}" '.linux.versions[] | select(. == $v)' >/dev/null; then
        selected_version="${requested_version}"
      else
        log "BEDROCK_VERSION=${requested_version} không tồn tại. Fallback về stable ${stable_version}."
        selected_version="${stable_version}"
      fi
      ;;
  esac

  if [[ -z "${selected_version}" || "${selected_version}" == "null" ]]; then
    log "Không xác định được phiên bản Bedrock hợp lệ."
    exit 1
  fi

  export BEDROCK_VERSION="${selected_version}"
  echo "${selected_version}"
}

resolve_bedrock_download_url() {
  local selected_version="$1"
  local metadata_url
  local download_url

  metadata_url="${BEDROCK_VERSIONS_BASE_URL}/linux/${selected_version}.json"
  download_url="$(curl -fsSL "${metadata_url}" | jq -r '.download_url // empty')"

  if [[ -z "${download_url}" ]]; then
    download_url="https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server-${selected_version}.zip"
  fi

  echo "${download_url}"
}

download_bedrock_zip() {
  local source_url="$1"
  local output_file="/tmp/bedrock-server.zip"
  local ua="Mozilla/5.0 (STACloud-MultiEgg)"

  log "URL tải BDS: ${source_url}"

  if curl --http1.1 -fL --retry 5 --retry-delay 2 --retry-all-errors --connect-timeout 20 --max-time 1800 \
    -A "${ua}" -o "${output_file}" "${source_url}"; then
    return 0
  fi

  log "Tải thất bại với cấu hình mặc định, thử lại với IPv4..."

  if curl -4 --http1.1 -fL --retry 5 --retry-delay 2 --retry-all-errors --connect-timeout 20 --max-time 1800 \
    -A "${ua}" -o "${output_file}" "${source_url}"; then
    return 0
  fi

  return 1
}

run_bds() {
  local bedrock_url
  local selected_version

  if [[ -f "./bedrock_server" ]]; then
    chmod +x ./bedrock_server 2>/dev/null || true
  fi

  if [[ -x "./bedrock_server" ]]; then
    log "Đã tìm thấy bedrock_server, bắt đầu khởi chạy."
    exec ./bedrock_server
  fi

  log "Chưa tìm thấy bedrock_server."

  if [[ -n "${BEDROCK_DOWNLOAD_URL:-}" ]]; then
    bedrock_url="${BEDROCK_DOWNLOAD_URL}"
    log "Đang tải BDS từ BEDROCK_DOWNLOAD_URL..."
  else
    selected_version="$(select_bedrock_version)"
    bedrock_url="$(resolve_bedrock_download_url "${selected_version}")"
    log "Đang tải BDS phiên bản ${selected_version}..."
  fi

  if ! ensure_unzip; then
    log "Không thể giải nén BDS vì thiếu unzip. Hãy rebuild image mới hoặc cài unzip thủ công."
    exit 1
  fi

  if ! download_bedrock_zip "${bedrock_url}"; then
    log "Không tải được BDS từ URL đã chọn. Nếu mạng node chặn minecraft.net, hãy đặt BEDROCK_DOWNLOAD_URL tới mirror trực tiếp."
    exit 1
  fi

  unzip -o /tmp/bedrock-server.zip -d /home/container
  rm -f /tmp/bedrock-server.zip

  if [[ -f "./bedrock_server" ]]; then
    chmod +x ./bedrock_server 2>/dev/null || true
  fi

  if [[ -x "./bedrock_server" ]]; then
    log "Tải và giải nén thành công, bắt đầu khởi chạy BDS."
    exec ./bedrock_server
  fi

  exit 1
}

run_pocketmine() {
  local pmmp_phar
  local pmmp_url
  local php_bin

  php_bin="$(ensure_php_for_pmmp)"

  if [[ -z "${php_bin}" || ! -x "${php_bin}" ]]; then
    log "Không tìm được PHP runtime hợp lệ cho PocketMine-MP."
    exit 1
  fi

  pmmp_phar="${PMMP_PHAR_FILE:-PocketMine-MP.phar}"
  pmmp_url="${PMMP_PHAR_URL:-https://github.com/pmmp/PocketMine-MP/releases/latest/download/PocketMine-MP.phar}"

  if [[ ! -f "${pmmp_phar}" ]]; then
    log "Đang tải PocketMine-MP phar..."
    curl -fsSL -o "${pmmp_phar}" "${pmmp_url}"
  fi

  log "Khởi chạy PocketMine-MP (bỏ qua php.ini mặc định để tránh cảnh báo opcache)."
  exec "${php_bin}" -n "${pmmp_phar}" --no-wizard
}

bedrock_mode="${BEDROCK_SERVER_TYPE:-}"
pmmp_phar_file="${PMMP_PHAR_FILE:-PocketMine-MP.phar}"

if [[ -z "${bedrock_mode}" ]]; then
  if [[ -f "./bedrock_server" ]]; then
    bedrock_mode="bds"
    log "Đã phát hiện bedrock_server, tự chạy Minecraft BDS."
  elif [[ -f "./${pmmp_phar_file}" ]]; then
    bedrock_mode="pocketmine"
    log "Đã phát hiện ${pmmp_phar_file}, tự chạy PocketMine-MP."
  fi
fi

if [[ -z "${bedrock_mode}" ]]; then
  echo -e "${C_TITLE}${C_BOLD}Chọn máy chủ Bedrock:${C_RESET}"
  echo -e "  ${C_OPTION}1) Minecraft BDS${C_RESET}"
  echo -e "  ${C_OPTION}2) PocketMine-MP${C_RESET}"
  if ! read -r -p "Nhập lựa chọn: " n; then
    n="1"
  fi

  case "${n}" in
    1) bedrock_mode="bds" ;;
    2) bedrock_mode="pocketmine" ;;
    *)
      log "Lựa chọn không hợp lệ."
      exit 1
      ;;
  esac
fi

case "${bedrock_mode}" in
  bds|bedrock|minecraft-bds|minecraft_bds)
    run_bds
    ;;
  pocketmine|pmmp)
    run_pocketmine
    ;;
  *)
    log "BEDROCK_SERVER_TYPE=${bedrock_mode} không hợp lệ, fallback về bds."
    run_bds
    ;;
esac
