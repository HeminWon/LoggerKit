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

if ! command -v pod >/dev/null 2>&1; then
  echo "pod not found. Please install CocoaPods first." >&2
  exit 1
fi

if ! command -v carthage >/dev/null 2>&1; then
  echo "carthage not found. Please install Carthage first." >&2
  exit 1
fi

if ! pod plugins installed | grep -q "cocoapods-generate"; then
  echo "cocoapods-generate not installed. Installing..."
  gem install cocoapods-generate
fi

pod gen "${PODSPEC_FILE}" \
  --share-schemes-for-development-pods \
  --sources=https://github.com/CocoaPods/Specs.git \
  --use-modular-headers

carthage build --project-directory "${GEN_PROJECT_DIR}" \
  --no-skip-current \
  --configuration Release \
  --platform all \
  --use-xcframeworks

XCFRAMEWORK_PATH="$(find "${GEN_PROJECT_DIR}/Carthage/Build" -maxdepth 1 -type d -name "*.xcframework" | head -n 1)"
if [[ -n "${XCFRAMEWORK_PATH}" ]]; then
  echo "Build output: ${XCFRAMEWORK_PATH}"
else
  echo "Build finished, but no xcframework found in ${GEN_PROJECT_DIR}/Carthage/Build" >&2
fi
