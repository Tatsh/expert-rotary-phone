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
`-DIOS_ARCHS="arm64"` (etc.) to match what you have.

Everything is configurable on the CMake command line (all options are cache entries):
`APP_BUNDLE_ID`, `APP_DISPLAY_NAME`, `APP_VERSION`, `APP_BUILD`, `IOS_ARCHS`,
`IOS_DEPLOYMENT_TARGET`, `IOS_SDK_VERSION`, `THEOS`, `XCODE_PATH`, `RESOURCES_DIR`.

## Assets

None of the game's runtime assets (images, `rhythmin.lv`, `.acv/.orb/.idx` charts, fonts)
are in this repo — only reconstructed *code*. Point the build at a directory holding the
original extracted `.app` payload with `-DRESOURCES_DIR=/path/to/PopnRhythmin.app`; the
build copies everything except the old Mach-O / signature / Info.plist into the new bundle
so each `imageNamed:` / `NSBundle` lookup resolves.

## Theos (recommended for legacy targets)

```sh
export THEOS=~/theos
cmake -B build -DBUILD_BACKEND=THEOS \
      -DIOS_ARCHS="armv7 arm64" \
      -DIOS_DEPLOYMENT_TARGET=5.1.1 \
      -DRESOURCES_DIR=/path/to/PopnRhythmin.app
# CMake writes ./Makefile, ./control and ./Resources/Info.plist:
rsync -a --exclude PopnRhythmin --exclude _CodeSignature --exclude Info.plist \
      /path/to/PopnRhythmin.app/ Resources/
make            # -> PopnRhythmin.app
make package    # -> a .deb
```

## Xcode (native CMake target)

Uses the [leetal/ios-cmake](https://github.com/leetal/ios-cmake) toolchain (not vendored):

```sh
cmake -B build -G Xcode \
      -DCMAKE_TOOLCHAIN_FILE=/path/to/ios.toolchain.cmake -DPLATFORM=OS \
      -DBUILD_BACKEND=XCODE \
      -DIOS_ARCHS="armv7 armv7s arm64" -DDEPLOYMENT_TARGET=5.1.1 \
      -DRESOURCES_DIR=/path/to/PopnRhythmin.app
cmake --build build --config Release
```

The app target is assembled from a **per-directory `CMakeLists.txt`** in every source
folder under `Project/` (each lists its own translation units and adds itself to the
include path); the root file wires them together, sets the MRC/arch/deployment flags,
links the frameworks and copies resources.

## Notes / caveats

* The whole codebase is **Manual Reference Counting** (explicit `-retain`/`-release`/
  `-dealloc`, matching the original), so ARC is force-disabled (`-fno-objc-arc`).
* A few files interoperate with C++ via `__bridge_*` casts (ARC spelling); under strict
  MRC those become plain casts. Fix per compiler diagnostics if your clang rejects them.
* No Objective-C toolchain is available in the reconstruction container, so none of this
  has been compile-verified here — the build files are written to be correct by
  construction and by inspection against the sources.
