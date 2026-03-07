#!/usr/bin/env bash

set -euo pipefail

cd /home/container 2>/dev/null || true

RUNTIME_ROOT="${RUNTIME_ROOT:-/home/container/.local/share/stacloud/runtime}"
JAVA_CACHE_DIR="${JAVA_CACHE_DIR:-${RUNTIME_ROOT}/java}"

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
  echo -e "${C_INFO}[INFO]${C_RESET} $*"
}

resolve_java_arch() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) echo "x64" ;;
    aarch64|arm64) echo "aarch64" ;;
    *)
      log "Kiến trúc ${arch} chưa được hỗ trợ tự động tải Java."
      exit 1
      ;;
  esac
}

ensure_java() {
  local major="$1"
  local arch
  local target_dir
  local api_url
  local download_url
  local tmp_archive
  local tmp_extract
  local extracted_root

  arch="$(resolve_java_arch)"
  target_dir="${JAVA_CACHE_DIR}/temurin-${major}-jdk"

  if [[ -x "${target_dir}/bin/java" ]]; then
    export JAVA_HOME="${target_dir}"
    export PATH="${JAVA_HOME}/bin:${PATH}"
    return
  fi

  mkdir -p "${JAVA_CACHE_DIR}"

  api_url="https://api.adoptium.net/v3/assets/latest/${major}/hotspot?architecture=${arch}&heap_size=normal&image_type=jdk&jvm_impl=hotspot&os=linux&vendor=eclipse"
  download_url="$(curl -fsSL "${api_url}" | jq -r '.[0].binary.package.link')"

  if [[ -z "${download_url}" || "${download_url}" == "null" ]]; then
    log "Không lấy được link tải Temurin JDK ${major}."
    exit 1
  fi

  tmp_archive="${JAVA_CACHE_DIR}/temurin-${major}.tar.gz"
  tmp_extract="${JAVA_CACHE_DIR}/.extract-${major}-$$"

  log "Đang tải Temurin JDK ${major} (${arch})..."
  curl -fsSL -o "${tmp_archive}" "${download_url}"

  mkdir -p "${tmp_extract}"
  tar -xzf "${tmp_archive}" -C "${tmp_extract}"

  extracted_root="$(find "${tmp_extract}" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
  if [[ -z "${extracted_root}" ]]; then
    log "Không tìm thấy thư mục sau khi giải nén JDK ${major}."
    rm -f "${tmp_archive}"
    rm -rf "${tmp_extract}"
    exit 1
  fi

  rm -rf "${target_dir}"
  mv "${extracted_root}" "${target_dir}"

  rm -f "${tmp_archive}"
  rm -rf "${tmp_extract}"

  if [[ ! -x "${target_dir}/bin/java" ]]; then
    log "Tải xong nhưng không tìm thấy binary java cho JDK ${major}."
    exit 1
  fi

  export JAVA_HOME="${target_dir}"
  export PATH="${JAVA_HOME}/bin:${PATH}"
}

select_proxy() {
  echo
  echo -e "${C_TITLE}${C_BOLD}Chọn proxy:${C_RESET}"
  echo -e "  ${C_OPTION}1) Velocity${C_RESET}"
  echo -e "  ${C_OPTION}2) BungeeCord${C_RESET}"
  echo
  if ! read -r -p "Nhập lựa chọn (mặc định 1): " proxy_choice; then
    proxy_choice="1"
  fi

  case "${proxy_choice:-1}" in
    1)
      PROXY_TYPE="velocity"
      ;;
    2)
      PROXY_TYPE="bungeecord"
      ;;
    *)
      log "Lựa chọn không hợp lệ, chuyển về Velocity."
      PROXY_TYPE="velocity"
      ;;
  esac

  log "Đã chọn: ${PROXY_TYPE}"
}

select_java_for_proxy() {
  # Proxy không cần chọn phiên bản Minecraft. Dùng Java ổn định mặc định.
  ensure_java "21"
  export JAVA_VERSION="21"
  log "JAVA_VERSION=${JAVA_VERSION}"
  java -version 2>&1 | head -n 1 | sed 's/^/[INFO] /'
}

download_velocity() {
  local project_json
  local versions_json
  local selected_version
  local latest_build
  local build_info
  local jar_name
  local server_jar

  project_json="$(curl -fsSL "https://api.papermc.io/v2/projects/velocity")"
  selected_version="$(echo "${project_json}" | jq -r '.versions[-1]')"

  if [[ -z "${selected_version}" || "${selected_version}" == "null" ]]; then
    log "Không lấy được phiên bản Velocity."
    exit 1
  fi

  versions_json="$(curl -fsSL "https://api.papermc.io/v2/projects/velocity/versions/${selected_version}")"
  latest_build="$(echo "${versions_json}" | jq -r '.builds[-1]')"

  if [[ -z "${latest_build}" || "${latest_build}" == "null" ]]; then
    log "Không lấy được build Velocity mới nhất."
    exit 1
  fi

  build_info="$(curl -fsSL "https://api.papermc.io/v2/projects/velocity/versions/${selected_version}/builds/${latest_build}")"
  jar_name="$(echo "${build_info}" | jq -r '.downloads.application.name // (.downloads | to_entries[0].value.name) // empty')"

  if [[ -z "${jar_name}" ]]; then
    jar_name="velocity-${selected_version}-${latest_build}.jar"
  fi

  server_jar="${PROXY_JARFILE:-proxy.jar}"

  if [[ -f "${server_jar}" ]]; then
    log "Đã phát hiện ${server_jar}, bỏ qua bước tải Velocity mới."
    return
  fi

  log "Đang tải Velocity ${selected_version} build ${latest_build}..."
  curl -fsSL -o "${server_jar}" "https://api.papermc.io/v2/projects/velocity/versions/${selected_version}/builds/${latest_build}/downloads/${jar_name}"
}

download_bungeecord() {
  local server_jar
  server_jar="${PROXY_JARFILE:-proxy.jar}"

  if [[ -f "${server_jar}" ]]; then
    log "Đã phát hiện ${server_jar}, bỏ qua bước tải BungeeCord mới."
    return
  fi

  log "Đang tải BungeeCord build mới nhất..."
  curl -fsSL -o "${server_jar}" "https://ci.md-5.net/job/BungeeCord/lastSuccessfulBuild/artifact/bootstrap/target/BungeeCord.jar"
}

launch_proxy() {
  local server_jar
  local proxy_java_args
  local resolved_proxy_args

  server_jar="${PROXY_JARFILE:-proxy.jar}"
  proxy_java_args="${PROXY_JAVA_ARGUMENTS:-}"

  if [[ -z "${proxy_java_args}" ]]; then
    proxy_java_args="-jar ${server_jar}"
  fi

  resolved_proxy_args="$(eval echo "${proxy_java_args}")"
  log "Lệnh khởi chạy proxy: java ${resolved_proxy_args}"

  # shellcheck disable=SC2086
  exec java ${resolved_proxy_args}
}

main() {
  select_proxy
  select_java_for_proxy

  if [[ "${PROXY_TYPE}" == "velocity" ]]; then
    download_velocity
  else
    download_bungeecord
  fi

  launch_proxy
}

main "$@"
