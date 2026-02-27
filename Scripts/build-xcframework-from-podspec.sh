#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "${cmd} not found." >&2
    exit 1
  fi
}

usage() {
  cat <<'USAGE'
Usage:
  sh Scripts/build-xcframework-from-podspec.sh [podspec] [options]

Options:
  --podspec <file>          Podspec path (default: auto-detect)
  --platforms <list>        Comma separated: ios,macos,tvos,watchos
                            (default: ios,macos,tvos,watchos)
  --configuration <name>    Build configuration (default: Release)
  --output <dir>            Output directory (default: ./gen/<pod>/Build)
  --keep-temp               Keep intermediate generated/archive directories
  --no-debug-symbols        Do not include dSYM when creating xcframework
  -h, --help                Show this help
USAGE
}

PODSPEC_FILE=""
PLATFORMS="ios,macos,tvos,watchos"
CONFIGURATION="Release"
OUTPUT_DIR_OVERRIDE=""
KEEP_TEMP_ARTIFACTS=0
INCLUDE_DEBUG_SYMBOLS=1

if [[ "${1:-}" == *.podspec && "${1:-}" != --* ]]; then
  PODSPEC_FILE="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --podspec)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Missing value for --podspec" >&2
        usage
        exit 1
      fi
      PODSPEC_FILE="$2"
      shift 2
      ;;
    --platforms)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Missing value for --platforms" >&2
        usage
        exit 1
      fi
      PLATFORMS="$2"
      shift 2
      ;;
    --configuration)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Missing value for --configuration" >&2
        usage
        exit 1
      fi
      CONFIGURATION="$2"
      shift 2
      ;;
    --output)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Missing value for --output" >&2
        usage
        exit 1
      fi
      OUTPUT_DIR_OVERRIDE="$2"
      shift 2
      ;;
    --keep-temp)
      KEEP_TEMP_ARTIFACTS=1
      shift
      ;;
    --no-debug-symbols)
      INCLUDE_DEBUG_SYMBOLS=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${PODSPEC_FILE}" ]]; then
  if [[ -f "HMLoggerKit.podspec" ]]; then
    PODSPEC_FILE="HMLoggerKit.podspec"
  else
    shopt -s nullglob
    podspec_files=("./"*.podspec)
    shopt -u nullglob

    if [[ "${#podspec_files[@]}" -eq 1 ]]; then
      PODSPEC_FILE="${podspec_files[0]#./}"
    elif [[ "${#podspec_files[@]}" -eq 0 ]]; then
      echo "No podspec found in ${ROOT_DIR}" >&2
      exit 1
    else
      echo "Multiple podspec files found. Please specify one with --podspec:" >&2
      printf '  %s\n' "${podspec_files[@]#./}" >&2
      exit 1
    fi
  fi
fi

if [[ ! -f "${PODSPEC_FILE}" ]]; then
  echo "Podspec not found: ${PODSPEC_FILE}" >&2
  exit 1
fi

if [[ ! -f "Gemfile" ]]; then
  echo "Gemfile not found in ${ROOT_DIR}. Please run this script with Bundler-managed CocoaPods." >&2
  exit 1
fi

require_cmd bundle
require_cmd ruby
require_cmd xcodebuild
require_cmd tee
require_cmd tail
require_cmd date
require_cmd tr
require_cmd xargs
require_cmd grep
require_cmd sed

POD_CMD=(bundle exec pod)

if ! "${POD_CMD[@]}" --version >/dev/null 2>&1; then
  echo "bundle exec pod not available. Please run bundle install first." >&2
  exit 1
fi

if ! "${POD_CMD[@]}" plugins installed | grep -q "cocoapods-generate"; then
  echo "cocoapods-generate not found in current Bundler environment. Please add it to Gemfile and run bundle install." >&2
  exit 1
fi

POD_NAME="$(basename "${PODSPEC_FILE}" .podspec)"
GEN_PROJECT_DIR="./gen/${POD_NAME}"
BUILD_OUTPUT_DIR="${GEN_PROJECT_DIR}/Build"
TEMP_GEN_ROOT="${GEN_PROJECT_DIR}/.xcframework-gen"
TEMP_ARCHIVE_ROOT="${GEN_PROJECT_DIR}/.archives"
LOG_DIR="${GEN_PROJECT_DIR}/logs"
RUN_TS="$(date +%Y%m%dT%H%M%S%z)"
GIT_SHORT_SHA="$(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || true)"
LOG_SHA_SUFFIX=""
if [[ -n "${GIT_SHORT_SHA}" ]]; then
  LOG_SHA_SUFFIX="-g${GIT_SHORT_SHA}"
fi
RUN_LOG="${LOG_DIR}/${RUN_TS}-xcfw-podspec-${POD_NAME}${LOG_SHA_SUFFIX}.log"

