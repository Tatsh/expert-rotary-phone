//
//  neEngineBridge.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The C++
//  engine singletons and lifecycle hooks the Objective-C layer drives. C++11
//  function- local statics reproduce the binary's __cxa_guard'd lazy
//  singletons.
//

#include <cstddef>
#include <cstring>

#import "AcNoteMng.h"    // AcNoteMng singleton (arcade note engine) — apply-settings re-seek
#import "AcViewerTask.h" // AcViewerTask named work-area (apply-settings owner)
#import "AepManager.h"   // AepManager::orderingTable() for neTextureForiOS_draw
#import "AepTexture.h"
#import "AppDelegate.h" // [AppDelegate appDelegate] / managedObjectContext (score store)
#import "AudioManager.h"
#import "PlayTask.h"        // PlayTask::m_state (the running play task's lifecycle state)
#import "ScoreData+Store.h" // +[ScoreData getScoreData:inManagedObjectContext:] / hashScore:
#import "ScoreData.h"       // ScoreData entity score/rank/playCnt/fullCombo/perfect properties
#import "UserSettingData.h" // +acvHiSpeed/+acvPopKun/+acvHidSud/+acvRanMir option accessors
#import "neEngineBridge.h"
#import "neGraphics.h"      // findCharIndexForColumn declaration (defined below)
#import "neTextureForiOS.h" // neTextureForiOS::LoadTexture + neTextureForiOS_draw (defined below)
#import <UIKit/UIKit.h>     // UIImage / CoreGraphics (neTextureForiOS::LoadTexture)

// Create + register the boot logo splash task (Task/TaskFactory.mm).
class C_TASK;
C_TASK *BootCreateTask(); // operator_new(0x4c) + BootLogoTask_ctor + setPriority(3)

// Head of the shared-texture cache list (Ghidra: DAT_00188464). Registered/
// unlinked by AepTexture as cached textures are acquired/released.
AepTexture *g_textureCacheList = nullptr;

#pragma mark - neAppEventCenter (guarded singleton @ DAT_00187bb8)

// @complete
neAppEventCenter &neAppEventCenter::shared() {
    static neAppEventCenter instance; // Ghidra: NEAppEventCenter_shared (FUN_0000b150)
    return instance;
}

// Ghidra: FUN_00028c70 — zero the transient event-center state. The binary
// zeroed the whole 0x48-byte singleton block in one sweep, which also cleared the
// login-context / AC-viewer globals; in the rebuild those live as separate
// file-statics reset by their own clear methods, so begin() only zeroes the
// result record and session dates it actually owns.
// @complete
void neAppEventCenter::begin() {
    m_result = PlayResult{};
    _startDate = nil;
    _endDate = nil;
    m_resultExt = PlayResultExt{};
}

// Ghidra: FUN_00028c9c — a no-op in this build.
// @complete
void neAppEventCenter::flush() {
}

// @ 0x29274 — record the session start time (_startDate @ +0x20). The binary
// released the previous NSDate and retained [NSDate date]; the ARC strong-ivar
// store does both.
// @complete
void neAppEventCenter::setStartDate() {
    _startDate = [NSDate date];
}

// @ 0x292c0 — record the session end time (_endDate @ +0x24). The binary
// released the previous NSDate and retained [NSDate date]; the ARC strong-ivar
// store does both.
// @complete
void neAppEventCenter::setEndDate() {
    _endDate = [NSDate date];
}

// Remote-push pending flag (event-center region global g_bRemoteNotifyPending).
// Set when a push notification is received (AppDelegate
// application:didReceiveRemoteNotification:) and cleared once the recommend
// list is refreshed.
static bool g_bRemoteNotifyPending = false;
bool neAppEventCenter::remoteNotifyPending() const {
    return g_bRemoteNotifyPending;
}
void neAppEventCenter::setRemoteNotifyPending(bool pending) {
    g_bRemoteNotifyPending = pending;
}

// AC-viewer selection state (event-center region): the current browsing pair
// and the pending "Sel" pair carried into the play scene.
static int g_dwAcViewerMusicId = -1;     // g_dwAcViewerMusicId      @ 0x187bf0
static int g_wAcViewerDifficulty = 0;    // g_wAcViewerDifficulty    @ 0x187bf4
static int g_dwAcViewerSelMusicId = -1;  // g_dwAcViewerSelMusicId   @ 0x187bf8
static int g_wAcViewerSelDifficulty = 0; // g_wAcViewerSelDifficulty @ 0x187bfc

// Reset the pending selection to the "none" sentinels (music id -1, difficulty
// 65535) — done when the viewer is cancelled.
void neAppEventCenter::clearAcViewerSelection() {
    g_dwAcViewerSelMusicId = -1;
    g_wAcViewerSelDifficulty = 0xffff;
}

