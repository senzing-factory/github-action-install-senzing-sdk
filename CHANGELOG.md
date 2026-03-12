# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog],
[markdownlint],
and this project adheres to [Semantic Versioning].

## [Unreleased]

-

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
