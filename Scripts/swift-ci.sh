#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_DIR="${ROOT_DIR}/ci-reports"
REPORT_FILE="${REPORT_DIR}/swift-ci-report.md"

cd "${ROOT_DIR}"
mkdir -p "${REPORT_DIR}"

MODE="${1:-all}"
shift || true

EXTRA_ARGS=("$@")
BUILD_STATUS="skipped"
TEST_STATUS="skipped"

get_swift_target_triple() {
  swift -print-target-info 2>/dev/null | sed -n 's/.*"triple"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

get_declared_platforms() {
  sed -n '/platforms:[[:space:]]*\[/,/\][[:space:]]*$/p' Package.swift \
    | sed -n 's/.*\.\([A-Za-z0-9_]*\)(\.v\([0-9.]*\)).*/\1 \2/p' \
    | awk 'NF { if (count++) printf ", "; printf "%s %s", $1, $2 } END { if (!count) printf "<unknown>" }'
}

write_report() {
  local exit_code="$1"
  local overall_status="success"
  if [[ "${exit_code}" -ne 0 ]]; then
    overall_status="failed"
  fi

  local swift_version
  swift_version="$(swift --version 2>/dev/null | head -n 1)"
  local xcode_version
  xcode_version="$(xcodebuild -version 2>/dev/null | paste -sd ' | ' -)"
  local host_arch
  host_arch="$(uname -m)"
  local target_triple
  target_triple="$(get_swift_target_triple)"
  local declared_platforms
  declared_platforms="$(get_declared_platforms)"
  local extra_args_text="<none>"
  if ((${#EXTRA_ARGS[@]})); then
    extra_args_text="${EXTRA_ARGS[*]}"
  fi

  cat > "${REPORT_FILE}" <<EOF
# Swift CI Report

- Status: ${overall_status}
- Mode: ${MODE}
- Build: ${BUILD_STATUS}
- Test: ${TEST_STATUS}
- Host Architecture: ${host_arch}
- Swift Target Triple: ${target_triple}
- Declared Platforms (Package.swift): ${declared_platforms}
- Extra Swift Args: ${extra_args_text}
- LOGGERKIT_SKIP_DATABASE_TESTS: ${LOGGERKIT_SKIP_DATABASE_TESTS:-1}
- Swift: ${swift_version}
- Xcode: ${xcode_version}
EOF

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat "${REPORT_FILE}" >> "${GITHUB_STEP_SUMMARY}"
    echo "" >> "${GITHUB_STEP_SUMMARY}"
    echo "> Full report file: \`ci-reports/swift-ci-report.md\`" >> "${GITHUB_STEP_SUMMARY}"
  fi
}

on_exit() {
  local exit_code="$1"
  write_report "${exit_code}"
}

trap 'on_exit $?' EXIT

run_build() {
  echo "==> swift build -v"
  if ((${#EXTRA_ARGS[@]})); then
    if swift build -v "${EXTRA_ARGS[@]}"; then
      BUILD_STATUS="success"
    else
      BUILD_STATUS="failed"
      return 1
    fi
  else
    if swift build -v; then
      BUILD_STATUS="success"
    else
      BUILD_STATUS="failed"
      return 1
    fi
  fi
}

run_test() {
  local skip_database_tests="${LOGGERKIT_SKIP_DATABASE_TESTS:-1}"
  echo "==> swift test -v"
  echo "==> LOGGERKIT_SKIP_DATABASE_TESTS=${skip_database_tests}"
  if ((${#EXTRA_ARGS[@]})); then
    if LOGGERKIT_SKIP_DATABASE_TESTS="${skip_database_tests}" swift test -v "${EXTRA_ARGS[@]}"; then
      TEST_STATUS="success"
    else
      TEST_STATUS="failed"
      return 1
    fi
  else
    if LOGGERKIT_SKIP_DATABASE_TESTS="${skip_database_tests}" swift test -v; then
      TEST_STATUS="success"
    else
      TEST_STATUS="failed"
      return 1
    fi
  fi
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
