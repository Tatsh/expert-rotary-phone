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
};

// Scene manager owning the root view controller (guarded singleton @ DAT_00187b74).
class neSceneManager {
public:
    static neSceneManager &shared();          // Ghidra: NESceneManager_shared (FUN_0000b194)
                                              //   lazily ctors via FUN_0002c5c0 (NESceneManager_init)
    void attachRoot(void *viewController);    // Ghidra: NESceneManager_attachRoot (FUN_0002c5b8)
};

// Renderer / graphics manager (singleton @ DAT_00188384, +0x88 = content scale).
// Related to the neIGLES GL abstraction (Project/System/src/OpenGL/neGLES11.cpp).
class neGraphics {
public:
    // Lazily creates the renderer and stores the content scale.
    static void configure(float contentScale); // Ghidra: NEGraphics_configure (FUN_00012368)
};

// Free-standing engine lifecycle hooks fired from the UIApplicationDelegate.
namespace neEngine {
    void bootstrapB();               // Ghidra: NEEngine_bootstrapB (FUN_0001ba2c)
    void bootstrapC(int flag);       // Ghidra: NEEngine_bootstrapC (FUN_0001796c)
    void onWillResignActive();       // Ghidra: NEEngine_onWillResignActive  (FUN_0000b278)
    void onWillResignActive2();      // Ghidra: NEEngine_onWillResignActive2 (FUN_0000b35c)
    void onDidEnterBackground();     // Ghidra: NEEngine_onDidEnterBackground (FUN_0001bdf8)
    void stopMainTask();             // Ghidra: NEEngine_stopMainTask   (FUN_00030710)
    void stopAcMainTask();           // Ghidra: NEEngine_stopAcMainTask (FUN_0002314c)
}

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
