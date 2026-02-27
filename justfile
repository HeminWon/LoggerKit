set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# List available recipes
help:
    @just --list

# Build XCFramework from Package.swift (logs enabled by default)
spm-xcframework platforms="ios,macos,tvos,watchos" output="./artifacts/spm":
    mkdir -p {{output}}
    sh Scripts/build-xcframework-from-package.sh --platforms {{platforms}} --output {{output}} 2>&1 | tee "{{output}}/build-$(date +%Y%m%d-%H%M%S).log"

# Build XCFramework via CocoaPods (logs enabled by default)
cocoapods-xcframework podspec="HMLoggerKit.podspec" keep_temp="0":
    mkdir -p ./gen/logs
    KEEP_TEMP_ARTIFACTS={{keep_temp}} sh Scripts/build-xcframework.sh {{podspec}} 2>&1 | tee "./gen/logs/cocoapods-build-$(date +%Y%m%d-%H%M%S).log"

# CocoaPods lint
pod-lint *args:
    sh Scripts/pod-lib-lint.sh {{args}}

# Local release checks
release-check *args:
    sh Scripts/release-check.sh {{args}}

# CI build script
swift-ci *args:
    sh Scripts/swift-ci.sh {{args}}
