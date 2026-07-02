# pop'n rhythmin — source reconstruction

Reconstructed Objective-C source for **pop'n rhythmin** (`jp.konami.popnmusic`),
Konami's iOS companion/rhythm game. The shipping binary is **32-bit only**
(`armv7`, `CFBundleShortVersionString` 2.0.3, built against the iOS 8.1 SDK), so
it stopped running once iOS 11 dropped 32-bit support. The goal of this tree is a
best-effort, modern-Objective-C reconstruction of the *original* application
source so it can be rebuilt for 64-bit / current iOS.

## Provenance

- **Binary:** `pop'n rhythmin 2.0.3-cracked/Payload/PopnRhythmin.app/PopnRhythmin`
  (Mach-O, `ARM:LE:32:v8`, image base `0x4000`, 3997 functions).
- **Ghidra project:** `rb420`, program `PopnRhythmin` (MCP bridge, TCP
  `127.0.0.1:8091`). Addresses cited in comments are relative to that program's
  image base and are the source of truth for anything reconstructed here.
- **Assets:** everything else in the `.app` bundle (`*.acv`, `*.map`, `*.idx`,
  `*.m4a`, fonts, `ScoreData.momd`, `DefaultUserData.plist`, `Settings.bundle`).

## What is and isn't reconstructed

**In scope** — original application code: the app's own Objective-C classes
(view controllers, data models, managers, the `ne*` OpenGL engine glue) and the
plain C helper functions that back them.

**Out of scope** (deliberately *not* re-implemented, per the reconstruction goal):

- Compiler/runtime-generated code: SjLj exception thunks, ARC/`objc_msgSend`
  stubs, `switchD_*` jump tables, Obj-C runtime metadata structs
  (`class_t`, `method_list_t`, `_Rep`, …), libstdc++ internals.
- Statically-linked library code that comes from the toolchain or system SDKs:
  `CF*`/Foundation/UIKit internals, `libz`, `libstdc++`, `memcpy`/`__stack_chk`
  style helpers. These are referenced, never redefined.

**Third-party SDKs bundled into the binary** are *not* reconstructed and *not*
stubbed. Original Konami code referenced them via their public headers, so this
tree does the same: it `#import`s the real library headers and treats the
libraries as external dependencies. See **Dependencies** below for the list and
how each was identified. (The exception is where a class name merely *collides*
with an SDK — e.g. the Core Data entity `TreasureData` is the local sugoroku
save record, unrelated to the TreasureData analytics SDK.)

## Conventions

- **Modern Objective-C throughout:** ARC, `@property`/dot-syntax, boxed
  literals (`@[]`, `@{}`, `@(x)`), `instancetype`, `NSInteger`/`CGFloat`.
- **Dot syntax whenever possible** for property/getter-style calls, including
  class getters: `UIDevice.currentDevice`, `NSUserDefaults.standardUserDefaults`,
  `array.count`, `results.lastObject` — not `[UIDevice currentDevice]`. Bracket
  syntax is kept only for calls that take arguments or have side-effect verbs.
- **Null literals by language:** Obj-C objects → `nil`; Obj-C++/C++ C-pointers
  (`.mm`/`.cpp`) → `nullptr`; plain C (`.c`) → `nullptr` (target is **C23**). C++
  target is **C++23**. (`NULL` is avoided outside legacy contexts.)
- **Include grouping:** standard library, then third-party/Apple frameworks,
  then project headers — groups separated by a blank line (no group-label
  comments), each sorted alphabetically (ASCII/case-sensitive, so `+`<`.` and
  lowercase after uppercase — matching clang-format).
- **C++ `auto`:** in C++/Obj-C++ code, prefer `auto` (with `&`/`const`/`*`
  qualifiers as needed) over spelling out types; name explicit types only when
  required or when it genuinely aids readability.
- **Decimal literals for readability:** write counts/sizes/masks in decimal
  (`24`, `64`, `31`) rather than hex when it reads better. Hex is reserved for
  Ghidra addresses in comments/citations (`@ 0xcae40`) and true address values.
  Exception: **bit-wise masks/flags use hex or binary** literals (`& 0x1f`,
  `| 0x3`, `1 << n`) since the bit pattern is the point.
- **File extensions by language:**
  - `.m` — pure Objective-C.
  - `.mm` — Objective-C++ (Obj-C mixed with C++; e.g. the `ne*` engine wrappers).
  - `.cpp` — pure C++ implementation (the `ne` engine core).
  - `.h` — all headers (C, C++, Obj-C, Obj-C++).

  Obj-C code calls the C++ engine through the `extern "C"` bridge in
  `Engine/NEEngineBridge.h`, so files that only *call* the engine stay `.m`.
- **Editor modelines on every Obj-C header:** each `.h` ends with Kate + vim
  modelines so editors treat it as Objective-C (or Objective-C++), since a bare
  `.h` is ambiguous:

  ```objc
  // kate: hl Objective-C;
  // vim: set ft=objc :
  // code: language=Objective-C
  ```

  The `code:` line is for the VSCode *vscode-modelines* extension. Obj-C++
  bridge headers use `hl Objective-C++;` / `ft=objcpp` / `language=Objective-C++`;
  C++ headers use the `C++` / `cpp` variants. All modelines also set 4-space,
  tabs-to-spaces indentation.
- **Header guards:** `#pragma once` for C++ headers; `#ifndef UPPERCASE_NAME_H`
  (all-caps) for pure C headers; Obj-C headers rely on `#import` and use no guard.