int neAppEventCenter::acViewerMusicId() {
    return g_dwAcViewerMusicId;
}
int neAppEventCenter::acViewerDifficulty() {
    return g_wAcViewerDifficulty;
}
void neAppEventCenter::setAcViewerSelection(int musicId, int difficulty) {
    g_dwAcViewerMusicId = musicId;
    g_wAcViewerDifficulty = difficulty;
}
int neAppEventCenter::acViewerSelMusicId() {
    return g_dwAcViewerSelMusicId;
}
int neAppEventCenter::acViewerSelDifficulty() {
    return g_wAcViewerSelDifficulty;
}
void neAppEventCenter::commitAcViewerSelection() {
    g_dwAcViewerSelMusicId = g_dwAcViewerMusicId;
    g_wAcViewerSelDifficulty = g_wAcViewerDifficulty;
}

// Reset only the current browsing music id (g_dwAcViewerMusicId) to the "none"
// sentinel (-1).
void neAppEventCenter::clearAcViewerCurrentMusic() {
    g_dwAcViewerMusicId = -1;
}

// e-AMUSEMENT login context (event-center region). The login flow populates
// these; the music-checker score sync reads them. Modelled as file-static
// globals, matching the AC-viewer selection state above.
static id g_pLinkRefId = nil;            // g_pLinkRefId       @ 0x187be0 (+0x28)
static NSString *g_pInputPassword = nil; // g_pInputPassword   @ 0x187be4 (+0x2c)
static bool g_bRequireOtpInput = false;  // g_bRequireOtpInput @ 0x187be9 (+0x31)

id neAppEventCenter::linkRefId() {
    return g_pLinkRefId;
}
NSString *neAppEventCenter::inputPassword() {
    return g_pInputPassword;
}
bool neAppEventCenter::requireOtpInput() {
    return g_bRequireOtpInput;
}

// Writers for the login context, driven by the KID-input screen. Under ARC the
// strong static ivars take care of the retain/release the binary did by hand.
void neAppEventCenter::setInputPassword(NSString *password) {
    g_pInputPassword = password;
}
void neAppEventCenter::setLinkRefId(id refId) {
    g_pLinkRefId = refId;
}
void neAppEventCenter::setRequireOtpInput(bool require) {
    g_bRequireOtpInput = require;
}

// pop'n-link availability (event-center region global @ g_bLinkButtonsEnabled).
// Populated by the (not-yet-reconstructed) pop'n-link login flow; false until
// the KID is linked, so the score-checker / quiz buttons stay disabled and the
// top screen forces KID input.
static bool g_bLinkButtonsEnabled = false;
bool neAppEventCenter::linkButtonsEnabled() {
    return g_bLinkButtonsEnabled;
}
void neAppEventCenter::setLinkButtonsEnabled(bool enabled) {
    g_bLinkButtonsEnabled = enabled;
}

int neAppEventCenter::lastMusic() const {
    return m_lastMusic;
}
void neAppEventCenter::setLastMusic(int music) {
    m_lastMusic = music;
}
int neAppEventCenter::lastSheet() const {
    return m_lastSheet;
}
void neAppEventCenter::setLastSheet(int sheet) {
    m_lastSheet = sheet;
}

// Guest / no-save run flag (event-center region global g_bGuestNoSaveMode).
static bool g_bGuestNoSaveMode = false;
bool neAppEventCenter::guestNoSaveMode() const {
    return g_bGuestNoSaveMode;
}
void neAppEventCenter::setGuestNoSaveMode(bool guest) {
    g_bGuestNoSaveMode = guest;
}

#pragma mark - Score store (Core Data ScoreData entity)

// PlayScore is a standalone store DTO: the (musicId, difficulty, tallies, score,
// rank, flags) record the two store functions read/write. The binary overlaid it
// on the event-center singleton, but it is also built free-standing (a friend's
// server score in FriendScoreMainView), so it is a plain value type here and the
// event-center wrappers copy fields to/from it by name rather than aliasing the
// singleton with a reinterpret_cast.

// @ 0x29438 — read one difficulty's columns out of a fetched ScoreData record.
// `rec` is unused (the binary reads everything from `recDup`, the same object);
// the null guard mirrors the binary (only the score/rank/playCnt out-params are
// checked).
// @complete
void readScoreDataFields(ScoreData *rec,
                         int *outScore,
                         short *outRank,
                         int *outPlayCnt,
                         bool *outFullCombo,
                         bool *outPerfect,
                         ScoreData *recDup,
                         int difficulty) {
    (void)rec;
    if (outScore == nullptr || outRank == nullptr || outPlayCnt == nullptr) {
        return;
    }
    *outScore = 0;
    NSNumber *score, *rank, *playCnt, *fullCombo, *perfect;
    switch (difficulty) {
    case 0:
        score = recDup.scoreN;
        rank = recDup.rankN;
        playCnt = recDup.playCntN;
        fullCombo = recDup.fullComboN;
        perfect = recDup.perfectN;
        break;
    case 1:
        score = recDup.scoreH;
        rank = recDup.rankH;
        playCnt = recDup.playCntH;
        fullCombo = recDup.fullComboH;
        perfect = recDup.perfectH;
        break;
    case 2:
        score = recDup.scoreEx;
        rank = recDup.rankEx;
        playCnt = recDup.playCntEx;
        fullCombo = recDup.fullComboEx;
        perfect = recDup.perfectEx;
        break;
    default:
        return; // unknown difficulty: leave *outScore == 0, others untouched
    }
    *outScore = [score intValue];
    *outRank = (short)[rank intValue];
    *outPlayCnt = [playCnt intValue];
    *outFullCombo = [fullCombo boolValue];
    *outPerfect = [perfect boolValue];
}

