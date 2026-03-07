#!/usr/bin/env bash

set -euo pipefail

cd /home/container

RUNTIME_ROOT="${RUNTIME_ROOT:-/home/container/.local/share/stacloud/runtime}"
JAVA_CACHE_DIR="${JAVA_CACHE_DIR:-${RUNTIME_ROOT}/java}"

if [[ -t 1 && "${NO_COLOR:-0}" != "1" ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_INFO=$'\033[38;5;81m'
else
  C_RESET=""
  C_BOLD=""
  C_INFO=""
fi

log() {
  echo -e "${C_INFO}${C_BOLD}[INFO]${C_RESET} $*"
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

select_java() {
  local requested="${JAVA_VERSION:-21}"

  # Tự động suy luận theo phiên bản Minecraft nếu người dùng chưa set JAVA_VERSION.
  if [[ -z "${JAVA_VERSION:-}" && -n "${MINECRAFT_VERSION:-}" ]]; then
    case "${MINECRAFT_VERSION}" in
      1.8* ) requested="8" ;;
      1.12* ) requested="11" ;;
      * ) requested="21" ;;
    esac
  fi

  case "${requested}" in
    8)
      ensure_java "8"
      ;;
    11)
      ensure_java "11"
      ;;
    17)
      ensure_java "17"
      ;;
    21)
      ensure_java "21"
      ;;
    25)
      ensure_java "25"
      ;;
    *)
      log "JAVA_VERSION=${requested} không nằm trong [8,11,17,21,25]. Fallback về 21."
      ensure_java "21"
      ;;
  esac

  if command -v java >/dev/null 2>&1; then
    log "Đang dùng Java: $(java -version 2>&1 | head -n 1)"
  else
    log "Không tìm thấy java trong PATH."
    exit 1
  fi
}

run_startup() {
  local raw_startup
  local processed_startup

  if [[ -z "${SERVER_JARFILE:-}" ]]; then
    export SERVER_JARFILE="server.jar"
  fi

  # Không preload Java ở entrypoint.
  # Mặc định ưu tiên vào launcher menu để người dùng chọn server trước,
  # sau đó script chuyên biệt mới tự tải runtime cần thiết (Java/PHP).
  raw_startup="${STARTUP:-}"
  if [[ -z "${raw_startup}" ]]; then
    if [[ -f "/opt/stacloud/t.sh" ]]; then
      raw_startup='bash /opt/stacloud/t.sh'
    else
      raw_startup='java -jar ${SERVER_JARFILE}'
    fi
  fi

  processed_startup=$(echo "${raw_startup}" | sed -e 's/{{/${/g' -e 's/}}/}/g')

  # Tương thích ngược: nhiều server cũ vẫn đang để STARTUP là `bash t.sh`.
  # Nếu thấy mẫu đó thì tự chuyển sang path tuyệt đối trong image mới.
  if [[ -f "/opt/stacloud/t.sh" ]]; then
    processed_startup=$(echo "${processed_startup}" | sed -E 's#(^|[[:space:]])bash[[:space:]]+(\./)?t\.sh([[:space:]]|$)#\1bash /opt/stacloud/t.sh\3#g')
    processed_startup=$(echo "${processed_startup}" | sed -E 's#(^|[[:space:]])(\./)?t\.sh([[:space:]]|$)#\1/opt/stacloud/t.sh\3#g')
  fi

  log "Lệnh khởi động: ${processed_startup}"

  # shellcheck disable=SC2086
  exec bash -lc "eval ${processed_startup}"
}

sanitize_java_env_for_java_eggs() {
  local startup_preview

  startup_preview="${STARTUP:-}"
  if [[ -z "${startup_preview}" ]]; then
    startup_preview='bash /opt/stacloud/t.sh'
  fi

  startup_preview="$(echo "${startup_preview}" | sed -e 's/{{/${/g' -e 's/}}/}/g')"

  # Nếu startup dùng launcher java/script java thì không giữ JAVA_VERSION mặc định từ môi trường container.
  # Việc chọn version Java sẽ do mc-java.sh quyết định theo jar/version đã lưu.
  if echo "${startup_preview}" | grep -Eq '(^|[[:space:]])(java|bash[[:space:]]+/opt/stacloud/t\.sh|/opt/stacloud/t\.sh)($|[[:space:]])'; then
    unset JAVA_VERSION || true
  fi
}

sanitize_java_env_for_java_eggs
run_startup
