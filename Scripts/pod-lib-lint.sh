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

pod lib lint "${PODSPEC_FILE}" \
  --verbose \
  --platforms=ios,osx \
  --allow-warnings \
  "$@"