// @ 0x293c4 — fetch the ScoreData record for `musicId` and hand it to
// readScoreDataFields. `center` is the app-event-center pointer the binary
// passes as arg 0; it is vestigial (unused).
// @complete
void fetchScoreDataForMusic(void *center,
                            int *outScore,
                            short *outRank,
                            int *outPlayCnt,
                            bool *outFullCombo,
                            bool *outPerfect,
                            unsigned musicId,
                            int difficulty) {
    (void)center;
    NSManagedObjectContext *ctx = [[AppDelegate appDelegate] managedObjectContext];
    ScoreData *rec = [ScoreData getScoreData:(int)musicId inManagedObjectContext:ctx];
    readScoreDataFields(
        rec, outScore, outRank, outPlayCnt, outFullCombo, outPerfect, rec, difficulty);
}

// @ 0x28ca0 — persist a finished play into the ScoreData store for its
// difficulty.
// @complete
void saveScoreData(PlayScore *s) {
    NSManagedObjectContext *ctx = [[AppDelegate appDelegate] managedObjectContext];
    [ctx reset];
    ScoreData *rec = [ScoreData getScoreData:(int)s->musicId inManagedObjectContext:ctx];
    const int diff = s->difficulty;

    // Full combo -> set this difficulty's FC medal; a spotless sheet (no GOOD and
    // no BAD) also sets the PERFECT medal.
    if (s->fullCombo) {
        switch (diff) {
        case 0:
            rec.fullComboN = @YES;
            break;
        case 1:
            rec.fullComboH = @YES;
            break;
        case 2:
            rec.fullComboEx = @YES;
            break;
        }
        if (s->badCount == 0 && s->goodCount == 0) {
            switch (diff) {
            case 0:
                rec.perfectN = @YES;
                break;
            case 1:
                rec.perfectH = @YES;
                break;
            case 2:
                rec.perfectEx = @YES;
                break;
            }
        }
    }

    // Better rank (lower is better) -> store it. A stored rank of -1 means
    // "unset".
    const int newRank = s->rank;
    switch (diff) {
    case 0: {
        int ex = [rec.rankN intValue];
        if (ex == -1 || newRank < ex) {
            rec.rankN = @(newRank);
        }
        break;
    }
    case 1: {
        int ex = [rec.rankH intValue];
        if (ex == -1 || newRank < ex) {
            rec.rankH = @(newRank);
        }
        break;
    }
    case 2: {
        int ex = [rec.rankEx intValue];
        if (ex == -1 || newRank < ex) {
            rec.rankEx = @(newRank);
        }
        break;
    }
    }

    // New high score -> store it and re-hash the tamper checksum.
    if (s->isNewHighScore) {
        switch (diff) {
        case 0:
            rec.scoreN = @(s->score);
            break;
        case 1:
            rec.scoreH = @(s->score);
            break;
        case 2:
            rec.scoreEx = @(s->score);
            break;
        }
        rec.chksco = [ScoreData hashScore:rec];
    }

    rec.lastPlayDate = [NSDate date];

    // Bump this difficulty's play count.
    switch (diff) {
    case 0:
        rec.playCntN = @([rec.playCntN intValue] + 1);
        break;
    case 1:
        rec.playCntH = @([rec.playCntH intValue] + 1);
        break;
    case 2:
        rec.playCntEx = @([rec.playCntEx intValue] + 1);
        break;
    }

    NSError *err = nil;
    if (![ctx save:&err]) {
        // On failure the binary walks the validation sub-errors
        // (NSDetailedErrorsKey). No user-visible handling beyond the enumeration;
        // the enumeration-mutation / stack-guard scaffolding around it is compiler
        // glue and is omitted.
        NSArray *detailed = [[err userInfo] objectForKey:NSDetailedErrorsKey];
        for (NSError *sub in detailed) {
            (void)sub;
        }
    }
}

