# Build-time patches

This reconstruction aims to be faithful to the shipped binary. Two preprocessor flags gate the
deliberate deviations needed to build a working game for 64-bit iOS 11+, so a faithful build (with
neither flag defined) stays as close to the original as possible.

- **`ENABLE_PATCHES`** — modern-iOS compatibility fixes and small quality-of-life changes. These
  cover behaviours that the iOS 8-era binary got for free but that abort, mis-render, or misbehave
  on current iOS, plus a handful of conveniences (server overrides, remembered difficulty).
- **`ENABLE_OFFLINE_PATCHES`** — fallbacks for online services that no longer exist. These let the
  affected flows complete locally instead of hanging on a dead endpoint.

Not every deviation is gated by these flags. Changes tied to a known iOS version are guarded at
runtime with `@available`/`__builtin_available` and marked `@newCode`, and remain active in a
faithful build; those are noted below where they work together with a flagged patch but are not
listed as patches themselves.

## `ENABLE_PATCHES`

### App startup

**File:** `Project/AppDelegate.mm` — `-application:didFinishLaunchingWithOptions:`

Two startup guards keep a fresh install from stalling on defunct Konami services: the Terms-of-Service
acceptance is pre-accepted (the acceptance server can no longer complete the first-run flow), and the
client is marked as up to date so the broken file-list/version download check is skipped instead of
looping forever.

### Engine text size

**File:** `Project/AppDelegate.mm` — `-application:didFinishLaunchingWithOptions:` (glyph bootstrap)

The binary calls the glyph manager's `bootstrapC(0)`, which leaves the rasterisation shift at 0 and
renders engine text at roughly ten pixels on a modern high-density display. The patch passes a shift
of 1 so glyphs are rasterised at 2x and drawn at half size, restoring legible text. See the note in
`Project/System/src/Render/neTextTexture.mm`, where the accompanying scale handling is a rendering
fix rather than a flagged change.

### Main-menu view-controller containment

**File:** `Project/MainViewController.mm` — `MainPresentContainerVC` and `MainDismissContainerVC`

The binary shows the navigation and split controllers with a bare `-addSubview:`. On iOS 13+ that
aborts when a container view enters the window without a parent-child controller relationship. The
patch adds proper `addChildViewController:`/`didMoveToParentViewController:` containment when
presenting and detaches the child controller on teardown.

### Song-select difficulty persistence

**Files:** `Project/System/src/Task/MainTask.mm` — `MainTask::update` (the chosen-song and
difficulty-select states); `Project/Game/Data/Save/UserSettingData.{h,mm}` — the
`lastPickedDifficulty` getter and `saveLastPickedDifficulty:` setter.

The overlay normally always opens on NORMAL. The patch remembers the last difficulty the player
picked and re-opens on it, clamped to a valid and unlocked sheet (EX falls back to NORMAL when
locked). The choice is stored through a plain `NSUserDefaults` key (`LastPickedDifficulty`) that
caches in memory and is flushed by the OS; the difficulty-select state writes it back whenever the
player changes difficulty.

### Jacket loader back-off

**File:** `Project/System/src/Task/MainTask.mm` — the background cell-loader routine

The binary sleeps before every scan of the 27-cell jacket ring, which serialises a freshly paginated
column into roughly one jacket every half second. The patch only sleeps once a full ring scan finds
no outstanding work, so queued jackets decode back to back and a new page fills quickly.

### Sound-settings sliders

**Files:** `Project/SoundSettingView.mm` — the `RHVolumeSliderCell` hit-test cell, `wireSliderDragFix:`,
`setEnclosingScrollEnabled:forSlider:`, and the slider touch-down/up handlers; the volume rows also
select `RHVolumeSliderCell` in `-tableView:cellForRowAtIndexPath:`.
`Project/SettingGameTableViewController.mm` — the `delaysContentTouches`/`canCancelContentTouches`
setup in `-initWithStyle:` and in the sound and effect detail cells of
`-tableView:cellForRowAtIndexPath:`.

The volume sliders live in a table embedded several layers deep inside the game-settings accordion (a
table inside a table). On modern iOS the enclosing scroll views claim the drag and the hit-test
resolves a touch on the slider to the enclosing cell, so the sliders never move. The patch delivers
content touches immediately without cancelling them on the involved tables, suspends the enclosing
scroll views for the duration of a drag, and routes touches straight to the slider through the
`RHVolumeSliderCell` hit-test override. This works together with always-on `@newCode` layout fixes in
the same files (disabling self-sizing via `estimatedRowHeight`, pinning the row height, and
re-querying heights on accordion toggle) that keep the host cell from collapsing.

### Input-name subtitle label

**File:** `Project/InputNameViewCtrl.mm` — `-init` (iPad subtitle label)

The binary sizes the subtitle label at exactly the font height, which clips the tops and bottoms of
full-width parentheses under modern text rendering. The patch gives the label a few points of
vertical headroom while keeping its visual centre.

### Server host overrides

**File:** `Project/StoreUtil.m` — `ResolveHost`

A faithful build always uses the shipped endpoints. The patch lets the API, secure, official, and
Konami-ID hosts be redirected through `NSUserDefaults` keys (`AprHost`, `AprSecureHost`,
`OfficialHost`, `KonamiIdHost`), so a revival or private server can be pointed to from configuration
without rebuilding.

