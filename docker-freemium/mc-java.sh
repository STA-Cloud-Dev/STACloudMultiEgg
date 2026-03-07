#!/usr/bin/env bash

set -euo pipefail

cd /home/container 2>/dev/null || true

RUNTIME_ROOT="${RUNTIME_ROOT:-/home/container/.local/share/stacloud/runtime}"
JAVA_CACHE_DIR="${JAVA_CACHE_DIR:-${RUNTIME_ROOT}/java}"
STATE_DIR="${STATE_DIR:-${RUNTIME_ROOT}/state}"
STATE_JAVA_VERSION_FILE="${STATE_DIR}/java_version"
STATE_MC_VERSION_FILE="${STATE_DIR}/minecraft_version"
LAST_VERSION_SELECTED_FILE="${LAST_VERSION_SELECTED_FILE:-${RUNTIME_ROOT}/lastversionselected}"
LEGACY_LAST_VERSION_SELECTED_FILE="${LEGACY_LAST_VERSION_SELECTED_FILE:-/home/container/lastversionselected}"

PAPER_API_BASE="https://api.papermc.io/v2/projects"
PURPUR_API_BASE="https://api.purpurmc.org/v2"
FABRIC_META_API="https://meta.fabricmc.net/v2"
FORGE_PROMOTIONS_URL="https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json"
FORGE_MAVEN_BASE="https://maven.minecraftforge.net/net/minecraftforge/forge"
MOHIST_API_BASE="https://mohistmc.com/api/v2/projects/mohist"
CANVAS_API_BASE="https://canvasmc.io/api/v2"
CANVAS_KNOWN_VERSIONS=("1.21.8" "1.21.11")
LEAF_GITHUB_API="https://api.github.com/repos/Winds-Studio/Leaf/releases"

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

read_state_value() {
  local state_file="$1"
  if [[ -f "${state_file}" ]]; then
    head -n 1 "${state_file}" 2>/dev/null || true
  fi
}

write_state_value() {
  local state_file="$1"
  local state_value="$2"

  mkdir -p "${STATE_DIR}"
  echo "${state_value}" > "${state_file}"
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

version_gte() {
  local left="$1"
  local right="$2"
  [[ "$(printf '%s\n' "$right" "$left" | sort -V | head -n 1)" == "$right" ]]
}

map_java_from_minecraft_version() {
  local mc_version="$1"

  if version_gte "${mc_version}" "1.26"; then
    echo "25"
  elif version_gte "${mc_version}" "1.20.5"; then
    echo "21"
  elif version_gte "${mc_version}" "1.17"; then
    echo "17"
  else
    echo "8"
  fi
}

read_last_selected_java() {
  local candidate_file=""
  local raw_value=""
  local normalized=""
  local mc_like=""

  if [[ -f "${LEGACY_LAST_VERSION_SELECTED_FILE}" ]]; then
    candidate_file="${LEGACY_LAST_VERSION_SELECTED_FILE}"
  elif [[ -f "${LAST_VERSION_SELECTED_FILE}" ]]; then
    candidate_file="${LAST_VERSION_SELECTED_FILE}"
  else
    echo ""
    return
  fi

  raw_value="$(head -n 1 "${candidate_file}" 2>/dev/null | tr -d '\r' | xargs || true)"
  normalized="$(echo "${raw_value}" | tr '[:upper:]' '[:lower:]')"

  case "${normalized}" in
    8|11|17|21|25)
      echo "${normalized}"
      return
      ;;
  esac

  if [[ "${normalized}" =~ ^java[-_[:space:]]*([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi

  if [[ "${normalized}" =~ ^(mc|minecraft)[:=_-]([0-9]+(\.[0-9]+)*)$ ]]; then
    mc_like="${BASH_REMATCH[2]}"
    echo "$(map_java_from_minecraft_version "${mc_like}")"
    return
  fi

  if [[ "${normalized}" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
    echo "$(map_java_from_minecraft_version "${normalized}")"
    return
  fi

  echo ""
}

write_last_selected_java() {
  local java_version="$1"

  if [[ -z "${java_version}" ]]; then
    return
  fi

  mkdir -p "$(dirname "${LAST_VERSION_SELECTED_FILE}")" 2>/dev/null || true
  echo "${java_version}" > "${LAST_VERSION_SELECTED_FILE}" 2>/dev/null || true
  echo "${java_version}" > "${LEGACY_LAST_VERSION_SELECTED_FILE}" 2>/dev/null || true
}

map_java_from_class_major() {
  local class_major="$1"

  case "${class_major}" in
    52) echo "8" ;;
    55) echo "11" ;;
    61) echo "17" ;;
    65) echo "21" ;;
    69) echo "25" ;;
    *) echo "" ;;
  esac
}

