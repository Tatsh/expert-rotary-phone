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
@class ScoreData;   // Game/Data/Save/ScoreData.h (Core Data entity, per-song play records)
class MainTask;     // System/src/Task/MainTask.h   (: C_TASK)
class AcMainTask;   // System/src/Task/AcMainTask.h (: C_TASK)
class AcViewerTask; // System/src/Task/AcViewerTask.h (: C_TASK) — the arcade note-play task

// The just-finished play's result record — the transient block the app-event-center singleton
// fills and the score store persists. This IS the leading layout of neAppEventCenter (the
// binary's free score-store functions take the singleton pointer, DAT_00187bb8, as a
// `unsigned int *`), named here so the store touches real fields instead of raw byte offsets.
// The COOL/GREAT/GOOD/BAD tallies at +0x08..+0x0e mirror neAppEventCenter::coolCount()..badCount().
struct PlayScore {
    unsigned      musicId;          // +0x00 music id being scored (== lastMusic)
    int           difficulty;       // +0x04 sheet index (0 N / 1 H / 2 EX) (== lastSheet)
    short         coolCount;        // +0x08 COOL tally
    short         greatCount;       // +0x0a GREAT tally
    short         goodCount;        // +0x0c GOOD tally  (a "miss/near" counter)
    short         badCount;         // +0x0e BAD  tally  (a "miss/near" counter)
    int           score;            // +0x10 final score
    short         rank;             // +0x14 rank (0 best .. 6 fail); written by the play task
    short         _pad16;           // +0x16
    short         maxCombo;         // +0x18 max combo; written by the play task
    short         _pad1a;           // +0x1a
    unsigned char fullCombo;        // +0x1c full-combo flag
    unsigned char _pad1d[0x15];     // +0x1d..+0x31 (transient state / _endDate region)
    unsigned char isNewHighScore;   // +0x32 set when this play beat the stored score
    unsigned char _pad33[0x15];     // +0x33..+0x47 (pad to the 0x48-byte singleton size)
};

// ===== Score store (Core Data ScoreData entity) — free functions the binary calls directly on
// the app-event-center singleton. Reconstructed in neEngineBridge.mm. =====

// Read the player's stored local best for (musicId, difficulty) out of the ScoreData entity.
// `center` is the app-event-center pointer the binary passes as the first argument; it is
// vestigial (unused). Out-params may be null (guarded). Ghidra: fetchScoreDataForMusic @ 0x293c4.
void fetchScoreDataForMusic(void *center, int *outScore, short *outRank, int *outPlayCnt,
                            bool *outFullCombo, bool *outPerfect,
                            unsigned musicId, int difficulty);

// Read the score/rank/playCnt/fullCombo/perfect fields for `difficulty` (0 N / 1 H / 2 EX) out
// of a fetched ScoreData record. `rec` and `recDup` are the same object (the binary passes it
// twice). Ghidra: readScoreDataFields @ 0x29438.
void readScoreDataFields(ScoreData *rec, int *outScore, short *outRank, int *outPlayCnt,
                         bool *outFullCombo, bool *outPerfect, ScoreData *recDup, int difficulty);

// Commit a finished play (`s`) into the local Core Data ScoreData store: full-combo / perfect /
// rank / score / play-count for its difficulty, re-hash the checksum, stamp the play date, save.
// Ghidra: saveScoreData @ 0x28ca0.
void saveScoreData(PlayScore *s);

// Pre-save "did we beat the record" check: read the current stored best for `s`, set
// s->isNewHighScore (return YES) when the stored score is lower than `newScore`, then write the
// passed tallies/score/full-combo into `s`. Ghidra: updateHighScore @ 0x2930c.
BOOL updateHighScore(PlayScore *s, unsigned newScore, short cool, short great,
                     short good, short bad, char fullCombo);

// App-wide event / notification center (guarded singleton @ DAT_00187bb8).
// Touched at launch, flushed on background/terminate, poked on push.
class neAppEventCenter {
public:
    static neAppEventCenter &shared();   // Ghidra: NEAppEventCenter_shared (FUN_0000b150)
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

    // Writers for the login context above, driven by the pop'n-link KID-input screen
    // (InputKIDViewCtrl): the decide button stashes the entered password and, on a
    // successful link POST, the returned ref-id / whether an OTP is still required.
    // Ghidra: raw stores into g_pInputPassword @ 0x187be4 (retain), g_pLinkRefId @
    // 0x187be0 (retain) and g_bRequireOtpInput @ 0x187be9.
    static void setInputPassword(NSString *password);
    static void setLinkRefId(id refId);
    static void setRequireOtpInput(bool require);

