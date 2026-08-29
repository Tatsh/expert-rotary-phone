# pop'n rhythmin — source reconstruction

<!-- WISWA-GENERATED-README:START -->

[![GitHub tag (with filter)](https://img.shields.io/github/v/tag/Tatsh/expert-rotary-phone)](https://github.com/Tatsh/expert-rotary-phone/tags)
[![License](https://img.shields.io/github/license/Tatsh/expert-rotary-phone)](https://github.com/Tatsh/expert-rotary-phone/blob/master/LICENSE.txt)
[![GitHub commits since latest release (by SemVer including pre-releases)](https://img.shields.io/github/commits-since/Tatsh/expert-rotary-phone/v2.0.3/master)](https://github.com/Tatsh/expert-rotary-phone/compare/v2.0.3...master)
[![Dependabot](https://img.shields.io/badge/Dependabot-enabled-blue?logo=dependabot)](https://github.com/dependabot)
[![GitHub Pages](https://github.com/Tatsh/expert-rotary-phone/actions/workflows/pages.yml/badge.svg)](https://tatsh.github.io/expert-rotary-phone/)
[![Stargazers](https://img.shields.io/github/stars/Tatsh/expert-rotary-phone?logo=github&style=flat)](https://github.com/Tatsh/expert-rotary-phone/stargazers)
[![pre-commit.ci status](https://results.pre-commit.ci/badge/github/Tatsh/expert-rotary-phone/master.svg)](https://results.pre-commit.ci/latest/github/Tatsh/expert-rotary-phone/master)
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

## Server API

The server API the app speaks is described in [openapi.yaml](openapi.yaml). A response schema
there is a lower bound, since the client ignores any field it does not need. It is browsable at
[tatsh.github.io/expert-rotary-phone/api/](https://tatsh.github.io/expert-rotary-phone/api/), which
shows each endpoint as a cURL, fetch, or other client call and can send the request.

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
    neEngineBridge.h                 C++ engine singleton interface
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

- Items that require online services are non-functional.

### iPhone support

- The app declares no support for screen sizes past the 4-inch (320x568) iPhone. It ships no launch
  storyboard and no larger launch images, so iOS runs it in compatibility mode on everything larger:
  - iPhone 6 / 6 Plus through 8 (4.7-inch and 5.5-inch) share the 4-inch 16:9 aspect ratio, so the
    content is just scaled up to fill the screen (slightly soft, but no black bars).
  - iPhone X and later (the tall 19.5:9 displays) have a different aspect ratio, so the 16:9 content
    cannot fill the screen and is letterboxed with black bars top and bottom.

  The render canvas is fixed to the legacy 640x960 / 640x1136 / 1536x2048 sizes and every sprite
  atlas is authored only at those resolutions, so a native-size drawable would just stretch the same
  fixed content. Using the whole screen at native resolution is a significant effort: a launch
  storyboard (not merely larger launch images) to leave compatibility mode, plus re-created assets
  and a reworked layout and touch path.