### Fixed device UUID

**File:** `Project/AppDelegate.mm` — `-uuId`

A faithful build mints and Keychain-persists a per-device UUID. The purchased-song lists
(`mulist` / `acmulist` / `prodlist` / `recpack`) are BFCodec-encrypted with a key of MD5 of that
UUID string, so each blob only decrypts on the device it was created on. The patch pins `uuId` to a
fixed value, making the key device-independent: the lists can be generated once offline against that
UUID and then decrypt on any device running the build, without per-device regeneration.

### Arcade viewer keep-awake

**File:** `Project/System/src/Task/AcViewerTask.mm` — `update()` / `cleanup()`.

The iOS 8 binary does not touch the system idle timer. The patch disables auto-lock / auto-dim only
while a chart is actually playing (`m_state == kAcvPlaying`) and restores it the moment the player
pauses, scrubs, opens the pause menu, or leaves the viewer, so the screen does not sleep mid-song but
power saving resumes as soon as play stops.

### Empty arcade catalog

**Files:** `Project/AcViewerMusicViewController.mm` — `-initWithData:`,
`Project/AcViewerCategoryCell.mm` — cell configuration.

The binary always ships three default arcade (`.acv`) songs, so the arcade-viewer
category/music screens never open with an empty catalog and read the first song's category
unconditionally (`array[0]`). The patch guards those subscripts on an empty (non-nil) array,
falling back to the "all" banner/base, so a build that ships **zero** `.acv` files (none bundled and
none downloaded) shows an empty arcade viewer instead of throwing `NSRangeException`. A faithful
build keeps the original unconditional read.

### Bundled assets folder and custom songs

**Files:** `Project/AppDelegate.{h,mm}` — `+appAssetsDirectory` / `+appAssetsPath:`;
`Project/Game/Data/Music/MusicManager.{h,m}` — `+assetOrAppSupportPath:`, the `.orb` / `.acv`
chart-path resolvers, `loadPurchasedMusics`, `-reconcilePurchasedMusics`,
`-reconcileList:excluded:prefix:suffix:`, and the `rhythmin_lv` loader.

The original downloaded its charts, purchased-song lists, and other data at runtime into Application
Support and Documents. This patch lets a self-contained build ship that content in an optional
`assets/` subdirectory of the app bundle, and makes adding songs painless.

- **Charts and lists** (`.orb`, `.acv`, `mulist`, `acmulist`) resolve with priority `assets/` then
  Application Support; a file present in neither is simply ignored. Nothing is copied to Documents.
- **Lists are seeded once, then read-write in Documents.** The bundle install is read-only, so on
  first boot a shipped `assets/mulist` / `assets/acmulist` is copied into Documents; from then on
  Documents is the read-write store. `mulist` lists only purchased songs (not the defaults, the
  always-unlocked invite/collabo/login-bonus/treasure songs, or IDs 0-3), and the unlock gates for
  those bundled songs are forced open (`createOpenTreasureMusics`, `+isOpenInviteMusic:`,
  `+isOpenBemaniCollaboMusic`, `+isOpenLoginBonusMusic:`) so they load from their own catalogue
  sources without ever being double-listed.
- **Custom songs** work with no list editing: after decrypting the lists, `loadPurchasedMusics`
  reconciles them against the charts actually present — it drops entries whose chart file is gone or
  that another catalogue source already provides (defaults 0-3, the invite/collabo/login-bonus rewards
  4-6, the treasure songs), registers any canonical `%09d.orb` / `ac%09d.acv` found in `assets/` or
  Application Support that is not already listed, and persists the result back to Documents when it
  changed. So dropping a chart into Application Support (or into `assets/` on a jailbroken device)
  makes it appear next boot, and duplicates can never occur.
- **Level overrides** (`rhythmin_lv`) and the App Support **BGM tracks** (`bgm01_modesel`,
  `bgm02_musicsel`, `bgm03_result`, `bgm04_tre_*`) load from `assets/` only via `+appAssetsPath:`,
  with no fallback. The bundle-native title track (`bgm00_title`) keeps loading from the bundle.

A faithful build keeps the original Application Support / Documents paths and the real unlock gates.

### 64-bit struct-layout trimming

**Files:** `Project/System/src/Task/MainTask.h`, `Project/System/src/Task/AcViewerTask.h`,
`Project/System/src/Task/PlayTask.h`, `Project/System/src/Task/PlayResultTask.h` (see also the note
in `Project/System/src/Task/AcViewerTask.mm`).

These headers reproduce the original 32-bit work-area layout, including padding and alignment slots
that the binary never accesses. The dead slots are wrapped in `#ifndef ENABLE_PATCHES`, so a faithful
build keeps them for byte-exact offsets while a patched 64-bit build drops them, since the recovered
structs use named fields rather than hardcoded offsets on the 64-bit target.

## `ENABLE_OFFLINE_PATCHES`

### Player-name registration

**File:** `Project/InputNameViewCtrl.mm` — `-startPlayerNewHttp:`

The original registration server issued the numeric PlayerId and can no longer be reached. The patch
saves the chosen name locally with a stable seven-digit id synthesised from the device UUID (matching
the server's short numeric IDs) and continues down the success path, so a new player can be created
offline.