    // pop'n-link availability flag (event-center region global, read only after
    // shared() has forced the singleton's init): true once the player has linked
    // their pop'n-link (e-AMUSEMENT KID), which is what enables the score-checker /
    // quiz buttons on the pop'n-link top screen. While false the top screen forces
    // the KID-input screen instead. Ghidra global g_bLinkButtonsEnabled, read after
    // NEAppEventCenter_shared() at 0xccacc / 0xcca48 / 0xcd4e4 / 0xcd5a8.
    static bool linkButtonsEnabled();
    // Set once a successful pop'n-link enables the checker / quiz buttons (and cleared
    // to force the KID-input screen while the link POST is in flight). Written by
    // InputKIDViewCtrl's decide button / link-finished handler. Ghidra: raw store into
    // g_bLinkButtonsEnabled.
    static void setLinkButtonsEnabled(bool enabled);

    void begin();                        // Ghidra: NEAppEventCenter_begin  (FUN_00028c70)
    void flush();                        // Ghidra: NEAppEventCenter_flush  (FUN_00028c9c)

    // Record a finished play's result into the event center (so the result screen can
    // read it back): looks up the stored high score for the current music/sheet, sets
    // the "new record" flag when `score` beats it, and stashes the COOL/GREAT/GOOD/BAD
    // tallies, the score and the full-combo flag. Returns true when a new record was set.
    // The play task additionally writes the rank (+0x14) and max combo (+0x18) after this
    // call. A thin wrapper over updateHighScore (Ghidra: FUN_0002930c) on this singleton.
    bool recordPlayResult(unsigned score, short cool, short great, short good, short bad,
                          bool fullCombo);

    // First two fields of the singleton (DAT_00187bb8 / DAT_00187bbc): the last
    // played music id and sheet (difficulty), persisted via UserSettingData. m_lastMusic @ +0x00
    // is g_pNeAppEventCenter (the result-record music id) and m_lastSheet @ +0x04 is g_wResultSheet
    // (the result-record difficulty) that PlayResultTask reads back.
    int  lastMusic() const;              // DAT_00187bb8 (== g_pNeAppEventCenter, result music id)
    int  lastSheet() const;              // DAT_00187bbc (== g_wResultSheet, result difficulty)
    void setLastMusic(int music);        // writes g_pNeAppEventCenter (m_lastMusic @ +0x00)
    void setLastSheet(int sheet);        // writes g_wResultSheet    (m_lastSheet @ +0x04)

    // Guest / no-save run flag (g_bGuestNoSaveMode). Set true when a guided first-play tutorial
    // starts, false on a normal music-select entry; gates whether stopAndSave persists a result.
    bool guestNoSaveMode() const;
    void setGuestNoSaveMode(bool guest);

    // Stamp the session start time into the +0x20 ivar (_startDate). Sibling of
    // setEndDate (same lazy-release-then-retain-[NSDate date] shape); called when the
    // player-get login response is parsed. Under ARC the strong ivar store does the
    // release+retain.
    void setStartDate();                 // @ 0x29274

    // Stamp the session end time into the +0x24 ivar (_endDate). The binary lazily
    // released any prior date and retained a fresh [NSDate date]; under ARC the strong
    // ivar assignment does that. Called at the end of the recommend-list download, so it
    // doubles as the recommend-list "last fetched" timestamp the refresh throttle reads.
    void setEndDate();                   // @ 0x292c0
    id recommendFetchDate() const { return _endDate; }   // _endDate @ +0x24, last recommend fetch

    // A remote push notification arrived and hasn't been consumed yet — the recommend-list
    // refresh throttle treats a pending push as an immediate "stale" trigger.
    bool remoteNotifyPending() const;
    void setRemoteNotifyPending(bool pending);

    // --- Just-finished play's result record ---
    // The play task fills these (recordPlayResult + direct stores of rank/combo);
    // the result screen (PlayResultTask, Ghidra resultTaskDraw @ 0x3dfe0) snapshots
    // them. Offsets are the DAT_00187bxx globals relative to this singleton base
    // (DAT_00187bb8 == +0x00); modelled as the named m_result fields below.
    short coolCount()  const { return m_result.coolCount; }        // DAT_00187bc0 low
    short greatCount() const { return m_result.greatCount; }       // DAT_00187bc0 high
    short goodCount()  const { return m_result.goodCount; }        // DAT_00187bc4 low
    short badCount()   const { return m_result.badCount; }         // DAT_00187bc4 high
    int   playScore()  const { return m_result.playScore; }        // DAT_00187bc8
    short playRank()   const { return m_result.playRank; }         // DAT_00187bcc
    short maxCombo()   const { return (short)m_result.maxCombo; }   // DAT_00187bd0 (low 16 bits)
    bool  isCleared()  const { return m_result.cleared != 0; }     // DAT_00187bd4
    bool  isNewRecord()const { return m_resultExt.newRecord != 0; }// DAT_00187bea

