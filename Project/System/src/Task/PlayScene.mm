//
//  PlayScene.mm
//  pop'n rhythmin
//
//  The two play-scene lifecycle seams the note-play state machine (PlayTask_update,
//  PlayTask.mm) drives at its endpoints: building the scene at state 0 and handing
//  off to the result screen at state 10. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin:
//
//    - PlayTaskInit        Ghidra: FUN_0002e2d8 (PlayTask_init)
//    - PlayTaskGotoResult  Ghidra: FUN_0003003c
//
//  The play data (`playData`) is the standard-mode MainTask, a large task struct not
//  yet reconstructed as a whole (PlayJudge.h's forward-declared MainTaskPlayData);
//  every field is reached by cited byte offset in the pd()/pdw() style PlayJudge.mm
//  established. The original FUN_0002e2d8 is a ~400-line megafunction; as PlayJudge.mm
//  does for the note-quad geometry, the asset-heavy repetitive units it calls into are
//  delegated to their own reconstruction seams (declared below) rather than re-derived
//  here: the song/BGM load (a separate binary function, FUN_00030720), the note-field
//  AepLyrCtrl construction + layer-handle table population, the chara-portrait texture
//  loading, and the per-frame draw hook (FUN_00030944). This file carries the verified
//  lifecycle control flow and the cited play-data field initialisation / teardown.
//
//  DISCREPANCY (followed the binary): the handles at +0x84/+0x88/+0x8c and the
//  +0x98..+0xc0 block are NOT audio SE instances (as PlayJudge.mm/PlayScore.mm label
//  them) but AepLyrCtrl animation layers, created here via operator new(0x60) +
//  AepLyrCtrl::init. +0x84 = "EFF_COM_025CMB" (25-combo effect), +0x88 = "EFF_COM_050CMB",
//  +0x8c = "EFF_COM_100CMB", +0x90 = "ARE_YOU_READY", +0x94 = "PAUSE" (byte-verified from
//  the layer-name table @ 0x103a22). The milestone "SE" play in PlayJudge is really the
//  combo-effect layer's animation restart (AepLyrCtrl fields +0x40 frame / +0x44 alpha /
//  +0x58 play-state). The actual play SEs are the three loaded at the tail (+0x3a8..+0x3b0)
//  plus the tap-feedback SE (+0x398, loaded by the song-load seam).
//

#import <Foundation/Foundation.h>

#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "MusicData.h"
#import "MusicManager.h"
#import "NoteMng.h"
#import "PlayJudge.h"        // MainTaskPlayData (fwd) + NoteJudgeState (judge pool)
#import "PlayTask.h"         // PlayTaskInit / PlayTaskGotoResult / PlayCurrentScore
#import "TaskFactory.h"      // MainTaskCreate / PlayResultCreateTask
#import "UserSettingData.h"
#import "neEngineBridge.h"   // neAppEventCenter / neSceneManager
#import "neTextureForiOS.h"
#include "C_TASK.h"

// --- Play-scene sub-unit seams ---------------------------------------------------
// These belong in PlayTask.h next to PlayTaskInit / PlayTaskGotoResult, but that
// header is out of scope for this change, so they are declared here (real, non-extern
// declarations) and each has its own reconstruction unit (see the report). They are
// the asset-heavy blocks the original FUN_0002e2d8 calls into.

// Ghidra: FUN_00030720. Load the chosen song's BGM (async), parse its sheet into the
// global NoteMng play data (NoteMng_initPlayDataWithData), and load the per-tap
// feedback SE into play data +0x398 at the user's touch-sound volume. `reload` != 0
// reparses the chart only (the state machine's mid-play reload), skipping the audio.
// Defined at the foot of this file.
void PlayLoadSong(void *playData, int reload);

// Build the 16 note-field AepLyrCtrl layers (+0x84..+0xc0), position them per display
// type, and resolve every note / combo-digit / tone / chara-animation layer handle
// (AepManager::getLyrNo + layerFrameCount) into the play-data handle tables at
// +0xc4..+0x378 and +0x154/+0x168. Ghidra: the AepLyrCtrl creation + getLyrNo loops
// in FUN_0002e2d8.
void PlayBuildFieldLayers(void *playData);

