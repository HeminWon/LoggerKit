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

require_cmd swift
require_cmd xcodebuild
require_cmd ruby
require_cmd find
require_cmd xargs
require_cmd tee
require_cmd tail
require_cmd tr
require_cmd date
require_cmd sed

PACKAGE_JSON="$(swift package dump-package)"

read_default_values() {
  printf '%s' "${PACKAGE_JSON}" | ruby -rjson -e '
    j = JSON.parse(STDIN.read)
    p = (j["products"] || []).find { |it| (it["type"] || {}).key?("library") }
    scheme = p ? p["name"].to_s : ""
    platforms = (j["platforms"] || []).map { |it| it["platformName"] }.join(",")
    puts scheme
    puts platforms
  '
}

mapfile -t defaults < <(read_default_values)
DEFAULT_SCHEME="${defaults[0]:-}"
DEFAULT_PLATFORMS="${defaults[1]:-}"

if [[ -z "${DEFAULT_SCHEME}" ]]; then
  echo "No library product found in Package.swift." >&2
  exit 1
fi
if [[ -z "${DEFAULT_PLATFORMS}" ]]; then
  DEFAULT_PLATFORMS="ios,macos,tvos,watchos"
fi

SCHEME="${DEFAULT_SCHEME}"
PLATFORMS="${DEFAULT_PLATFORMS}"
OUTPUT_DIR="./artifacts/spm"
CONFIGURATION="Release"
KEEP_ARCHIVES=0
SKIP_SWIFT_INTERFACE_VERIFICATION=1
STRICT_ARTIFACT_VALIDATION=0
INCLUDE_DEBUG_SYMBOLS=1
RESOURCE_BUNDLE_PREFIX="${SCHEME}_"
RESOURCE_PREFIX_EXPLICIT=0

usage() {
  cat <<'USAGE'
Usage:
  sh Scripts/build-xcframework-from-package.sh [options]

Options:
  --scheme <name>           Library product / scheme name (default: first library product in Package.swift)
  --platforms <list>        Comma separated: ios,macos,tvos,watchos
                            (default: platforms declared in Package.swift)
  --output <dir>            Output directory (default: ./artifacts/spm)
  --configuration <name>    Build configuration (default: Release)
  --keep-archives           Keep intermediate .xcarchive directories
  --verify-swiftinterface   Enable strict Swift interface verification
  --strict-artifacts        Fail build when key metadata/resources are missing
  --no-debug-symbols        Do not include dSYM when creating xcframework
  --resource-prefix <name>  Resource bundle prefix (default: "<scheme>_")
  -h, --help                Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Missing value for --scheme" >&2
        usage
        exit 1
      fi
      SCHEME="${2:-}"
      shift 2
      ;;
    --platforms)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Missing value for --platforms" >&2
        usage
        exit 1
      fi
      PLATFORMS="${2:-}"
      shift 2
      ;;
    --output)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Missing value for --output" >&2
        usage
        exit 1
      fi
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --configuration)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Missing value for --configuration" >&2
        usage
        exit 1
      fi
      CONFIGURATION="${2:-}"
      shift 2
      ;;
    --keep-archives)
      KEEP_ARCHIVES=1
      shift
      ;;
    --verify-swiftinterface)
      SKIP_SWIFT_INTERFACE_VERIFICATION=0
      shift
      ;;
    --strict-artifacts)
      STRICT_ARTIFACT_VALIDATION=1
      shift
      ;;
    --no-debug-symbols)
      INCLUDE_DEBUG_SYMBOLS=0
      shift
      ;;
    --resource-prefix)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Missing value for --resource-prefix" >&2
        usage
        exit 1
      fi
      RESOURCE_BUNDLE_PREFIX="${2:-}"
      RESOURCE_PREFIX_EXPLICIT=1
      shift 2
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

if [[ -z "${SCHEME}" ]]; then
  echo "Scheme cannot be empty." >&2
  exit 1
fi

if [[ "${RESOURCE_PREFIX_EXPLICIT}" != "1" ]]; then
  RESOURCE_BUNDLE_PREFIX="${SCHEME}_"
fi

BUILD_ROOT="${OUTPUT_DIR}/.archives"
XCFRAMEWORK_OUTPUT="${OUTPUT_DIR}/${SCHEME}.xcframework"
LOG_DIR="${OUTPUT_DIR}/logs"
RUN_TS="$(date +%Y%m%dT%H%M%S%z)"
GIT_SHORT_SHA="$(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || true)"
LOG_SHA_SUFFIX=""
if [[ -n "${GIT_SHORT_SHA}" ]]; then
  LOG_SHA_SUFFIX="-g${GIT_SHORT_SHA}"
