#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

PODSPEC_FILE=""
if [[ "${1:-}" == *.podspec ]]; then
  PODSPEC_FILE="$1"
  shift
elif [[ -f "HMLoggerKit.podspec" ]]; then
  PODSPEC_FILE="HMLoggerKit.podspec"
else
  PODSPEC_FILE="$(find . -maxdepth 1 -name "*.podspec" | head -n 1 | sed 's|^\./||')"
fi

if [[ -z "${PODSPEC_FILE}" || ! -f "${PODSPEC_FILE}" ]]; then
  echo "No podspec found in ${ROOT_DIR}" >&2
  exit 1
fi

PLATFORMS="ios,osx"

if command -v xcrun >/dev/null 2>&1 && xcrun simctl list devices available | grep -q "Apple Watch"; then
  PLATFORMS="${PLATFORMS},watchos"
else
  echo "watchOS simulator not available, skipping watchOS lint"
fi

if command -v xcrun >/dev/null 2>&1 && xcrun simctl list devices available | grep -q "Apple TV"; then
  PLATFORMS="${PLATFORMS},tvos"
else
  echo "tvOS simulator not available, skipping tvOS lint"
fi

echo "Lint platforms: ${PLATFORMS}"

run_lint() {
  local platforms="$1"
  shift
  local extra_args=("$@")
  local log_file
  log_file="$(mktemp -t pod-lint-log.XXXXXX)"

  set +e
  pod lib lint "${PODSPEC_FILE}" \
    --verbose \
    --platforms="${platforms}" \
    --allow-warnings \
    "${extra_args[@]}" 2>&1 | tee "${log_file}"
  local exit_code=${PIPESTATUS[0]}
  set -e

  if [[ ${exit_code} -eq 0 ]]; then
    echo "Validated platforms: ${platforms}"
    rm -f "${log_file}"
    return 0
  fi

  if [[ "${platforms}" == *"tvos"* ]] && grep -q "\[tvOS\].*Unable to find a destination matching the provided destination specifier" "${log_file}"; then
    local retry_platforms="${platforms//,tvos/}"
    echo "tvOS destination unavailable, retrying without tvOS: ${retry_platforms}"
    rm -f "${log_file}"
    run_lint "${retry_platforms}" "${extra_args[@]}"
    return $?
  fi

  if [[ "${platforms}" == *"watchos"* ]] && grep -q "\[watchOS\].*Found no destinations for the scheme 'App'" "${log_file}"; then
    local retry_platforms="${platforms//,watchos/}"
    echo "watchOS destination unavailable, retrying without watchOS: ${retry_platforms}"
    rm -f "${log_file}"
    run_lint "${retry_platforms}" "${extra_args[@]}"
    return $?
  fi

  rm -f "${log_file}"
  return ${exit_code}
}

run_lint "${PLATFORMS}" "$@"
