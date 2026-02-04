#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

if ! command -v pod >/dev/null 2>&1; then
  echo "pod not found. Please install CocoaPods first." >&2
  exit 1
fi

if ! command -v carthage >/dev/null 2>&1; then
  echo "carthage not found. Please install Carthage first." >&2
  exit 1
fi

if ! pod plugins installed | rg -q "cocoapods-generate"; then
  echo "cocoapods-generate not installed. Installing..."
  gem install cocoapods-generate
fi

pod gen LoggerKit.podspec \
  --share-schemes-for-development-pods \
  --sources=https://github.com/CocoaPods/Specs.git \
  --use-modular-headers

carthage build --project-directory ./gen/LoggerKit \
  --no-skip-current \
  --configuration Release \
  --platform all \
  --use-xcframeworks

echo "Build output: gen/LoggerKit/Carthage/Build/LoggerKit.xcframework"
