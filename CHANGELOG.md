# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog],
[markdownlint],
and this project adheres to [Semantic Versioning].

## [Unreleased]

### Changed in Unreleased

- **Breaking:** root action now references the `@v5` internal subactions. Callers must pin to `@v5` (or `@main`) — `@v4` users keep the old DMG-only behavior on macOS.

### Added in Unreleased

- `darwin-installer` input (macOS only): selects `homebrew` or `native`. Defaults to auto-detect (homebrew for pinned SDK ≥ 4.3.0; native for pre-4.3.0 pinned versions and for floating tags `staging-vN`/`production-vN`). Requesting `homebrew` against a pre-4.3.0 pinned version warns and falls back to `native`. The floating-tag default will move to `homebrew` once 4.3.0 is live in both taps.
- `senzingsdk-token` input (macOS only): GitHub token used to clone the private staging Homebrew tap. Defaults to `${{ github.token }}`.
- macOS homebrew install path: taps `Senzing/senzingsdk` (production) or `senzing-factory/senzingsdk-staging` (private) and runs `brew install --cask`. Pinned `X.Y.Z.BUILD` versions are forwarded via `HOMEBREW_SENZING_SDK_VERSION`; pinned `X.Y.Z` resolves the latest build from S3 before installing. `$HOME/senzing` is symlinked to the homebrew install for backward compatibility.

## [4.0.0] - 2026-03-12

### Changed in 4.0.0

- `senzingsdk-version` is now a required input
- `senzingsdk-repository-path` now requires `senzingsdk-version` to be set (previously defaulted to major version 4)
- Refactored install scripts to separate repository selection, version extraction, and artifact resolution into distinct phases

### Added in 4.0.0

- Semantic version support (`X.Y.Z`) for macOS and Windows — resolves the latest build for the given version from the S3 bucket
- Error handling when no matching artifact is found in the S3 bucket

## [1.0.0] - 2024-11-12

### Added to 1.0.0

- Install Senzing SDK on Linux, macOS, and Windows

[Keep a Changelog]: https://keepachangelog.com/en/1.0.0/
[markdownlint]: https://dlaa.me/markdownlint/
[Semantic Versioning]: https://semver.org/spec/v2.0.0.html
