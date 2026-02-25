# HMLoggerKit CocoaPods Release Guide (Maintainers)

This document defines the standard release workflow for `HMLoggerKit`.

## 1. Scope

- Repository: `https://github.com/HeminWon/LoggerKit`
- Pod: `HMLoggerKit`
- Podspec: `HMLoggerKit.podspec`
- Release channel: CocoaPods Trunk

## 2. Pre-release Checklist

Before releasing, confirm:

- You are on the intended release branch (usually `main`)
- The working tree has no uncommitted changes (recommended)
- `HMLoggerKit.podspec` fields are correct:
  - `s.name`
  - `s.version`
  - `s.source` (tag must match version)
  - `s.swift_version`
  - `s.platforms`
- Required tools are available locally: `pod`, `git`

Run local lint first:

```bash
sh Scripts/pod-lib-lint.sh
```

## 3. One-time Setup (First Release on a Machine)

1. Register your trunk account:

```bash
pod trunk register heminwon@gmail.com "HeminWon"
```

2. Confirm via the email link.
3. Verify session:

```bash
pod trunk me
```

## 4. Standard Release Steps

Example version: `0.2.3`.

1. Update podspec version:

```ruby
s.version = "0.2.3"
```

2. Run lint again:

```bash
sh Scripts/pod-lib-lint.sh
```

3. Commit and tag (tag must exactly match version):

```bash
git add HMLoggerKit.podspec
git commit -m "release: 0.2.3"
git tag 0.2.3
git push origin main --tags
```

4. Publish to CocoaPods:

```bash
pod trunk push HMLoggerKit.podspec --allow-warnings
```

5. Verify release:

```bash
pod trunk info HMLoggerKit
```

Or check the website:

- `https://cocoapods.org/pods/HMLoggerKit`

## 5. Common Issues

### 5.1 `No podspec exists at path ...`

Cause: Wrong podspec filename/path in script or command.

Fix: Ensure you use `HMLoggerKit.podspec` and run from repository root.

### 5.2 `Unable to find a specification for ...` / dependency resolution failure

Cause: Spec repo is stale or network issue.

Fix:

```bash
pod repo update
```

Then rerun lint/push.

### 5.3 `The version should be incremented`

Cause: `s.version` already exists on trunk.

Fix: Bump version, create a new matching tag, and release again.

### 5.4 Tag does not match podspec version

Cause: Parsed `s.source[:tag]` does not match `s.version`.

Fix: Keep `s.version`, git tag, and pushed tag identical.

## 6. Rollback and Hotfix Strategy

CocoaPods Trunk does not recommend deleting published versions. Preferred approach:

- Keep the incorrect version
- Release a fix version quickly (for example `0.2.3` -> `0.2.4`)
- Explain issue and fix in release notes

If a severe issue requires stronger action, evaluate downstream impact before using trunk delete/deprecate capabilities.

## 7. Suggested Release Checklist

- [ ] Update `HMLoggerKit.podspec` version
- [ ] Pass local `pod lib lint`
- [ ] Commit version change
- [ ] Create and push matching git tag
- [ ] `pod trunk push` succeeds
- [ ] New version is visible in `pod trunk info` and cocoapods.org