// Load the character-portrait / window / text-panel textures into the play data
// (+0x2c window, +0x30[] portraits, +0x50[] text panels), random-picking unlocked
// characters in normal mode. Ghidra: the neTextureForiOS load block in FUN_0002e2d8.
void PlayLoadCharaTextures(void *playData);

// The play scene's per-frame draw hook, registered through the Aep manager.
// Ghidra: FUN_00030944.
void PlayTaskDraw(void *context);

// Clear the note manager's active-play flag on teardown. Ghidra: FUN_0003395c
// (a single store of 0 to NoteMng + 0x13cb6). Defined at the foot of this file.
void PlayNoteMngDetach(NoteMng *nm);

// --- Play-data field access ------------------------------------------------------
// Same convention as PlayJudge.mm / PlayScore.mm: the standard-mode MainTask is not
// reconstructed as a whole, so its fields are reached by documented byte offset.
namespace {

inline const char *pd(const void *p) { return reinterpret_cast<const char *>(p); }
inline char       *pdw(void *p)      { return reinterpret_cast<char *>(p); }

inline int           &pdInt(void *p, int off)   { return *reinterpret_cast<int *>(pdw(p) + off); }
inline float         &pdFloat(void *p, int off) { return *reinterpret_cast<float *>(pdw(p) + off); }
inline short         &pdShort(void *p, int off) { return *reinterpret_cast<short *>(pdw(p) + off); }
inline unsigned char &pdByte(void *p, int off)  { return *reinterpret_cast<unsigned char *>(pdw(p) + off); }
inline void          *&pdPtr(void *p, int off)  { return *reinterpret_cast<void **>(pdw(p) + off); }

// Score -> rank index (0 best .. 6 worst). Ghidra: FUN_00028a40.
int scoreToRank(int score) {
    if (score >= 100000) return 0;
    if (score >= 98000)  return 1;
    if (score >= 95000)  return 2;
    if (score >= 90000)  return 3;
    if (score >= 80000)  return 4;
    if (score >= 70000)  return 5;
    return 6;
}

// Destroy an array of scene textures held by pointer at `base`+i*4 (guards nulls,
// nulls the slot). Ghidra: the (**(vtable+4))() deleting-dtor loops in FUN_0003003c.
void destroyTextureArray(void *playData, int base, int count) {
    for (int i = 0; i < count; ++i) {
        void *&slot = pdPtr(playData, base + i * 4);
        if (slot != nullptr) {
            delete reinterpret_cast<neTextureForiOS *>(slot);
            slot = nullptr;
        }
    }
}

// Destroy an array of AepLyrCtrl layers held by pointer at `base`+i*4. The binary
// calls AepLyrCtrl_unlink (FUN_0002ca9c) then the deleting dtor; the reconstructed
// ~AepLyrCtrl folds the draw-list unlink in, so delete alone matches.
void destroyLayerArray(void *playData, int base, int count) {
    for (int i = 0; i < count; ++i) {
        AepLyrCtrl *&slot = *reinterpret_cast<AepLyrCtrl **>(pdw(playData) + base + i * 4);
        if (slot != nullptr) {
            delete slot;
            slot = nullptr;
        }
    }
}

}  // namespace

