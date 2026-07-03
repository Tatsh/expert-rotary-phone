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

// Real types used across the ObjC<->C++ boundary (this header is ObjC++; every including
// translation unit is .mm). Using the true types instead of opaque void* keeps the bridge
// signatures honest.
@class UIViewController;
class MainTask;     // System/src/Task/MainTask.h   (: C_TASK)
class AcMainTask;   // System/src/Task/AcMainTask.h (: C_TASK)

// App-wide event / notification center (guarded singleton @ DAT_00187bb8).
// Touched at launch, flushed on background/terminate, poked on push.
class neAppEventCenter {
public:
    static neAppEventCenter &shared();   // Ghidra: NEAppEventCenter_shared (FUN_0000b150)
    // Record the last-played music id (drives the "continue from" / event state).
    // Ghidra: neAppEventSetLastMusic (global DAT_00187bf0).
    static void setLastMusic(int music);
    // Reset the AC-viewer's pending selection to the "none" sentinels (music id -1,
    // difficulty 0xffff) — done when the viewer is cancelled. Ghidra globals
    // g_dwAcViewerSelMusicId @ 0x187bf8 / g_wAcViewerSelDifficulty @ 0x187bfc (in the
    // event-center region; NEAppEventCenter_shared() is touched first to force init).
    static void clearAcViewerSelection();

    // The AC-viewer's *current* browsing selection — the music id / difficulty the
    // arcade-viewer list is showing right now. Read by the AC-viewer option screen to
    // build its header (song banner, BPM, difficulty). Ghidra globals
    // g_dwAcViewerMusicId @ 0x187bf0 / g_wAcViewerDifficulty @ 0x187bf4.
    static int  acViewerMusicId();
    static int  acViewerDifficulty();
    static void setAcViewerSelection(int musicId, int difficulty);
    // The *pending* selection carried into the play scene (compared against the current
    // pair to decide "continue vs. play from start"). Ghidra globals
    // g_dwAcViewerSelMusicId @ 0x187bf8 / g_wAcViewerSelDifficulty @ 0x187bfc.
    static int  acViewerSelMusicId();
    static int  acViewerSelDifficulty();
    // Commit the current browsing pair as the pending one (Sel := current), done when
    // the arcade-viewer PLAY button is pressed.
    static void commitAcViewerSelection();
    // Reset only the *current* AC-viewer browsing music id to the "none" sentinel (-1),
    // leaving the difficulty untouched — done when the category list's back button
    // cancels the viewer. Ghidra global g_dwAcViewerMusicId @ 0x187bf0.
    static void clearAcViewerCurrentMusic();

    // e-AMUSEMENT login context read by the music-checker score sync. The (not-yet-
    // reconstructed) login flow populates these; they sit in the event-center region.
    // Ghidra globals g_pLinkRefId @ 0x187be0 (event-center +0x28), g_pInputPassword
    // @ 0x187be4 (+0x2c) and g_bRequireOtpInput @ 0x187be9 (+0x31).
    static id linkRefId();            // the Core Data ref-id the arcade records key on
    static NSString *inputPassword(); // the entered account password
    static bool requireOtpInput();    // true when a one-time password must still be entered

    void begin();                        // Ghidra: NEAppEventCenter_begin  (FUN_00028c70)
    void flush();                        // Ghidra: NEAppEventCenter_flush  (FUN_00028c9c)

    // Record a finished play's result into the event center (so the result screen can
    // read it back): looks up the stored high score for the current music/sheet, sets
    // the "new record" flag when `score` beats it, and stashes the COOL/GREAT tallies
    // and the score. Returns true when a new record was set. The play task additionally
    // writes the rank (+0x14) and max combo (+0x18) after this call. Ghidra: FUN_0002930c.
    bool recordPlayResult(int score, int cool, int great);

    // First two fields of the singleton (DAT_00187bb8 / DAT_00187bbc): the last
    // played music id and sheet (difficulty), persisted via UserSettingData. (The
    // setter is the static setLastMusic above, which writes the DAT_00187bf0 global.)
    int  lastMusic() const;              // DAT_00187bb8
    int  lastSheet() const;              // DAT_00187bbc

    // --- Just-finished play's result record ---
    // The play task fills these (recordPlayResult + direct stores of rank/combo);
    // the result screen (PlayResultTask::resultSetup, Ghidra FUN_0003dfe0) snapshots
    // them. Offsets are the DAT_00187bxx globals relative to this singleton base
    // (DAT_00187bb8 == +0x00) and sit inside the transient state region above, so
    // they are read raw at their exact byte offsets.
    short coolCount()  const { return raw<short>(0x08); }         // DAT_00187bc0 low
    short greatCount() const { return raw<short>(0x0a); }         // DAT_00187bc0 high
    short goodCount()  const { return raw<short>(0x0c); }         // DAT_00187bc4 low
    short badCount()   const { return raw<short>(0x0e); }         // DAT_00187bc4 high
    int   playScore()  const { return raw<int>(0x10); }           // DAT_00187bc8
    short playRank()   const { return raw<short>(0x14); }         // DAT_00187bcc
    short maxCombo()   const { return raw<short>(0x18); }         // DAT_00187bd0
    bool  isCleared()  const { return raw<unsigned char>(0x1c) != 0; } // DAT_00187bd4
    bool  isNewRecord()const { return raw<unsigned char>(0x32) != 0; } // DAT_00187bea

