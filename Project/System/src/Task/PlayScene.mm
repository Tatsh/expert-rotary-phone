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

#include <cstdlib>           // rand / srand (Ghidra: _rand / _srand)
#include <ctime>             // time (Ghidra: _time)

#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "CharaManager.h"     // gCharaManager / CharaManagerShared (unlocked-chara pick)
#import "MusicData.h"
#import "MusicManager.h"
#import "NoteMng.h"
#import "PlayJudge.h"        // MainTaskPlayData (fwd) + NoteJudgeState (judge pool)
#import "PlayTask.h"         // PlayTaskInit / PlayTaskGotoResult / PlayCurrentScore
#import "RhUtil.h"           // RhFileExists / RhTestBitInNumberArray
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

// The play scene's per-frame note-field draw pass, registered through the Aep manager
// and invoked by AepDrawLayer's type-3 dispatch with the full per-frame draw args
// (AepGroupDrawFn); the trailing `context` is the play data. Ghidra: FUN_00030944.
void PlayTaskDraw(int child, int frame, int x, int y, int scaleX, int scaleY,
                  int anchorX, int anchorY, int color, int alpha, int rotation,
                  uint32_t blend, int *clipRect, uint32_t p17, void *context);

// Clear the note manager's active-play flag on teardown. Ghidra: FUN_0003395c
// (a single store of 0 to NoteMng + 0x13cb6). Defined at the foot of this file.
void PlayNoteMngDetach(NoteMng *nm);

// The demo-mode character-window gauge: maps the current scroll position through a table
// of per-section fade ramps (+0x9f4), then draws the highlighted text panel (+0x58.. by
// section) and the window frame (+0x2c) with a fade. A large position-table draw unit of
// its own; declared here as a real seam (its own reconstruction). Ghidra: FUN_000313b0.
void PlayDrawCharaWindow(void *playData, int x, int y);

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

// ---------------------------------------------------------------------------------
// PlayBuildFieldLayers — the AepLyrCtrl-creation + handle-table-fill block inlined in
// FUN_0002e2d8 (PlayTask_init). Builds the 16 note-field animation layers and resolves
// every note / combo-digit / tone / chara-animation handle from the just-loaded
// "game_cmn" group. All name tables are byte-verified from the pointer arrays at
// 0x131164..0x13143c (targets in the string blob @ 0x103a22 / @ 0x102c6d), and the
// per-layer draw orders from the int arrays DAT_0012e600 / DAT_0012e614.
//
// Every string below reproduces the binary exactly, INCLUDING its oddities (followed
// the binary, verified byte-for-byte):
//   * the 960-phone bg table mixes widths: "FAILED640IMG" is followed by
//     "FAILED960IMG_FC" (not FAILED640IMG_FC) — @ 0x103af1 / 0x103afe.
//   * PAUSE_LOOP (the +0xe4[5] entry) is the lone string outside the main blob,
//     @ 0x00102c6d.
//   * the +0x2a8 tone-number table pads its tail with duplicates: TONE_04_1 twice
//     then TONE_08_1 four times (DAT_0013134c @ 0x40f1/0x4060).
//   * the +0x2d0 same-tone table repeats + reorders its 5 real graphics across 10
//     slots: 00,01,02,03,04,04,04,02,03,01 (PTR_s_TONE_SAME_00 @ 0x131374).
// ---------------------------------------------------------------------------------

