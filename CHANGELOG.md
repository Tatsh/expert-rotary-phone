<!-- markdownlint-configure-file {"MD024": { "siblings_only": true } } -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.1/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [unreleased]

### Added

- Location and Photos usage-description strings in `Info.plist` so the
  arcade-finder map's user-location display and the result-screenshot save to
  the camera roll work on modern iOS.

### Fixed

- Saving a result screenshot no longer crashes on iOS 11 and later: the required
  `NSPhotoLibraryAddUsageDescription` purpose string was missing from
  `Info.plist`.

## [0.0.1] - 2026-00-00

First version.

[unreleased]: https://github.com/Tatsh/expert-rotary-phone/compare/v2.0.3...HEAD
[0.0.1]: https://github.com/Tatsh/expert-rotary-phone/releases/tag/v2.0.3
