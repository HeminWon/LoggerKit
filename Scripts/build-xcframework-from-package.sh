#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

if ! command -v swift >/dev/null 2>&1; then
  echo "swift not found." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found." >&2
  exit 1
fi

PACKAGE_JSON="$(swift package dump-package)"

DEFAULT_SCHEME="$(printf '%s' "${PACKAGE_JSON}" | ruby -rjson -e 'j = JSON.parse(STDIN.read); p = (j["products"] || []).find { |it| (it["type"] || {}).key?("library") }; puts(p ? p["name"] : "")')"
DEFAULT_PLATFORMS="$(printf '%s' "${PACKAGE_JSON}" | ruby -rjson -e 'j = JSON.parse(STDIN.read); puts((j["platforms"] || []).map { |p| p["platformName"] }.join(","))')"

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
  cat <<'EOF'
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
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)
      SCHEME="${2:-}"
      shift 2
      ;;
    --platforms)
      PLATFORMS="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --configuration)
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

rm -rf "${XCFRAMEWORK_OUTPUT}" "${BUILD_ROOT}"
mkdir -p "${OUTPUT_DIR}" "${BUILD_ROOT}"

cleanup() {
  if [[ "${KEEP_ARCHIVES}" != "1" ]]; then
    rm -rf "${BUILD_ROOT}"
  fi
}
trap cleanup EXIT

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

  mkdir -p "${modules_dest_dir}"
  while IFS= read -r source_module_dir; do
    found_count=$((found_count + 1))
    cp -f "${source_module_dir}"/* "${modules_dest_dir}/" 2>/dev/null || true
  done < <(find "${build_products_root}" -type d -name "${SCHEME}.swiftmodule" -print)

  printf '%s\n' "${found_count}"
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
  local swift_header_path=""

  swift_header_path="$(find "${derived_data_path}" -type f -name "${SCHEME}-Swift.h" -print | head -n 1 || true)"
  if [[ -z "${swift_header_path}" ]]; then
    printf '%s\n' "0"
    return 0
  fi

  mkdir -p "${headers_dir}" "$(dirname "${modulemap_path}")"
  cp -f "${swift_header_path}" "${headers_dir}/${SCHEME}-Swift.h"
  cat > "${headers_dir}/${SCHEME}.h" <<EOF
#import <${SCHEME}/${SCHEME}-Swift.h>
EOF
  cat > "${modulemap_path}" <<EOF
framework module ${SCHEME} {
  umbrella header "${SCHEME}.h"

  export *
  module * { export * }
}
EOF

  printf '%s\n' "1"
}

inject_swiftmodules_into_framework() {
  local archive_path="$1"
  local derived_data_path="$2"
  local framework_path=""
  local build_products_root=""
  local swiftmodule_count=0
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

  swiftmodule_count="$(inject_swiftmodules "${framework_path}" "${build_products_root}")"
  resource_count="$(inject_resource_bundles "${framework_path}" "${build_products_root}" "${derived_data_path}")"
  objc_header_count="$(inject_objc_headers "${framework_path}" "${derived_data_path}")"

  if [[ "${swiftmodule_count}" -gt 0 ]]; then
    echo "Injected swiftmodule metadata into ${framework_path} (${swiftmodule_count} source dirs)"
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
}

find_framework_dsym() {
  local archive_path="$1"
  local label
  local dsym_path=""
  local derived_data_path
  local dwarf_binary=""
  local abs_path=""

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
  xcodebuild archive \
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

IFS=',' read -r -a platform_list <<< "${PLATFORMS}"

for raw_platform in "${platform_list[@]}"; do
  platform="$(echo "${raw_platform}" | tr '[:upper:]' '[:lower:]' | xargs)"
  case "${platform}" in
    ios)
      archive_slice "ios-device" "generic/platform=iOS"
      archive_slice "ios-simulator" "generic/platform=iOS Simulator"
      ;;
    macos)
      archive_slice "macos" "generic/platform=macOS"
      ;;
    tvos)
      archive_slice "tvos-device" "generic/platform=tvOS"
      archive_slice "tvos-simulator" "generic/platform=tvOS Simulator"
      ;;
    watchos)
      archive_slice "watchos-device" "generic/platform=watchOS"
      archive_slice "watchos-simulator" "generic/platform=watchOS Simulator"
      ;;
    "")
      ;;
    *)
      echo "Unsupported platform: ${platform}. Supported: ios,macos,tvos,watchos" >&2
      exit 1
      ;;
  esac
done

framework_args=()
library_args=()
mixed_binary_types=0
detected_type=""

EMPTY_HEADERS_DIR="${BUILD_ROOT}/.empty-headers"
mkdir -p "${EMPTY_HEADERS_DIR}"

for archive_dir in "${BUILD_ROOT}"/*.xcarchive; do
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
  echo "No archives found. Nothing to package." >&2
  exit 1
fi

if [[ "${#framework_args[@]}" -gt 0 ]]; then
  xcodebuild -create-xcframework \
    "${framework_args[@]}" \
    -output "${XCFRAMEWORK_OUTPUT}"
else
  xcodebuild -create-xcframework \
    "${library_args[@]}" \
    -output "${XCFRAMEWORK_OUTPUT}"
fi

echo "Build output: ${XCFRAMEWORK_OUTPUT}"