namespace {

// A field layer by play-data offset (the +0x84.. / +0x98.. AepLyrCtrl slots).
inline AepLyrCtrl *pdLayer(void *p, int off) {
    return reinterpret_cast<AepLyrCtrl *>(pdPtr(p, off));
}

// Effect layers (+0x84..+0x94) — names @ PTR_s_EFF_COM_025CMB (0x131164), draw order
// @ DAT_0012e600.
const char *const kEffectLayerNames[5] = {
    "EFF_COM_025CMB", "EFF_COM_050CMB", "EFF_COM_100CMB", "ARE_YOU_READY", "PAUSE_BUTTON",
};
const int kEffectLayerOrder[5] = {25, 25, 25, 11, 12};

// Background layers (+0x98..+0xc0) — one 11-name table per display tier, order shared
// @ DAT_0012e614. Set A phone-960 (0x131178), Set B phone-1136 (0x1311a4), Set C pad
// (0x1311d0).
const char *const kBgNames960[11] = {
    "BG_640X960_COMBO0", "BG_640X960_COMBO00", "BG_640X960_COMBO000", "BG_640X960_IMG",
    "CLEARE640IMG", "CLEARE640IMG_FC", "CLEARE640IMG_PF", "CLEARE640IMG_PFEX",
    "FAILED640IMG", "FAILED960IMG_FC", "BG_640X960_BPM1_CLEAR",
};
const char *const kBgNames1136[11] = {
    "BG_640X1136_COMBO0", "BG_640X1136_COMBO00", "BG_640X1136_COMBO000", "BG_640X1136_IMG",
    "CLEARE1136IMG", "CLEARE1136IMG_FC", "CLEARE1136IMG_PF", "CLEARE1136IMG_PFEX",
    "FAILED1136IMG", "FAILED1136IMG_FC", "BG_640X1136_BPM1_CLEAR",
};
const char *const kBgNamesPad[11] = {
    "BG_COMBO0", "BG_COMBO00", "BG_COMBO000", "BG_IMG",
    "CLEARE2048IMG", "CLEARE2048IMG_FC", "CLEARE2048IMG_PF", "CLEARE2048IMG_PFEX",
    "FAILED2048IMG", "FAILED2048IMG_FC", "BG_BPM1_CLEAR",
};
const int kBgLayerOrder[11] = {24, 24, 24, 49, 11, 11, 11, 11, 11, 11, 26};

// Score / BPM getLyrNo table (+0x154 handles, +0x168 frame counts) — one 5-name table
// per display tier. Set A (0x1311fc), Set B (0x131210), Set C (0x131224).
const char *const kScoreNames960[5] = {
    "BG_640X960_BPM2SCORE", "BG_640X960_BPM0", "BG_640X960_BPM1",
    "BGMTSCO_TW0_960START", "BGMTSCO_TW1_960LAST",
};
const char *const kScoreNames1136[5] = {
    "BG_640X1136_BPM2SCORE", "BG_640X1136_BPM0", "BG_640X1136_BPM1",
    "BGMTSCO_TW0_START", "BGMTSCO_TW1_LAST",
};
const char *const kScoreNamesPad[5] = {
    "BG_BPM2SCORE", "BG_BPM0", "BG_BPM1",
    "BGMTSCO_TW0_2048START", "BGMTSCO_TW1_2048LAST",
};

// getLyrNo tables: handle -> +lyrBase, frame count -> +frmBase.
const char *const kToneJudgeNames[4] = {          // +0xc4 / +0xd4 (DAT_00131238)
    "TONE_DEFAULT_120PER", "TONE_NEAR_15F_", "TONE_OUT_0", "TONE_OUT_1",
};
const char *const kEffectStateNames[14] = {       // +0xe4 / +0x11c (DAT_00131248)
    "GG_HANTEI", "EFF_NEAR_UNDER", "EFF_HIT_OVER", "EFF_HIT_OVER2", "EFF_HIT_OVER_MORE",
    "PAUSE_LOOP", "FRAME_SIDEMT_BARSTAR0", "FRAME_SIDEMT_BARSTAR1", "FRAME_SIDEMT_BAR",
    "BGMTSCO_TWL0_START", "BGMT_CD", "BGMT_CD_COLOR", "EFF_HIT_LONG", "EFF_HIT",
};
const char *const kCharaJumpNames[8] = {          // +0x17c / +0x1dc (DAT_00131280)
    "BGMTBPM1_CHARA0_JUMP", "BGMTBPM1_CHARA1_JUMP", "BGMTBPM1_CHARA2_JUMP",
    "BGMTBPM1_CHARA3_JUMP", "BGMTBPM1_CHARA4_JUMP", "BGMTBPM1_CHARA5_JUMP",
    "BGMTBPM1_CHARA6_JUMP", "BGMTBPM1_CHARA7_JUMP",
};

// getFrameNo (AepManager::getFrameNo) tables — handle only.
const char *const kPauseEyeToneFrames[9] = {      // +0x1fc (DAT_001312a0)
    "CMD_PAUSE_1_F", "ORB_EYES_0", "ORB_EYES_1", "ORB_EYES_2", "ORB_EYES_8", "ORB_EYES_9",
    "TONE_L1_2", "TONE_L1_2_PUSH", "TONE_L1_2_LIGHT",
};
const char *const kScoreDigitFrames[10] = {       // +0x220 (DAT_001312c4)
    "SCO_0", "SCO_1", "SCO_2", "SCO_3", "SCO_4", "SCO_5", "SCO_6", "SCO_7", "SCO_8", "SCO_9",
};
const char *const kComboDigitFrames[10] = {       // +0x248 (PTR_s_EFF_C_NUM0)
    "EFF_C_NUM0", "EFF_C_NUM1", "EFF_C_NUM2", "EFF_C_NUM3", "EFF_C_NUM4",
    "EFF_C_NUM5", "EFF_C_NUM6", "EFF_C_NUM7", "EFF_C_NUM8", "EFF_C_NUM9",
};
const char *const kGaugeFlashFrames[4] = {        // +0x270 (DAT_00131314)
    "GG_IFL_D", "GG_IFL_C", "GG_IFL_B", "GG_IFL_A",
};
const char *const kTone08Frames[5] = {            // +0x280 (PTR_s_TONE_08_1)
    "TONE_08_1", "TONE_09_1", "TONE_10_1", "TONE_11_1", "TONE_08_NUM1",
};
const char *const kTone08NumFrames[5] = {         // +0x294 (DAT_00131338)
    "TONE_08_NUM2", "TONE_08_NUM3", "TONE_08_NUM4", "TONE_08_NUM5", "TONE_00_1",
};
const char *const kToneNumberFrames[10] = {       // +0x2a8 (DAT_0013134c) — padded tail
    "TONE_01_1", "TONE_02_1", "TONE_03_1", "TONE_04_1", "TONE_04_1",
    "TONE_08_1", "TONE_08_1", "TONE_08_1", "TONE_08_1", "TONE_SAME_00",
};
const char *const kToneSameFrames[10] = {         // +0x2d0 (PTR_s_TONE_SAME_00) — reordered
    "TONE_SAME_00", "TONE_SAME_01", "TONE_SAME_02", "TONE_SAME_03", "TONE_SAME_04",
    "TONE_SAME_04", "TONE_SAME_04", "TONE_SAME_02", "TONE_SAME_03", "TONE_SAME_01",
};

// getUserNo (AepManager::getUserNo) tables — handle only.
const char *const kUserSpriteNames[15] = {        // +0x2f8 (DAT_0013139c)
    "GG_IFL", "CMD_PAUSE_1", "TONE_1", "TONE_08_NUM", "ORB_EYES_0", "ORB_EYES_1",
    "ORB_EYES_2", "ORB_EYES_8", "ORB_EYES_9", "BG_CL_COLOR", "FRAME_STAR",
    "FRAME_SIDEBAR", "EFF_C_NUM001", "EFF_C_NUM010", "EFF_C_NUM100",
};
const char *const kNumComboUser[3] = {            // +0x334 (DAT_001313d8)
    "NUM_COMBO_0001", "NUM_COMBO_0010", "NUM_COMBO_0100",
};
const char *const kScoreNumUser[6] = {            // +0x340 (DAT_001313e4)
    "SCO_000001", "SCO_000010", "SCO_000100", "SCO_001000", "SCO_010000", "SCO_100000",
};
const char *const kCharaUser[8] = {               // +0x358 (DAT_001313fc)
    "CHARA0", "CHARA1", "CHARA2", "CHARA3", "CHARA4", "CHARA5", "CHARA6", "CHARA7",
};
const char *const kCharaAnmUser[8] = {            // +0x378 (PTR_s_CHARA0_ANM)
    "CHARA0_ANM", "CHARA1_ANM", "CHARA2_ANM", "CHARA3_ANM",
    "CHARA4_ANM", "CHARA5_ANM", "CHARA6_ANM", "CHARA7_ANM",
};

}  // namespace

