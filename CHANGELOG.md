<!-- markdownlint-configure-file {"MD024": { "siblings_only": true } } -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.1/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [unreleased]

## [2.0.3] - 2026-08-30

First release.

### Added

- Reconstructed source for pop'n rhythmin (`jp.konami.popnmusic`) that builds a 64-bit binary for
  iOS 11 and later. The repository carries no copyrighted material, so an IPA you own supplies the
  game assets.
- Two documented build paths, Theos and a CMake Xcode target. See [BUILD.md](BUILD.md).
- [openapi.yaml](openapi.yaml), describing the server API the client speaks, published at
  [tatsh.github.io/expert-rotary-phone/api/](https://tatsh.github.io/expert-rotary-phone/api/).
- The `ENABLE_PATCHES` and `ENABLE_OFFLINE_PATCHES` build options, which restore behaviour lost to
  the shut-down services and to later iOS releases. See [PATCHES.md](PATCHES.md).

[unreleased]: https://github.com/Tatsh/expert-rotary-phone/compare/v2.0.3...HEAD
[2.0.3]: https://github.com/Tatsh/expert-rotary-phone/releases/tag/v2.0.3