infer_java_from_existing_jar() {
  local jar_file="$1"
  local manifest main_class class_file class_hex class_major inferred_java first_class

  if [[ ! -f "${jar_file}" ]]; then
    echo ""
    return
  fi

  if ! command -v unzip >/dev/null 2>&1; then
    echo ""
    return
  fi

  manifest="$(unzip -p "${jar_file}" META-INF/MANIFEST.MF 2>/dev/null | tr -d '\r' || true)"
  main_class="$(echo "${manifest}" | sed -n 's/^Main-Class:[[:space:]]*//p' | head -n 1)"

  class_file=""
  if [[ -n "${main_class}" ]]; then
    class_file="${main_class//./\/}.class"
  fi

  if [[ -z "${class_file}" ]]; then
    first_class="$(unzip -l "${jar_file}" 2>/dev/null | awk '/\.class$/ {print $4; exit}')"
    class_file="${first_class:-}"
  fi

  if [[ -z "${class_file}" ]]; then
    echo ""
    return
  fi

  class_hex="$(unzip -p "${jar_file}" "${class_file}" 2>/dev/null | od -An -tx1 -j 6 -N 2 | tr -d ' \n\r' || true)"
  if [[ -z "${class_hex}" ]]; then
    echo ""
    return
  fi

  class_major="$((16#${class_hex}))"
  inferred_java="$(map_java_from_class_major "${class_major}")"

  echo "${inferred_java}"
}

infer_minecraft_version_from_logs() {
  local candidate=""
  local log_file="./logs/latest.log"

  if [[ ! -f "${log_file}" ]]; then
    echo ""
    return
  fi

  candidate="$(grep -Eo 'Starting minecraft server version [0-9]+(\.[0-9]+)*' "${log_file}" | tail -n 1 | sed -E 's/.*version ([0-9]+(\.[0-9]+)*)/\1/' || true)"
  if [[ -n "${candidate}" ]]; then
    echo "${candidate}"
    return
  fi

  candidate="$(grep -Eo 'MC: [0-9]+(\.[0-9]+)*' "${log_file}" | tail -n 1 | awk '{print $2}' || true)"
  echo "${candidate}"
}

select_project() {
  echo
  echo -e "${C_TITLE}${C_BOLD}Chọn phần mềm máy chủ Java:${C_RESET}"
  echo -e "  ${C_OPTION}--- Vanilla Forks ---${C_RESET}"
  echo -e "  ${C_OPTION}1) Paper${C_RESET}"
  echo -e "  ${C_OPTION}2) Folia${C_RESET}"
  echo -e "  ${C_OPTION}3) Purpur${C_RESET}"
  echo -e "  ${C_OPTION}4) Leaf${C_RESET}"
  echo -e "  ${C_OPTION}5) Canvas (CanvasMC / Folia fork)${C_RESET}"
  echo -e "  ${C_OPTION}--- Mod Loaders ---${C_RESET}"
  echo -e "  ${C_OPTION}6) Forge${C_RESET}"
  echo -e "  ${C_OPTION}7) Fabric${C_RESET}"
  echo -e "  ${C_OPTION}8) Mohist (Forge + Bukkit)${C_RESET}"
  echo
  if ! read -r -p "Nhập lựa chọn (mặc định 1): " project_choice; then
    project_choice="1"
  fi

  case "${project_choice:-1}" in
    1) PROJECT="paper" ;;
    2) PROJECT="folia" ;;
    3) PROJECT="purpur" ;;
    4) PROJECT="leaf" ;;
    5) PROJECT="canvas" ;;
    6) PROJECT="forge" ;;
    7) PROJECT="fabric" ;;
    8) PROJECT="mohist" ;;
    *)
      log "Lựa chọn không hợp lệ, chuyển về Paper."
      PROJECT="paper"
      ;;
  esac

  log "Đã chọn dự án: ${PROJECT}"
}

is_excluded_mc_version() {
  local project="$1"
  local mc_version="$2"

  case "${project}" in
    paper)
      if [[ "${mc_version}" =~ ^1\.(9|10|11)(\.|$) ]]; then
        return 0
      fi
      ;;
  esac

  return 1
}