void PlayBuildFieldLayers(void *playData) {
    AepManager &aep = AepManager::shared();       // Ghidra: AepManager_shared (uVar5)
    AppDelegate *app = [AppDelegate appDelegate];  // display-tier query below

    // The five effect layers at +0x84..+0x94. Each is operator new(0x60) + AepLyrCtrl
    // ctor, stored into its slot, then AepLyrCtrl::init(group 0, name, owner=playData,
    // order). The order is the 5th init arg the pseudocode truncates (local_1c0 =
    // DAT_0012e600[i], verified against the AepLyrCtrl::init(...,owner,order) form).
    for (int i = 0; i < 5; ++i) {
        AepLyrCtrl *layer = new AepLyrCtrl();
        pdPtr(playData, 0x84 + i * 4) = layer;
        layer->init(0, kEffectLayerNames[i], playData, kEffectLayerOrder[i]);
    }

    // Per-display-tier repositioning of the effect banners + selection of the bg /
    // score name tables and the field draw offset at +0x978. Layer anchor = clear the
    // y slot (+0x18) and store a raw screen offset into the z slot (+0x1c) — the same
    // +0x18/+0x1c store AepLyrCtrl::setRouletteAnchor performs.
    const bool pad = pdByte(playData, 0x9ca) != 0;
    const char *const *bgNames;
    const char *const *scoreNames;
    if (!pad) {
        if ([app displayType] == 2) {   // 1136 tall phone
            pdLayer(playData, 0x90)->setRouletteAnchor(0x140);   // ARE_YOU_READY y=320
            pdInt(playData, 0x978) = 0;
            bgNames = kBgNames1136;
            scoreNames = kScoreNames1136;
        } else {                        // 960 phone
            pdLayer(playData, 0x84)->setRouletteAnchor(-0x28);   // combo 25 -> y=-40
            pdLayer(playData, 0x88)->setRouletteAnchor(-0x28);   // combo 50
            pdLayer(playData, 0x8c)->setRouletteAnchor(-0x28);   // combo 100
            pdLayer(playData, 0x90)->setRouletteAnchor(0x132);   // ARE_YOU_READY y=306
            pdInt(playData, 0x978) = -0xb0;                       // field offset -176
            bgNames = kBgNames960;
            scoreNames = kScoreNames960;
        }
    } else {                            // pad
        pdLayer(playData, 0x90)->setRouletteAnchor(0x300);       // ARE_YOU_READY y=768
        pdInt(playData, 0x978) = 0;
        bgNames = kBgNamesPad;
        scoreNames = kScoreNamesPad;
    }

    // The eleven background layers at +0x98..+0xc0, same new + init + order pattern.
    for (int i = 0; i < 11; ++i) {
        AepLyrCtrl *layer = new AepLyrCtrl();
        pdPtr(playData, 0x98 + i * 4) = layer;
        layer->init(0, bgNames[i], playData, kBgLayerOrder[i]);
    }

    // getLyrNo -> +lyrBase, layerFrameCount(handle) -> +frmBase.
    auto fillLyr = [&](int lyrBase, int frmBase, const char *const *names, int n) {
        for (int i = 0; i < n; ++i) {
            const int lyr = aep.getLyrNo(0, names[i]);
            pdInt(playData, lyrBase + i * 4) = lyr;
            pdInt(playData, frmBase + i * 4) = aep.layerFrameCount(lyr);
        }
    };
    // getFrameNo -> +base (no frame count).
    auto fillFrm = [&](int base, const char *const *names, int n) {
        for (int i = 0; i < n; ++i) {
            pdInt(playData, base + i * 4) = aep.getFrameNo(0, names[i]);
        }
    };
    // getUserNo -> +base (no frame count).
    auto fillUsr = [&](int base, const char *const *names, int n) {
        for (int i = 0; i < n; ++i) {
            pdInt(playData, base + i * 4) = aep.getUserNo(0, names[i]);
        }
    };

    fillLyr(0x154, 0x168, scoreNames, 5);
    fillLyr(0xc4, 0xd4, kToneJudgeNames, 4);
    fillLyr(0xe4, 0x11c, kEffectStateNames, 14);
    fillLyr(0x17c, 0x1dc, kCharaJumpNames, 8);

    fillFrm(0x1fc, kPauseEyeToneFrames, 9);
    fillFrm(0x220, kScoreDigitFrames, 10);
    fillFrm(0x248, kComboDigitFrames, 10);
    fillFrm(0x270, kGaugeFlashFrames, 4);
    // In the binary the +0x280/+0x294 fills interleave in one loop, as do +0x2a8/+0x2d0;
    // split here since each is an independent lookup with no ordering dependency.
    fillFrm(0x280, kTone08Frames, 5);
    fillFrm(0x294, kTone08NumFrames, 5);
    fillFrm(0x2a8, kToneNumberFrames, 10);
    fillFrm(0x2d0, kToneSameFrames, 10);

    fillUsr(0x2f8, kUserSpriteNames, 15);
    fillUsr(0x334, kNumComboUser, 3);
    fillUsr(0x340, kScoreNumUser, 6);
    // +0x358 / +0x378 interleave in one binary loop; independent lookups, split here.
    fillUsr(0x358, kCharaUser, 8);
    fillUsr(0x378, kCharaAnmUser, 8);
}