// @ 0x2930c — pre-save "beat the record" check: read the current stored best,
// flag a new high score, then write the passed play tallies / score /
// full-combo into the record `s`.
// @complete
BOOL updateHighScore(PlayScore *s,
                     unsigned newScore,
                     short cool,
                     short great,
                     short good,
                     short bad,
                     char fullCombo) {
    s->isNewHighScore = 0;

    int curScore = 0;
    short curRank = 0;
    int curPlayCnt = 0;
    bool curFullCombo = false, curPerfect = false;
    ScoreData *rec = [ScoreData getScoreData:(int)s->musicId
                      inManagedObjectContext:[[AppDelegate appDelegate] managedObjectContext]];
    readScoreDataFields(
        rec, &curScore, &curRank, &curPlayCnt, &curFullCombo, &curPerfect, rec, s->difficulty);

    const BOOL isNew = (curScore < (int)newScore);
    s->isNewHighScore = isNew ? 1 : 0;

    s->coolCount = cool;
    s->greatCount = great;
    s->goodCount = good;
    s->badCount = bad;
    s->score = (int)newScore;
    s->fullCombo = (unsigned char)fullCombo;
    return isNew;
}

#pragma mark - neAppEventCenter score-store wrappers

// The three OO faces the ObjC layer calls. The binary overlaid the singleton on
// a PlayScore; here they copy fields to/from a local PlayScore DTO by name, so no
// reinterpret_cast (and no 0x48-byte overlay requirement) is needed.

void neAppEventCenter::readStoredResult(
    int *outScore, short *outRank, int *outPlayCnt, bool *outFullCombo, bool *outPerfect) {
    fetchScoreDataForMusic(this,
                           outScore,
                           outRank,
                           outPlayCnt,
                           outFullCombo,
                           outPerfect,
                           (unsigned)m_lastMusic,
                           m_lastSheet);
}

// Snapshot this play's result fields into a store DTO and persist it.
// saveScoreData only reads the DTO; +0x1c doubles as the full-combo flag the
// store medals key on (m_result.cleared).
void neAppEventCenter::commitResultToScoreData() {
    PlayScore ps = {};
    ps.musicId = (unsigned)m_lastMusic;
    ps.difficulty = m_lastSheet;
    ps.coolCount = m_result.coolCount;
    ps.greatCount = m_result.greatCount;
    ps.goodCount = m_result.goodCount;
    ps.badCount = m_result.badCount;
    ps.score = m_result.playScore;
    ps.rank = m_result.playRank;
    ps.maxCombo = (short)m_result.maxCombo;
    ps.fullCombo = m_result.cleared;
    ps.isNewHighScore = m_resultExt.newRecord;
    saveScoreData(&ps);
}

bool neAppEventCenter::recordPlayResult(
    unsigned score, short cool, short great, short good, short bad, bool fullCombo) {
    // updateHighScore reads musicId/difficulty and writes the tallies, score,
    // full-combo and new-record flag back into the DTO; mirror those writes into
    // the singleton fields the old overlay updated in place (+0x1c is the
    // full-combo byte, +0x32 the new-record byte).
    PlayScore ps = {};
    ps.musicId = (unsigned)m_lastMusic;
    ps.difficulty = m_lastSheet;
    const BOOL isNew = updateHighScore(&ps, score, cool, great, good, bad, fullCombo ? 1 : 0);
    m_result.coolCount = ps.coolCount;
    m_result.greatCount = ps.greatCount;
    m_result.goodCount = ps.goodCount;
    m_result.badCount = ps.badCount;
    m_result.playScore = ps.score;
    m_result.cleared = ps.fullCombo;
    m_resultExt.newRecord = ps.isNewHighScore;
    return isNew != NO;
}

#pragma mark - neSceneManager (guarded singleton @ DAT_00187b74)

// @complete
neSceneManager &neSceneManager::shared() {
    static neSceneManager instance; // Ghidra: NESceneManager_shared (FUN_0000b194)
    return instance;
}

// Ghidra: NESceneManager_attachRoot (FUN_0002c5b8).
// @complete
void neSceneManager::attachRoot(UIViewController *viewController) {
    m_root = viewController;
}

// Ghidra: NESceneManager_rootViewController (FUN_0002c5bc) — returns m_root.
// @complete
UIViewController *neSceneManager::rootViewController() {
    return shared().m_root;
}

// Ghidra: getNormalSoundName @ 0x2c7c0 — the display name for a touch-sound
// kind, indexed by kind (low 16 bits; anything past the last entry folds to 0).
// The binary returns one of ten constant CFStrings from PTR_cf_normal_001310d4;
// the picker rows show it. Returned as a __bridge void* to match the header's
// opaque type (mirroring rootViewController()'s ObjC-on-the-far-side handoff).
// @complete
void *neSceneManager::normalSoundName(int soundNo) {
    static NSString *const kNames[] = {
        @"normal",
        @"water",
        @"crack",
        @"shooting",
        @"tambourine",
        @"sword",
        @"cheer",
        @"shishamo",
        @"bag",
        @"bat",
    };
    unsigned kind = static_cast<unsigned>(soundNo) & 0xffff;
    if (kind > 9) {
        kind = 0;
    }
    return (__bridge void *)kNames[kind];
}

