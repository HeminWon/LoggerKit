# Changelog

This project follows a Keep a Changelog-style format.

## [Unreleased]

## [0.2.5] - 2026-02-25

### Added

- Added GitHub Actions workflow for XCFramework release, including ZIP packaging and SwiftPM checksum output.

### Changed

- Reworked `Scripts/carthage-build-binary.sh` to build XCFramework via per-platform `pod gen` + `xcodebuild archive` + `xcodebuild -create-xcframework`.
- Updated release examples in `README.md` and bumped CocoaPods/SPM version references to `0.2.5`.

### Fixed

- Fixed watchOS 32-bit overflow in `LogDetailScene` session color hashing logic.
- Fixed false-positive XCFramework output reporting by validating fresh build artifacts in release script.

### Added

- Added open-source collaboration docs: Contributing, Security, and Code of Conduct.

### Changed

- Reworked `README.md` with installation matrix, UIKit/SwiftUI entry points, and FAQ.
- Updated `Examples/iOS/README.md` to current `LK` APIs.
- Standardized public-facing docs to English.

### Fixed
