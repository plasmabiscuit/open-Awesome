#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CACHE_DIR="${REPO_ROOT}/.cache"
FINGERPRINT_FILE="${CACHE_DIR}/preflight.fingerprint"

PREFLIGHT_DRY_RUN=${PREFLIGHT_DRY_RUN:-0}
REQUIRED_ENV=(OPENWEBUI_CONTAINER OPENWEBUI_STACK_FILE)

TOOL_DEPENDENCIES=(docker rsync)

# shellcheck disable=SC2086
usage() {
  cat <<'USAGE'
Usage: scripts/preflight.sh [--dry-run]

Validates environment, ensures required tooling exists, applies any overlays
from openwebui-custom/Replace into the running Open WebUI container, and
restarts the service when configuration fingerprints change.

Options:
  --dry-run   Skip Docker mutations (overlay copy and restarts) but still run
             validations and fingerprinting logic.
USAGE
}

info() { printf '[preflight] %s\n' "$*"; }
error() { printf '[preflight][error] %s\n' "$*" >&2; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        PREFLIGHT_DRY_RUN=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

require_env() {
  local missing=0
  for var in "${REQUIRED_ENV[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      error "Required environment variable '${var}' is not set."
      missing=1
    fi
  done

  if [[ ${missing} -ne 0 ]]; then
    error "Set the required variables and re-run."
    exit 1
  fi
}

install_tooling() {
  local missing_tools=()
  for tool in "${TOOL_DEPENDENCIES[@]}"; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      missing_tools+=("${tool}")
    fi
  done

  if [[ ${#missing_tools[@]} -eq 0 ]]; then
    info "All required tools present: ${TOOL_DEPENDENCIES[*]}"
    return
  fi

  info "Attempting to install missing tools: ${missing_tools[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    local apt_cmd=(apt-get -y install)
    if command -v sudo >/dev/null 2>&1 && [[ $(id -u) -ne 0 ]]; then
      apt_cmd=(sudo "${apt_cmd[@]}")
      sudo apt-get update -y
    else
      apt-get update -y
    fi

    "${apt_cmd[@]}" "${missing_tools[@]}" || {
      error "Failed to install required tools: ${missing_tools[*]}"
      exit 1
    }
  else
    error "Automatic installation unavailable. Please install: ${missing_tools[*]}"
    exit 1
  fi
}

fingerprint_inputs() {
  local overlay_dir="$1"
  local stack_file="$2"
  local digest_file
  digest_file=$(mktemp)

  if [[ -d "${overlay_dir}" ]]; then
    (cd "${overlay_dir}" && find . -type f -print0 | sort -z | xargs -0 sha256sum || true) >>"${digest_file}"
  fi

  if [[ -f "${stack_file}" ]]; then
    sha256sum "${stack_file}" >>"${digest_file}"
  fi

  sha256sum "${digest_file}" | cut -d ' ' -f1
}

container_running() {
  local container="$1"
  docker inspect "${container}" >/dev/null 2>&1
}

apply_overlays() {
  local overlay_dir="$1"
  local container="$2"
  local target="$3"

  if [[ ! -d "${overlay_dir}" ]]; then
    info "Overlay directory not found at ${overlay_dir}; skipping overlay copy."
    return 1
  fi

  if [[ -z $(find "${overlay_dir}" -type f -print -quit) ]]; then
    info "No overlay files found in ${overlay_dir}; nothing to apply."
    return 1
  fi

  if [[ ${PREFLIGHT_DRY_RUN} -eq 1 ]]; then
    info "Dry-run enabled; would copy overlays from ${overlay_dir} to ${container}:${target}"
    return 0
  fi

  info "Copying overlays from ${overlay_dir} into ${container}:${target}"
  docker cp "${overlay_dir}/." "${container}:${target}"
}

restart_service() {
  local stack_file="$1"
  local service="$2"
  local container="$3"

  if [[ ${PREFLIGHT_DRY_RUN} -eq 1 ]]; then
    info "Dry-run enabled; would restart service '${service}' or container '${container}'."
    return 0
  fi

  if [[ -f "${stack_file}" && -s "${stack_file}" ]]; then
    info "Restarting service ${service} via docker compose."
    docker compose -f "${stack_file}" up -d --no-deps "${service}"
  else
    info "Restarting container ${container}."
    docker restart "${container}"
  fi
}

main() {
  parse_args "$@"
  mkdir -p "${CACHE_DIR}"
  require_env
  install_tooling

  local overlay_root overlay_dir stack_file container target service
  overlay_root="${OPENWEBUI_OVERLAY_ROOT:-${REPO_ROOT}/openwebui-custom}"
  overlay_dir="${overlay_root}/Replace"
  stack_file="${OPENWEBUI_STACK_FILE}"
  container="${OPENWEBUI_CONTAINER}"
  target="${OPENWEBUI_OVERLAY_TARGET:-/}"
  service="${OPENWEBUI_SERVICE:-${container}}"

  local current_fingerprint previous_fingerprint
  current_fingerprint=$(fingerprint_inputs "${overlay_dir}" "${stack_file}")
  previous_fingerprint=$(cat "${FINGERPRINT_FILE}" 2>/dev/null || true)

  info "Overlay root: ${overlay_root}"
  info "Stack file: ${stack_file}"
  info "Docker container: ${container}"
  if [[ ${PREFLIGHT_DRY_RUN} -eq 1 ]]; then
    info "Running in dry-run mode; Docker changes will be skipped."
  fi

  if [[ ${PREFLIGHT_DRY_RUN} -eq 0 ]] && ! container_running "${container}"; then
    error "Docker container '${container}' is not available. Start it or set PREFLIGHT_DRY_RUN=1."
    exit 1
  fi

  local overlays_applied=0
  apply_overlays "${overlay_dir}" "${container}" "${target}" && overlays_applied=1 || overlays_applied=0

  if [[ "${current_fingerprint}" != "${previous_fingerprint}" ]]; then
    info "Detected configuration change (fingerprint mismatch)."
    restart_service "${stack_file}" "${service}" "${container}"
  elif [[ ${overlays_applied} -eq 1 ]]; then
    info "Overlays applied with unchanged fingerprint; restarting to ensure updates take effect."
    restart_service "${stack_file}" "${service}" "${container}"
  else
    info "No changes detected; skipping restart."
  fi

  echo "${current_fingerprint}" >"${FINGERPRINT_FILE}"
  info "Preflight completed."
}

main "$@"
