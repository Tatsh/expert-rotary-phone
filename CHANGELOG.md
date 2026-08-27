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

### Changed

- Both build systems now run `destin rhythmin extract-dialogue` at configure time to generate the
  sugoroku dialogue tables, so `destin` on `PATH` replaces `python3` plus the in-tree script. With
  neither, the tables are still generated empty, as before.
- The app is now portrait only. `Info.plist` no longer declares the landscape
  orientations, which the game was never authored for: iPhone is locked to
  portrait, and iPad allows portrait and upside-down portrait. See
  [PATCHES.md](PATCHES.md) for the details.

### Fixed

- Saving a result screenshot no longer crashes on iOS 11 and later: the required
  `NSPhotoLibraryAddUsageDescription` purpose string was missing from
  `Info.plist`.
- Fixed a 64-bit pointer truncation in the arcade treasure-map edge list. The
  edge-array pointer was stored in a 32-bit `int` field (in `TreasureMap` and the
  arcade play data), which corrupted it on arm64 and garbled or crashed the
  sugoroku map's edge drawing; it is now a real typed pointer.
- The result screen's share button now works. It posted the score through the Social framework's
  Twitter service, which iOS 11 removed, so the button accepted a tap and did nothing. Patched
  builds now present the system share sheet with the same score text and the result screenshot,
  reaching any installed share extension; the shared text also drops the dead campaign short link.
  See [PATCHES.md](PATCHES.md) for the details.

### Removed

- The `tools/chr_dump.py`, `tools/idx_dump.py`, `tools/map_dump.py`, `tools/sheet_dump.py` and
  `tools/extract_sugoroku_dialogue.py` offline data-file tools. They are asset extractors rather
  than part of the reconstruction, and now live in [destin](https://github.com/Tatsh/destin) as
  `destin rhythmin dump-chara`, `dump-idx`, `dump-map`, `dump-sheet` and `extract-dialogue`.
- `tools/repack_ipa.py`. Nothing in it was specific to this project, so it now lives in
  [recon-tools](https://github.com/Tatsh/recon-tools) as `rctool ipa repack`, which reads the
  repository from this working tree's GitHub remote instead of carrying it as a default:

  <!-- prettier-ignore -->
  ```shell
  rctool ipa repack -a PopnRhythmin-adhoc-ipa -A <assets> <bundle-dir> PopnRhythmin-signed.ipa
  ```

## [0.0.1] - 2026-00-00

First version.

[unreleased]: https://github.com/Tatsh/expert-rotary-phone/compare/v2.0.3...HEAD
[0.0.1]: https://github.com/Tatsh/expert-rotary-phone/releases/tag/v2.0.3