SPEC_JSON="$("${POD_CMD[@]}" ipc spec "${PODSPEC_FILE}")"
MODULE_NAME="$(printf '%s' "${SPEC_JSON}" | ruby -rjson -e 'j = JSON.parse(STDIN.read); m = j["module_name"]; n = j["name"]; puts((m && !m.empty?) ? m : n.to_s)')"

if [[ -z "${MODULE_NAME}" ]]; then
  echo "Failed to resolve module_name/name from ${PODSPEC_FILE}" >&2
  exit 1
fi

if [[ -n "${OUTPUT_DIR_OVERRIDE}" ]]; then
  BUILD_OUTPUT_DIR="${OUTPUT_DIR_OVERRIDE}"
fi

rm -rf "${BUILD_OUTPUT_DIR}" "${TEMP_GEN_ROOT}" "${TEMP_ARCHIVE_ROOT}"
mkdir -p "${BUILD_OUTPUT_DIR}" "${TEMP_GEN_ROOT}" "${TEMP_ARCHIVE_ROOT}" "${LOG_DIR}"
: > "${RUN_LOG}"

run_logged() {
  echo ">>> $*" | tee -a "${RUN_LOG}"
  "$@" 2>&1 | tee -a "${RUN_LOG}"
  local rc=${PIPESTATUS[0]}
  if [[ "${rc}" -ne 0 ]]; then
    echo "Command failed (exit=${rc}). Log: ${RUN_LOG}" >&2
    echo "Last 40 log lines:" >&2
    tail -n 40 "${RUN_LOG}" >&2 || true
    exit "${rc}"
  fi
}

cleanup() {
  if [[ "${KEEP_TEMP_ARTIFACTS}" != "1" ]]; then
    rm -rf "${TEMP_GEN_ROOT}" "${TEMP_ARCHIVE_ROOT}"
  fi
}
trap cleanup EXIT

log_build_env() {
  {
    echo "== Build Metadata =="
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S %z')"
    echo "Root: ${ROOT_DIR}"
    echo "Podspec: ${PODSPEC_FILE}"
    echo "Pod name: ${POD_NAME}"
    echo "Module name: ${MODULE_NAME}"
    echo "Platforms: ${PLATFORMS}"
    echo "Configuration: ${CONFIGURATION}"
    echo "Output: ${BUILD_OUTPUT_DIR}"
    echo "Keep temp: ${KEEP_TEMP_ARTIFACTS}"
    echo "Include debug symbols: ${INCLUDE_DEBUG_SYMBOLS}"
    if [[ -n "${GIT_SHORT_SHA}" ]]; then
      echo "Git short sha: ${GIT_SHORT_SHA}"
    fi
    echo "Xcode: $(xcodebuild -version | tr '\n' ' ' | sed 's/  */ /g')"
    echo "Ruby: $(ruby --version)"
    echo "CocoaPods: $("${POD_CMD[@]}" --version)"
    echo
  } | tee -a "${RUN_LOG}"
}

archive_for_destination() {
  local label="$1"
  local destination="$2"
  local scheme="$3"
  local archive_path="${TEMP_ARCHIVE_ROOT}/${label}"

  run_logged xcodebuild \
    -workspace "${TEMP_GEN_ROOT}/${POD_NAME}/${POD_NAME}.xcworkspace" \
    -scheme "${scheme}" \
    -configuration "${CONFIGURATION}" \
    -destination "${destination}" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY= \
    SUPPORTS_MACCATALYST=NO \
    archive \
    VALIDATE_WORKSPACE=NO \
    -archivePath "${archive_path}" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES
}

AVAILABLE_SCHEMES=()

load_available_schemes() {
  mapfile -t AVAILABLE_SCHEMES < <(
    xcodebuild -list -json \
      -workspace "${TEMP_GEN_ROOT}/${POD_NAME}/${POD_NAME}.xcworkspace" \
      | ruby -rjson -e 'j = JSON.parse(STDIN.read); puts((j.dig("workspace", "schemes") || []))'
  )
}

scheme_exists() {
  local candidate="$1"
  local scheme=""
  for scheme in "${AVAILABLE_SCHEMES[@]}"; do
    if [[ "${scheme}" == "${candidate}" ]]; then
      return 0
    fi
  done
  return 1
}

resolve_workspace_scheme() {
  local platform_suffix="$1"
  local scheme=""
  local -a preferred_candidates=()

  preferred_candidates=(
    "${POD_NAME}-${platform_suffix}"
    "${MODULE_NAME}-${platform_suffix}"
    "${POD_NAME}"
    "${MODULE_NAME}"
  )

  for scheme in "${preferred_candidates[@]}"; do
    if scheme_exists "${scheme}"; then
      printf '%s\n' "${scheme}"
      return 0
    fi
  done

  for scheme in "${AVAILABLE_SCHEMES[@]}"; do
    if [[ "${scheme}" == "${POD_NAME}-${platform_suffix}"* ]]; then
      printf '%s\n' "${scheme}"
      return 0
    fi
  done

  echo "Failed to resolve a build scheme for platform ${platform_suffix}." >&2
  echo "Available schemes:" >&2
  printf '  %s\n' "${AVAILABLE_SCHEMES[@]}" >&2
  exit 1
}