    // The bundled-demo / sugoroku play flag (+0x33). PlayTask_init copies this raw byte into
    // its own m_isDemoPlay to drive the tutorial / auto-demo play path.
    unsigned char demoPlayFlag() const { return m_resultExt.demoPlayFlag; }

    // The play task writes the finished play's rank (+0x14, 2-byte) and max combo (+0x18, 4-byte)
    // directly after recordPlayResult so the result screen can read them back.
    void setPlayRank(short rank) { m_result.playRank = rank; }         // DAT_00187bcc
    void setMaxCombo(int combo)  { m_result.maxCombo = combo; }        // DAT_00187bd0

    // Read the player's stored local best for this play's music/sheet (out-params may be null).
    // Thin wrapper over the free fetchScoreDataForMusic (below) on this singleton.
    void readStoredResult(int *outScore, short *outRank, int *outPlayCnt,
                          bool *outFullCombo, bool *outPerfect);

    // Commit this play's result into the local Core Data ScoreData store
    // (setFullCombo/Perfect/Rank/Score/PlayCnt + save). Thin wrapper over the free saveScoreData.
    void commitResultToScoreData();

private:
    // The just-finished play's result record. In the binary these are read at fixed
    // byte offsets in the event-center's transient region (DAT_00187bc0..); modelled
    // here as named fields so no raw offset access is needed. begin() zeroes them.
    struct PlayResult {                // +0x08..0x20
        short         coolCount = 0;   // +0x08
        short         greatCount = 0;  // +0x0a
        short         goodCount = 0;   // +0x0c
        short         badCount = 0;    // +0x0e
        int           playScore = 0;   // +0x10
        short         playRank = 0;    // +0x14
        short         _rsvd16 = 0;     // +0x16
        int           maxCombo = 0;    // +0x18
        unsigned char cleared = 0;     // +0x1c
        unsigned char _rsvd1d[3] = {}; // +0x1d
    };
    struct PlayResultExt {                        // +0x28..0x40
        unsigned char _rsvd28[0x32 - 0x28] = {};  // +0x28
        unsigned char newRecord = 0;              // +0x32 DAT_00187bea
        unsigned char demoPlayFlag = 0;           // +0x33
        unsigned char _rsvd34[0x40 - 0x34] = {};  // +0x34
    };

    int m_lastMusic = 0;      // +0x00
    int m_lastSheet = 0;      // +0x04
    PlayResult m_result;      // +0x08..0x20 (was float m_state[6])
    __strong id _startDate = nil; // +0x20 session start timestamp (NSDate); setStartDate @ 0x29274
    __strong id _endDate = nil; // +0x24 session end timestamp (NSDate); setEndDate @ 0x292c0
    PlayResultExt m_resultExt; // +0x28..0x40 (was float m_state2[6])
    int m_flags[2] = {};      // +0x40..0x48
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
    // into the live AcViewerTask (the arcade note-play task AppDelegate holds in its
    // acMainTask property), re-seek its note stream and resume the render loop.
    // Ghidra: applyGameplaySettings (FUN_00023850).
    void acMainApplyGameplaySettings(AcViewerTask *task);

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

    // True while the scene manager's system-SE slot `slot` is still sounding (slot 2
    // is the cancel/back SE the music-select teardown waits on). Ghidra: isSePlaying
    // (FUN_0002c764), which probes the SE-handle table on the scene manager global.
    bool isSePlaying(int slot);

    // Set the scene's touch input mode (0 = normal, non-zero = suspended while a
    // modal/animation runs). Ghidra: neSceneSetInputMode.
    void setInputMode(int mode);

    // Height (in points) of the AEP-rendered content area, used to place UIKit
    // overlays below the GL scene. Ghidra: neAepContentHeight.
    int aepContentHeight();
}

// The UI scale = screenScale * 0.5, stored as float BITS in a 32-bit slot (binary: DAT written by
// MainViewController::loadView @0xb51c as `(dword)float`). Task m_uiScale caches copy it as int and
// reinterpret_cast<float&> to read it (see PlayScene.mm / AcViewerTask.mm).
extern int g_dwUiScale;

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