select_version_menu() {
  local project_display="$1"
  shift
  local -a versions=("$@")
  local total="${#versions[@]}"
  local default_choice="${total}"
  local latest="${versions[total-1]}"
  local version_choice idx

  echo
  echo -e "${C_TITLE}${C_BOLD}Chọn phiên bản ${project_display} (menu số):${C_RESET}"
  echo -e "${C_OPTION}Mặc định: ${default_choice} = ${latest}${C_RESET}"
  for idx in "${!versions[@]}"; do
    printf "  %s%3d) %-12s%s" "${C_OPTION}" "$((idx + 1))" "${versions[idx]}" "${C_RESET}"
    if (( (idx + 1) % 3 == 0 )); then
      echo
    fi
  done
  if (( ${#versions[@]} % 3 != 0 )); then
    echo
  fi
  if ! read -r -p "Nhập số lựa chọn [1-${total}, mặc định ${default_choice}]: " version_choice; then
    version_choice="${default_choice}"
  fi
  version_choice="$(echo "${version_choice:-${default_choice}}" | xargs || true)"
  if [[ -z "${version_choice}" ]]; then
    version_choice="${default_choice}"
  fi

  if [[ "${version_choice}" =~ ^[0-9]+$ ]] && (( version_choice >= 1 && version_choice <= total )); then
    MINECRAFT_VERSION="${versions[version_choice-1]}"
  else
    log "Lựa chọn không hợp lệ. Chuyển sang bản mặc định ${latest}."
    MINECRAFT_VERSION="${latest}"
  fi
  log "Dùng phiên bản: ${MINECRAFT_VERSION}"
}

resolve_version_purpur() {
  local project_json
  local -a all_versions=()
  local requested_version v

  project_json="$(curl -fsSL "${PURPUR_API_BASE}/purpur")"
  mapfile -t all_versions < <(echo "${project_json}" | jq -r '.versions[]')

  if [[ "${#all_versions[@]}" -eq 0 ]]; then
    log "Không lấy được danh sách phiên bản Purpur."
    exit 1
  fi

  requested_version="${MINECRAFT_VERSION:-}"
  if [[ -n "${requested_version}" ]]; then
    for v in "${all_versions[@]}"; do
      if [[ "${v}" == "${requested_version}" ]]; then
        MINECRAFT_VERSION="${requested_version}"
        log "Dùng phiên bản Purpur: ${MINECRAFT_VERSION}"
        return
      fi
    done
    log "MINECRAFT_VERSION=${requested_version} không có sẵn cho Purpur. Chuyển sang menu."
  fi

  select_version_menu "Purpur" "${all_versions[@]}"
}

resolve_version_fabric() {
  local game_versions_json
  local -a stable_versions=()
  local requested_version v

  game_versions_json="$(curl -fsSL "${FABRIC_META_API}/versions/game")"
  mapfile -t stable_versions < <(echo "${game_versions_json}" | jq -r '[.[] | select(.stable == true)] | reverse | .[].version')

  if [[ "${#stable_versions[@]}" -eq 0 ]]; then
    log "Không lấy được danh sách phiên bản Fabric."
    exit 1
  fi

  requested_version="${MINECRAFT_VERSION:-}"
  if [[ -n "${requested_version}" ]]; then
    for v in "${stable_versions[@]}"; do
      if [[ "${v}" == "${requested_version}" ]]; then
        MINECRAFT_VERSION="${requested_version}"
        log "Dùng phiên bản Fabric: ${MINECRAFT_VERSION}"
        return
      fi
    done
    log "MINECRAFT_VERSION=${requested_version} không có sẵn cho Fabric. Chuyển sang menu."
  fi

  select_version_menu "Fabric" "${stable_versions[@]}"
}

resolve_version_forge() {
  local promotions_json
  local -a mc_versions=()
  local requested_version v

  promotions_json="$(curl -fsSL "${FORGE_PROMOTIONS_URL}")"
  mapfile -t mc_versions < <(echo "${promotions_json}" | jq -r '.promos | keys[]' | sed -n 's/-latest$//p' | sort -V | uniq)

  if [[ "${#mc_versions[@]}" -eq 0 ]]; then
    log "Không lấy được danh sách phiên bản Forge."
    exit 1
  fi

  requested_version="${MINECRAFT_VERSION:-}"
  if [[ -n "${requested_version}" ]]; then
    for v in "${mc_versions[@]}"; do
      if [[ "${v}" == "${requested_version}" ]]; then
        MINECRAFT_VERSION="${requested_version}"
        log "Dùng phiên bản Forge cho MC: ${MINECRAFT_VERSION}"
        return
      fi
    done
    log "MINECRAFT_VERSION=${requested_version} không có sẵn cho Forge. Chuyển sang menu."
  fi

  select_version_menu "Forge" "${mc_versions[@]}"
}

resolve_version_mohist() {
  local project_json
  local -a all_versions=()
  local requested_version v

  project_json="$(curl -fsSL "${MOHIST_API_BASE}")"
  mapfile -t all_versions < <(echo "${project_json}" | jq -r '.versions[]' 2>/dev/null || true)

  if [[ "${#all_versions[@]}" -eq 0 ]]; then
    log "Không lấy được danh sách phiên bản Mohist."
    exit 1
  fi

  requested_version="${MINECRAFT_VERSION:-}"
  if [[ -n "${requested_version}" ]]; then
    for v in "${all_versions[@]}"; do
      if [[ "${v}" == "${requested_version}" ]]; then
        MINECRAFT_VERSION="${requested_version}"
        log "Dùng phiên bản Mohist: ${MINECRAFT_VERSION}"
        return
      fi
    done
    log "MINECRAFT_VERSION=${requested_version} không có sẵn cho Mohist. Chuyển sang menu."
  fi

  select_version_menu "Mohist" "${all_versions[@]}"
}

resolve_version_canvas() {
  # Canvas REST API: https://canvasmc.io/api/v2
  local builds_json latest_json
  local -a mc_versions=()
  local requested_version v

  # Lấy danh sách phiên bản MC có sẵn từ tất cả builds thành công
  builds_json="$(curl -fsSL "${CANVAS_API_BASE}/builds" 2>/dev/null || true)"
  if [[ -z "${builds_json}" ]]; then
    log "Không lấy được danh sách build Canvas."
    exit 1
  fi

  mapfile -t mc_versions < <(echo "${builds_json}" | jq -r '
    [.builds // . | .[] | select(.result == "SUCCESS" and .downloadUrl != null) | .channelVersion] | unique | sort_by(split(".") | map(tonumber)) | .[]
  ' 2>/dev/null || true)

  # Fallback: nếu API không trả về danh sách, dùng danh sách cứng
  if [[ "${#mc_versions[@]}" -eq 0 ]]; then
    log "API không trả về danh sách phiên bản, dùng danh sách mặc định."
    mc_versions=("${CANVAS_KNOWN_VERSIONS[@]}")
  fi

  if [[ "${#mc_versions[@]}" -eq 0 ]]; then
    log "Không tìm thấy phiên bản Canvas nào."
    exit 1
  fi

  requested_version="${MINECRAFT_VERSION:-}"
  if [[ -n "${requested_version}" ]]; then
    for v in "${mc_versions[@]}"; do
      if [[ "${v}" == "${requested_version}" ]]; then
        MINECRAFT_VERSION="${requested_version}"
        log "Dùng phiên bản Canvas: ${MINECRAFT_VERSION}"
        # Lấy build mới nhất cho version này
        _canvas_resolve_latest_build
        return
      fi
    done
    log "MINECRAFT_VERSION=${requested_version} không có sẵn cho Canvas. Chuyển sang menu."
  fi

  select_version_menu "Canvas" "${mc_versions[@]}"
  _canvas_resolve_latest_build
}

_canvas_resolve_latest_build() {
  # Lấy build mới nhất cho MINECRAFT_VERSION hiện tại
  local builds_json build_info

  builds_json="$(curl -fsSL "${CANVAS_API_BASE}/builds?minecraft_version=${MINECRAFT_VERSION}" 2>/dev/null || true)"
  build_info="$(echo "${builds_json}" | jq -r '
    [.builds // . | .[] | select(.result == "SUCCESS" and .downloadUrl != null)] | sort_by(.buildNumber) | last
  ' 2>/dev/null || true)"

  if [[ -z "${build_info}" || "${build_info}" == "null" ]]; then
    # Fallback: dùng /builds/latest
    build_info="$(curl -fsSL "${CANVAS_API_BASE}/builds/latest" 2>/dev/null || true)"
  fi

  CANVAS_BUILD_NUMBER="$(echo "${build_info}" | jq -r '.buildNumber // empty' 2>/dev/null || true)"
  CANVAS_DOWNLOAD_URL="$(echo "${build_info}" | jq -r '.downloadUrl // empty' 2>/dev/null || true)"

  if [[ -z "${CANVAS_BUILD_NUMBER}" || -z "${CANVAS_DOWNLOAD_URL}" ]]; then
    log "Không lấy được thông tin build Canvas cho MC ${MINECRAFT_VERSION}."
    exit 1
  fi

  log "Canvas build mới nhất cho MC ${MINECRAFT_VERSION}: #${CANVAS_BUILD_NUMBER}"
}

resolve_version_leaf() {
  local releases_json
  local -a all_versions=()
  local requested_version v

  releases_json="$(curl -fsSL "${LEAF_GITHUB_API}")"
  # Chỉ lấy tag dạng ver-X.Y.Z (bỏ qua tag cũ, purpur-*, date-only, ...)
  mapfile -t all_versions < <(echo "${releases_json}" | jq -r '.[].tag_name' | grep -E '^ver-[0-9]' | sed 's/^ver-//' | sort -V)

  if [[ "${#all_versions[@]}" -eq 0 ]]; then
    log "Không lấy được danh sách phiên bản Leaf."
    exit 1
  fi

  requested_version="${MINECRAFT_VERSION:-}"
  if [[ -n "${requested_version}" ]]; then
    for v in "${all_versions[@]}"; do
      if [[ "${v}" == "${requested_version}" ]]; then
        MINECRAFT_VERSION="${requested_version}"
        log "Dùng phiên bản Leaf: ${MINECRAFT_VERSION}"
        return
      fi
    done
    log "MINECRAFT_VERSION=${requested_version} không có sẵn cho Leaf. Chuyển sang menu."
  fi

  select_version_menu "Leaf" "${all_versions[@]}"
}

resolve_version() {
  case "${PROJECT}" in
    purpur)   resolve_version_purpur; return ;;
    leaf)     resolve_version_leaf; return ;;
    fabric)   resolve_version_fabric; return ;;
    forge)    resolve_version_forge; return ;;
    mohist)   resolve_version_mohist; return ;;
    canvas)   resolve_version_canvas; return ;;
  esac

  local project_json
  local min_version
  local max_version
  local latest_allowed
  local requested_version
  local version_choice
  local default_choice
  local selected_version
  local idx
  local total_menu
  local -a all_versions=()
  local -a allowed_versions=()
  local -a menu_versions=()

  case "${PROJECT}" in
    paper)
      min_version="1.8.8"
      max_version="1.21.11"
      ;;
    folia)
      min_version="1.19.4"
      max_version="1.21.11"
      ;;
    *)
      min_version="1.8.8"
      max_version="1.21.11"
      ;;
  esac

  project_json="$(curl -fsSL "${PAPER_API_BASE}/${PROJECT}")"
  mapfile -t all_versions < <(echo "${project_json}" | jq -r '.versions[]')

  if [[ "${#all_versions[@]}" -eq 0 ]]; then
    log "Không lấy được danh sách phiên bản cho ${PROJECT}."
    exit 1
  fi

  for selected_version in "${all_versions[@]}"; do
    if version_gte "${selected_version}" "${min_version}" \
      && version_gte "${max_version}" "${selected_version}" \
      && ! is_excluded_mc_version "${PROJECT}" "${selected_version}"; then
      allowed_versions+=("${selected_version}")
    fi
  done

  if [[ "${#allowed_versions[@]}" -eq 0 ]]; then
    log "Không có phiên bản ${PROJECT} nào trong khoảng ${min_version} -> ${max_version}."
    exit 1
  fi

  latest_allowed="${allowed_versions[${#allowed_versions[@]}-1]}"

  requested_version="${MINECRAFT_VERSION:-}"
  if [[ -n "${requested_version}" ]]; then
    if version_gte "${requested_version}" "${min_version}" \
      && version_gte "${max_version}" "${requested_version}" \
      && ! is_excluded_mc_version "${PROJECT}" "${requested_version}" \
      && echo "${project_json}" | jq -e --arg v "${requested_version}" '.versions[] | select(. == $v)' >/dev/null; then
      MINECRAFT_VERSION="${requested_version}"
      log "Dùng phiên bản từ MINECRAFT_VERSION: ${MINECRAFT_VERSION}"
      return
    fi

    log "MINECRAFT_VERSION=${requested_version} không hợp lệ cho ${PROJECT} trong khoảng ${min_version} -> ${max_version}."
    log "Chuyển sang menu chọn phiên bản."
  fi

  for ((idx=0; idx<${#allowed_versions[@]}; idx++)); do
    menu_versions+=("${allowed_versions[idx]}")
  done

  total_menu="${#menu_versions[@]}"
  default_choice="${total_menu}"

  echo
  echo -e "${C_TITLE}${C_BOLD}Chọn phiên bản ${PROJECT} (menu số):${C_RESET}"
  echo -e "${C_OPTION}Giới hạn: ${min_version} -> ${max_version} | Mặc định: ${default_choice} = ${latest_allowed}${C_RESET}"
  for idx in "${!menu_versions[@]}"; do
    printf "  %s%3d) %-12s%s" "${C_OPTION}" "$((idx + 1))" "${menu_versions[idx]}" "${C_RESET}"
    if (( (idx + 1) % 3 == 0 )); then
      echo
    fi
  done
  if (( ${#menu_versions[@]} % 3 != 0 )); then
    echo
  fi
  if ! read -r -p "Nhập số lựa chọn [1-${total_menu}, mặc định ${default_choice}]: " version_choice; then
    version_choice="${default_choice}"
  fi
  version_choice="$(echo "${version_choice:-${default_choice}}" | xargs || true)"

  if [[ -z "${version_choice}" ]]; then
    version_choice="${default_choice}"
  fi

  if [[ "${version_choice}" =~ ^[0-9]+$ ]]; then
    if (( version_choice >= 1 && version_choice <= total_menu )); then
      MINECRAFT_VERSION="${menu_versions[version_choice-1]}"
      log "Dùng phiên bản: ${MINECRAFT_VERSION}"
      return
    fi

    log "Lựa chọn số ${version_choice} không hợp lệ. Chuyển sang bản mặc định ${latest_allowed}."
    MINECRAFT_VERSION="${latest_allowed}"
    return
  fi

  # Tương thích ngược: vẫn cho phép nhập trực tiếp version nếu không nhập số.
  if version_gte "${version_choice}" "${min_version}" \
    && version_gte "${max_version}" "${version_choice}" \
    && ! is_excluded_mc_version "${PROJECT}" "${version_choice}" \
    && echo "${project_json}" | jq -e --arg v "${version_choice}" '.versions[] | select(. == $v)' >/dev/null; then
    MINECRAFT_VERSION="${version_choice}"
    log "Dùng phiên bản nhập tay: ${MINECRAFT_VERSION}"
    return
  fi

  log "Lựa chọn không hợp lệ (${version_choice}). Chuyển sang bản mặc định ${latest_allowed}."
  MINECRAFT_VERSION="${latest_allowed}"
}

select_java_for_version() {
  local selected_java

  selected_java="$(map_java_from_minecraft_version "${MINECRAFT_VERSION}")"

  case "${selected_java}" in
    8)
      ensure_java "8"
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
      ensure_java "17"
      ;;
  esac

  export JAVA_VERSION="${selected_java}"
  write_state_value "${STATE_JAVA_VERSION_FILE}" "${JAVA_VERSION}"
  write_state_value "${STATE_MC_VERSION_FILE}" "${MINECRAFT_VERSION}"
  write_last_selected_java "${JAVA_VERSION}"

  log "JAVA_VERSION=${JAVA_VERSION}"
  java -version 2>&1 | head -n 1 | sed 's/^/[INFO] /'
}

select_java_for_existing_jar() {
  local requested="${JAVA_VERSION:-}"
  local last_selected_java=""
  local state_java_version=""
  local state_mc_version=""
  local inferred_mc_version=""
  local inferred_java_from_jar=""
  local server_jar

  server_jar="${SERVER_JARFILE:-server.jar}"

  if [[ -z "${requested}" ]]; then
    inferred_java_from_jar="$(infer_java_from_existing_jar "${server_jar}")"
    if [[ -n "${inferred_java_from_jar}" ]]; then
      requested="${inferred_java_from_jar}"
      log "Suy luận Java từ server.jar -> Java ${requested}."
    fi
  fi

  if [[ -z "${requested}" && -n "${MINECRAFT_VERSION:-}" ]]; then
    requested="$(map_java_from_minecraft_version "${MINECRAFT_VERSION}")"
    log "Dùng Java theo MINECRAFT_VERSION=${MINECRAFT_VERSION} -> Java ${requested}."
  fi

  if [[ -z "${requested}" ]]; then
    if [[ -n "${MINECRAFT_VERSION:-}" ]]; then
      inferred_mc_version="${MINECRAFT_VERSION}"
    else
      state_mc_version="$(read_state_value "${STATE_MC_VERSION_FILE}")"
      if [[ -n "${state_mc_version}" ]]; then
        inferred_mc_version="${state_mc_version}"
      else
        inferred_mc_version="$(infer_minecraft_version_from_logs)"
      fi
    fi

    if [[ -n "${inferred_mc_version}" ]]; then
      requested="$(map_java_from_minecraft_version "${inferred_mc_version}")"
      log "Suy luận Minecraft ${inferred_mc_version} -> Java ${requested}."
      write_state_value "${STATE_MC_VERSION_FILE}" "${inferred_mc_version}"
    fi
  fi

  if [[ -z "${requested}" ]]; then
    last_selected_java="$(read_last_selected_java)"
    if [[ -n "${last_selected_java}" ]]; then
      requested="${last_selected_java}"
      log "Dùng Java theo lastversionselected: ${requested}."
    fi
  fi

  if [[ -z "${requested}" ]]; then
    state_java_version="$(read_state_value "${STATE_JAVA_VERSION_FILE}")"
    if [[ -n "${state_java_version}" ]]; then
      requested="${state_java_version}"
      log "Dùng Java từ state trước đó: ${requested}."
    fi
  fi

  if [[ -z "${requested}" ]]; then
    requested="21"
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
      requested="21"
      ensure_java "21"
      ;;
  esac

  export JAVA_VERSION="${requested}"
  write_state_value "${STATE_JAVA_VERSION_FILE}" "${JAVA_VERSION}"
  write_last_selected_java "${JAVA_VERSION}"
  if [[ -n "${MINECRAFT_VERSION:-}" ]]; then
    write_state_value "${STATE_MC_VERSION_FILE}" "${MINECRAFT_VERSION}"
  fi
  log "JAVA_VERSION=${JAVA_VERSION}"
  java -version 2>&1 | head -n 1 | sed 's/^/[INFO] /'
}

download_server() {
  case "${PROJECT}" in
    purpur)   download_server_purpur; return ;;
    leaf)     download_server_leaf; return ;;
    fabric)   download_server_fabric; return ;;
    forge)    download_server_forge; return ;;
    mohist)   download_server_mohist; return ;;
    canvas)   download_server_canvas; return ;;
  esac

  local builds_json latest_build jar_name download_url server_jar

  builds_json="$(curl -fsSL "${PAPER_API_BASE}/${PROJECT}/versions/${MINECRAFT_VERSION}")"
  latest_build="$(echo "${builds_json}" | jq -r '.builds[-1]')"

  if [[ -z "${latest_build}" || "${latest_build}" == "null" ]]; then
    log "Không tìm thấy bản build cho ${PROJECT} ${MINECRAFT_VERSION}."
    exit 1
  fi

  jar_name="${PROJECT}-${MINECRAFT_VERSION}-${latest_build}.jar"
  download_url="${PAPER_API_BASE}/${PROJECT}/versions/${MINECRAFT_VERSION}/builds/${latest_build}/downloads/${jar_name}"
  server_jar="${SERVER_JARFILE:-server.jar}"

  if [[ -f "${server_jar}" ]]; then
    log "Đã phát hiện ${server_jar}, bỏ qua bước tải server mới."
    return
  fi

  log "Đang tải ${jar_name}"
  curl -fsSL -o "${server_jar}" "${download_url}"
  log "Đã tải xong -> ${server_jar}"
}

