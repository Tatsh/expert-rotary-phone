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
  - Returning from the friend-score panel refreshes the previewed song's scores rather than a song
    in another column. The refresh addressed the jacket cell by its position within the column and
    left out the column's own row base, so two times in three it rewrote an off-screen cell and left
    the previewed song showing stale scores.
  - The teardown hand-off polls the select sound effect's own instance, so the select voice is no
    longer cut off and the hand-off no longer stalls.
  - The friend-score badge on the picked-song overlay reflects whether the song actually has an
    over-score entry. The chosen song's id was written to a field the draw callback does not read,
    so the badge always drew its 'untouched' artwork and the friend-update bar never appeared.
- The title screen now behaves as the original binary does in the places where the reconstruction
  had diverged:
  - The device-transfer button is anchored ten points below the top of the frame rather than ten
    points above it. The -10 the reconstruction took for the button's Y belongs to its X, so the
    safe-area-inset correction that compensated for the clipped origin is gone with it.
  - The device-transfer button fades out over 0.3 s rather than 0.25 s, restoring the original's
    asymmetry with its 0.25 s fade-in, which is unchanged.
  - The network-failure alert shown when the file-list download fails on an out-of-date client
    carries the original's text asking the player to retry somewhere with better reception, and an
    OK button. Both its message and its button label were empty.
  - The device-transfer alert carries its title, the full explanation that a transfer pass has
    already been issued and that the data must be reset, and its reset-data button label. The
    title, three of the four message lines, and the label were missing, which left the button that
    starts the data-reset flow unlabelled.
- The mode-select screen, the main menu, now behaves as the original binary does in the places where
  the reconstruction had diverged:
  - Taps are hit-tested against the release point instead of the finger-down point. The accept gate
    allows up to ten device pixels of travel, so a tap near a button edge hit the neighbouring
    button or nothing at all. This is the same defect already fixed on the song-select screen, and
    it affected every mode button, the settings, present, and featured buttons, and the news-ticker
    band.
  - The three background and prompt layers are built with the original's owner and ordering
    priorities of 14, 14, and 11 rather than no owner and priority 0, so they are no longer drawn
    last over the settings, store, and gift button labels and over the new-pack, treasure-event,
    game-event, and friend-request badges.
  - The three event badges and three button labels are drawn through the sprite-handle draw their
    handles were resolved for rather than the layer-tree draw, which drew nothing or an unrelated
    sprite. The attention pulse now reaches the three badges, so they flash again.
  - The friend-request warning badge samples its own 42-texel window of the texture, 86 on iPad,
    instead of an over-extended 100-texel crop: its size and scale arguments were transposed. Its
    alpha and texture-filter arguments are no longer left at zero.
  - The menu BGM fades in over half a second, as the original does, rather than cutting hard.
  - The arcade-viewer button plays its own voice. The sixth menu sound effect loaded the wrong clip.
  - The reward-network session parameters carry the reward application id and the player id
    alongside the environment pair, as the binary stores them. They are archived to disk and read
    back by later token requests.
- `CharaManagerShared` no longer reloads every character record on first use. In the binary, that
  accessor builds nothing: it is an empty constructor behind a one-shot guard, and the two real
  reload sites, the title hand-off and the arcade task, are already reconstructed. The spurious
  reload re-created the character records just after the title screen had built them, which also
  left a cached pointer in the arcade task dangling.
- Text the reconstruction had left blank or filled with placeholders now carries the binary's own
  literals. Every CFString in the shipped image was compared against this tree; the differences the
  player can see are:
  - The low-storage warning shown at launch carries its title, the warning that the game may not
    run correctly with so little space free, and an OK button. All three were nil, so the player
    saw an empty card, and the missing button label also made the alert build its unlabelled 'yes'
    button in place of the OK button.
  - The terms-of-service text on the acceptance screen is the original's request to read the terms
    and press 'agree' before playing rather than placeholder text.
  - The store's delete-pack confirmation, pack-download progress message, restore-purchases
    confirmation, and install-all prompt carry the original wording, and the treasure-point reward
    notice shown after a recommended pack is added carries the original message rather than
    invented text.
  - The friend-removal screen shows the right message for each outcome. An empty response body is
    the success case and a JSON body carries an error code, but the success text and the original
    communication-failure text sat on opposite branches.
  - The arcade-finder map's prompt to zoom in before shops are listed is the original text rather
    than a placeholder constant.
  - The age-verification dialogue regains the indentation on its spending-limit figures and the
    blank line between two of the tiers.
  - The store's price fallback shows the full-width yen sign the original uses rather than the
    half-width one.
  - Three small labels were blank or wrong: the trailing chevron on an arcade-viewer option cell,
    the multiplication-sign prefix on the sub-map list's collected counts, and the dash the
    friend-score list shows in place of a missing score.
  - The policy view pads the loaded text with the original's seven trailing line breaks rather
    than one.
  - The default-data download screen's progress label reads 'File check...', with the space the
    original has.
  - The name-display character table maps the full-width reverse solidus rather than the
    full-width less-than sign, so the character the original replaces in displayed names is the
    one that is now replaced.
- Resource names that silently failed to load now match the binary:
  - Character data is read as `chara%03d.chr` rather than `chara_%03d.chr`.
  - The sugoroku wall-nail texture is `sugo_wall_nail%02d`, the quiz answer-base image is
    `pq_ansbase_top%d`, and the quiz present-number digits are `pq_present_num%d@2x`. Each carried
    an extra underscore or the wrong suffix.
  - The StoreKit pack product identifier prefix is `rhythmin.pack` rather than `rhythmin_pack`.
    The same identifier is corrected in [openapi.yaml](openapi.yaml).
- The CoreAudio graph's mixer-gain set and both of its `AUGraphUpdate` calls are checked and logged
  as the binary does rather than having their return values discarded.
- The reward network installs its UDID pasteboard under the service name and data type the binary
  registers. It was never created, so nothing could be written to it or read back from it.
- The reward network's user-agent string no longer carries a slash the binary does not have.
- The half-width character test that measures text for layout uses the binary's literal yen signs
  rather than backslash escapes, which changes which characters count as one column.

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
