#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_DIR="${ROOT_DIR}/ci-reports"
REPORT_FILE="${REPORT_DIR}/cocoapods-lint-report.md"

cd "${ROOT_DIR}"
mkdir -p "${REPORT_DIR}"

FINAL_VALIDATED_PLATFORMS=""
WATCH_AVAILABLE="no"
TV_AVAILABLE="no"
RETRY_NOTES=""

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
  WATCH_AVAILABLE="yes"
else
  echo "watchOS simulator not available, skipping watchOS lint"
fi

if command -v xcrun >/dev/null 2>&1 && xcrun simctl list devices available | grep -q "Apple TV"; then
  PLATFORMS="${PLATFORMS},tvos"
  TV_AVAILABLE="yes"
else
  echo "tvOS simulator not available, skipping tvOS lint"
fi

echo "Lint platforms: ${PLATFORMS}"

write_report() {
  local exit_code="$1"
  local status="success"
  if [[ "${exit_code}" -ne 0 ]]; then
    status="failed"
  fi
  local swift_version
  swift_version="$(swift --version 2>/dev/null | head -n 1)"
  local xcode_version
  xcode_version="$(xcodebuild -version 2>/dev/null | paste -sd ' | ' -)"
  local host_arch
  host_arch="$(uname -m)"
  local lint_platforms
  lint_platforms="${FINAL_VALIDATED_PLATFORMS:-<none>}"
  local retry_notes
  retry_notes="${RETRY_NOTES:-<none>}"

  cat > "${REPORT_FILE}" <<EOF
# CocoaPods Lint Report

- Status: ${status}
- Podspec: ${PODSPEC_FILE}
- Host Architecture: ${host_arch}
- Requested Platforms: ${PLATFORMS}
- Final Validated Platforms: ${lint_platforms}
- watchOS Simulator Available: ${WATCH_AVAILABLE}
- tvOS Simulator Available: ${TV_AVAILABLE}
- Retry Notes: ${retry_notes}
- Swift: ${swift_version}
- Xcode: ${xcode_version}
EOF

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat "${REPORT_FILE}" >> "${GITHUB_STEP_SUMMARY}"
    echo "" >> "${GITHUB_STEP_SUMMARY}"
    echo "> Full report file: \`ci-reports/cocoapods-lint-report.md\`" >> "${GITHUB_STEP_SUMMARY}"
  fi
}

on_exit() {
  local exit_code="$1"
  write_report "${exit_code}"
}

trap 'on_exit $?' EXIT

run_lint() {
  local platforms="$1"
  shift
  local extra_args=("$@")
  local log_file
  log_file="$(mktemp -t pod-lint-log.XXXXXX)"

  set +e
  if ((${#extra_args[@]})); then
    pod lib lint "${PODSPEC_FILE}" \
      --verbose \
      --platforms="${platforms}" \
      --allow-warnings \
      "${extra_args[@]}" 2>&1 | tee "${log_file}"
  else
    pod lib lint "${PODSPEC_FILE}" \
      --verbose \
      --platforms="${platforms}" \
      --allow-warnings 2>&1 | tee "${log_file}"
  fi
  local exit_code=${PIPESTATUS[0]}
  set -e

  if [[ ${exit_code} -eq 0 ]]; then
    FINAL_VALIDATED_PLATFORMS="${platforms}"
    echo "Validated platforms: ${platforms}"
    rm -f "${log_file}"
    return 0
  fi

  if [[ "${platforms}" == *"tvos"* ]] && grep -q "\[tvOS\].*Unable to find a destination matching the provided destination specifier" "${log_file}"; then
    local retry_platforms="${platforms//,tvos/}"
    echo "tvOS destination unavailable, retrying without tvOS: ${retry_platforms}"
    RETRY_NOTES="${RETRY_NOTES} dropped tvOS;"
    rm -f "${log_file}"
    if ((${#extra_args[@]})); then
      run_lint "${retry_platforms}" "${extra_args[@]}"
    else
      run_lint "${retry_platforms}"
    fi
    return $?
  fi

  if [[ "${platforms}" == *"watchos"* ]] && grep -q "\[watchOS\].*Found no destinations for the scheme 'App'" "${log_file}"; then
    local retry_platforms="${platforms//,watchos/}"
    echo "watchOS destination unavailable, retrying without watchOS: ${retry_platforms}"
    RETRY_NOTES="${RETRY_NOTES} dropped watchOS;"
    rm -f "${log_file}"
    if ((${#extra_args[@]})); then
      run_lint "${retry_platforms}" "${extra_args[@]}"
    else
      run_lint "${retry_platforms}"
    fi
    return $?
  fi

  rm -f "${log_file}"
  return ${exit_code}
}

run_lint "${PLATFORMS}" "$@"
