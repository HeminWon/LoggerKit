#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

TAG_NAME=""
if [[ "${1:-}" == "--tag" ]]; then
  TAG_NAME="${2:-}"
  if [[ -z "${TAG_NAME}" ]]; then
    echo "Usage: $0 [--tag <tag>]" >&2
    exit 1
  fi
fi

SPEC_VERSION="$(ruby -e 'puts File.read("HMLoggerKit.podspec")[/s.version\s*=\s*"([^"]+)"/, 1]')"
if [[ -z "${SPEC_VERSION}" ]]; then
  echo "Failed to parse s.version from HMLoggerKit.podspec" >&2
  exit 1
fi

if [[ -n "${TAG_NAME}" ]]; then
  if ! git rev-parse -q --verify "refs/tags/${TAG_NAME}" >/dev/null; then
    echo "Tag does not exist locally: ${TAG_NAME}" >&2
    exit 1
  fi

  NORMALIZED_TAG="${TAG_NAME#v}"
  if [[ "${NORMALIZED_TAG}" != "${SPEC_VERSION}" ]]; then
    echo "Tag (${TAG_NAME}) does not match podspec version (${SPEC_VERSION})" >&2
    exit 1
  fi

  if ! rg -q "(from: \"${NORMALIZED_TAG}\"|~> ${NORMALIZED_TAG}|${TAG_NAME})" README.md; then
    echo "README.md does not contain release tag/version: ${TAG_NAME} (${NORMALIZED_TAG})" >&2
    exit 1
  fi

  echo "Release check passed: tag=${TAG_NAME}, version=${SPEC_VERSION}, README contains tag/version."
  exit 0
fi

if ! rg -q "(from: \"${SPEC_VERSION}\"|~> ${SPEC_VERSION}|v${SPEC_VERSION})" README.md; then
  echo "README.md does not contain podspec version: ${SPEC_VERSION}" >&2
  exit 1
fi

echo "Release check passed: version=${SPEC_VERSION}, README contains version."