find_framework_dsym() {
  local archive_path="$1"
  local dsym_path="${archive_path}/dSYMs/${MODULE_NAME}.framework.dSYM"
  local dwarf_binary="${dsym_path}/Contents/Resources/DWARF/${MODULE_NAME}"
  local abs_path=""

  if [[ -d "${dsym_path}" && -f "${dwarf_binary}" ]]; then
    abs_path="$(cd "$(dirname "${dsym_path}")" && pwd)/$(basename "${dsym_path}")"
    printf '%s\n' "${abs_path}"
  fi
}

declare -A PLATFORM_DESTINATIONS
PLATFORM_DESTINATIONS[ios]=$'ios-device|generic/platform=iOS|iOS\nios-simulator|generic/platform=iOS Simulator|iOS'
PLATFORM_DESTINATIONS[macos]=$'macos-device|generic/platform=macOS|macOS'
PLATFORM_DESTINATIONS[tvos]=$'tvos-device|generic/platform=tvOS|tvOS\ntvos-simulator|generic/platform=tvOS Simulator|tvOS'
PLATFORM_DESTINATIONS[watchos]=$'watchos-device|generic/platform=watchOS|watchOS\nwatchos-simulator|generic/platform=watchOS Simulator|watchOS'

log_build_env

echo "Generating workspace once with cocoapods-generate..." | tee -a "${RUN_LOG}"
run_logged "${POD_CMD[@]}" gen "${PODSPEC_FILE}" \
  --gen-directory="${TEMP_GEN_ROOT}" \
  --share-schemes-for-development-pods \
  --sources=https://github.com/CocoaPods/Specs.git \
  --use-modular-headers

if [[ ! -f "${TEMP_GEN_ROOT}/${POD_NAME}/${POD_NAME}.xcworkspace/contents.xcworkspacedata" ]]; then
  echo "Generated workspace not found: ${TEMP_GEN_ROOT}/${POD_NAME}/${POD_NAME}.xcworkspace" >&2
  exit 1
fi

load_available_schemes

framework_args=()
IFS=',' read -r -a platform_list <<< "${PLATFORMS}"
for raw_platform in "${platform_list[@]}"; do
  platform="$(echo "${raw_platform}" | tr '[:upper:]' '[:lower:]' | xargs)"
  if [[ -z "${platform}" ]]; then
    continue
  fi

  if [[ -z "${PLATFORM_DESTINATIONS[${platform}]:-}" ]]; then
    echo "Unsupported platform: ${platform}. Supported: ios,macos,tvos,watchos" >&2
    exit 1
  fi

  while IFS= read -r entry; do
    if [[ -z "${entry}" ]]; then
      continue
    fi
    label=""
    destination=""
    scheme_platform=""
    build_scheme=""
    IFS='|' read -r label destination scheme_platform <<< "${entry}"
    build_scheme="$(resolve_workspace_scheme "${scheme_platform}")"
    echo "Using scheme '${build_scheme}' for ${label} (${destination})" | tee -a "${RUN_LOG}"
    archive_for_destination "${label}" "${destination}" "${build_scheme}"

    framework_path="${TEMP_ARCHIVE_ROOT}/${label}.xcarchive/Products/Library/Frameworks/${MODULE_NAME}.framework"
    if [[ ! -d "${framework_path}" ]]; then
      echo "Expected framework not found: ${framework_path}" >&2
      exit 1
    fi
    framework_args+=("-framework" "${framework_path}")
    if [[ "${INCLUDE_DEBUG_SYMBOLS}" == "1" ]]; then
      dsym_path="$(find_framework_dsym "${TEMP_ARCHIVE_ROOT}/${label}.xcarchive" || true)"
      if [[ -n "${dsym_path}" ]]; then
        framework_args+=("-debug-symbols" "${dsym_path}")
      fi
    fi
  done <<< "${PLATFORM_DESTINATIONS[${platform}]}"
done

if [[ "${#framework_args[@]}" -eq 0 ]]; then
  echo "No archives built. Nothing to package." >&2
  exit 1
fi

XCFRAMEWORK_OUTPUT="${BUILD_OUTPUT_DIR}/${MODULE_NAME}.xcframework"
run_logged xcodebuild -create-xcframework \
  "${framework_args[@]}" \
  -output "${XCFRAMEWORK_OUTPUT}"

echo "Build output: ${XCFRAMEWORK_OUTPUT}"
echo "Build log: ${RUN_LOG}"