// ---------------------------------------------------------------------------------
// PlayLoadCharaTextures — the neTextureForiOS chara-portrait / window / text-panel
// load block inlined in FUN_0002e2d8. Two modes, split on the bundled/sugoroku flag
// at +0x9c9:
//   * normal play (+0x9c9 == 0): fill the eight portrait slots at +0x30 with the
//     player's own character plus a random draw of the *other* unlocked characters
//     (bit-tested against gotCharaArray). Missing files null their slot.
//   * bundled demo / sugoroku (+0x9c9 != 0): a fixed three portraits (+0x30), the
//     window frame (+0x2c), and thirteen text panels (+0x50).
// Names byte-verified from the CFString tables @ 0x13143c / 0x131448 / 0x131454 and
// the single CFStrings (targets in the string blob @ 0x1042ad). "%03d" format strings
// are @ 0x1043a8 (open) / 0x104395 (sugo).
// ---------------------------------------------------------------------------------

namespace {

// Bundled portrait names (+0x30[0..2]) for normal hardware — PTR_cf_open_chara_ssm
// (0x13143c); loaded from the main bundle with type "png".
NSString *const kBundleCharaNames[3] = {@"open_chara_ssm", @"open_chara000", @"open_chara001"};

// Bundled sugoroku portrait file names for slots 1..2 (PTR_cf_sugo_charassm[1..2] @
// 0x131448); appended to the app-support directory. Slot 0 uses the bundled
// "sugo_charassm.png" instead, so entry [0] here is unused (kept for fidelity).
NSString *const kSugoCharaFiles[3] = {@"sugo_charassm", @"sugo_chara000.png", @"sugo_chara001.png"};

// Text-panel names (+0x50[0..12]) — PTR_cf_t_text_00 (0x131454); bundle type "png".
NSString *const kTextPanelNames[13] = {
    @"t_text_00", @"t_text_01", @"t_text_02", @"t_text_03", @"t_text_04", @"t_text_05",
    @"t_text_06", @"t_text_07", @"t_text_08", @"t_text_09", @"t_text_10", @"t_text_11",
    @"t_text_12",
};

}  // namespace

