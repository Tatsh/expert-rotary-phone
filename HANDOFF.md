# HANDOFF — pop'n rhythmin source reconstruction

Living status board for the reconstruction. Update after every completed class.

## Goal

Reconstruct the original Objective-C source of **pop'n rhythmin 2.0.3** (32-bit
`armv7`, `jp.konami.popnmusic`) into `rhythmin-src/` so it can be rebuilt for
64-bit iOS. Modern Objective-C (ARC, literals, `instancetype`). Do **not**
re-implement compiler/runtime output (SjLj, `switchD_*`, objc runtime structs)
or statically-linked SDK/system code (`CF*`, `libz`, …). Third-party SDKs are
`#import`ed, not reconstructed (see README "Dependencies"). No compiler is
available in this container — code is best-effort, not compile-checked.

## Environment / provenance

- Ghidra project **rb420**, program **PopnRhythmin**, MCP bridge TCP `:8091`.
- Binary: `.../Payload/PopnRhythmin.app/PopnRhythmin` (ARM:LE:32:v8, base `0x4000`).
- Assets: `.../PopnRhythmin.app/` (`*.acv`, `*.map`, `*.idx`, `*.m4a`, `*.momd`, …).

### Discovered original source tree (from embedded __FILE__ strings)

Root: `/Users/usr10013727/Documents/Project/Rhythmin/branches/v203/Project/`
Confirmed files (reconstruct into these exact paths as they are tackled):
- Project/AppDelegate.mm                                   [done]
- Project/System/src/Aep/AepManager.mm, AepOrderingTable.mm, AepLyrCtrl.mm
- Project/System/src/OpenGL/neGLES11.cpp        (class neIGLES/neGLES_11; enums
    RenderKind, RenderType, MatrixMode, Hint, FogMode, ClientState, EnableState,
    CullFace, FrontFace, BlendSrcValue/BlendDestValue, TexFormat, TexParamType,
    TexParamValue, CompareFunc — all GL tables decoded from DAT_0012e100-e2df)
- Project/System/src/Render/neTextTexture.mm    (CreateNewTextTexture)
- Project/System/src/Sound/caplayer.mm          (CoreAudio AUGraph: CAComponent)
- Project/Game/Note/NoteMng.mm, AcNoteMng.mm
- Project/Game/Util/Random.cpp
- Project/Game/Task/SugorokuMainTask.mm
- Project/Game/Data/Chara/CharaData.mm, SkillData.mm
- Project/Game/Data/TreasureMap/SugorokuMap.mm
Technique: `search_strings` for the project path, class names, assert text, and
NSLog/debug identifiers; plus C++ RTTI. Use it before naming/placing new files.

## Conventions (see README for full text)

- Every reconstructed C `FUN_*` gets a descriptive name **+ a citation comment**
  `// Ghidra: <newname> (FUN_<addr>) (project rb420, program PopnRhythmin)`.
