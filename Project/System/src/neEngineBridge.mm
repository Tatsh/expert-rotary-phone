//
//  neEngineBridge.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The C++ engine
//  singletons and lifecycle hooks the Objective-C layer drives. C++11 function-
//  local statics reproduce the binary's __cxa_guard'd lazy singletons.
//

#include <cstring>

#import "AepTexture.h"
#import "AudioManager.h"
#import "neEngineBridge.h"

// Create + register the boot logo splash task (Task/TaskFactory.mm).
class C_TASK;
C_TASK *BootCreateTask();   // operator_new(0x4c) + BootLogoTask_ctor + setPriority(3)

// Head of the shared-texture cache list (Ghidra: DAT_00188464). Registered/
// unlinked by AepTexture as cached textures are acquired/released.
AepTexture *g_textureCacheList = nullptr;

// Task state-machine field offsets (play-data): 0x9fc (main), 0x20c (arcade);
// state 6 = running, transitioned to a stopping state on resign.
static const int kTaskStateOffsetMain = 0x9fc;
static const int kTaskStateOffsetAc = 0x20c;

#pragma mark - neAppEventCenter (guarded singleton @ DAT_00187bb8)

neAppEventCenter &neAppEventCenter::shared() {
    static neAppEventCenter instance;   // Ghidra: NEAppEventCenter_shared (FUN_0000b150)
    return instance;
}

// Ghidra: FUN_00028c70 — zero the transient event-center state.
void neAppEventCenter::begin() {
    std::memset(m_state, 0, sizeof(m_state));
    _endDate = nil;
    std::memset(m_state2, 0, sizeof(m_state2));
    m_flags[0] = 0;
    m_flags[1] = 0;
}

// Ghidra: FUN_00028c9c — a no-op in this build.
void neAppEventCenter::flush() {}

// @ 0x292c0 — record the session end time (_endDate @ +0x24). The binary released the
// previous NSDate and retained [NSDate date]; the ARC strong-ivar store does both.
void neAppEventCenter::setEndDate() {
    _endDate = [NSDate date];
}

// AC-viewer selection state (event-center region): the current browsing pair and the
// pending "Sel" pair carried into the play scene.
static int g_dwAcViewerMusicId       = -1;  // g_dwAcViewerMusicId      @ 0x187bf0
static int g_wAcViewerDifficulty    = 0;   // g_wAcViewerDifficulty    @ 0x187bf4
static int g_dwAcViewerSelMusicId    = -1;  // g_dwAcViewerSelMusicId   @ 0x187bf8
static int g_wAcViewerSelDifficulty = 0;   // g_wAcViewerSelDifficulty @ 0x187bfc

// Reset the pending selection to the "none" sentinels (music id -1, difficulty 0xffff)
// — done when the viewer is cancelled.
void neAppEventCenter::clearAcViewerSelection() {
    g_dwAcViewerSelMusicId = -1;
    g_wAcViewerSelDifficulty = 0xffff;
}

int  neAppEventCenter::acViewerMusicId() { return g_dwAcViewerMusicId; }
int  neAppEventCenter::acViewerDifficulty() { return g_wAcViewerDifficulty; }
void neAppEventCenter::setAcViewerSelection(int musicId, int difficulty) {
    g_dwAcViewerMusicId = musicId;
    g_wAcViewerDifficulty = difficulty;
}
int  neAppEventCenter::acViewerSelMusicId() { return g_dwAcViewerSelMusicId; }
int  neAppEventCenter::acViewerSelDifficulty() { return g_wAcViewerSelDifficulty; }
void neAppEventCenter::commitAcViewerSelection() {
    g_dwAcViewerSelMusicId = g_dwAcViewerMusicId;
    g_wAcViewerSelDifficulty = g_wAcViewerDifficulty;
}

// Reset only the current browsing music id (@ 0x187bf0) to the "none" sentinel.
void neAppEventCenter::clearAcViewerCurrentMusic() {
    g_dwAcViewerMusicId = -1;
}

// e-AMUSEMENT login context (event-center region). The login flow populates these;
// the music-checker score sync reads them. Modelled as file-static globals, matching
// the AC-viewer selection state above.
static id        g_pLinkRefId      = nil;    // g_pLinkRefId       @ 0x187be0 (+0x28)
static NSString *g_pInputPassword  = nil;    // g_pInputPassword   @ 0x187be4 (+0x2c)
static bool      g_bRequireOtpInput = false; // g_bRequireOtpInput @ 0x187be9 (+0x31)