// Ghidra: getHitSoundName @ 0x2c7a8 (the normalSoundName sibling) — the bundle
// resource base-name of the SE previewed for a touch-sound kind (0..9), loaded
// as "<name>.m4a". The kind-order matches normalSoundName's display names.
// Constant CFString table; kinds past the last fold to 0.
// @complete
void *neSceneManager::hitSoundName(int soundNo) {
    // Ghidra: PTR_cf_hit001_001310ac[kind] — kind 7 ("shishamo") uses se06_nya,
    // not hit008.
    static NSString *const kNames[] = {
        @"hit001",
        @"hit002",
        @"hit003",
        @"hit004",
        @"hit005",
        @"hit006",
        @"hit007",
        @"se06_nya",
        @"hit008",
        @"hit009",
    };
    unsigned kind = static_cast<unsigned>(soundNo) & 0xffff;
    if (kind > 9) {
        kind = 0;
    }
    return (__bridge void *)kNames[kind];
}

// The 5 shared "system" UI SE source ids (scene-manager global +0x14) and the
// once-per-scene loaded flag (+0x3c). The playing-instance handles live in
// neEngine::g_systemSeHandles.
static RSND_SOURCE_ID s_systemSeSource[5] = {
    (RSND_SOURCE_ID)-1,
    (RSND_SOURCE_ID)-1,
    (RSND_SOURCE_ID)-1,
    (RSND_SOURCE_ID)-1,
    (RSND_SOURCE_ID)-1,
}; // -1 sentinel (RSND_SOURCE_ID is unsigned; the loaded flag gates use)

// SE-instance handles for the 5 shared UI sounds, indexed by slot (Ghidra: the
// scene-manager global DAT_00187b74 + 0x28, the array that immediately follows
// s_systemSeSource at +0x14 and precedes the loaded flag at +0x3c). -1 = idle.
static RSND_INSTANCE_ID g_systemSeHandles[5] = {
    (RSND_INSTANCE_ID)-1,
    (RSND_INSTANCE_ID)-1,
    (RSND_INSTANCE_ID)-1,
    (RSND_INSTANCE_ID)-1,
    (RSND_INSTANCE_ID)-1,
};
static bool s_systemSeLoaded = false;

// Ghidra: loadSoundEffects FUN_0002c5c8 — load the 5 shared UI SEs (decide /
// cancel / two slide sounds) into group 1 once per scene, then apply the saved
// SE volume.
// @complete
void neSceneManager::loadSystemSe() {
    if (s_systemSeLoaded) {
        return;
    }
    static NSString *const kNames[5] = {
        @"v21", @"se02_kettei", @"se03_cancell", @"se05_slide2", @"se04_slide1"};
    AudioManager *audio = [AudioManager sharedManager];
    for (int i = 0; i < 5; i++) {
        NSString *path = [[NSBundle mainBundle] pathForResource:kNames[i] ofType:@"m4a"];
        s_systemSeSource[i] = [audio loadSe:path isLoop:NO callName:nil group:1]; // +0x14
        g_systemSeHandles[i] = -1; // +0x28: reset the playing-instance handle to idle
    }
    [audio setSeVolume:[UserSettingData seVolume] groupId:1];
    s_systemSeLoaded = true;
}

// Ghidra: releaseSoundEffects FUN_0002c6bc — release the 5 UI SEs on scene
// teardown.
// @complete
void neSceneManager::releaseSystemSe() {
    if (!s_systemSeLoaded) {
        return;
    }
    AudioManager *audio = [AudioManager sharedManager];
    for (int i = 0; i < 5; i++) {
        [audio releaseSe:nil resourceId:s_systemSeSource[i]]; // release by source id (+0x14)
        g_systemSeHandles[i] = -1; // clear the playing-instance handle (+0x28), not the source
    }
    s_systemSeLoaded = false;
}

// Live drawable metrics (Ghidra globals DAT_00187b7c/78/80).
static float s_screenWidth = 640.0f;
static float s_screenHeight = 960.0f;
static float s_screenScale = 1.0f;

float neSceneManager::screenWidth() {
    return s_screenWidth;
}
float neSceneManager::screenHeight() {
    return s_screenHeight;
}
float neSceneManager::screenScale() {
    return s_screenScale;
}

void neSceneManager::setScreenMetrics(float width, float height, float scale) {
    s_screenWidth = width;
    s_screenHeight = height;
    s_screenScale = scale;
}

// Device-class flag (Ghidra global DAT_00187b84).
static bool s_isPadDisplay = false;
bool neSceneManager::isPadDisplay() {
    return s_isPadDisplay;
}
void neSceneManager::setPadDisplay(bool isPad) {
    s_isPadDisplay = isPad;
}

// neGraphics (the DAT_00188384 render/input manager) lives in
// Render/neGraphics.cpp.

#pragma mark - Lifecycle hooks

