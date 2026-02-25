#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

MODE="${1:-all}"
shift || true

EXTRA_ARGS=("$@")

run_build() {
  echo "==> swift build -v"
  swift build -v "${EXTRA_ARGS[@]}"
}

run_test() {
  local skip_database_tests="${LOGGERKIT_SKIP_DATABASE_TESTS:-1}"
  echo "==> swift test -v"
  echo "==> LOGGERKIT_SKIP_DATABASE_TESTS=${skip_database_tests}"
  LOGGERKIT_SKIP_DATABASE_TESTS="${skip_database_tests}" swift test -v "${EXTRA_ARGS[@]}"
}

case "${MODE}" in
  build)
    run_build
    ;;
  test)
    run_test
    ;;
  all)
    run_build
    run_test
    ;;
  *)
    echo "Usage: $0 [all|build|test] [extra swift args...]" >&2
    echo "Env: LOGGERKIT_SKIP_DATABASE_TESTS=1 (default) skips DB benchmark/optimization tests in SPM runtime" >&2
    exit 1
    ;;
esac