id        neAppEventCenter::linkRefId()      { return g_pLinkRefId; }
NSString *neAppEventCenter::inputPassword()  { return g_pInputPassword; }
bool      neAppEventCenter::requireOtpInput() { return g_bRequireOtpInput; }

// Writers for the login context, driven by the KID-input screen. Under ARC the strong
// static ivars take care of the retain/release the binary did by hand.
void neAppEventCenter::setInputPassword(NSString *password) { g_pInputPassword = password; }
void neAppEventCenter::setLinkRefId(id refId)               { g_pLinkRefId = refId; }
void neAppEventCenter::setRequireOtpInput(bool require)     { g_bRequireOtpInput = require; }

// pop'n-link availability (event-center region global @ g_bLinkButtonsEnabled). Populated
// by the (not-yet-reconstructed) pop'n-link login flow; false until the KID is linked, so
// the score-checker / quiz buttons stay disabled and the top screen forces KID input.
static bool g_bLinkButtonsEnabled = false;
bool      neAppEventCenter::linkButtonsEnabled() { return g_bLinkButtonsEnabled; }
void      neAppEventCenter::setLinkButtonsEnabled(bool enabled) { g_bLinkButtonsEnabled = enabled; }

int neAppEventCenter::lastMusic() const { return m_lastMusic; }
void neAppEventCenter::setLastMusic(int music) { m_lastMusic = music; }
int neAppEventCenter::lastSheet() const { return m_lastSheet; }
void neAppEventCenter::setLastSheet(int sheet) { m_lastSheet = sheet; }

#pragma mark - neSceneManager (guarded singleton @ DAT_00187b74)

neSceneManager &neSceneManager::shared() {
    static neSceneManager instance;   // Ghidra: NESceneManager_shared (FUN_0000b194)
    return instance;
}

// Ghidra: NESceneManager_attachRoot (FUN_0002c5b8).
void neSceneManager::attachRoot(UIViewController *viewController) {
    m_root = viewController;
}

// Ghidra: NESceneManager_rootViewController (FUN_0002c5bc) — returns m_root.
UIViewController *neSceneManager::rootViewController() {
    return shared().m_root;
}

// Ghidra: getNormalSoundName @ 0x2c7c0 — the display name for a touch-sound kind, indexed by kind
// (low 16 bits; anything past the last entry folds to 0). The binary returns one of ten constant
// CFStrings from PTR_cf_normal_001310d4; the picker rows show it. Returned as a __bridge void* to
// match the header's opaque type (mirroring rootViewController()'s ObjC-on-the-far-side handoff).
void *neSceneManager::normalSoundName(int soundNo) {
    static NSString *const kNames[] = {
        @"normal", @"water", @"crack",    @"shooting", @"tambourine",
        @"sword",  @"cheer", @"shishamo", @"bag",      @"bat",
    };
    unsigned kind = static_cast<unsigned>(soundNo) & 0xffff;
    if (kind > 9) {
        kind = 0;
    }
    return (__bridge void *)kNames[kind];
}

// Live drawable metrics (Ghidra globals DAT_00187b7c/78/80).
static float s_screenWidth = 640.0f;
static float s_screenHeight = 960.0f;
static float s_screenScale = 1.0f;

float neSceneManager::screenWidth() { return s_screenWidth; }
float neSceneManager::screenHeight() { return s_screenHeight; }
float neSceneManager::screenScale() { return s_screenScale; }

void neSceneManager::setScreenMetrics(float width, float height, float scale) {
    s_screenWidth = width;
    s_screenHeight = height;
    s_screenScale = scale;
}

// Device-class flag (Ghidra global DAT_00187b84).
static bool s_isPadDisplay = false;
bool neSceneManager::isPadDisplay() { return s_isPadDisplay; }
void neSceneManager::setPadDisplay(bool isPad) { s_isPadDisplay = isPad; }

// neGraphics (the DAT_00188384 render/input manager) lives in Render/neGraphics.cpp.

#pragma mark - Lifecycle hooks