namespace neEngine {

// Ghidra: NEEngine_bootstrapB (FUN_0001ba2c) — dispatch_once bring-up: build the
// shared texture-cache sentinel (a self-linked empty AepTexture) and publish it as
// the cache list head. The binary boxes the head behind a heap holder cell (double
// indirection through DAT_00188464 -> holder -> sentinel, self-linked via +0x8/+0xc);
// the reconstruction flattens that to the direct g_textureCacheList pointer that
// AepTextureCacheSentinel() builds, so this eager bootstrap and the lazy-on-first-use
// acquire path converge on one sentinel.
// @complete
void bootstrapB() {
    static bool once = false;
    if (!once) {
        once = true;
        AepTextureCacheSentinel(); // create + publish the sentinel (once)
    }
}

// Ghidra: NEEngine_bootstrapC (FUN_0001796c) — create the glyph/text-texture
// manager. Defined in Render/neTextTexture.mm, the same translation unit as the
// g_pTextTextureMgr static it must store into (a stub here could not reach that
// static, which left the whole text path dereferencing a null manager).

// Ghidra: FUN_0001bdf8 — walk the shared texture cache list (circular, via +0x8)
// and free every texture's GL name (invalidated by the GL context going away).
// Reads the same g_textureCacheList head the acquire path links into; null before
// the first texture is cached (the lazy sentinel), so the guard is a no-op then.
// @complete
void onDidEnterBackground() {
    AepTexture *head = g_textureCacheList;
    if (head == nullptr) {
        return;
    }
    for (AepTexture *tex = head->next; tex != head; tex = tex->next) {
        tex->releaseGL(); // FUN_00018884
    }
}

// Ghidra: FUN_00030710 — nudge the running play task toward its stop state
// (6->5). AppDelegate's "mainTask" slot holds the current foreground task,
// which during play is a PlayTask; the poked field is PlayTask::m_state (+0x9fc
// in the 32-bit binary). Reaching it by name lets the compiler resolve the real
// rebuilt (64-bit) offset instead of the drifted original literal. The
// reconstruction adds a defensive null guard (the binary dereferences
// unconditionally); behaviour is identical for non-null tasks.
// @complete
void stopMainTask(PlayTask *playTask) {
    if (playTask == nullptr) {
        return;
    }
    if (playTask->m_state == 6) { // running -> stopping
        playTask->m_state = 5;
    }
}

// Ghidra: FUN_0002314c — nudge the running arcade viewer toward its stop state
// (6->0xc). AppDelegate's acMainTask slot holds the AcViewerTask (it registers
// itself via setAcMainTask:self), so the poked +0x20c field is
// AcViewerTask::m_state. The reconstruction adds a defensive null guard (the
// binary dereferences unconditionally); behaviour is identical for non-null
// tasks.
// @complete
void stopAcMainTask(AcViewerTask *acViewerTask) {
    if (acViewerTask == nullptr) {
        return;
    }
    if (acViewerTask->playState() == kAcViewerRunning) {
        acViewerTask->setPlayState(kAcViewerStopping);
    }
}

// Ghidra: requestGameExit (FUN_0002315c) — flag the running AcViewerTask to
// leave the arcade-viewer play (play state @ +0x20c := 8, board-up flag @ +0x1d9
// := 1). The reconstruction adds a defensive null guard (the binary dereferences
// unconditionally); behaviour is identical for non-null tasks.
// @complete
void acMainRequestGameExit(AcViewerTask *acViewerTask) {
    if (acViewerTask == nullptr) {
        return;
    }
    acViewerTask->setPlayState(kAcViewerExitRequested);
    acViewerTask->setPadBoardUp(true);
}

// The arcade-viewer option bridge: a thin forwarder to
// AcViewerTask::applyGameplaySettings so the options view controller stays
// decoupled from the task class. Ghidra: applyGameplaySettings (FUN_00023850).
void acMainApplyGameplaySettings(AcViewerTask *task) {
    if (task != nullptr) {
        task->applyGameplaySettings();
    }
}

// Ghidra: operator_new(0x4c) + BootLogoTask_ctor + setPriority(3).
void startBootTask() {
    BootCreateTask();
}

// Ghidra: FUN_0001be20 — walk the same shared texture cache list on foreground,
// re-decoding + re-uploading each texture (its per-texture reload is FUN_000188ac).
// This is the single reconstruction of the foreground-reload walk (the former
// AepTexture.mm duplicate was dead and has been removed).
// @complete
void notifyEnterForeground() {
    AepTexture *head = g_textureCacheList;
    if (head == nullptr) {
        return;
    }
    for (AepTexture *tex = head->next; tex != head; tex = tex->next) {
        tex->reload(); // FUN_000188ac
    }
}

// Ghidra: playSystemSe FUN_0002c724 — play the UI SE whose loaded source id is
// s_systemSeSource[slot] (+0x14) and cache the returned instance handle in
// g_systemSeHandles[slot] (+0x28). The binary indexes both arrays directly with
// no bounds check (the slot is a fixed caller-side constant).
// @complete
void playSystemSe(int slot) {
    RSND_INSTANCE_ID handle = [[AudioManager sharedManager] playSe:nil
                                                        resourceId:s_systemSeSource[slot]];
    g_systemSeHandles[slot] = handle;
}

// Ghidra: isSePlaying FUN_0002c764 — true while the SE instance cached in `slot`
// is still audible. The binary reads the handle at +0x28, returns false when it
// is negative (the -1 idle sentinel), and otherwise tail-calls
// AudioManager isPlayingSe: on it. The guard is on the HANDLE, not the slot.
// @complete
bool isSePlaying(int slot) {
    RSND_INSTANCE_ID handle = g_systemSeHandles[slot];
    if ((int)handle < 0) {
        return false;
    }
    return [[AudioManager sharedManager] isPlayingSe:handle];
}

// Menu button hit-test (the abstraction the ~13 inlined pointInRect hit-tests
// share): true when the active touch `touchId` in render manager `gfx` lies
// inside `rect` (x,y,w,h) and the button is enabled (enable[0] != 0). Ghidra:
// the inlined findTouchById + neGraphics::pointInRect blocks in
// MainTask/MenuMainTask/AcMain update.
bool menuButtonHit(void *gfx, int touchId, const int *rect, const int *enable) {
    if (enable == nullptr || enable[0] == 0) {
        return false;
    }
    const neTouchPoint *t = static_cast<neGraphics *>(gfx)->findTouchById(touchId);
    if (t == nullptr) {
        return false;
    }
    // Ghidra: MenuMainTask_update divides the tap by the UI scale (g_dwUiScale)
    // before the rect test -- the mode-button rects are stored in logical
    // (unscaled) space, so the raw physical-pixel touch must be scaled down to
    // match (FPToFixed round-to-zero = trunc). Without this, buttons mis-hit on
    // every scale != 1 device (Retina / iPad).
    const int scale = g_dwUiScale > 0 ? g_dwUiScale : 1;
    const int px = (int)((float)t->x / (float)scale);
    const int py = (int)((float)t->y / (float)scale);
    return neGraphics::pointInRect(px, py, rect[0], rect[1], rect[2], rect[3]);
}

// Height (points) of the AEP-rendered content area, used to place UIKit
// overlays below the GL scene (iPad panel layout). This is the AEP screen-quad
// height, which AepManager::screenHeight() also reads. A thin helper — the
// original inlined this read at its one call site, so there is no distinct
// function to verify against.
int aepContentHeight() {
    return AepManager::shared().screenHeight();
}

} // namespace neEngine