download_server_purpur() {
  local builds_json latest_build download_url server_jar

  builds_json="$(curl -fsSL "${PURPUR_API_BASE}/purpur/${MINECRAFT_VERSION}")"
  latest_build="$(echo "${builds_json}" | jq -r '.builds.latest')"

  if [[ -z "${latest_build}" || "${latest_build}" == "null" ]]; then
    log "Không tìm thấy bản build Purpur cho ${MINECRAFT_VERSION}."
    exit 1
  fi

  download_url="${PURPUR_API_BASE}/purpur/${MINECRAFT_VERSION}/${latest_build}/download"
  server_jar="${SERVER_JARFILE:-server.jar}"

  if [[ -f "${server_jar}" ]]; then
    log "Đã phát hiện ${server_jar}, bỏ qua bước tải."
    return
  fi

  log "Đang tải Purpur ${MINECRAFT_VERSION} (build ${latest_build})..."
  curl -fsSL -o "${server_jar}" "${download_url}"
  log "Đã tải xong -> ${server_jar}"
}

download_server_fabric() {
  local loader_version installer_version download_url server_jar

  loader_version="$(curl -fsSL "${FABRIC_META_API}/versions/loader" | jq -r '[.[] | select(.stable == true)][0].version')"
  installer_version="$(curl -fsSL "${FABRIC_META_API}/versions/installer" | jq -r '[.[] | select(.stable == true)][0].version')"

  if [[ -z "${loader_version}" || "${loader_version}" == "null" ]]; then
    log "Không lấy được phiên bản Fabric Loader."
    exit 1
  fi
  if [[ -z "${installer_version}" || "${installer_version}" == "null" ]]; then
    log "Không lấy được phiên bản Fabric Installer."
    exit 1
  fi

  download_url="${FABRIC_META_API}/versions/loader/${MINECRAFT_VERSION}/${loader_version}/${installer_version}/server/jar"
  server_jar="${SERVER_JARFILE:-server.jar}"

  if [[ -f "${server_jar}" ]]; then
    log "Đã phát hiện ${server_jar}, bỏ qua bước tải."
    return
  fi

  log "Đang tải Fabric Server (MC ${MINECRAFT_VERSION}, Loader ${loader_version})..."
  curl -fsSL -o "${server_jar}" "${download_url}"
  log "Đã tải xong -> ${server_jar}"
}

