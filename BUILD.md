# Building pop'n rhythmin

The original game shipped **only as a 32-bit (armv7) binary**, which is why it will not
run on iOS 11+ (64-bit only). This reconstruction rebuilds it from source and, by default,
produces a fat binary spanning **armv7 armv7s arm64 arm64e** so it can run on both the
original hardware *and* modern iOS.

Your installed toolchain decides which slices you can actually produce:

| Slice | Needs |
|-------|-------|
| `armv7` / `armv7s` | Xcode ≤ 11 (32-bit codegen dropped in Xcode 12) |
| `arm64` | any modern Xcode |
| `arm64e` | recent Xcode with arm64e *app* codegen + iOS ≥ 12.1 |

On a 2017 MacBook Pro the two practical routes are **Theos** (easiest for legacy targets)
and **Xcode 10.1–11** (last versions that still emit armv7). Override the slice set with
`-DIOS_ARCHS="arm64"` (CMake) or `ARCHS="arm64"` (Theos) to match what you have.

There are two independent build systems:

* **Theos** — a fixed, hand-maintained Theos application project at [`theos/Makefile`](theos/Makefile).
  It does **not** go through CMake; edit its values in place. Build with `make -C theos`.
* **CMake/Xcode** — a native `.app` target. Everything is configurable on the CMake command
  line (all options are cache entries): `APP_BUNDLE_ID`, `APP_DISPLAY_NAME`, `APP_VERSION`,
  `APP_BUILD`, `IOS_ARCHS`, `IOS_DEPLOYMENT_TARGET`, `XCODE_PATH`, `RESOURCES_DIR`,
  `POPNRHYTHMIN_BINARY`.

## Assets

None of the game's runtime assets (images, `rhythmin.lv`, `.acv/.orb/.idx` charts, fonts)
are in this repo — only reconstructed *code*. Point the build at a directory holding the
original extracted `.app` payload with `-DRESOURCES_DIR=/path/to/PopnRhythmin.app`; the
build copies everything except the old Mach-O / signature / Info.plist into the new bundle
so each `imageNamed:` / `NSBundle` lookup resolves.

## Theos (recommended for legacy targets)

A fixed Theos project lives in [`theos/`](theos/) — `Makefile`, `control` and
`Resources/Info.plist`, all hand-maintained (no CMake, no configure step). The Makefile
anchors its paths to the repo root via its own location, so it builds from the subdirectory:

```sh
export THEOS=~/theos
# Optional: embed the copyrighted board dialogue from an owned binary (else blank).
cp -r /path/to/PopnRhythmin.app/. theos/Resources/    # game assets -> the bundle
make -C theos \
     ARCHS="armv7 arm64" \
     POPNRHYTHMIN_BINARY=/path/to/PopnRhythmin.app/PopnRhythmin   # -> PopnRhythmin.app
make -C theos package                                             # -> a .deb
```

Edit `theos/Makefile` directly to change the arch set, frameworks or flags; edit
`theos/control` / `theos/Resources/Info.plist` for packaging and bundle metadata.
Drop the extracted game assets into `theos/Resources/` (alongside `Info.plist`) so
`application.mk` copies them into the bundle.

## Xcode (native CMake target)

Uses the [leetal/ios-cmake](https://github.com/leetal/ios-cmake) toolchain (not vendored):

```sh
cmake -B build -G Xcode \
      -DCMAKE_TOOLCHAIN_FILE=/path/to/ios.toolchain.cmake -DPLATFORM=OS \
      -DIOS_ARCHS="armv7 armv7s arm64" -DDEPLOYMENT_TARGET=5.1.1 \
      -DRESOURCES_DIR=/path/to/PopnRhythmin.app
cmake --build build --config Release
```

The app target is assembled from a **per-directory `CMakeLists.txt`** in every source
folder under `Project/` (each lists its own translation units and adds itself to the
include path); the root file wires them together, sets the MRC/arch/deployment flags,
links the frameworks and copies resources.

## Continuous integration (GitLab)

[`.gitlab-ci.yml`](.gitlab-ci.yml) builds the app on a **macOS runner with Xcode** and
produces an **ad-hoc-signed** artifact (identity `-`, no Apple Developer account needed):

* `build:xcode` (default) — configures the CMake/Xcode backend with the fetched
  leetal/ios-cmake toolchain, builds `Release`, ad-hoc-signs `PopnRhythmin.app`
  (`codesign -s -`) and packages `PopnRhythmin-adhoc.ipa`.
* `build:theos` (manual, `allow_failure`) — bootstraps Theos and runs `make -C theos
  package` (Theos fake-signs via `ldid`), producing a `.deb`.

Defaults build **arm64 only** (SaaS runners run Xcode 12+, which cannot emit armv7). Set
`IOS_ARCHS`, `DEPLOYMENT_TARGET`, `MACOS_RUNNER_TAG`, and optionally `POPNRHYTHMIN_BINARY`
(embed the board dialogue) / `RESOURCES_DIR` (bundle assets) as CI/CD variables. Since the
tree has never been compiled, the first run is expected to surface real compile errors.

## Notes / caveats

* The whole codebase is **ARC** (targeting iOS 5+; the original's manual retain/release
  teardown is captured in `// @ 0xADDR` comments but synthesized by ARC), so both builds
  compile with `-fobjc-arc`.
* A few files interoperate with C++ via `__bridge_*` casts (ARC spelling) — 15 translation
  units; these require ARC and are why `-fno-objc-arc` would break the build.
* No Objective-C toolchain is available in the reconstruction container, so none of this
  has been compile-verified here — the build files are written to be correct by
  construction and by inspection against the sources.
