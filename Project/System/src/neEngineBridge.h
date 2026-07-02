//
//  neEngineBridge.h
//  pop'n rhythmin
//
//  C++ interface to the "ne" (System-layer) engine singletons that the
//  Objective-C layer drives at launch and across lifecycle transitions. The
//  engine is C++ (guarded lazy-init singletons, operator_new), so these are
//  modelled as C++ classes; any Objective-C file that calls them is compiled as
//  Objective-C++ (.mm) — e.g. Project/AppDelegate.mm.
//
//  PROVISIONAL: these three singletons are real C++ objects (globals
//  DAT_00187bb8 / DAT_00187b74 / DAT_00188384) whose *exact* class names have
//  not yet been recovered from RTTI / debug strings, so the names below are
//  best-effort and follow the System-layer lowercase "ne" convention (cf.
//  neIGLES, neTextTexture). Each member cites the Ghidra symbol it maps to
//  (project rb420, program PopnRhythmin). Replace with the true class names as
//  they are recovered (see HANDOFF.md — Engine).
//

#pragma once

// App-wide event / notification center (guarded singleton @ DAT_00187bb8).
// Touched at launch, flushed on background/terminate, poked on push.
class neAppEventCenter {
public:
    static neAppEventCenter &shared();   // Ghidra: NEAppEventCenter_shared (FUN_0000b150)
    void begin();                        // Ghidra: NEAppEventCenter_begin  (FUN_00028c70)
    void flush();                        // Ghidra: NEAppEventCenter_flush  (FUN_00028c9c)

    // First two fields of the singleton (DAT_00187bb8 / DAT_00187bbc): the last
    // played music id and sheet (difficulty), persisted via UserSettingData.
    int  lastMusic() const;              // DAT_00187bb8
    void setLastMusic(int music);
    int  lastSheet() const;              // DAT_00187bbc
    void setLastSheet(int sheet);

private:
    int m_lastMusic = 0;     // +0x00
    int m_lastSheet = 0;     // +0x04
    float m_state[16] = {};  // +0x08..0x44 (transient event-center state, zeroed by begin)
    int m_flags[2] = {};     // +0x40..0x44
};

// Scene manager owning the root view controller (guarded singleton @ DAT_00187b74).
class neSceneManager {
public:
    static neSceneManager &shared();          // Ghidra: NESceneManager_shared (FUN_0000b194)
                                              //   lazily ctors via FUN_0002c5c0 (NESceneManager_init)
    // Store the app's root view controller. `viewController` is a bridged
    // UIViewController — this is the ObjC->C++ boundary, so it stays an opaque
    // pointer on the C++ side. Ghidra: NESceneManager_attachRoot (FUN_0002c5b8).
    void attachRoot(void *viewController);

    // The stored root view controller (the app's navigation host the title/menu
    // flow sends Goto*/Insert*/Delete* messages to). Ghidra:
    // NESceneManager_rootViewController (FUN_0002c5bc) returns m_root.
    static void *rootViewController();

    // Live drawable metrics (Ghidra globals DAT_00187b7c/78/80), updated by the
    // GL view on layout; used to place notes/sprites on screen.
    static float screenWidth();
    static float screenHeight();
    static float screenScale();
    static void setScreenMetrics(float width, float height, float scale);

    // Device-class flag (Ghidra global DAT_00187b84). The boot logo setup uses it to
    // pick phone- vs pad-sized branding assets, so it is modelled as "is a pad-class
    // display" (true when the flag is non-zero); set at launch alongside the metrics.
    static bool isPadDisplay();
    static void setPadDisplay(bool isPad);

private:
    void *m_root = nullptr;   // +0x00 the bridged root UIViewController
};

// The renderer / graphics manager (singleton @ DAT_00188384, +0x88 = content
// scale) is a full class of its own — see Render/neGraphics.h. It also owns the
// live touch pool driven by neGLView.

// Free-standing engine lifecycle hooks fired from the UIApplicationDelegate.
//
// NOTE: the app resign handler also *touches* the global NoteMng/AcNoteMng to
// force their construction — those are NoteMng::shared() (FUN_0000b278) and
// AcNoteMng::shared() (FUN_0000b35c), not engine hooks, so they live on those
// classes rather than here. The actual resign work is NoteMng::onResignActivePushHook
// (FUN_00034510).
namespace neEngine {
    void bootstrapB();               // Ghidra: NEEngine_bootstrapB (FUN_0001ba2c)
    void bootstrapC(int flag);       // Ghidra: NEEngine_bootstrapC (FUN_0001796c)
    void onDidEnterBackground();     // Ghidra: NEEngine_onDidEnterBackground (FUN_0001bdf8)

    // Nudge the running MainTask / AcMainTask toward its stop state. The task
    // pointer is passed in by the caller (AppDelegate's _mainTask / _acMainTask).
    void stopMainTask(void *mainTask);     // Ghidra: NEEngine_stopMainTask   (FUN_00030710)
    void stopAcMainTask(void *acMainTask); // Ghidra: NEEngine_stopAcMainTask (FUN_0002314c)

    // Create + register the app's boot task at priority 3.
    void startBootTask();            // Ghidra: operator_new(0x4c) + FUN_0002af58 + FUN_00027f08(_,3)
    // Notify every foreground observer (observer list head @ DAT_00188464).
    void notifyEnterForeground();    // Ghidra: FUN_000188ac walk

    // Play a short UI system sound effect and cache its instance handle in slot
    // `slot` of the scene manager's SE-handle table (so it can be stopped later).
    // Slot 1 is the decide/confirm SE, slot 2 the cancel/back SE.
    // Ghidra: SysSePlayIntoSlot (FUN_0002c724) — [[AudioManager sharedManager]
    // playSe:resourceId:] storing the handle at the scene-manager global + 0x28.
    void playSystemSe(int slot);
}

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
