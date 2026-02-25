# Contributing

Thanks for your interest in LoggerKit.

## Development Environment

- Xcode 15+
- Swift 5.9+
- iOS 15+ / macOS 12+

## Quick Start

```bash
git clone https://github.com/HeminWon/LoggerKit.git
cd LoggerKit
swift build
swift test
```

## Branch and Commit Conventions

- Recommended branch names: `feat/*`, `fix/*`, `docs/*`, `refactor/*`, `test/*`
- Recommended commit style: Conventional Commits
  - `feat: ...`
  - `fix: ...`
  - `docs: ...`
  - `refactor: ...`
  - `test: ...`

## Pull Request Requirements

- Ensure `swift build` and `swift test` pass before submitting
- PR description should include:
  - Background
  - What changed
  - Potential impact
  - Validation steps
- If public APIs change, update `README.md` and example docs in the same PR

## Code Style

- Keep API naming clear and consistent
- Prefer maintainability over over-engineering
- Add comments only when needed, and explain why rather than what

## Documentation and Communication

- Issues and PRs can be written in English or Chinese
- Documentation should stay in Markdown with copy-paste runnable examples