// Ghidra: FUN_0002e2d8 (PlayTask_init) — allocate + initialise the note-play scene.
void PlayTaskInit(void *playData) {
    AepManager &aep = AepManager::shared();          // Ghidra: AepManager_shared
    neAppEventCenter &evc = neAppEventCenter::shared();  // NEAppEventCenter_shared
    pdPtr(playData, 0x968) = &evc;                    // +0x968 = the event-center singleton
    NoteMng &nm = NoteMng::shared();                  // force the note manager up

    AppDelegate *app = [AppDelegate appDelegate];     // AppDelegate_appDelegate
    [app setMainTask:playData];                       // register this task as the play task

    // Two cached screen-quad extents pulled out of the Aep transition region.
    pdInt(playData, 0x96c) = aep.transitionOverlayWidth();   // FUN_0000f498 (aep + 0x7f3afc)
    pdInt(playData, 0x970) = aep.transitionOverlayHeight();  // FUN_0000f4a4 (aep + 0x7f3b00)

    neSceneManager::shared();
    pdFloat(playData, 0x974) = neSceneManager::screenScale();  // +0x974 play scale (DAT_00187b80)

    // User settings driving the note field / judge.
    pdShort(playData, 0x9b4) = [UserSettingData touchSoundVolume];         // +0x9b4
    pdByte(playData, 0x9e4)  = [UserSettingData isSimpleMode] ? 1 : 0;     // +0x9e4
    pdByte(playData, 0x9e5)  = [UserSettingData isEffectOn] ? 1 : 0;       // +0x9e5
    pdByte(playData, 0x9e6)  = [UserSettingData isLongNotesEffectOn] ? 1 : 0;  // +0x9e6

    // Note ("popkun") size -> 16.16 fixed. Ghidra: FPToFixed(popkunSize).
    pdInt(playData, 0x9bc) = (int)([UserSettingData popkunSize] * 65536.0f);  // +0x9bc

    // The bundled-demo / sugoroku play flag, copied out of the event center (+0x33).
    pdByte(playData, 0x9c9) = (unsigned char)pd(&evc)[0x33];  // +0x9c9

    pdByte(playData, 0x9e7) = [app isOldHardware] ? 1 : 0;              // +0x9e7
    pdByte(playData, 0x9ca) = neSceneManager::isPadDisplay() ? 1 : 0;   // +0x9ca (DAT_00187b84)

    // Load the song's BGM + parse its chart into NoteMng + load the tap SE (+0x398).
    PlayLoadSong(playData, 0);   // Ghidra: FUN_00030720 (reload = 0: full first load)

    // Gauge / score bookkeeping. +0x9cc is the per-note gauge weight: a fixed 3072-unit
    // budget (DAT_0002e768 == 3072.0) spread across the chart's playable-note total.
    pdShort(playData, 0x9ac) = 0;                                          // +0x9ac (DAT_00178d00)
    pdFloat(playData, 0x9cc) = 3072.0f / (float)nm.totalNoteCount();       // +0x9cc
    pdInt(playData, 0x9d0)   = 0x3f800000;                                 // +0x9d0 = 1.0f
    pdInt(playData, 0x9d4)   = (int)0xc2088889;                            // +0x9d4 = -34.1333f
    pdShort(playData, 0x9c0) = 0;                                          // +0x9c0

    // Per-display note-field geometry + the common AEP layer group.
    if (pdByte(playData, 0x9ca) == 0) {   // phone
        pdInt(playData, 0x98c) = 0x24e;
        pdInt(playData, 0x990) = 0x32;
        pdInt(playData, 0x994) = 0x40;
        pdInt(playData, 0x998) = 0x3fe;
        pdInt(playData, 0x99c) = 0x4a;
        pdInt(playData, 0x9a0) = 0x82;
        pdInt(playData, 0x9a4) = -0x44;      // 0xffffffbc
        pdInt(playData, 0x97c) = 0x194;
        pdInt(playData, 0x980) = 0x248;
        pdInt(playData, 0x984) = 0x306;
        pdInt(playData, 0x988) = 0x5e;
        pdInt(playData, 0x9b8) = 0x43080000; // +0x9b8 hit radius = 136.0f
        pdInt(playData, 0x9a8) = 0xc4;
        pdInt(playData, 0x9e0) = 500;
        AepLoadGroup(&aep, 0, "game_cmn");
    } else {                              // pad
        pdInt(playData, 0x98c) = 0x590;
        pdInt(playData, 0x990) = 0x7e;
        pdInt(playData, 0x994) = 0x40;
        pdInt(playData, 0x998) = 0x666;
        pdInt(playData, 0x99c) = 0x76;
        pdInt(playData, 0x9a0) = 0xb2;
        pdInt(playData, 0x9a4) = -0x74;      // 0xffffff8c
        pdInt(playData, 0x97c) = 0x32e;
        pdInt(playData, 0x980) = 0x434;
        pdInt(playData, 0x984) = 0x53e;
        pdInt(playData, 0x988) = 0xb0;
        pdInt(playData, 0x9b8) = 0x43880000; // +0x9b8 hit radius = 272.0f
        pdInt(playData, 0x9a8) = 0x228;
        pdInt(playData, 0x9e0) = 1000;
        AepLoadGroup(&aep, 0, "game_cmn_ipad");
    }

    // Build every field layer (combo/ready/pause effects + note lanes) and resolve the
    // note/effect/tone/chara-anim layer-handle tables from the just-loaded group.
    PlayBuildFieldLayers(playData);

    // Three of the field layers draw additively: force their blend mode (+0x34) to 0x200.
    pdInt(*reinterpret_cast<void **>(pdw(playData) + 0x98), 0x34) = 0x200;
    pdInt(*reinterpret_cast<void **>(pdw(playData) + 0x9c), 0x34) = 0x200;
    pdInt(*reinterpret_cast<void **>(pdw(playData) + 0xa0), 0x34) = 0x200;

    // Initialise the 60-entry judge-state pool: each slot's persistent layer id is its
    // index; the note-binding fields stay zero (free). Ghidra: the +0x3c8 stride-24 loop.
    NoteJudgeState *judge = reinterpret_cast<NoteJudgeState *>(pdw(playData) + 0x3c8);
    for (int i = 0; i < 60; ++i) {
        judge[i].layerId = i;
    }

    // Character-portrait / window / text-panel textures.
    PlayLoadCharaTextures(playData);

    // Install the scene's per-frame draw pass on group 0.
    aep.setGroupDrawCallback(0, &PlayTaskDraw, playData);  // FUN_0000f9b0 / FUN_00030944

    // Load the three play SEs into +0x3a8/+0x3ac/+0x3b0 (v12/v13/v14 .m4a). Ghidra: the
    // loadSe:isLoop:callName:group: loop at the tail.
    AudioManager *audio = [AudioManager sharedManager];
    static const char *const kPlaySeNames[3] = {"v12", "v13", "v14"};
    for (int i = 0; i < 3; ++i) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@(kPlaySeNames[i]) ofType:@"m4a"];
        RSND_SOURCE_ID src = [audio loadSe:path isLoop:NO callName:nil group:0];
        pdInt(playData, 0x3a8 + i * 4) = (int)src;
    }
}