fi
RUN_LOG="${LOG_DIR}/${RUN_TS}-xcfw-spm-${SCHEME}${LOG_SHA_SUFFIX}.log"

rm -rf "${XCFRAMEWORK_OUTPUT}" "${BUILD_ROOT}"
mkdir -p "${OUTPUT_DIR}" "${BUILD_ROOT}" "${LOG_DIR}"
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
  if [[ "${KEEP_ARCHIVES}" != "1" ]]; then
    rm -rf "${BUILD_ROOT}"
  fi
}
trap cleanup EXIT

log_build_env() {
  {
    echo "== Build Metadata =="
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S %z')"
    echo "Root: ${ROOT_DIR}"
    echo "Scheme: ${SCHEME}"
    echo "Platforms: ${PLATFORMS}"
    echo "Configuration: ${CONFIGURATION}"
    echo "Output: ${OUTPUT_DIR}"
    echo "Keep archives: ${KEEP_ARCHIVES}"
    echo "Strict artifacts: ${STRICT_ARTIFACT_VALIDATION}"
    echo "Skip swiftinterface verify: ${SKIP_SWIFT_INTERFACE_VERIFICATION}"
    echo "Include debug symbols: ${INCLUDE_DEBUG_SYMBOLS}"
    echo "Resource prefix: ${RESOURCE_BUNDLE_PREFIX}"
    if [[ -n "${GIT_SHORT_SHA}" ]]; then
      echo "Git short sha: ${GIT_SHORT_SHA}"
    fi
    echo "Xcode: $(xcodebuild -version | tr '\n' ' ' | sed 's/  */ /g')"
    echo "Swift: $(swift --version | tr '\n' ' ' | sed 's/  */ /g')"
    echo
  } | tee -a "${RUN_LOG}"
}

find_framework_in_archive() {
  local archive_path="$1"
  local framework_name="$2"
  local framework_path=""

  if [[ -d "${archive_path}/Products/Library/Frameworks/${framework_name}.framework" ]]; then
    framework_path="${archive_path}/Products/Library/Frameworks/${framework_name}.framework"
  elif [[ -d "${archive_path}/Products/usr/local/lib/${framework_name}.framework" ]]; then
    framework_path="${archive_path}/Products/usr/local/lib/${framework_name}.framework"
  else
    framework_path="$(find "${archive_path}/Products" -type d -name "${framework_name}.framework" -print -quit || true)"
  fi

  if [[ -n "${framework_path}" ]]; then
    printf '%s\n' "${framework_path}"
  fi
}

find_library_in_archive() {
  local archive_path="$1"
  local library_name="$2"
  local library_path=""

  if [[ -f "${archive_path}/Products/usr/local/lib/lib${library_name}.a" ]]; then
    library_path="${archive_path}/Products/usr/local/lib/lib${library_name}.a"
  elif [[ -f "${archive_path}/Products/Library/lib${library_name}.a" ]]; then
    library_path="${archive_path}/Products/Library/lib${library_name}.a"
  else
    library_path="$(find "${archive_path}/Products" -type f -name "lib${library_name}.a" -print -quit || true)"
  fi

  printf '%s\n' "${library_path}"
}

find_build_products_root() {
  local derived_data_path="$1"
  local build_products_root="${derived_data_path}/Build/Intermediates.noindex/ArchiveIntermediates/${SCHEME}/BuildProductsPath"
  if [[ -d "${build_products_root}" ]]; then
    printf '%s\n' "${build_products_root}"
  fi
}