void PlayLoadCharaTextures(void *playData) {
    const bool pad = pdByte(playData, 0x9ca) != 0;   // isPadDisplay (drives sugo naming)

    if (pdByte(playData, 0x9c9) == 0) {
        // Normal play: build the pool of other unlocked characters, then fill eight
        // portrait slots. Ghidra: _srand(_time(0)) then the CharaManager pick loop.
        srand((unsigned)time(nullptr));
        const short selfChara = [UserSettingData charaId];
        NSArray *gotCharas = [UserSettingData gotCharaArray];
        NSMutableArray *pool = [NSMutableArray array];

        // Lazily ensure the chara lists are built (Ghidra: FUN_0002980c guard), then
        // collect every available index (other than the player's own) whose owned bit
        // is set. The list index is used directly as the character id, exactly as the
        // binary tests it against gotCharaArray.
        NSArray *available = CharaManagerShared().availableInfos();
        const int availableCount = (int)available.count;
        for (int i = 0; i < availableCount; ++i) {
            if (i != (int)selfChara && RhTestBitInNumberArray(gotCharas, (unsigned)i)) {
                [pool addObject:@(i)];
            }
        }

        for (int slot = 0; slot < 8; ++slot) {
            // Slot 0 is always the player's own character; later slots draw randomly
            // from the pool (removing the pick). Once the pool is empty, stop after the
            // first three slots; the remaining slots resolve to the placeholder.
            int chara = selfChara;
            if (slot != 0) {
                if (pool.count == 0) {
                    if (slot > 2) {
                        break;
                    }
                    chara = -1;
                } else {
                    const int pick = rand() % (int)pool.count;
                    chara = [[pool objectAtIndexedSubscript:pick] intValue];
                    [pool removeObjectAtIndex:pick];
                }
            }

            neTextureForiOS *tex = new neTextureForiOS();
            pdPtr(playData, 0x30 + slot * 4) = tex;

            NSString *path;
            if (chara < 0) {
                // Placeholder portrait: bundled "<open|sugo>_chara[_]ssm.png".
                path = [[NSBundle mainBundle] pathForResource:(pad ? @"sugo_charassm"
                                                                   : @"open_chara_ssm")
                                                       ofType:@"png"];
            } else if (!pad) {
                // Phone: bundled open_charaNNN.png for the first 30 built-in charas,
                // else the downloaded copy under the app-support directory.
                NSString *file = [NSString stringWithFormat:@"open_chara%03d.png", chara];
                if (chara < 30) {
                    path = [[NSBundle mainBundle] pathForResource:file ofType:nil];
                } else {
                    path = [[AppDelegate appAppSupportDirectory]
                        stringByAppendingPathComponent:file];
                }
            } else {
                // Pad: the downloaded sugo_charaNNN.png under the app-support directory.
                NSString *file = [NSString stringWithFormat:@"sugo_chara%03d.png", chara];
                path = [[AppDelegate appAppSupportDirectory]
                    stringByAppendingPathComponent:file];
            }

            if (RhFileExists(path)) {
                tex->load([path UTF8String]);
            } else {
                delete tex;
                pdPtr(playData, 0x30 + slot * 4) = nullptr;
            }
        }
        return;
    }

    // Bundled demo / sugoroku: three portraits, the window frame, thirteen text panels.
    for (int i = 0; i < 3; ++i) {
        neTextureForiOS *tex = new neTextureForiOS();
        pdPtr(playData, 0x30 + i * 4) = tex;

        NSString *path;
        if (!pad) {
            path = [[NSBundle mainBundle] pathForResource:kBundleCharaNames[i] ofType:@"png"];
        } else if (i == 0) {
            path = [[NSBundle mainBundle] pathForResource:@"sugo_charassm" ofType:@"png"];
        } else {
            path = [[AppDelegate appAppSupportDirectory]
                stringByAppendingPathComponent:kSugoCharaFiles[i]];
        }
        tex->load([path UTF8String]);
    }

    neTextureForiOS *window = new neTextureForiOS();
    pdPtr(playData, 0x2c) = window;
    NSString *windowPath = [[NSBundle mainBundle] pathForResource:@"t_window" ofType:@"png"];
    window->load([windowPath UTF8String]);

    for (int i = 0; i < 13; ++i) {
        neTextureForiOS *tex = new neTextureForiOS();
        pdPtr(playData, 0x50 + i * 4) = tex;
        NSString *path = [[NSBundle mainBundle] pathForResource:kTextPanelNames[i] ofType:@"png"];
        tex->load([path UTF8String]);
    }
}