- **Ghidra DB kept in sync:** as `FUN_*` functions are identified they are
  renamed in the `rb420` database to match the names used here, with a plate
  comment pointing back to the reconstructed file. The DB is thus a live
  cross-reference; a citation like `Ghidra: NEAppEventCenter_shared (FUN_0000b150)`
  resolves in either direction.
- **Core Data models** live in `Models/` and were recovered with full fidelity
  from `ScoreData.momd` (they need no decompilation — the schema is serialized).
- **Renamed C functions:** any function that is still `FUN_<addr>` in Ghidra and
  gets re-implemented here is given a descriptive name, and the definition
  carries a citation comment so the mapping back to Ghidra is never lost:

  ```objc
  // Ghidra: FUN_0000a9cc  (project rb420, program PopnRhythmin)
  // Original: unnamed; renamed here for readability.
  static PersistentStore *rhythmin_makePersistentStoreCoordinator(void) { ... }
  ```

  Named Objective-C methods keep their real selectors and cite their address:
  `// -[AppDelegate application:didFinishLaunchingWithOptions:]  @ 0x8cf0`.

- This container has **no Xcode / Objective-C compiler**, so nothing here is
  compile-checked. Code is written to be faithful and buildable-in-principle,
  not verified against a compiler.

## Dependencies

These are **not** reconstructed here — add them to the project (CocoaPods /
Carthage / SPM / vendored source) and the reconstructed `#import`s will resolve.

### System frameworks (link against the iOS SDK)

`Foundation`, `UIKit`, `CoreData`, `CoreGraphics`, `QuartzCore`, `OpenGLES`,
`AVFoundation`, `AudioToolbox`, `StoreKit`, `GameKit`, `MapKit`, `CoreLocation`,
`Social`, `AdSupport`, `Security`, `libz`, `libstdc++`. (Derived from the Ghidra
class list — the `/System/Library/Frameworks/...` and `/usr/lib/...` entries.)

### Bundled third-party libraries — functional (vendor the real source/headers)

| Import as | Library | How identified |
|---|---|---|
| `CJSONDeserializer.h`, `CJSONSerializer.h`, `CDataScanner.h`, … | **TouchJSON** (Jonathan Wight) | `CJSON*` / `CDataScanner` / `CSerializedJSONData` class names are TouchJSON's exact public API. |
| `ZipArchive.h` (a.k.a. `UnZipArchive`) | **ZipArchive / SSZipArchive** (minizip wrapper) | `UnZipArchive` class + `libz` linkage. |

If exact upstream versions matter, pin to releases from ~mid-2014 (build date of
the bundle, 2014-07-18) to match the shipped behavior.

### Ad / analytics — STUBBED OUT, dependency eliminated

Per project policy, **nothing ad- or analytics-related is imported or shipped**.
These dependencies are removed; where original code called into them, the call
sites are backed by **no-op stubs** in `Stubs/` so the app still builds and runs
with all tracking/advertising inert. Do not vendor the real SDKs.

| Removed dependency | Kind | Handling |
|---|---|---|
| **TreasureData** analytics SDK (`TDClient` etc.) | analytics | no-op stub in `Stubs/` |
| **RewardNetwork** SDK (`RewardNetwork*`, `RewardNetworkResources.bundle`) | ad reward | no-op stub in `Stubs/` |
| `ASIdentifierManager` / `AdSupport` (IDFA) | ad tracking | eliminated; return zeroed/absent IDFA |

The app's *own* cross-promotion classes (`Recommend*`) are still reconstructed as
original source, but their network/ad calls are neutralized to no-ops so they
pull in no external ad services.

## Layout

The tree mirrors the **original source layout**, recovered from `__FILE__`
strings embedded in the binary (assert macros). The real project root was
`/Users/usr10013727/Documents/Project/Rhythmin/branches/v203/Project/`, so this
tree reproduces that `Project/` structure:

```
Project/
  AppDelegate.{h,mm}                 confirmed original path
  System/src/
    OpenGL/     neGLES11.cpp -> neIGLES (GL ES abstraction)   [pending]
    Render/     neTextTexture.mm                              [pending]
    Sound/      caplayer.mm (CoreAudio AUGraph player)        [pending]
    Aep/        AepManager/AepOrderingTable/AepLyrCtrl.mm     [pending]
    Util/       RhCrypto.{h,c}, NSData+Crypt.{h,m}            (crypto helpers)
    neEngineBridge.h                 provisional C++ engine singleton interface
  Game/
    Note/       NoteMng.mm, AcNoteMng.mm                      [pending]
    Task/       SugorokuMainTask.mm                           [pending]
    Util/       Random.cpp                                    [pending]
    Data/
      Chara/        CharaData.mm, SkillData.mm                [pending]
      TreasureMap/  SugorokuMap.mm                            [pending]
      Save/         Core Data models + query categories +
                    UserSettingData (save/settings store)     (done)
Stubs/            No-op replacements for removed ad/analytics SDKs (our addition)
```

Paths marked `[pending]` are confirmed-original filenames not yet reconstructed.
`Data/Save/` is a provisional grouping for the persistence classes (their exact
original subdir is not yet confirmed from strings).

Naming follows the original: System-layer C++ uses the lowercase `ne` prefix
(`neIGLES`, `neTextTexture`); Game-layer classes are PascalCase (`NoteMng`,
`CharaData`, `SugorokuMap`). Identifiers are recovered from embedded debug/assert
strings and C++ RTTI wherever possible rather than invented.

See `HANDOFF.md` for the per-class reconstruction status board.