// @ 0x2da34
// Ghidra: findCharIndexForColumn. Sibling engine text helper declared in
// neGraphics.h (defined here because it needs Foundation). Walks `text` one
// character at a time accumulating a display width — a halfwidth glyph is 1
// column, a full-width (CJK) glyph is 2 — and returns the index of the
// character at which the running width first reaches `columnWidth`; returns -1
// when the whole string fits. Full-width is detected by NON-membership in a
// halfwidth matcher: the binary tests each glyph with
// `-rangeOfString:options:NSRegularExpressionSearch` (options 0x400) against a
// regex constant, and a glyph that does NOT match counts as 2 columns.
// kHalfWidthPattern is a best-effort recovery of that regex constant (the
// binary's cf__ string): printable ASCII plus the halfwidth-katakana range.
// @complete
int findCharIndexForColumn(NSString *text, int columnWidth) {
    static NSString *const kHalfWidthPattern = @"[\\x01-\\x7e\\uff61-\\uffdc\\uffe8-\\uffee]";
    NSUInteger length = [text length];
    int width = 0;
    for (NSUInteger i = 0; i < length; i++) {
        NSString *ch = [text substringWithRange:NSMakeRange(i, 1)];
        int columns = 1;
        if (ch) {
            NSRange match = [ch rangeOfString:kHalfWidthPattern options:NSRegularExpressionSearch];
            if (match.location == NSNotFound) {
                columns = 2; // not a halfwidth glyph -> counts as two display columns
            }
        }
        width += columns;
        if (width >= columnWidth) {
            return (int)i;
        }
    }
    return -1;
}

// @ 0x1acac
// neTextureForiOS LoadTexture: — decode one PNG (bridged NSData) into a padded
// power-of-two RGBA8 GL texture. Rounds the CGImage's width/height up to the
// next power of two, renders the image Y-flipped into a zeroed RGBA buffer, and
// hands it to neCreateTextureFromData (whose AepTexture is the binary's
// C_TEXTURE); the unpadded source width/height pass through so the sprite
// samples only the used sub-rect. Returns nullptr when the data isn't a
// decodable image.
// @complete
AepTexture *neTextureForiOS::LoadTexture(NSData *data) {
    UIImage *image = [[UIImage alloc] initWithData:data];
    if (image == nil) {
        return nullptr;
    }
    CGImageRef cgImage = image.CGImage;
    const int srcW = (int)CGImageGetWidth(cgImage);
    const int srcH = (int)CGImageGetHeight(cgImage);

    int potW = 1;
    while (potW < srcW) {
        potW <<= 1;
    }
    int potH = 1;
    while (potH < srcH) {
        potH <<= 1;
    }

    unsigned char *pixels = new unsigned char[potW * potH * 4];
    std::memset(pixels, 0, potW * potH * 4);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(
        pixels, potW, potH, 8, potW * 4, colorSpace, kCGImageAlphaPremultipliedLast);
    // Draw the source Y-flipped (GL wants a top-down row order) into the padded
    // buffer.
    CGContextTranslateCTM(ctx, 0, (CGFloat)srcH);
    CGContextScaleCTM(ctx, 1.0f, -1.0f);
    CGContextDrawImage(ctx, CGRectMake(0, 0, srcW, srcH), cgImage);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);

    AepTexture *texture = neCreateTextureFromData(potW, potH, 1, pixels, srcW, srcH);
    delete[] pixels;
    return texture;
}

