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

// Ghidra: NESceneManager_rootViewController (FUN_0002c5bc) — returns m_root.
void *neSceneManager::rootViewController() {
    return shared().m_root;
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
void stopMainTask(void *mainTask) {
    if (mainTask == nullptr) {
        return;
    }
    int *state = reinterpret_cast<int *>(static_cast<char *>(mainTask) + kTaskStateOffsetMain);
    if (*state == 6) {
        *state = 5;
    }
}

// Ghidra: FUN_0002314c — nudge the passed AcMainTask toward its stop state (6->0xc).
void stopAcMainTask(void *acMainTask) {
    if (acMainTask == nullptr) {
        return;
    }
    int *state = reinterpret_cast<int *>(static_cast<char *>(acMainTask) + kTaskStateOffsetAc);
    if (*state == 6) {
        *state = 0xc;
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

}  // namespace neEngine

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