// Ghidra: FUN_00030944 (PlayTaskDraw) — the note-field per-frame draw dispatcher the Aep
// manager invokes for group 0. `child` is the layer id being drawn; `context` is the play
// data. It matches `child` against the play-data handle tables PlayBuildFieldLayers filled
// and emits the right sprite: an atlas quad (AepDrawSpriteHandle / FUN_0000fcd0), a nested
// animated layer (AepManager::drawLayer / LAB_00031196), or a standalone texture
// (neTextureForiOS). The dispatch structure and per-branch priority / handle selection are
// reproduced from the binary; leaf per-sprite geometry is delegated to those draw units.
void PlayTaskDraw(int child, int /*frame*/, int x, int y, int scaleX, int scaleY,
                  int anchorX, int anchorY, int color, int alpha, int rotation,
                  uint32_t blend, int *clipRect, uint32_t p17, void *context) {
    AepManager &aep = AepManager::shared();          // Ghidra: AepManager_shared
    NoteMng &nm = NoteMng::shared();                 // binary forces the manager up
    void *pData = context;                              // the play data (param_15)

    // Atlas-quad tail (Ghidra: LAB_00030cc6 -> FUN_0000fcd0). `handle`/`priority` vary.
    auto noteQuad = [&](int handle, int priority) {
        AepDrawSpriteHandle(&aep, handle, x, y, scaleX, scaleY, rotation, anchorX, anchorY,
                            color, alpha, blend, 0xffffff, clipRect, priority, 1);
    };
    // Nested-layer tail (Ghidra: LAB_00031196 -> AepManager::drawLayer). Arg mapping
    // corrected against the binary: loopFlags = 1, p9/p10 = anchorX/anchorY, colour/alpha
    // pass straight through, blend 0x20, p15 0xffffff, p19 1; the OT priority slot (fe8c
    // p17) is 0 in this call and the callback's p17 word is threaded as the context.
    auto layerDraw = [&](int lyr, int lframe, int lscaleY, int *lclip, int /*unused*/) {
        aep.drawLayer(lyr, lframe, x, y, scaleX, lscaleY, rotation,
                      1, anchorX, anchorY, color, alpha, 0x20,
                      0xffffff, lclip, reinterpret_cast<void *>((intptr_t)p17), 0, 1);
    };

    // --- Combo-count digits (NUM_COMBO_*, +0x334): only once combo exceeds 4 ---
    // The binary reads DAT_00179000 (the combo mirror in the NoteMng region); the modelled
    // accessor NoteMng::combo() carries the same gameplay combo (documented best-effort).
    if (nm.combo() > 4) {
        int v = nm.combo();
        for (int i = 0; i < 3; ++i) {
            if (pdInt(pData, 0x334 + i * 4) == child) {
                noteQuad(pdInt(pData, 0x248 + (v % 10) * 4), (int)p17);   // +0x248 EFF_C_NUM
                return;
            }
            v /= 10;
        }
    }
    // --- Score digits (SCO_0000NN user sprites, +0x340) ---
    {
        int v = pdInt(pData, 0x9b0);                                     // running score
        for (int i = 0; i < 6; ++i) {
            if (pdInt(pData, 0x340 + i * 4) == child) {
                noteQuad(pdInt(pData, 0x220 + (v % 10) * 4), (int)p17);   // +0x220 SCO_N frames
                return;
            }
            v /= 10;
        }
    }
    // --- Gauge flash (GG_IFL, +0x2f8): this judge slot's gauge index @ +0x3d4 ---
    if (pdInt(pData, 0x2f8) == child) {
        const int gi = pdInt(pData, (int)p17 * 0x18 + 0x3d4);
        if (gi < 0) return;
        noteQuad(pdInt(pData, 0x270 + gi * 4), 0xe);                     // +0x270 GG_IFL_* frames
        return;
    }
    // --- Pause command icon (CMD_PAUSE_1, +0x2fc) ---
    if (pdInt(pData, 0x2fc) == child) {
        noteQuad(pdInt(pData, 0x1fc), 9);                               // +0x1fc CMD_PAUSE_1_F
        return;
    }
    // --- Tone lane graphic (TONE_1, +0x300): pick a tone sprite from this note's state ---
    if (pdInt(pData, 0x300) == child) {
        const int id      = pdInt(pData, (int)p17 * 0x18 + 0x3cc);      // this slot's tone note id
        const int graphic = NoteToneGraphic(id);                    // FUN_00034bb4
        const int flags   = NoteToneFlags(id);                      // FUN_00034b98
        const int state   = NoteToneState(id);                      // FUN_00034b5c
        int handle;
        if ((flags & 2) == 0) {
            if (state == 1) {
                const int def = NoteToneDefaultGraphic(graphic);    // FUN_00034a5c
                handle = pdInt(pData, 0x280 + (def - 1) * 4);          // +0x280 TONE_08 table
            } else {
                handle = pdInt(pData, 0x2a8 + graphic * 4);            // +0x2a8 tone-number table
            }
        } else {
            handle = pdInt(pData, 0x2d0 + graphic * 4);                // +0x2d0 tone-same table
        }
        noteQuad(handle, 0x13);
        return;
    }
    // --- Tone number overlay (TONE_08_NUM, +0x304) ---
    if (pdInt(pData, 0x304) == child) {
        const int id = pdInt(pData, (int)p17 * 0x18 + 0x3cc);
        if (NoteToneState(id) != 1) return;
        const int n = NoteToneCount(id);                            // FUN_00034bd0
        if (n < 1) return;
        noteQuad(pdInt(pData, 0x290 + n * 4), 0x11);                   // +0x290 TONE_08_NUM table
        return;
    }
    // --- Pause-eye tone frames (ORB_EYES_*, +0x308..+0x318) ---
    if (pdInt(pData, 0x308) == child) { noteQuad(pdInt(pData, 0x200), 0x12); return; }
    if (pdInt(pData, 0x30c) == child) { noteQuad(pdInt(pData, 0x204), 0x12); return; }
    if (pdInt(pData, 0x310) == child) { noteQuad(pdInt(pData, 0x208), 0x12); return; }
    if (pdInt(pData, 0x314) == child) { noteQuad(pdInt(pData, 0x20c), 0x12); return; }
    if (pdInt(pData, 0x318) == child) { noteQuad(pdInt(pData, 0x210), 0x12); return; }

    // --- Background colour layer (BG_CL_COLOR, +0x31c): effects-on, new hardware only ---
    if (pdInt(pData, 0x31c) == child) {
        if (pdByte(pData, 0x9e5) == 0) return;                         // effects off
        if (pdByte(pData, 0x9e7) != 0) return;                         // old hardware
        layerDraw(pdInt(pData, 0x110), pdInt(pData, 0x3bc), scaleY, clipRect, (int)p17);
        return;
    }
    // --- On-field combo digits (EFF_C_NUM001/010/100, +0x328/+0x32c/+0x330) ---
    if (pdInt(pData, 0x328) == child) {
        const int v = (int)pdShort(pData, 0x9c4);
        noteQuad(pdInt(pData, 0x248 + (v % 10) * 4), (int)p17);
        return;
    }
    if (pdInt(pData, 0x32c) == child) {
        const int v = (int)pdShort(pData, 0x9c4) / 10;
        noteQuad(pdInt(pData, 0x248 + (v % 10) * 4), (int)p17);
        return;
    }
    if (pdInt(pData, 0x330) == child) {
        if ((int)pdShort(pData, 0x9c4) < 100) return;
        const int v = (int)pdShort(pData, 0x9c4) / 100;
        noteQuad(pdInt(pData, 0x248 + (v % 10) * 4), (int)p17);
        return;
    }
    // --- Score star badge (FRAME_STAR, +0x320 == decimal 800) ---
    if (pdInt(pData, 0x320) == child) {
        int lyr, lframe;
        if (pdInt(pData, 0x9b0) < 70000) {                             // FRAME_SIDEMT_BARSTAR0
            lyr = pdInt(pData, 0xfc);  lframe = 0;
        } else {                                                    // FRAME_SIDEMT_BARSTAR1
            lyr = pdInt(pData, 0x100); lframe = pdInt(pData, 0x3c0);
        }
        layerDraw(lyr, lframe, 100, nullptr, 0x16);                 // scaleY forced to 100
        return;
    }
    // --- Gauge side bar (FRAME_SIDEBAR, +0x324) ---
    if (pdInt(pData, 0x324) == child) {
        const int barCount = pdInt(pData, 0x13c);                     // FRAME_SIDEMT_BAR length
        const int t = (int)pdShort(pData, 0x9c0) * (barCount - 1);    // gauge * (frames-1)
        const int lframe = (t + (int)((unsigned)(t >> 31) >> 22)) >> 10;   // t / 1024 toward 0
        layerDraw(pdInt(pData, 0x104), lframe, scaleY, nullptr, 0x16);
        return;
    }

    // --- Character jump layers / portraits (CHARA[i] +0x358, CHARA[i]_ANM +0x378) ---
    // Skipped entirely when effects are off and this is not the bundled demo.
    if (pdByte(pData, 0x9e5) != 0 || pdByte(pData, 0x9c9) != 0) {
        const int ivl = (int)NoteBeatIntervalMs();                 // beat interval, ms
        const int pos = (ivl != 0) ? (nm.getCurrentPosition() % ivl) : 0;
        int scoreGate = 0;                                         // i * 10000
        for (int i = 0; i < 8; ++i) {
            if (pdInt(pData, 0x358 + i * 4) == child) {               // chara i jump layer
                if (pdByte(pData, 0x9c9) == 0) {                      // normal play
                    if (pdInt(pData, 0x9b0) < scoreGate) return;      // score below chara threshold
                    AepLyrCtrl *bg = reinterpret_cast<AepLyrCtrl *>(pdPtr(pData, 0xc0));
                    if (i > 2 && bg != nullptr && bg->isAnimating()) return;
                } else {                                           // bundled demo
                    if (i > 2) return;
                    if (i == 4) {
                        PlayDrawCharaWindow(pData, x - (anchorX * scaleX) / 100,
                                                y - (scaleY * anchorY) / 100);
                    }
                }
                const int jumpCount = pdInt(pData, 0x1dc + i * 4);    // chara jump layer length
                const int lframe = (ivl != 0) ? (pos * (jumpCount - 1)) / ivl : 0;
                layerDraw(pdInt(pData, 0x17c + i * 4), lframe, scaleY, clipRect, 0x1a);
                return;
            }
            if (pdInt(pData, 0x378 + i * 4) == child) {               // chara i portrait (anim)
                neTextureForiOS *portrait =
                    reinterpret_cast<neTextureForiOS *>(pdPtr(pData, 0x30 + i * 4));
                if (portrait == nullptr) return;
                const int csize = pdInt(pData, 0x9a8);                // chara draw size
                neSpriteDrawParams p;
                p.w = csize;  p.h = csize;
                p.x = x;      p.y = y;
                p.sx = scaleX; p.sy = scaleY;
                p.ex = anchorX; p.ey = anchorY;
                p.color = color; p.rotation = rotation;
                p.blend0 = 0x20; p.blend1 = (short)alpha;          // alpha rides the sub-blend
                p.colorMul = 0xffffff; p.priority = (int)p17;
                portrait->draw(aep.orderingTable(), p);
                return;
            }
            scoreGate += 10000;
        }
    }
    // Unmatched child: nothing to draw (the binary's loop simply exhausts and returns).
}
