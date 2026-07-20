# pop'n rhythmin — source reconstruction

<!-- WISWA-GENERATED-README:START -->

[![GitHub tag (with filter)](https://img.shields.io/github/v/tag/Tatsh/expert-rotary-phone)](https://github.com/Tatsh/expert-rotary-phone/tags)
[![License](https://img.shields.io/github/license/Tatsh/expert-rotary-phone)](https://github.com/Tatsh/expert-rotary-phone/blob/master/LICENSE.txt)
[![GitHub commits since latest release (by SemVer including pre-releases)](https://img.shields.io/github/commits-since/Tatsh/expert-rotary-phone/v2.0.3/master)](https://github.com/Tatsh/expert-rotary-phone/compare/v2.0.3...master)
[![Dependabot](https://img.shields.io/badge/Dependabot-enabled-blue?logo=dependabot)](https://github.com/dependabot)
[![pages-build-deployment](https://github.com/Tatsh/expert-rotary-phone/actions/workflows/pages/pages-build-deployment/badge.svg)](https://tatsh.github.io/expert-rotary-phone/)
[![Stargazers](https://img.shields.io/github/stars/Tatsh/expert-rotary-phone?logo=github&style=flat)](https://github.com/Tatsh/expert-rotary-phone/stargazers)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)
[![Prettier](https://img.shields.io/badge/Prettier-black?logo=prettier)](https://prettier.io/)

[![@Tatsh](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fpublic.api.bsky.app%2Fxrpc%2Fapp.bsky.actor.getProfile%2F%3Factor=did%3Aplc%3Auq42idtvuccnmtl57nsucz72&query=%24.followersCount&label=Follow+%40Tatsh&logo=bluesky&style=social)](https://bsky.app/profile/Tatsh.bsky.social)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-Tatsh-black?logo=buymeacoffee)](https://buymeacoffee.com/Tatsh)
[![Libera.Chat](https://img.shields.io/badge/Libera.Chat-Tatsh-black?logo=liberadotchat)](irc://irc.libera.chat/Tatsh)
[![Mastodon Follow](https://img.shields.io/mastodon/follow/109370961877277568?domain=hostux.social&style=social)](https://hostux.social/@Tatsh)
[![Patreon](https://img.shields.io/badge/Patreon-Tatsh2-F96854?logo=patreon)](https://www.patreon.com/Tatsh2)

<!-- WISWA-GENERATED-README:STOP -->

Reconstructed source of **pop'n rhythmin** (`jp.konami.popnmusic`). This will work on 64-bit devices
and iOS 11+.

No copyrighted material is in this repository. You must provide your own IPA with the game assets.
Building this source alone will not result in a playable game.

## Bundled third-party libraries

| Import as                                                       | Library                                         | How identified                                                                                  |
| --------------------------------------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `CJSONDeserializer.h`, `CJSONSerializer.h`, `CDataScanner.h`, … | **TouchJSON** (Jonathan Wight)                  | `CJSON*` / `CDataScanner` / `CSerializedJSONData` class names are TouchJSON's exact public API. |
| `ZipArchive.h` (a.k.a. `UnZipArchive`)                          | **ZipArchive / SSZipArchive** (minizip wrapper) | `UnZipArchive` class + `libz` linkage.                                                          |

## Layout

This tree tries to mimic the original source layout recovered from the strings embedded in the binary
(`assert` macros).

```plain
Project/
  AppDelegate.{h,mm}                 confirmed original path
  System/src/
    OpenGL/     neGLES11.cpp -> neIGLES (GL ES abstraction)
    Render/     neTextTexture.mm
    Sound/      caplayer.mm (CoreAudio AUGraph player)
    Aep/        AepManager/AepOrderingTable/AepLyrCtrl.mm
    Util/       RhCrypto.{h,c}, NSData+Crypt.{h,m}
    neEngineBridge.h                 provisional C++ engine singleton interface
  Game/
    Note/       NoteMng.mm, AcNoteMng.mm
    Task/       SugorokuMainTask.mm
    Util/       Random.cpp
    Data/
      Chara/        CharaData.mm, SkillData.mm
      TreasureMap/  SugorokuMap.mm
      Save/         Core Data models + query categories +
                    UserSettingData (save/settings store)
```

Naming follows the original: System-layer C++ uses the lowercase `ne` prefix (`neIGLES`,
`neTextTexture`); Game-layer classes are PascalCase (`NoteMng`, `CharaData`, `SugorokuMap`).
Identifiers are recovered from embedded debug/assert strings and C++ RTTI wherever possible.

## Status

- Items that require online services are obviously non-functional.
- Taps on the main menu and song selection screen can be less than ideal in terms of
  accuracy/timing/lag. This looks like it may have been an issue in the original version, at least
  slightly.

### Song selection screen

- Unusual rendering when moving to a page on the left (song titles show but no border or cover for a
  visible number of frames).
- Pagination rubber-band mechanics is imperfect.
- Patches are used that are not faithful to the original game.

#### Picked song overlay

- Inaccurate animation: it shows the overlay but then moves and fades in a copy downward.

### Main menu

- Treasure Mode goes to a black screen.

### Arcade viewer

- Viewer is not functional: song does not play.
