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

POD_NAME="$(basename "${PODSPEC_FILE}" .podspec)"
GEN_PROJECT_DIR="./gen/${POD_NAME}"
BUILD_OUTPUT_DIR="${GEN_PROJECT_DIR}/Carthage/Build"
TEMP_GEN_ROOT="${GEN_PROJECT_DIR}/.xcframework-gen"
TEMP_ARCHIVE_ROOT="${GEN_PROJECT_DIR}/.archives"
MODULE_NAME="$(ruby -e 'spec = File.read(ARGV[0]); m = spec[/s\.module_name\s*=\s*"([^"]+)"/, 1]; n = spec[/s\.name\s*=\s*"([^"]+)"/, 1]; puts(m && !m.empty? ? m : n)' "${PODSPEC_FILE}")"

if ! command -v pod >/dev/null 2>&1; then
  echo "pod not found. Please install CocoaPods first." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found." >&2
  exit 1
fi

if ! pod plugins installed | grep -q "cocoapods-generate"; then
  echo "cocoapods-generate not installed. Installing..."
  gem install cocoapods-generate
fi

rm -rf "${BUILD_OUTPUT_DIR}"
rm -rf "${TEMP_GEN_ROOT}" "${TEMP_ARCHIVE_ROOT}"
mkdir -p "${BUILD_OUTPUT_DIR}" "${TEMP_GEN_ROOT}" "${TEMP_ARCHIVE_ROOT}"

cleanup() {
  if [[ "${KEEP_TEMP_ARTIFACTS:-0}" != "1" ]]; then
    rm -rf "${TEMP_GEN_ROOT}" "${TEMP_ARCHIVE_ROOT}"
  fi
}
trap cleanup EXIT

archive_for_platform() {
  local platform="$1"
  local sdk="$2"
  local suffix="$3"
  local gen_dir="${TEMP_GEN_ROOT}/${platform}-${suffix}"
  local workspace_dir="${gen_dir}/${POD_NAME}"
  local archive_path="${TEMP_ARCHIVE_ROOT}/${platform}-${suffix}"

  pod gen "${PODSPEC_FILE}" \
    --gen-directory="${gen_dir}" \
    --share-schemes-for-development-pods \
    --sources=https://github.com/CocoaPods/Specs.git \
    --use-modular-headers \
    --platforms="${platform}"

  xcodebuild \
    -workspace "${workspace_dir}/${POD_NAME}.xcworkspace" \
    -scheme "${POD_NAME}" \
    -configuration Release \
    -sdk "${sdk}" \
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

archive_for_platform "ios" "iphoneos" "device"
archive_for_platform "ios" "iphonesimulator" "simulator"
archive_for_platform "macos" "macosx" "device"
archive_for_platform "tvos" "appletvos" "device"
archive_for_platform "tvos" "appletvsimulator" "simulator"
archive_for_platform "watchos" "watchos" "device"
archive_for_platform "watchos" "watchsimulator" "simulator"

XCFRAMEWORK_OUTPUT="${BUILD_OUTPUT_DIR}/${MODULE_NAME}.xcframework"
xcodebuild -create-xcframework \
  -framework "${TEMP_ARCHIVE_ROOT}/ios-device.xcarchive/Products/Library/Frameworks/${MODULE_NAME}.framework" \
  -framework "${TEMP_ARCHIVE_ROOT}/ios-simulator.xcarchive/Products/Library/Frameworks/${MODULE_NAME}.framework" \
  -framework "${TEMP_ARCHIVE_ROOT}/macos-device.xcarchive/Products/Library/Frameworks/${MODULE_NAME}.framework" \
  -framework "${TEMP_ARCHIVE_ROOT}/tvos-device.xcarchive/Products/Library/Frameworks/${MODULE_NAME}.framework" \
  -framework "${TEMP_ARCHIVE_ROOT}/tvos-simulator.xcarchive/Products/Library/Frameworks/${MODULE_NAME}.framework" \
  -framework "${TEMP_ARCHIVE_ROOT}/watchos-device.xcarchive/Products/Library/Frameworks/${MODULE_NAME}.framework" \
  -framework "${TEMP_ARCHIVE_ROOT}/watchos-simulator.xcarchive/Products/Library/Frameworks/${MODULE_NAME}.framework" \
  -output "${XCFRAMEWORK_OUTPUT}"

echo "Build output: ${XCFRAMEWORK_OUTPUT}"