- Also **rename the FUN_\* in the Ghidra rb420 DB** to match + add a plate
  comment pointing to the reconstructed file (DB = live cross-reference).
  (Ghidra's PascalCase lint warnings are advisory; readable names kept.)
- Obj-C methods keep real selectors + cite address: `// -[Class sel] @ 0xADDR`.
- File extensions: `.m` pure ObjC · `.mm` ObjC++ · `.cpp` C++ · `.h` all headers.
- Use dot syntax for property/getter calls incl. class getters
  (UIDevice.currentDevice, arr.count, results.lastObject); brackets only for
  arg-taking / side-effecting calls.
- Includes grouped (blank line, no labels): standard / 3rd-party+Apple /
  project; each alphabetical (ASCII case-sensitive).
- Null literals: ObjC objects -> nil; .mm/.cpp C-pointers -> nullptr; C (.c) ->
  nullptr. Targets: C23 and C++23. Decimal literals except bitwise masks (hex).
- Header guards: `#pragma once` (C++), `#ifndef UPPERCASE_NAME_H` (pure C),
  none for ObjC (`#import`).
- Naming = original: System C++ uses lowercase `ne` prefix; Game classes are
  PascalCase. Recover real names from embedded debug/assert strings + RTTI
  (NOT invented) — e.g. neIGLES, NoteMng, CharaData, SugorokuMap found this way.
- Mirror the ORIGINAL tree under Project/ (from __FILE__ strings; see below).
- Every Obj-C `.h` ends with Kate + vim + VSCode modelines:
  `// kate: hl Objective-C;` / `// vim: set ft=objc :` / `// code: language=Objective-C`
  (Obj-C++ bridge headers use Objective-C++ / objcpp variants).
- Verify scalar-vs-`NSNumber` and types from call sites, not assumptions
  (lesson: Core Data numeric attrs turned out NSNumber-backed, not scalar).

## Status legend

`[x]` done · `[~]` in progress · `[ ]` todo · `[import]` 3rd-party, import only

## Core Data models (Models/) — ground truth from ScoreData.momd

- [x] ScoreData
- [x] OverScoreData
- [x] ArcadeScoreData
- [x] TreasureData  (entity; NOT the analytics SDK)
- [x] CharaTicketData

## Third-party — functional libs (import only — do not reconstruct)

- [import] TouchJSON — CJSONDataSerializer, CJSONDeserializer, CJSONScanner,
  CJSONSerializer, CSerializedJSONData, CDataScanner
- [import] ZipArchive — UnZipArchive

## Ad / analytics — STUB or ELIMINATE (do not import, do not ship)

- [ ] Stubs/TreasureDataSDK — no-op analytics stub (SDK classes, distinct from
      the CoreData entity which is already done)
- [ ] Stubs/RewardNetwork — no-op ad-reward stub covering RewardNetwork,
      RewardNetworkError, RewardNetworkIndicator, RewardNetworkMessage,
      RewardNetworkPasteBoard, RewardNetworkURLConnection, RewardNetworkUdid,
      RewardNetworkUtilities, RewardNetworkWebAPI, RewardNetworkWebViewController
- [ ] ASIdentifierManager / AdSupport (IDFA) — eliminate at call sites
- Note: app-own `Recommend*` classes are still reconstructed, but their ad/net
  calls are neutralized to no-ops.

## App classes to reconstruct (Classes/)

### App lifecycle / entry
- [x] AppDelegate   (Project/AppDelegate.{h,mm}) — COMPLETE: launch, lifecycle,
      Core Data stack, push registration, + appDelegate/appDocumentsDirectory/
      freeFileSystemSize/uuId (keychain CFUUID)/initHardware/isOldHardware/
      hardwareType/displayType. RewardNetwork ad call neutralized. Engine calls
      via neEngineBridge.h (startBootTask/onResignActivePushHook/notifyEnterForeground
      + appAppSupportDirectory). kHardwareModels[40] filled from DAT_00130574. COMPLETE.
- [ ] Init
- [~] MainViewController — Project/MainViewController.{h,mm}. UIKit<->engine
      bridge: CADisplayLink loop (StartLoop/Pause/Resume/SetLoopInterval/Create/
      RemoveTimer/mainLoop/isPause/isLoop verified) -> task (dt-update all C_TASK
      via neTaskManagerUpdate + reap) + draw (neGLView BeginRender -> clear ->
      AepManager draw -> Present; frame-limited by m_RenderTime). Pending: init/
      viewDidLoad (glView + AepManager setup), capture:, screenshot path.

## *** GRAPHICS / ENGINE C++ CORE — the heart of the app (LARGEST work area) ***

The app is a HYBRID: UIKit view controllers drive the menu/network/store UI,
but all gameplay + animated screens run on a bespoke **C++ OpenGL ES 1.1 engine
and a Task/scene framework**. This is the bulk of the codebase by logic and was
badly under-scoped earlier. C++ impl in .cpp / Obj-C++ bridges in .mm. Real
class names recovered from RTTI type_info + Obj-C type-encoding strings.

- [x] neEngineBridge.h — provisional C++ bridge the ObjC layer calls (ne* names).
      Its singletons still need real bodies (Ghidra renames done):
      NEAppEventCenter (FUN_0000b150/28c70/28c9c), NESceneManager (FUN_0000b194/
      2c5c0/2c5b8), NEGraphics_configure (FUN_00012368), NEEngine_bootstrapB/C
      (FUN_0001ba2c/1796c), onWillResignActive/2, onDidEnterBackground
      (FUN_b278/b35c/1bdf8), stopMainTask/stopAcMainTask (FUN_00030710/2314c),
      foreground observer walk (FUN_000188ac, head @ DAT_00188464).

### ne render engine — Project/System/src/{OpenGL,Render}
- [x] ne::neGLES_11 (System/src/OpenGL/neGLES11.{h,cpp}) — GL ES 1.1 abstraction.
      ALL enum<->GL tables now DECODED BYTE-FOR-BINARY from the __const region and
      cited per-table in-code (no more standard-order guesses). Verified tables:
      RenderKind (DAT_0012e110, FBO OES COLOR/DEPTH/STENCIL attach); MatrixMode
      (DAT_0012e11c + default GL_MODELVIEW 0x1700; 4-value enum over a 3-entry
      table — see setMatrixMode 0x13110); CompareFunc shared depth/alpha
      (DAT_0012e130, GL_NEVER..GL_ALWAYS); TexParamValue (DAT_0012e150);
      BlendSrc 9 (DAT_0012e170) / BlendDest 8 (DAT_0012e1a0) + equation ->
      glBlendEquationOES (setBlendFunc 0x13a34, now 3-arg); CullFace (DAT_0012e1c0);
      EnableState 35 caps (DAT_0012e1d0, alphabetical, no STENCIL_TEST);
      ClientState 8 arrays (DAT_0012e25c); FogMode LINEAR/EXP/EXP2 (DAT_0012e27c);
      Hint 5 (DAT_0012e290); TexParamType (DAT_0012e2d0). Method bodies verified:
      setMatrixMode (0x13110), deleteBuffer (0x13290, clears cached bindings at
      ivars 0x44/0x50/0x5c/0x6c + 8-slot tex array 0xb4), setBlendFunc (0x13a34),
      texImage2D (0x13970), get/setTexParameter (0x138cc/0x13864),
      RenderKindToGL (0x12f64). Ghidra: those 6 renamed + plate-commented, saved.
      Only two labeled INFERENCES remain (no DAT table exists — stated in-code):
      RenderType renderbuffer storage formats (pair 1:1 with RenderKind) and
      FrontFace CW/CCW (2 legal values, mapped inline). Note: the small-int
      permutation table @ DAT_0012e2b0 {0,3,2,1,5,6,4} is NOT part of this class's
      enum set (left unidentified rather than guessed).
- [ ] neTextTexture (System/src/Render/neTextTexture.mm) — CreateNewTextTexture.
- [ ] neTextureForiOS (.mm) — GL texture from image; 0x18-byte C++ obj, ctor
      FUN_00011818, load-from-path FUN_00011a2c.
- [~] neGLView — Project/System/src/Render/neGLView.{h,mm}. TOUCH BRIDGE done:
      touchesBegan @ 0x285e8 / touchesEnded @ 0x28850 -> engine input
      (neTaskInputTouchBegan FUN_000124f8 / TouchEnded FUN_000125ec / ClearTouches
      FUN_00012698; coords 16.16 fixed). layerClass=CAEAGLLayer. Render methods
      (BeginRender/SetDefaultFrameBuffer/SetDefaultColorBuffer/Present) declared;
      EAGL framebuffer bodies pending.
- [ ] neWindow (.mm) — UIWindow subclass hosting the GL view.
- [ ] Graphics manager singleton (@ DAT_00188384, 0x8c bytes; NEGraphics_configure
      @ FUN_00012368) — creates sprite/text/sound handles: FUN_0000fac8/f9cc/
      fb40 (create by name), FUN_0000fb8c, FUN_0000f758/f9b0, FUN_0000f1ec/f498/f4a4.
- [ ] Sprite/renderable object (0x60 bytes; ctor FUN_0002c7d8, init-with-tex
      FUN_0002c834).

### Aep 2D scene / animation system — Project/System/src/Aep
- [~] AepManager (System/src/Aep/AepManager.h) — INTERFACE done: loadAepData,
      draw (FUN_0001058c: screen-transition fade then ordering-table draw),
      orderingTable(). Concrete obj is huge (embeds OT @ +0x727538 + all sprite/
      texture slots @ +0x7f3xxx = the global scene). Pending: storage + .mm body.
- [~] AepOrderingTable (System/src/Aep/AepOrderingTable.h) — INTERFACE done:
      addLayer/draw (FUN_000115d0)/drawnCount (FUN_000117dc)/drawLayer/clear.
- [~] AepLyrCtrl (System/src/Aep/AepLyrCtrl.h) — struct done from ctor
      (FUN_0002c7d8, 0x60B: links/texId(-1)/pos xyz/size 100x100/alpha 1.0/
      flags); init(group,name) = FUN_0002c834. Pending: draw + transform roles.
- [x] AepTexture — Project/System/src/Render/AepTexture.{h,cpp}. 0x18B texture:
      ctor FUN_00011818, load FUN_00011a2c (neDecodeImage FUN_0001bbf0 -> w/h,
      neUploadGLTexture FUN_000166ec). Pending: image-decode + GL-upload helper bodies.
- NOTE: concrete Task subclasses (TitleTask "9TitleTask" typeinfo @ 0x131090,
      MainTask, MusicSelTask, ResultTask, SugorokuMainTask) need C++ vtable/RTTI
      analysis (typeinfo -> vtable -> ctor/update/draw); distinct sub-effort.

### Task / scene framework (C++) — Project/Game/Task (+ engine base)
Each screen is a C++ Task over base **C_TASK**, each with a big per-screen
WorkStruct (contains AepManager*, AepLyrCtrl[]/AepTexture[] arrays, JacketStruct,
MusicInfoStruct, RECT_GCU, ...). Driven by MainViewController's loop
(SetLoopInterval:/StartLoop/PauseLoop/ResumeLoop/mainLoop).
- [~] C_TASK base — Project/System/src/Task/C_TASK.{h,cpp}. Scheduler = single
      PRIORITY-SORTED linked list (head @ DAT_00188468); setPriority (FUN_00027f08)
      unlinks + re-inserts sorted; ctor FUN_0002af58 (base FUN_00027ea8) + vtable
      @ PTR_FUN_0002b02c. Layout: vtable/prev/next/priority/4x link/name/active/
      transform. Pending: task manager frame-walk (update/draw dispatch),
      mainTask/acMainTask wiring (AppDelegate _mainTask/_acMainTask).
      Render primitives noted: texture obj (0x18B, ctor FUN_00011818, load
      FUN_00011a2c -> FUN_0001bbf0 image load); sprite/AepLyrCtrl (0x60B, ctor
      FUN_0002c7d8: pos xyz / size 100x100 / alpha 1.0 / flags; init FUN_0002c834).
- [ ] MainTask (RTTI "8MainTask"), AcMainTask ("10AcMainTask")
- [ ] TitleTask ("9TitleTask"), ModeSelTask, MusicSelTask, ResultTask
      ("10ResultTask"), SugorokuMainTask ("16SugorokuMainTask",
      Game/Task/SugorokuMainTask.mm; setup @ FUN_0009fc90 — huge, layout-heavy)
- [ ] launch task obj: operator_new(0x4c) + FUN_0002af58 + FUN_00027f08(obj,3)

### Gameplay note management — Project/Game/Note
- [ ] NoteMng (NoteMng.mm), AcNoteMng (AcNoteMng.mm) — falling-note logic.

### Sound engine — Project/System/src/Sound
- [ ] caplayer (caplayer.mm) — CoreAudio AUGraph player (CAComponent
      prepareGraph/preparePlayer/setPlayerVolume).

### Shared engine structs (define once, used across tasks)
- [ ] C_TASK, per-task WorkStruct, JacketStruct, MusicInfoStruct, RECT_GCU,
      AepTexture, AepLyrCtrl (all recoverable from the Obj-C type-encoding blobs
      @ ~0x10355f / 0x1091ed / 0x12af38).
- [ ] Random.cpp (Project/Game/Util/Random.cpp)

### Audio
- [~] AudioManager — Project/System/src/Sound/AudioManager.{h,mm}. CORE done:
      sharedManager (@synchronized singleton @ 0x1dea0), systemStartBlock/Suspend/
      Resume, pushBgm/popBgm/isPushBgm (BGM duck stack), playSe:resourceId: (group
      0 = C++ caplayer, else AVFoundation). Pending bodies: onStartPlayer:/
      suspendPlayer:/resumePlayer:/onPauseBgm:/releaseBgm/getGroupID:resourceId:/
      prepare:resourceId:volume:/loadBgm:isLoop:/setBgmVolume:/stopBgm:/loadSe:...
- [ ] AVBus
- [ ] SoundSettingView
- [ ] caplayer (C++ CoreAudio AUGraph SE player; sePlayer backend; System/src/Sound)

### Data models / info (plain objects, not Core Data)
- [~] MusicManager — Project/Game/Data/Music/MusicManager.{h,m}. Singleton +
      getMusicData/AcMusicData/arrays, getMusicDataFilename (%09d.orb),
      createMusicDataArray (defaults+purchased+treasure/invite/collabo/loginBonus
      + lv patches), loadPurchasedMusics (Blowfish/BFCodec, keyed by uuId).
      createAcMusicDataArray @0xcaabc + createMusicLvPatchArray @0xcb610 DONE
      (rhythmin.lv JSON level patches), getAcPathFromPurchased: added,
      kTreasureMusicIds filled. File marker-clean. Deps done (MusicData/AcMusicData/
      MusicPatch/BFCodec). Remaining: -init population of m_DefaultMusicIDs /
      m_AcDefaultMusicIDs (populated by unlock logic elsewhere; not a stub).
- .orb decode chain DONE for MusicData + AcMusicData: .orb is a ZIP; the "info"
  entry (name @ 0x137a78) is BFCodec-decrypted. Key = MD5(deobfuscated 25-byte
  const), where deobfuscation is byte+index -> "Popn Orbit Note. xjr1300.".
  getZipData:Path:[DecodeType:] + decodeBF:Key:KeyLength: reconstructed.
  Still pending: kana initial tables (GetYomiIndex/String, GetGyoIndex/Name).
- [x] MusicData — Project/Game/Data/Music/MusicData.{h,m}. Full fields +
      dataWithPath:ID: (zipped-JSON .orb parse, level validation N/H 1-10 Ex 1-11,
      kana yomi initials) + setLevelN:H:Ex: + MusicID. Pending helper bodies:
      getZipData:Path:DecodeType:, GetYomiIndex:/GetYomiString:, rhythmin_parseJSON
      (FUN_0005c258), .orb key literal @ 0x137a78.
- [x] MusicPatch — Project/Game/Data/Music/MusicPatch.{h,m} (atomic scalar rec).
- [x] AcMusicData — Project/Game/Data/Music/AcMusicData.{h,m}. Full fields +
      dataWithPath:ID: (BPMs are strings; category clamp 0..23; gyo initials).
      Pending: getZipData:Path:, GetGyoIndex:/GetGyoName:.
- [x] BFCodec — Project/System/src/Util/BFCodec.{h,m}. **NON-STANDARD** Blowfish
      (F = (S0+S1)^(S2+S3), not the textbook form) — CBC + [origLen][paddedLen]
      trailer. Verified against reference project ~/dev-paused/bfcodec (src/
      bfcodec.c), confirmed to decode this game's .orb/mulist. key = MD5(uuId),
      IV = E3 66 31 DA 2C 85 A0 64 (fixed). P/S init = standard pi constants
      (DAT_0012f6c8 / DAT_0012e6c8 == bfcodec bf_init_bytes.inc), referenced.
- [x] RhUtil — Project/System/src/Util/RhUtil.{h,m}. RhParsePlistDict (0x5c258),
      RhParsePlistArray (0x5c330), RhFileExists (0x5c434), RhMD5Data (FUN_0005b4b8).
      NOTE: .orb / mulist payloads are PROPERTY LISTS (not JSON). MusicData/
      AcMusicData/MusicManager now use these. (FUN_0005b4b8 kept as FUN_ name:
      DB linter rejects RhMD5* vs RhMD5.)
- REFERENCE: ~/dev-paused/bfcodec is the user's RB-derived Blowfish+archive
    toolkit — reuse its constants/logic (IV, init bytes, key=MD5(uuid), .orb zip
    handling) rather than re-deriving. Confirmed working against real .orb files.
- [x] CharaInfo — Project/Game/Data/Chara/CharaInfo.{h,m} (charaId/charaName/
      skillId/skillName; charaId+skillId atomic scalar)
- [x] LimitedCharaInfo — Project/Game/Data/Chara/LimitedCharaInfo.{h,m} (charaIds)
- [x] PreferredCharaInfo — Project/Game/Data/Chara/PreferredCharaInfo.{h,m}
      (musicIds + charaIds)  [CharaInfo family corrected: CharaInfo also has
       info/rarity; Preferred/Limited also have musicIds — from loader @ 0xb85bc]
- [x] CharaData — Project/Game/Data/Chara/CharaData.{h,mm} COMPLETE. All 30
      built-in characters extracted from the Mach-O __cfstring table (name/info/
      skillName constant NSStrings — mostly UTF-16, entry 24 skillName 8-bit
      "Hello World!"), plus skillId + rarity(100/70/50). Struct {NSString* name,
      info, skillName; short skillId, rarity} @ 0x133298. Every Japanese string
      has an inline English translation. Ghidra: GetHardCodeCharaDataStruct
      @ 0xcb958 renamed + plate-commented, saved.
- [x] SkillData — Project/Game/Data/Chara/SkillData.{h,mm} (renamed .cpp->.mm to
      match assert path SkillData.mm:199). COMPLETE: two-level layout fully
      decoded. Outer table @ 0x133478 = 30x{const Skill*, int weight}; inner Skill
      objects @ 0x13aa48 = 30x{vtable(bss 0x1a7800), int base=2000, char16_t*
      jp-desc, int len}; 30 UTF-16 Japanese descriptions @ 0x12d9c0 extracted from
      the Mach-O (all lens verified == char count) with English translations added.
      Skill class + 30 instances + weighted table reconstructed. Ghidra:
      GetSkillDataStruct @ 0xcb9d0 renamed + plate-commented, saved.
- [ ] CharaManager/loader (FUN_000b85bc) — builds CharaInfo[] from CharaData +
      downloadable chara_%03d.chr files (FUN_0005c508 decode + JSON: Preferred/
      Limited/Chara). Big; pending.
- [x] UserSettingData — Project/Game/Data/Save/UserSettingData.{h,mm}
      Full class: NSUserDefaults primitives (get/save Int/Float/String/BOOL/Data),
      AES-128 Crypt109 blob reader/writer + full Crypt109Data struct (36 bytes),
      all field accessors, gotChara/gotCharaArray/saveGotCharaArray:, all *108
      legacy readers, effects, load/saveSettingData (incl. v108->v109 migration
      and touch-sound/treasure reconciliation). .mm (syncs neAppEventCenter).
      Ghidra: FUN_000a218c renamed neSugorokuTouchSoundBit; plate docs on
      loadSettingData/crypt109Data:/neSugorokuTouchSoundBit.
- [x] NSData+Crypt (Project/System/src/Util/NSData+Crypt.{h,m}) — AES-128-CBC
      category (behavioral; real body was thunk-only @ 0x1a0506/0x1a1202).
- [x] neEngineBridge.h — provisional C++ singleton interface (ne* names).
- [x] ScoreData Core Data helpers — Models/ScoreData+Store.{h,m}
      (getScoreData:/recordWithMusicId:/getAllScoreData:/reset:/checkScore:/
       hashScore:/hashScoreForTune:...). chksco = MD5 of 8 mixed int32s.
- [x] RhCrypto.{h,c} — RhMD5 (FUN_0005b484, CommonCrypto CC_MD5 wrapper)
- [x] OverScoreData helpers — Models/OverScoreData+Store.{h,m} (0xba0a4…0xba8d8)
- [x] ArcadeScoreData helpers — Models/ArcadeScoreData+Store.{h,m} (0xcea60…,
      -reset @ 0xcf220). isOpenMusic-adjacent sort orders noted.
- [x] TreasureData helpers — Models/TreasureData+Store.{h,m} (0xc088c…, isOpenMusic
      @ 0xc0d90 = >8 music-piece bits map-wide, -reset @ 0xc0c9c)
- [x] CharaTicketData helpers — Models/CharaTicketData+Store.{h,m} (0xe2c6c…0xe3048)
      ==> ALL Core Data category helpers done.

### Networking / download
- [ ] HttpConn
- [ ] Downloader
- [ ] DownloadMain
- [ ] DevDataDownloader
- [ ] ImageDownloader
- [ ] DownloadImageView
- [ ] DelayImageView
- [ ] DownloadProgresView
- [ ] DefaultDataDownloadView
- [ ] BFCodec

### Arcade Viewer (Ac*)
- [ ] AcViewerSplitViewController
- [ ] AcViewerCategoryViewController / AcViewerCategoryCell
- [ ] AcViewerMusicViewController / AcViewerMusicCell
- [ ] AcViewerDetailCell
- [ ] AcViewerOptionViewController / AcViewerOptionCell
- [ ] AcViewerHiSpeedViewController
- [ ] AcViewerHidSudViewController
- [ ] AcViewerPopKunViewController
- [ ] AcViewerRanMirViewController

### Checker
- [ ] CheckerCategoryViewController / CheckerCategoryCell
- [ ] CheckerMusicViewController / CheckerMusicCell
- [ ] CheckerDetail

### Store
- [ ] StoreMainViewController / StoreViewController
- [ ] StoreDetailViewController / StoreDetailHeaderView / StoreDetailMusicCell / StoreDetailCopyrightCell
- [ ] StoreManageViewController / StoreAcvManageViewController
- [ ] StorePackListController / StorePackView / StorePackMusicView / StorePackCell / StorePackDetailViewPad
- [ ] StorePromotionView / StorePromotionTableCell
- [ ] StoreTableCell / StoreImageView / StoreDialogView
- [ ] StoreDownloadManager / StoreDownloadTask / StorePackInfoDownloader
- [ ] StoreMusicInfo / StoreAcMusicInfo / StorePackInfo
- [ ] StoreUtil

### Purchase (StoreKit)
- [ ] PurchaseManager
- [ ] PurchaseStore
- [ ] PurchaseTransactionCache

### Friends / social
- [ ] FriendMngTopViewController / FriendMngTopSplitViewController
- [ ] FriendListViewController / FriendListCell / FriendListDetail / FriendListDetailChara
- [ ] FriendReplyViewController / FriendReplyCell
- [ ] FriendRequestViewController / FriendRequestCell / FriendRequestTable
- [ ] FriendScoreMainView / FriendScoreTableCell
- [ ] FreeRequestListViewController / FreeRequestListCell / FreeRequestDetail
- [ ] TwitterUtil

### Invite / link / codes
- [ ] InviteTopViewController / InviteTopViewControllerPad
- [ ] MyInviteCodeViewController
- [ ] PopnLinkTopViewController / PopnLinkTopSplitViewController
- [ ] InputKidViewController / InputKIDViewCtrl
- [ ] InputOTPViewCtrl
- [ ] InputNameViewCtrl
- [ ] InputConversionPassViewController
- [ ] ConversionView

### Map / sugoroku
- [ ] MapSelectViewController / MapSelectSplitViewController / MapListCell
- [ ] SubMapSelectViewController / SubMapListCell
- [ ] MapAnnotation

### Login bonus / present / quiz
- [ ] LoginBonusView / RandomLoginBonusView
- [ ] PresentBoxViewController / PresentBoxCell
- [ ] QuizMainViewController / QuizCell

### Settings
- [ ] SettingTopViewController
- [ ] SettingTableViewController / SettingTableSplitViewController
- [ ] SettingGameTableViewController
- [ ] SettingCustomerTableViewController
- [ ] SettingHowtoTableViewController
- [ ] SettingOtherTableViewController

### Recommend (cross-promo)
- [ ] RecommendCore / RecommendNetwork / RecommendAdId
- [ ] RecommendViewController / RecommendListCell
- [ ] RecommendWebView / RecommendWebViewController

### Over-score log
- [ ] OverScoreLogViewController / OverScoreLogCell

### Policy / how-to / birthday
- [ ] AcceptPolicyViewController / PolicyView
- [ ] HowToViewCtrl / HowToViewCtrlPad / HowToView
- [ ] BirthDayViewController / YearAndMonthPicker
- [ ] PopkunSizeViewCtrl

### Custom UI widgets / utilities
- [x] CustomTextView — Project/CustomTextView.{h,m} (display-only UITextView:
      canBecomeFirstResponder=NO @ 0x28080, canPerformAction suppresses menu @ 0x28034)
- [ ] CustomButton / CustomWebView
- [x] CommonAlertView — Project/CommonAlertView.{h,mm} + CommonAlertViewDelegate.
      Custom modal (gradient card + CustomTextView msg + optional title + cancel/
      other buttons) shown over root scene view. init @ 0x4a350 (view-builder;
      exact pixel/color consts @ DAT_0004a7xx/4b4xx are placeholders), show
      @ 0x4b4cc, isVisible @ 0x4bb9c verified. Pending: startOpenAnimation, exact
      frames. Delegate commonAlertView:clickedButtonAtIndex: (impl by ~25 VCs).
- [ ] CustomAlertView  (sibling; customAlertView:clickedButtonAtIndex:)
- [ ] CustomSplitViewController
- [ ] TouchableScrollView / TouchableTableView
- [ ] TouchRangeView / TouchRangeViewCtrl
- [ ] SearchView / SortSelectViewController / SortCell
- [ ] CommunicatingView
- [ ] GameEffectView
- [ ] ViewUtility
- [x] SystemHardware — Project/System/src/SystemHardware.{h,m} (lazy hw.machine
      detect; 14-entry model table filled from DAT_001306ec). COMPLETE.

## Next steps

1. Reconstruct the Core Data fetch/insert helpers as categories on the entities
   (already located): ScoreData getScoreData:/recordWithMusicId: @ 0x6da30/0x6ded0
   (+ checkScore/reset), OverScoreData 0xba0a4…0xba8d8, TreasureData 0xc088c…,
   ArcadeScoreData 0xcea60…, CharaTicketData 0xe2c6c…0xe3048.
2. MusicManager (singleton, getInstance) + MusicData / AcMusicData / MusicPatch.
3. UserSettingData (loadSettingData + save* accessors used at launch).
4. Then MainViewController, then the ne engine core, then outward by subsystem.
5. Keep renaming FUN_* in Ghidra + updating this board after each class.