inject_swiftmodules() {
  local framework_path="$1"
  local build_products_root="$2"
  local modules_dest_dir="${framework_path}/Modules/${SCHEME}.swiftmodule"
  local found_count=0
  local copied_count=0

  mkdir -p "${modules_dest_dir}"
  while IFS= read -r source_module_dir; do
    found_count=$((found_count + 1))
    shopt -s nullglob
    module_files=("${source_module_dir}"/*)
    shopt -u nullglob
    if [[ "${#module_files[@]}" -gt 0 ]]; then
      cp -f "${module_files[@]}" "${modules_dest_dir}/"
      copied_count=$((copied_count + ${#module_files[@]}))
    fi
  done < <(find "${build_products_root}" -type d -name "${SCHEME}.swiftmodule" -print)

  printf '%s:%s\n' "${found_count}" "${copied_count}"
}

inject_resource_bundles() {
  local framework_path="$1"
  local build_products_root="$2"
  local derived_data_path="$3"
  local found_count=0

  while IFS= read -r bundle_path; do
    found_count=$((found_count + 1))
    rm -rf "${framework_path}/$(basename "${bundle_path}")"
    cp -R "${bundle_path}" "${framework_path}/"
  done < <(
    find "${build_products_root}" -type d \
      \( -name "${RESOURCE_BUNDLE_PREFIX}*.bundle" -o -name "${SCHEME}.bundle" \) \
      -print
  )

  if [[ "${found_count}" -eq 0 ]]; then
    while IFS= read -r bundle_path; do
      found_count=$((found_count + 1))
      rm -rf "${framework_path}/$(basename "${bundle_path}")"
      cp -R "${bundle_path}" "${framework_path}/"
    done < <(
      find "${derived_data_path}" -type d \
        \( -name "${RESOURCE_BUNDLE_PREFIX}*.bundle" -o -name "${SCHEME}.bundle" \) \
        -print
    )
  fi

  printf '%s\n' "${found_count}"
}

inject_objc_headers() {
  local framework_path="$1"
  local derived_data_path="$2"
  local headers_dir="${framework_path}/Headers"
  local modulemap_path="${framework_path}/Modules/module.modulemap"
  local swift_headers=()
  local generated_headers=()
  local selected_header=""

  while IFS= read -r swift_header_path; do
    generated_headers+=("${swift_header_path}")
  done < <(find "${derived_data_path}" -type f -path "*/GeneratedModuleMaps-*/*" -name "${SCHEME}-Swift.h" -print)

  if [[ "${#generated_headers[@]}" -gt 0 ]]; then
    swift_headers=("${generated_headers[@]}")
  else
    while IFS= read -r swift_header_path; do
      swift_headers+=("${swift_header_path}")
    done < <(find "${derived_data_path}" -type f -name "${SCHEME}-Swift.h" -print)
  fi

  if [[ "${#swift_headers[@]}" -eq 0 ]]; then
    printf '%s\n' "0"
    return 0
  fi

  if [[ "${#swift_headers[@]}" -gt 1 ]]; then
    local sorted_headers=()
    mapfile -t sorted_headers < <(printf '%s\n' "${swift_headers[@]}" | sort)
    selected_header="${sorted_headers[0]}"
  else
    selected_header="${swift_headers[0]}"
  fi

  mkdir -p "${headers_dir}" "$(dirname "${modulemap_path}")"
  cp -f "${selected_header}" "${headers_dir}/${SCHEME}-Swift.h"
  cat > "${headers_dir}/${SCHEME}.h" <<EOF2
#import <${SCHEME}/${SCHEME}-Swift.h>
EOF2
  cat > "${modulemap_path}" <<EOF2
framework module ${SCHEME} {
  umbrella header "${SCHEME}.h"

  export *
  module * { export * }
}
EOF2

  printf '%s\n' "1"
}

validate_framework_artifact() {
  local framework_path="$1"
  local has_issue=0
  local module_dir="${framework_path}/Modules/${SCHEME}.swiftmodule"
  local modulemap_path="${framework_path}/Modules/module.modulemap"

  if [[ ! -f "${framework_path}/Info.plist" ]]; then
    echo "Warning: missing Info.plist in ${framework_path}" >&2
    has_issue=1
  fi

  if [[ ! -d "${module_dir}" ]]; then
    echo "Warning: missing swiftmodule directory ${module_dir}" >&2
    has_issue=1
  else
    shopt -s nullglob
    swiftinterface_files=("${module_dir}"/*.swiftinterface)
    shopt -u nullglob
    if [[ "${#swiftinterface_files[@]}" -eq 0 ]]; then
      echo "Warning: no .swiftinterface files found in ${module_dir}" >&2
      has_issue=1
    fi
  fi

  if [[ ! -f "${modulemap_path}" ]]; then
    echo "Warning: missing module.modulemap in ${framework_path}" >&2
    has_issue=1
  fi

  if [[ "${STRICT_ARTIFACT_VALIDATION}" == "1" && "${has_issue}" -ne 0 ]]; then
    exit 1
  fi
}

inject_swiftmodules_into_framework() {
  local archive_path="$1"
  local derived_data_path="$2"
  local framework_path=""
  local build_products_root=""
  local swiftmodule_stats=""
  local swiftmodule_dir_count=0
  local swiftmodule_file_count=0
  local resource_count=0
  local objc_header_count=0

  framework_path="$(find_framework_in_archive "${archive_path}" "${SCHEME}" || true)"
  if [[ -z "${framework_path}" ]]; then
    return 0
  fi

  build_products_root="$(find_build_products_root "${derived_data_path}")"
  if [[ -z "${build_products_root}" ]]; then
    echo "Warning: cannot locate BuildProductsPath under ${derived_data_path}" >&2
    return 0
  fi

  swiftmodule_stats="$(inject_swiftmodules "${framework_path}" "${build_products_root}")"
  swiftmodule_dir_count="${swiftmodule_stats%%:*}"
  swiftmodule_file_count="${swiftmodule_stats##*:}"
  resource_count="$(inject_resource_bundles "${framework_path}" "${build_products_root}" "${derived_data_path}")"

  if ! objc_header_count="$(inject_objc_headers "${framework_path}" "${derived_data_path}")"; then
    msg="Warning: failed to inject ObjC headers/modulemap for ${framework_path}"
    if [[ "${STRICT_ARTIFACT_VALIDATION}" == "1" ]]; then
      echo "${msg}" >&2
      exit 1
    else
      echo "${msg}" >&2
    fi
  fi

  if [[ "${swiftmodule_dir_count}" -gt 0 ]]; then
    echo "Injected swiftmodule metadata into ${framework_path} (${swiftmodule_dir_count} source dirs, ${swiftmodule_file_count} files)"
  else
    msg="Warning: no ${SCHEME}.swiftmodule metadata found for ${framework_path}"
    if [[ "${STRICT_ARTIFACT_VALIDATION}" == "1" ]]; then
      echo "${msg}" >&2
      exit 1
    else
      echo "${msg}" >&2
    fi
  fi

  if [[ "${resource_count}" -eq 0 ]]; then
    msg="Warning: no resource bundles copied into ${framework_path}"
    if [[ "${STRICT_ARTIFACT_VALIDATION}" == "1" ]]; then
      echo "${msg}" >&2
      exit 1
    else
      echo "${msg}" >&2
    fi
  fi

  if [[ "${objc_header_count}" -gt 0 ]]; then
    echo "Injected ObjC headers/modulemap into ${framework_path}"
  fi

  validate_framework_artifact "${framework_path}"
}

find_framework_dsym() {
  local archive_path="$1"
  local dsym_path=""
  local dwarf_binary=""
  local label
  local derived_data_path
  local abs_path=""

  while IFS= read -r dsym_path; do
    dwarf_binary="${dsym_path}/Contents/Resources/DWARF/${SCHEME}"
    if [[ -d "${dsym_path}" && -f "${dwarf_binary}" ]]; then
      abs_path="$(cd "$(dirname "${dsym_path}")" && pwd)/$(basename "${dsym_path}")"
      printf '%s\n' "${abs_path}"
      return 0
    fi
  done < <(
    find "${archive_path}/dSYMs" -type d -name "${SCHEME}.framework.dSYM" -print 2>/dev/null
  )

  label="$(basename "${archive_path}" .xcarchive)"
  derived_data_path="${BUILD_ROOT}/deriveddata/${label}"
  while IFS= read -r dsym_path; do
    dwarf_binary="${dsym_path}/Contents/Resources/DWARF/${SCHEME}"
    if [[ -d "${dsym_path}" && -f "${dwarf_binary}" ]]; then
      abs_path="$(cd "$(dirname "${dsym_path}")" && pwd)/$(basename "${dsym_path}")"
      printf '%s\n' "${abs_path}"
      return 0
    fi
  done < <(
    find "${derived_data_path}" -type d -name "${SCHEME}.framework.dSYM" -print 2>/dev/null
  )
}

archive_slice() {
  local label="$1"
  local destination="$2"
  local archive_path="${BUILD_ROOT}/${label}.xcarchive"
  local derived_data_path="${BUILD_ROOT}/deriveddata/${label}"
  local swift_verify_flags=()

  # Some third-party dependencies fail strict emitted module interface verification
  # on newer toolchains. Skip verification by default for better XCFramework build stability.
  if [[ "${SKIP_SWIFT_INTERFACE_VERIFICATION}" == "1" ]]; then
    swift_verify_flags+=(OTHER_SWIFT_FLAGS="-no-verify-emitted-module-interface")
  fi

  echo "Archiving ${label} (${destination})"
  run_logged xcodebuild archive \
    -scheme "${SCHEME}" \
    -destination "${destination}" \
    -archivePath "${archive_path}" \
    -derivedDataPath "${derived_data_path}" \
    -configuration "${CONFIGURATION}" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    "${swift_verify_flags[@]}"

  inject_swiftmodules_into_framework "${archive_path}" "${derived_data_path}"
}

log_build_env

declare -A PLATFORM_DESTINATIONS
PLATFORM_DESTINATIONS[ios]=$'ios-device|generic/platform=iOS\nios-simulator|generic/platform=iOS Simulator'
PLATFORM_DESTINATIONS[macos]=$'macos|generic/platform=macOS'
PLATFORM_DESTINATIONS[tvos]=$'tvos-device|generic/platform=tvOS\ntvos-simulator|generic/platform=tvOS Simulator'
PLATFORM_DESTINATIONS[watchos]=$'watchos-device|generic/platform=watchOS\nwatchos-simulator|generic/platform=watchOS Simulator'

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
    label="${entry%%|*}"
    destination="${entry#*|}"
    archive_slice "${label}" "${destination}"
  done <<< "${PLATFORM_DESTINATIONS[${platform}]}"
done

framework_args=()
library_args=()
mixed_binary_types=0
detected_type=""

EMPTY_HEADERS_DIR="${BUILD_ROOT}/.empty-headers"
mkdir -p "${EMPTY_HEADERS_DIR}"

shopt -s nullglob
archive_dirs=("${BUILD_ROOT}"/*.xcarchive)
shopt -u nullglob

if [[ "${#archive_dirs[@]}" -eq 0 ]]; then
  echo "No archives found. Nothing to package." >&2
  exit 1
fi

for archive_dir in "${archive_dirs[@]}"; do
  framework_path="$(find_framework_in_archive "${archive_dir}" "${SCHEME}" || true)"
  if [[ -n "${framework_path}" ]]; then
    framework_args+=("-framework" "${framework_path}")
    if [[ "${INCLUDE_DEBUG_SYMBOLS}" == "1" ]]; then
      dsym_path="$(find_framework_dsym "${archive_dir}" || true)"
      if [[ -n "${dsym_path}" ]]; then
        framework_args+=("-debug-symbols" "${dsym_path}")
      fi
    fi
    if [[ -n "${detected_type}" && "${detected_type}" != "framework" ]]; then
      mixed_binary_types=1
    fi
    detected_type="framework"
    continue
  fi

  library_path="$(find_library_in_archive "${archive_dir}" "${SCHEME}")"
  if [[ -n "${library_path}" ]]; then
    headers_path=""
    if [[ -d "${archive_dir}/Products/usr/local/include" ]]; then
      headers_path="${archive_dir}/Products/usr/local/include"
    elif [[ -d "${archive_dir}/Products/include" ]]; then
      headers_path="${archive_dir}/Products/include"
    else
      headers_path="${EMPTY_HEADERS_DIR}"
    fi
    library_args+=("-library" "${library_path}" "-headers" "${headers_path}")
    if [[ -n "${detected_type}" && "${detected_type}" != "library" ]]; then
      mixed_binary_types=1
    fi
    detected_type="library"
    continue
  fi

  echo "Failed to locate ${SCHEME}.framework or lib${SCHEME}.a in archive: ${archive_dir}" >&2
  echo "Discovered candidates under archive:" >&2
  find "${archive_dir}/Products" \( -name "*.framework" -o -name "lib*.a" \) -print >&2 || true
  echo "Tip: If this package emits object files only, set library product type to dynamic in Package.swift:" >&2
  echo "  .library(name: \"${SCHEME}\", type: .dynamic, targets: [\"${SCHEME}\"])" >&2
  exit 1
done

if [[ "${mixed_binary_types}" == "1" ]]; then
  echo "Mixed binary artifact types detected across archives. Please keep all slices framework or all slices static library." >&2
  exit 1
fi

if [[ "${#framework_args[@]}" -eq 0 && "${#library_args[@]}" -eq 0 ]]; then
  echo "No packageable artifacts found in archives." >&2
  exit 1
fi

if [[ "${#framework_args[@]}" -gt 0 ]]; then
  run_logged xcodebuild -create-xcframework \
    "${framework_args[@]}" \
    -output "${XCFRAMEWORK_OUTPUT}"
else
  run_logged xcodebuild -create-xcframework \
    "${library_args[@]}" \
    -output "${XCFRAMEWORK_OUTPUT}"
fi

METADATA_OUTPUT="${OUTPUT_DIR}/package.json"
printf '%s\n' "${PACKAGE_JSON}" > "${METADATA_OUTPUT}"

echo "Build output: ${XCFRAMEWORK_OUTPUT}"
echo "Build log: ${RUN_LOG}"
echo "Metadata output: ${METADATA_OUTPUT}"