// Ghidra: FUN_0003003c — tear down the play scene and hand off to the result screen.
void PlayTaskGotoResult(void *playData) {
    NoteMng &nm = NoteMng::shared();                  // Ghidra: NoteMng_shared
    AepManager &aep = AepManager::shared();           // AepManager_shared
    AudioManager *audio = [AudioManager sharedManager];

    // Free the scene's cached textures (window / chara portraits / text panels).
    destroyTextureArray(playData, 0x28, 2);
    destroyTextureArray(playData, 0x30, 8);
    destroyTextureArray(playData, 0x50, 13);

    // Tear down the field layers (unlink from the draw list + delete).
    destroyLayerArray(playData, 0x84, 5);
    destroyLayerArray(playData, 0x98, 11);

    aep.unloadGroup(0);   // Ghidra: FUN_0000f988 — drop the common AEP group

    // Stop + release every SE this scene created: the three play SEs (+0x3a8..) and the
    // two gauge/tap SEs (+0x398..), then release the BGM.
    for (int i = 0; i < 3; ++i) {
        RSND_SOURCE_ID src = (RSND_SOURCE_ID)pdInt(playData, 0x3a8 + i * 4);
        [audio stopSe:(RSND_INSTANCE_ID)src];
        [audio releaseSe:nil resourceId:src];
    }
    for (int i = 0; i < 2; ++i) {
        RSND_SOURCE_ID src = (RSND_SOURCE_ID)pdInt(playData, 0x398 + i * 4);
        [audio stopSe:(RSND_INSTANCE_ID)src];
        [audio releaseSe:nil resourceId:src];
    }
    [audio releaseBgm];

    // Record the result into the event center for the result screen to read back —
    // unless the play was aborted (+0x9e8 set, e.g. quit from the pause menu).
    if (pdByte(playData, 0x9e8) == 0) {
        int cool = 0, great = 0;
        for (int k = 0; k < kNoteKindCount; ++k) {
            cool  += nm.judgeCount(k, NOTE_JUDGE_COOL);   // DAT_00179014 columns
            great += nm.judgeCount(k, NOTE_JUDGE_GREAT);  // DAT_00179010 columns
        }
        const int score = PlayCurrentScore();   // Ghidra: FUN_0002ff7c
        const int rank  = scoreToRank(score);    // Ghidra: FUN_00028a40

        neAppEventCenter *event = reinterpret_cast<neAppEventCenter *>(pdPtr(playData, 0x968));
        event->recordPlayResult(score, cool, great);      // Ghidra: FUN_0002930c
        pdInt(event, 0x18)   = nm.maxCombo();             // event +0x18 (DAT_00179004)
        pdShort(event, 0x14) = (short)rank;               // event +0x14
    }

    PlayNoteMngDetach(&nm);   // Ghidra: FUN_0003395c — clear the note-play active flag

    [[AppDelegate appDelegate] setMainTask:nullptr];   // deregister the play task
    pdByte(playData, 0x24) = 1;   // +0x24 = C_TASK m_killed (reap on next scheduler pass)

    // Spawn the next scene at priority 3: the result screen for a completed normal play,
    // else back to the music-select MainTask (aborted play, or the bundled/sugoroku path).
    C_TASK *next;
    if (pdByte(playData, 0x9e8) == 0 && pdByte(playData, 0x9c9) == 0) {
        next = PlayResultCreateTask();   // operator_new(0x3a0) + FUN_0003d5bc
    } else {
        next = MainTaskCreate();         // operator_new(0xaa8) + MainTask_ctor
    }
    next->setPriority(3);   // Ghidra: C_TASK_setPriority
    pdByte(playData, 0x9c7) = 1;   // +0x9c7 = hand-off complete
}