    // Read the player's stored local best for this play's music/sheet (out-params
    // may be null). Ghidra: FUN_000293c4 (-> ScoreData getScoreData... FUN_00029438).
    void readStoredResult(int *outScore, short *outRank, int *outPlayCnt,
                          bool *outFullCombo, bool *outPerfect);   // @ 0x293c4

    // Commit this play's result into the local Core Data ScoreData store
    // (setFullCombo/Perfect/Rank/Score/PlayCnt + save). Ghidra: FUN_00028ca0 @ 0x28ca0.
    void commitResultToScoreData();

private:
    template <typename T> T raw(int off) const {
        return *reinterpret_cast<const T *>(reinterpret_cast<const char *>(this) + off);
    }

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
    // Store the app's root view controller. Ghidra: NESceneManager_attachRoot (FUN_0002c5b8).
    void attachRoot(UIViewController *viewController);

    // The stored root view controller (the app's navigation host the title/menu
    // flow sends Goto*/Insert*/Delete* messages to). Ghidra:
    // NESceneManager_rootViewController (FUN_0002c5bc) returns m_root.
    static UIViewController *rootViewController();

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

    // The scene manager owns a small pool of shared "system" SEs (decide/cancel/…),
    // reloaded on each scene change. A scene teardown releases the current pool,
    // cleans up the mixer, then reloads it for the next scene. Ghidra:
    // releaseSystemSe FUN_0002c6bc @ 0x2c6bc / loadSystemSe FUN_0002c5c8 @ 0x2c5c8
    // (both operate on this singleton, DAT_00187b74).
    void releaseSystemSe();
    void loadSystemSe();

    // Touch-sound ("hit sound") name tables owned by the scene manager. Both take a
    // touch-sound kind index (0..9) and return a bridged NSString (cast with
    // __bridge on the ObjC side, mirroring rootViewController()):
    //  * hitSoundName   -> the bundle resource base-name of the SE previewed for that
    //    kind (used to build the ".m4a" path loaded into the low-latency SE player).
    //  * normalSoundName -> the kind's user-facing display name (shown in the touch-
    //    sound picker rows).
    // Ghidra: getHitSoundName(&g_pNeSceneManager, no) / getNormalSoundName(&g_pNeSceneManager, no).
    static void *hitSoundName(int soundNo);
    static void *normalSoundName(int soundNo);

private:
    // +0x00 the root UIViewController. __unsafe_unretained so this C++ singleton stays a plain
    // (trivial) type under ARC and does not own the VC (the UIWindow owns it), matching the
    // binary's non-retaining raw pointer store.
    __unsafe_unretained UIViewController *m_root = nullptr;
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
    void stopMainTask(MainTask *mainTask);     // Ghidra: NEEngine_stopMainTask   (FUN_00030710)
    void stopAcMainTask(AcMainTask *acMainTask); // Ghidra: NEEngine_stopAcMainTask (FUN_0002314c)

    // Ask the running AcMainTask to leave the arcade-viewer play and exit back to the
    // menu (sets its exit state @ +0x20c := 8 and exit-request flag @ +0x1d9 := 1).
    // Ghidra: requestGameExit (FUN_0002315c).
    void acMainRequestGameExit(AcMainTask *acMainTask);
    // Push the arcade-viewer option selections (hi-speed / pop-kun / hid-sud / ran-mir)
    // into the live AcMainTask, re-seek its note stream and resume the render loop.
    // Ghidra: applyGameplaySettings (FUN_00023850).
    void acMainApplyGameplaySettings(AcMainTask *acMainTask);

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

    // Menu button hit-test: true when the active touch `touchId` in the render
    // manager `gfx` lies inside `rect` (x,y,w,h) and `enable[0]` is set.
    // Ghidra: FUN_0002d974.
    bool menuButtonHit(void *gfx, int touchId, const int *rect, const int *enable);

    // Set the scene's touch input mode (0 = normal, non-zero = suspended while a
    // modal/animation runs). Ghidra: neSceneSetInputMode.
    void setInputMode(int mode);

    // Height (in points) of the AEP-rendered content area, used to place UIKit
    // overlays below the GL scene. Ghidra: neAepContentHeight.
    int aepContentHeight();
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
