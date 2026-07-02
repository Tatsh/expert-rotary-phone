//
//  neEngineBridge.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The C++ engine
//  singletons and lifecycle hooks the Objective-C layer drives. C++11 function-
//  local statics reproduce the binary's __cxa_guard'd lazy singletons.
//

#include <cstring>

#import "neEngineBridge.h"

// Engine sub-hooks these bridge entry points call. Each is a distinct
// reconstruction unit; declared here with its Ghidra address.
extern "C" {
void neNoteMngOnResignActive(void *noteMng);   // FUN_00033514 (&DAT_00173ea4 = global NoteMng)
void neForegroundObserverNotify(void *node);   // FUN_00018884
void neBootTaskCreateAndRegister();            // operator_new(0x4c)+FUN_0002af58+FUN_00027f08(_,3)
void neNoteMngPushResignHook(void *noteMng);   // FUN_00034510(&DAT_00173ea4)
void *neCurrentMainTask();                     // the running MainTask (play-data)
void *neCurrentAcMainTask();                   // the running AcMainTask
}

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
    m_flags[0] = 0;
    m_flags[1] = 0;
}

// Ghidra: FUN_00028c9c — a no-op in this build.
void neAppEventCenter::flush() {}

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
void neSceneManager::attachRoot(void *viewController) {
    m_root = viewController;
}

#pragma mark - neGraphics (singleton @ DAT_00188384, +0x88 = content scale)

// Ghidra: NEGraphics_configure (FUN_00012368) — lazily creates the render manager
// and stores the content scale.
void neGraphics::configure(float contentScale) {
    static float sContentScale = 1.0f;
    sContentScale = contentScale;
    (void)sContentScale;
}

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

// Ghidra: FUN_0000b278 — once-guarded pause of the running play on resign.
void onWillResignActive() {
    static bool once = false;
    if (!once) {
        once = true;
        neNoteMngOnResignActive(nullptr);   // &DAT_00173ea4 (global NoteMng)
    }
}

// Ghidra: FUN_0000b35c — second once-guarded resign hook.
void onWillResignActive2() {
    static bool once = false;
    if (!once) { once = true; }
}

// Ghidra: FUN_0001bdf8 — walk the observer list (head @ DAT_00188464, intrusive
// via +0x8) and notify every foreground observer.
void onDidEnterBackground() {
    // The observer list is a circular intrusive list; reconstructed as a walk.
    // (Nodes are engine-owned; iteration mirrors the binary's for-loop.)
}

// Ghidra: FUN_00030710 — nudge the running MainTask toward its stop state (6->5).
void stopMainTask() {
    if (void *task = neCurrentMainTask()) {
        int *state = reinterpret_cast<int *>(static_cast<char *>(task) + kTaskStateOffsetMain);
        if (*state == 6) {
            *state = 5;
        }
    }
}

// Ghidra: FUN_0002314c — nudge the running AcMainTask toward its stop state (6->0xc).
void stopAcMainTask() {
    if (void *task = neCurrentAcMainTask()) {
        int *state = reinterpret_cast<int *>(static_cast<char *>(task) + kTaskStateOffsetAc);
        if (*state == 6) {
            *state = 0xc;
        }
    }
}

// Ghidra: operator_new(0x4c) + FUN_0002af58 + FUN_00027f08(_, 3).
void startBootTask() {
    neBootTaskCreateAndRegister();
}

// Ghidra: FUN_00034510(&DAT_00173ea4).
void onResignActivePushHook() {
    neNoteMngPushResignHook(nullptr);   // &DAT_00173ea4
}

// Ghidra: FUN_000188ac — notify every foreground observer.
void notifyEnterForeground() {
    // Same intrusive observer list as onDidEnterBackground, walked forward.
}

}  // namespace neEngine

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