// The per-tap feedback SE resource name for a touch-sound kind (clamped to 0..9).
// Ghidra: FUN_0002c7a8 — a fixed "hit001".."hit010" table (the scene-manager argument
// the binary threads in is unused).
static NSString *TouchSeResourceName(int kind) {
    if ((unsigned)kind > 9) {
        kind = 0;
    }
    return [NSString stringWithFormat:@"hit%03d", kind + 1];
}

// Ghidra: FUN_00030720 — resolve the picked song, kick off the async BGM + tap-SE
// load on a first load, and parse the chosen difficulty's sheet into the note manager.
void PlayLoadSong(void *playData, int reload) {
    AudioManager *audio = [AudioManager sharedManager];
    NoteMng &nm = NoteMng::shared();

    MusicData *music;
    int sheetIndex;
    if (pdByte(playData, 0x9c9) == 0) {
        // Normal play: the event center carries the picked music id + difficulty.
        neAppEventCenter *evc = reinterpret_cast<neAppEventCenter *>(pdPtr(playData, 0x968));
        sheetIndex = evc->lastSheet();
        music = [[MusicManager getInstance] getMusicData:evc->lastMusic()];
    } else {
        // Bundled demo / sugoroku: the fixed bundled song, always the normal sheet.
        sheetIndex = 0;
        music = [MusicData dataWithPath:[MusicManager getPathFromBundle:0] ID:0];
    }

    if (reload == 0) {
        [audio stopBgm:0.0f];
        // Decode + start the BGM off the main thread so the parse below is not blocked
        // on the audio; flag it ready (@ +0x9c6) when done.
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSData *bgm = [music music];
            [audio loadBgmData:bgm isLoop:NO];
            [audio setBgmVolume:1.0f];
            pdByte(playData, 0x9c6) = 1;
        });
    }

    // Parse the chosen difficulty's sheet into the global note manager. The binary
    // also threads a per-note spawn callback and this play data as the two context
    // args; NoteMng::initPlayData does not consume them in this reconstruction, so only
    // the play-data context is forwarded.
    NSData *sheet = (sheetIndex == 2) ? [music sheetEx]
                  : (sheetIndex == 1) ? [music sheetHyper]
                                      : [music sheetNormal];
    nm.initPlayDataWithData(sheet, 0, (uint32_t)(uintptr_t)playData);

    if (reload == 0) {
        // The per-tap feedback SE, named by the user's touch-sound kind, at their
        // touch-sound volume.
        const int kind = [UserSettingData touchSoundKind];
        NSString *path = [[NSBundle mainBundle] pathForResource:TouchSeResourceName(kind)
                                                         ofType:@"m4a"];
        pdInt(playData, 0x398) = (int)[audio loadSe:path isLoop:NO callName:nil group:0];
        [audio setSeVolume:pdShort(playData, 0x9b4) groupId:0];
    }
}

// Ghidra: FUN_0003395c — the play scene releasing the note manager: clear its
// "play session active" flag (@ +0x13cb6) so a later app-resign does not try to
// pause a scene that is already tearing down.
void PlayNoteMngDetach(NoteMng *nm) {
    nm->setPlayActive(false);
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