namespace neEngine {

// Ghidra: NEEngine_bootstrapB (FUN_0001ba2c) / NEEngine_bootstrapC (FUN_0001796c) —
// engine bring-up steps run once at launch (guarded singletons in the binary).
void bootstrapB() {
    static bool once = false;
    if (!once) { once = true; }
}

void bootstrapC(int /*flag*/) {
    static bool once = false;
    if (!once) { once = true; }
}

// Ghidra: FUN_0001bdf8 — walk the reloadable-texture list (circular, via +0x8)
// and free every texture's GL name (invalidated by the GL context going away).
void onDidEnterBackground() {
    AepTexture *head = g_textureCacheList;
    if (head == nullptr) {
        return;
    }
    for (AepTexture *tex = head->next; tex != head; tex = tex->next) {
        tex->releaseGL();   // FUN_00018884
    }
}

// Ghidra: FUN_00030710 — nudge the passed MainTask toward its stop state (6->5).
void stopMainTask(MainTask *mainTask) {
    if (mainTask == nullptr) {
        return;
    }
    int *state = reinterpret_cast<int *>(reinterpret_cast<char *>(mainTask) + kTaskStateOffsetMain);
    if (*state == 6) {
        *state = 5;
    }
}

// Ghidra: FUN_0002314c — nudge the passed AcMainTask toward its stop state (6->0xc).
void stopAcMainTask(AcMainTask *acMainTask) {
    if (acMainTask == nullptr) {
        return;
    }
    int *state = reinterpret_cast<int *>(reinterpret_cast<char *>(acMainTask) + kTaskStateOffsetAc);
    if (*state == 6) {
        *state = 0xc;
    }
}

// Ghidra: requestGameExit (FUN_0002315c) — flag the running AcMainTask to leave the
// arcade-viewer play (exit state @ +0x20c := 8, exit-request flag @ +0x1d9 := 1).
void acMainRequestGameExit(AcMainTask *acMainTask) {
    if (acMainTask == nullptr) {
        return;
    }
    char *t = reinterpret_cast<char *>(acMainTask);
    *reinterpret_cast<int *>(t + 0x20c) = 8;
    *(t + 0x1d9) = 1;
}

// Ghidra: applyGameplaySettings (FUN_00023850). TODO(dep): the full routine also copies
// the UserSettingData acv* selections into the task (+0x1f8 pop-kun / +0x1fc hid-sud /
// +0x1f4 hi-speed / +0x200 ran-mir) and re-seeks the AcNoteMng note stream — those touch
// note-engine internals not yet bridged. The observable tail (resume the render loop and,
// on phone, advance the task's play state @ +0x20c := 0xd) is modelled here.
void acMainApplyGameplaySettings(AcMainTask *acMainTask) {
    if (acMainTask == nullptr) {
        return;
    }
    [neSceneManager::rootViewController() performSelector:@selector(ResumeLoop)];
    if (!neSceneManager::isPadDisplay()) {
        *reinterpret_cast<int *>(reinterpret_cast<char *>(acMainTask) + 0x20c) = 0xd;
    }
}

// Ghidra: operator_new(0x4c) + BootLogoTask_ctor + setPriority(3).
void startBootTask() {
    BootCreateTask();
}

// Walk the same reloadable-texture list on foreground, re-decoding + re-uploading
// each texture (its per-texture reload is Ghidra FUN_000188ac).
void notifyEnterForeground() {
    AepTexture *head = g_textureCacheList;
    if (head == nullptr) {
        return;
    }
    for (AepTexture *tex = head->next; tex != head; tex = tex->next) {
        tex->reload();      // FUN_000188ac
    }
}

// SE-instance handles for short UI sounds, indexed by slot (Ghidra: the scene
// manager global DAT_00187b74 + 0x28). Kept here as the engine's SE-handle table.
static RSND_INSTANCE_ID g_systemSeHandles[8] = {0};

// @ 0x2c724 — play a UI SE and remember its instance handle in `slot`. The binary
// passes the SE resource id in registers (not recoverable from the decompile), so
// the slot doubles as the resource selector here.
void playSystemSe(int slot) {
    RSND_INSTANCE_ID handle =
        [[AudioManager sharedManager] playSe:nil resourceId:(RSND_SOURCE_ID)slot];
    if (slot >= 0 && slot < (int)(sizeof(g_systemSeHandles) / sizeof(g_systemSeHandles[0]))) {
        g_systemSeHandles[slot] = handle;
    }
}

// @ 0x2c764 (isSePlaying) — true while the SE instance cached in `slot` is still
// audible. The binary probes AudioManager isPlayingSe: on the handle stored at the
// scene-manager global + 0x28; here that handle table is g_systemSeHandles.
bool isSePlaying(int slot) {
    if (slot < 0 || slot >= (int)(sizeof(g_systemSeHandles) / sizeof(g_systemSeHandles[0]))) {
        return false;
    }
    return [[AudioManager sharedManager] isPlayingSe:g_systemSeHandles[slot]] != NO;
}

}  // namespace neEngine