// Ghidra: FUN_00011cbc (neTextureLoadSingle) — upload an in-memory PNG (a
// bridged NSData* of image bytes) as a single-tile texture. Same one-tile setup
// as load(), but the tile comes from LoadTexture (the in-memory decoder above)
// instead of the file cache. Defined here rather than neTextureForiOS.cpp
// because LoadTexture needs NSData/CoreGraphics. Returns 0 on success, -1 for
// null data, -5 on decode/upload failure.
// @complete
int neTextureForiOS::loadFromImageData(const void *imageData) {
    if (imageData == nullptr) {
        return -1;
    }
    m_tileCount = 1;
    m_tiles = new AepTexture *[1];
    m_tileRects = new AepTile[1];
    m_tileWidths = new int[1];
    m_tileHeights = new int[1];

    m_tiles[0] = LoadTexture((__bridge NSData *)imageData);
    if (m_tiles[0] == nullptr) {
        return -5;
    }
    m_tileWidths[0] = m_tiles[0]->textureWidth();
    m_tileHeights[0] = m_tiles[0]->textureHeight();
    AepTextureUploadTiles(&m_tileRects[0], m_tiles[0]);
    return 0;
}

// UI scale (screenScale * 0.5) as float bits; published by
// MainViewController::loadView, read by the task m_uiScale caches
// (neEngineBridge.h).
int g_dwUiScale = 0;

// neTextureForiOS_draw (FUN_0000fbcc): the flat-argument wrapper the task draw
// passes call — packs the args into a neSpriteDrawParams and emits the sprite
// via this texture's draw() into aep's ordering table. Lives here (ObjC++)
// rather than neTextureForiOS.cpp because AepManager's header pulls Foundation.
// Argument order verified against FUN_00011468 (drawSprite) + the call sites
// (AcViewer digit blit / MainTask badges): u,v, source w,h, screen x,y, scale
// sx,sy, rotation, anchor ex,ey, colour, alpha, blend, colour-multiplier,
// extra, priority; trailing layer (1) is the live-command marker draw() stamps.
// Disassembly-verified: r0 = aep + 0x727538 (the ordering table), r1 preserved as
// pTexture, args 9/10 (sx/sy) taken through vcvt.f32.s32 to float, and the
// extra->clip / colorMul / alpha / layer routing matches FUN_0000fbcc store-for-store.
// @complete
void neTextureForiOS_draw(AepManager *aep,
                          neTextureForiOS *tex,
                          int u,
                          int v,
                          int w,
                          int h,
                          int x,
                          int y,
                          int sx,
                          int sy,
                          int rotation,
                          int ex,
                          int ey,
                          int color,
                          int alpha,
                          int blend0,
                          int colorMul,
                          const int *extra,
                          int priority,
                          int layer) {
    if (tex == nullptr) {
        return;
    }
    neSpriteDrawParams p;
    p.u = u;
    p.v = v;
    p.w = w;
    p.h = h;
    p.x = x;
    p.y = y;
    p.sx = sx;
    p.sy = sy;
    p.rotation = rotation;
    p.ex = ex;
    p.ey = ey;
    p.color = color;
    // FUN_0000fbcc routes `alpha` to command +0x3c (str r4=[r7+0x30] @ 0x0fc1a), which
    // draw() fills from p.alpha -> nColorRGB; storing it in the unread p.blend1 dropped
    // it (every wrapped sprite got +0x3c = 0). `layer` is command +0x44 (str r4=[r7+0x44]
    // @ 0x0fc02), which draw() fills from p.layer -> clipTop.
    p.alpha = alpha;
    p.blend0 = static_cast<short>(blend0);
    p.colorMul = colorMul;
    // FUN_0000fbcc's `extra` arg is the clip-rect block pointer routed to command
    // +0x4c (str r10=[r7+0x3c] @ 0x0fbe6; drawSprite copies 16 bytes from it when
    // non-null). Store it as a real pointer (p.clip) rather than truncating into an
    // int, and let draw() forward it to the clip-spill slot.
    p.clip = extra;
    p.layer = layer;
    p.priority = priority;
    tex->draw(aep->orderingTable(), p);
}