download_server_forge() {
  local promotions_json forge_version installer_jar installer_url server_jar forge_jar

  promotions_json="$(curl -fsSL "${FORGE_PROMOTIONS_URL}")"
  # Ưu tiên bản recommended, nếu không có thì dùng latest
  forge_version="$(echo "${promotions_json}" | jq -r --arg v "${MINECRAFT_VERSION}-recommended" '.promos[$v] // empty')"
  if [[ -z "${forge_version}" ]]; then
    forge_version="$(echo "${promotions_json}" | jq -r --arg v "${MINECRAFT_VERSION}-latest" '.promos[$v] // empty')"
  fi

  if [[ -z "${forge_version}" ]]; then
    log "Không tìm thấy phiên bản Forge cho MC ${MINECRAFT_VERSION}."
    exit 1
  fi

  # Nếu đã cài Forge trước đó thì bỏ qua
  if [[ -f "run.sh" ]] || compgen -G "forge-*.jar" >/dev/null 2>&1; then
    log "Đã phát hiện Forge cài sẵn, bỏ qua bước tải."
    return
  fi

  installer_jar="forge-${MINECRAFT_VERSION}-${forge_version}-installer.jar"
  installer_url="${FORGE_MAVEN_BASE}/${MINECRAFT_VERSION}-${forge_version}/${installer_jar}"

  log "Đang tải Forge ${MINECRAFT_VERSION}-${forge_version}..."
  curl -fsSL -o "${installer_jar}" "${installer_url}"

  log "Đang cài đặt Forge server (có thể mất vài phút)..."
  java -jar "${installer_jar}" --installServer

  rm -f "${installer_jar}" "${installer_jar}.log"

  # Forge modern (1.17+): installer tạo run.sh
  if [[ -f "run.sh" ]]; then
    chmod +x run.sh
    log "Forge đã cài đặt xong (run.sh mode)."
  else
    # Forge legacy: tìm forge jar và copy thành server.jar
    server_jar="${SERVER_JARFILE:-server.jar}"
    forge_jar="$(find . -maxdepth 1 -name 'forge-*.jar' ! -name '*installer*' -print -quit 2>/dev/null || true)"
    if [[ -n "${forge_jar}" && "${forge_jar}" != "./${server_jar}" ]]; then
      cp "${forge_jar}" "${server_jar}"
    fi
    log "Forge đã cài đặt xong."
  fi
}

