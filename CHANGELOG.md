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
- BGM transitions on the standard-mode song-select screen cross-fade over half a second, as the
  original does, rather than cutting hard.
- Song titles and the page counter on the standard-mode song-select screen render in the original's
  dark grey rather than pure black.

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
- The standard-mode song-select screen now behaves as the original binary does in the places where
  the reconstruction had diverged:
  - Paging to a column on the left draws that column's jacket covers and cell borders. The jacket
    grid's draw callback painted only the current and incoming-next columns, so a page entered from
    the left showed its song titles over empty cells.
  - A fling no longer travels backwards for its first frames. The drag velocity was computed with
    an inverted sign, and the fling integrator accelerates whatever sign it is handed.
  - The background jacket loader yields for one frame (0.016 s) per step of its 27-cell ring rather
    than 0.3 s, so jackets arrive roughly 18 times faster and a freshly paginated column no longer
    shows empty cells for a visible number of frames.
  - The picked-song difficulty overlay no longer draws twice. Its idle loop layer was started while
    the opening sweep was still playing, which put a translucent copy of the panel behind the
    opaque one and slid it down; the loop now starts on the one frame the sweep reports finished.
  - Taps are hit-tested against the release point instead of the finger-down point, the screen's
    buttons and grid cells are hit-tested against the tracked drag touch's current point, and an
    extra vertical-slop gate the original does not have no longer rejects taps.
  - The numeric-level display toggle, the small sub-rect on each jacket cell, toggles the level and
    rank display instead of doing nothing.
  - The 'new recommend' badge is cleared once the Recommend screen has been opened.
  - Backing out to the mode menu discards the selection state the original discards, and can no
    longer pop the once-a-day official-info web view that belongs only to the boot and title path.
  - The friend-score panel can again be opened by tapping the over-score badge strip above the
    button, which the original also accepts once the song has an over-score entry.
  - With the numeric-level display on, a cell with no chart at a difficulty no longer draws a stray
    '0'.
  - The over-score dictionary is held with a strong reference, as the binary retains it. It could
    previously be deallocated and then dereferenced by the per-frame badge draws.
  - The teardown hand-off polls the select sound effect's own instance, so the select voice is no
    longer cut off and the hand-off no longer stalls.
  - The friend-score badge on the picked-song overlay reflects whether the song actually has an
    over-score entry. The chosen song's id was written to a field the draw callback does not read,
    so the badge always drew its 'untouched' artwork and the friend-update bar never appeared.

### Removed

- The `ENABLE_PATCHES` jacket-loader back-off. It existed only to compensate for a misread sleep
  constant in the background jacket loader, so with that constant corrected the stock loader fills a
  page on its own.
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