download_server_mohist() {
  local builds_json download_url server_jar

  builds_json="$(curl -fsSL "${MOHIST_API_BASE}/${MINECRAFT_VERSION}/builds")"
  download_url="$(echo "${builds_json}" | jq -r '
    if type == "array" then .[-1].url // .[-1].download_url // empty
    elif .builds then .builds[-1].url // .builds[-1].download_url // empty
    else empty
    end
  ' 2>/dev/null || true)"

  if [[ -z "${download_url}" || "${download_url}" == "null" ]]; then
    log "Không tìm thấy bản build Mohist cho MC ${MINECRAFT_VERSION}."
    exit 1
  fi

  server_jar="${SERVER_JARFILE:-server.jar}"

  if [[ -f "${server_jar}" ]]; then
    log "Đã phát hiện ${server_jar}, bỏ qua bước tải."
    return
  fi

  log "Đang tải Mohist ${MINECRAFT_VERSION}..."
  curl -fsSL -o "${server_jar}" "${download_url}"
  log "Đã tải xong -> ${server_jar}"
}

download_server_canvas() {
  local download_url server_jar build_number

  download_url="${CANVAS_DOWNLOAD_URL:-}"
  build_number="${CANVAS_BUILD_NUMBER:-}"

  # Fallback nếu chưa có URL (chạy lại từ server có sẵn)
  if [[ -z "${download_url}" ]]; then
    local latest_json
    latest_json="$(curl -fsSL "${CANVAS_API_BASE}/builds/latest" 2>/dev/null || true)"
    download_url="$(echo "${latest_json}" | jq -r '.downloadUrl // empty' 2>/dev/null || true)"
    build_number="$(echo "${latest_json}" | jq -r '.buildNumber // empty' 2>/dev/null || true)"
  fi

  if [[ -z "${download_url}" || "${download_url}" == "null" ]]; then
    log "Không lấy được link tải Canvas."
    exit 1
  fi

  server_jar="${SERVER_JARFILE:-server.jar}"

  if [[ -f "${server_jar}" ]]; then
    log "Đã phát hiện ${server_jar}, bỏ qua bước tải."
    return
  fi

  log "Đang tải Canvas (build #${build_number})..."
  curl -fsSL -o "${server_jar}" "${download_url}"
  log "Đã tải xong -> ${server_jar}"
}

download_server_leaf() {
  local releases_json download_url server_jar tag_name

  tag_name="ver-${MINECRAFT_VERSION}"
  releases_json="$(curl -fsSL "${LEAF_GITHUB_API}")"
  # Ưu tiên lấy file .jar không phải mojmap/reobf, nếu không có thì lấy mojmap
  download_url="$(echo "${releases_json}" | jq -r --arg tag "${tag_name}" '
    .[] | select(.tag_name == $tag) | .assets[]
    | select(.name | endswith(".jar"))
    | select(.name | test("reobf|sources") | not)
    | .browser_download_url
  ' | head -n 1)"

  if [[ -z "${download_url}" || "${download_url}" == "null" ]]; then
    log "Không tìm thấy file tải Leaf cho phiên bản ${MINECRAFT_VERSION}."
    exit 1
  fi

  server_jar="${SERVER_JARFILE:-server.jar}"

  if [[ -f "${server_jar}" ]]; then
    log "Đã phát hiện ${server_jar}, bỏ qua bước tải."
    return
  fi

  log "Đang tải Leaf ${MINECRAFT_VERSION}..."
  curl -fsSL -L -o "${server_jar}" "${download_url}"
  log "Đã tải xong -> ${server_jar}"
}

prepare_files() {
  if [[ ! -f eula.txt ]]; then
    echo "eula=true" > eula.txt
  fi

  # Forge cần file user_jvm_args.txt
  if { [[ "${PROJECT:-}" == "forge" ]] || { [[ -f "run.sh" ]] && [[ -d "libraries" ]]; }; } && [[ ! -f "user_jvm_args.txt" ]]; then
    echo "# Forge JVM Arguments - thêm các tham số JVM tùy chỉnh ở đây" > user_jvm_args.txt
  fi

  touch server.properties
  if ! grep -q '^motd=' server.properties; then
    echo "motd=STACloud | Bạn có thể đổi MOTD trong server.properties" >> server.properties
  fi
  if ! grep -q '^view-distance=' server.properties; then
    echo "view-distance=6" >> server.properties
  fi
}

launch_server() {
  local server_jar
  local java_args
  local resolved_java_args

  server_jar="${SERVER_JARFILE:-server.jar}"
  java_args="${JAVA_ARGUMENTS:-}"

  # Forge modern (1.17+): sử dụng run.sh do installer tạo ra
  # Phát hiện cả khi PROJECT chưa được set (restart scenario)
  if [[ -f "run.sh" ]] && { [[ "${PROJECT:-}" == "forge" ]] || [[ -f "user_jvm_args.txt" ]] || [[ -d "libraries" ]]; }; then
    log "Khởi chạy Forge server qua run.sh..."
    exec bash run.sh
  fi

  if [[ -z "${java_args}" ]]; then
    java_args="-jar ${server_jar}"
  fi

  resolved_java_args="$(eval echo "${java_args}")"
  log "Lệnh khởi chạy: java ${resolved_java_args}"

  # shellcheck disable=SC2086
  exec java ${resolved_java_args}
}

main() {
  local server_jar

  server_jar="${SERVER_JARFILE:-server.jar}"

  # Forge modern (1.17+): run.sh + dấu hiệu Forge (user_jvm_args.txt hoặc libraries/)
  # Ưu tiên trước server.jar vì có thể tồn tại server.jar cũ từ phần mềm khác
  if [[ -f "run.sh" ]] && { [[ -f "user_jvm_args.txt" ]] || [[ -d "libraries" ]]; }; then
    log "Đã phát hiện Forge server (run.sh), chạy thẳng."
    select_java_for_existing_jar
    prepare_files
    log "Khởi chạy Forge server qua run.sh..."
    exec bash run.sh
  fi

  # Forge legacy: có forge-*.jar nhưng không có server.jar → copy rồi chạy
  if [[ ! -f "${server_jar}" ]]; then
    local forge_jar_legacy
    forge_jar_legacy="$(find . -maxdepth 1 -name 'forge-*.jar' ! -name '*installer*' -print -quit 2>/dev/null || true)"
    if [[ -n "${forge_jar_legacy}" ]]; then
      log "Đã phát hiện Forge legacy (${forge_jar_legacy}), copy thành ${server_jar}."
      cp "${forge_jar_legacy}" "${server_jar}"
    fi
  fi

  if [[ -f "${server_jar}" ]]; then
    log "Đã phát hiện ${server_jar}, chạy thẳng server hiện có."
    select_java_for_existing_jar
    prepare_files
    launch_server
    return
  fi

  select_project
  resolve_version
  select_java_for_version
  download_server
  prepare_files
  launch_server
}

main "$@"
