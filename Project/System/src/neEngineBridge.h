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

#import <Foundation/Foundation.h>

// Real types used across the ObjC<->C++ boundary (this header is ObjC++; every
// including translation unit is .mm). Using the true types instead of opaque
// void* keeps the bridge signatures honest.
@class UIViewController;
@class ScoreData;   // Game/Data/Save/ScoreData.h (Core Data entity, per-song play
                    // records)
class PlayTask;     // System/src/Task/PlayTask.h    (: ne::C_TASK)
class AcViewerTask; // System/src/Task/AcViewerTask.h (: ne::C_TASK) — the arcade
                    // note-play task (AppDelegate's acMainTask slot)

// Persisted score difficulty tier — the sheet index held in PlayScore::difficulty
// that selects which ScoreData N/H/Ex field group a play reads or writes. This is
// the three-tier save scheme (Normal/Hyper/Ex), distinct from the arcade viewer's
// four-tier AcvDifficulty. Ghidra: readScoreDataFields (0x29438) and saveScoreData
// (0x28ca0) branch on these values. Pinned to int so an out-of-range sheet index
// (which readScoreDataFields guards with its default arm) casts cleanly.
enum ScoreDifficulty : int {
    kScoreDiffNormal = 0, // ScoreData scoreN / rankN / playCntN / fullComboN / perfectN
    kScoreDiffHyper = 1,  // ScoreData scoreH / rankH / playCntH / fullComboH / perfectH
    kScoreDiffEx = 2,     // ScoreData scoreEx / rankEx / playCntEx / fullComboEx / perfectEx
};

/**
 * @brief The store DTO for one (musicId, difficulty) result: the tallies, score, rank and flags
 * that saveScoreData() and updateHighScore() read and write.
 *
 * The binary overlaid this record on the event-center singleton's result region (the free store
 * functions took the singleton pointer, DAT_00187bb8, as an `unsigned int *`), but it is also
 * built free-standing (a friend's server score in FriendScoreMainView), so it is a plain value
 * type. The event-center wrappers copy its fields to and from the singleton by name, so there is
 * no overlay requirement and no reinterpret_cast. The singleton offset each field mapped to in the
 * binary is noted per field.
 */
struct PlayScore {
    unsigned musicId;        /**< Singleton +0x00 The music id being scored; equals lastMusic(). */
    int difficulty;          /**< +0x04 The sheet index (a ScoreDifficulty); equals lastSheet(). */
    short coolCount;         /**< +0x08 COOL tally. */
    short greatCount;        /**< +0x0a GREAT tally. */
    short goodCount;         /**< +0x0c GOOD tally; a miss/near counter. */
    short badCount;          /**< +0x0e BAD tally; a miss/near counter. */
    int score;               /**< +0x10 The final score. */
    short rank;              /**< +0x14 Rank, 0 best to 6 fail; written by the play task. */
    short maxCombo;          /**< +0x18 Max combo; written by the play task. */
    unsigned char fullCombo; /**< +0x1c Full-combo flag. */
    unsigned char isNewHighScore; /**< +0x32 Set when this play beat the stored score. */
};

// ===== Score store (Core Data ScoreData entity) — free functions the binary
// calls directly on the app-event-center singleton. Reconstructed in
// neEngineBridge.mm. =====

// Read the player's stored local best for (musicId, difficulty) out of the
// ScoreData entity. `center` is the app-event-center pointer the binary passes
// as the first argument; it is vestigial (unused). Out-params may be null
// (guarded). Ghidra: fetchScoreDataForMusic @ 0x293c4.
void fetchScoreDataForMusic(void *center,
                            int *outScore,
                            short *outRank,
                            int *outPlayCnt,
                            bool *outFullCombo,
                            bool *outPerfect,
                            unsigned musicId,
                            int difficulty);

// Read the score/rank/playCnt/fullCombo/perfect fields for `difficulty` (0 N /
// 1 H / 2 EX) out of a fetched ScoreData record. `rec` and `recDup` are the
// same object (the binary passes it twice). Ghidra: readScoreDataFields @
// 0x29438.
void readScoreDataFields(ScoreData *rec,
                         int *outScore,
                         short *outRank,
                         int *outPlayCnt,
                         bool *outFullCombo,
                         bool *outPerfect,
                         ScoreData *recDup,
                         int difficulty);

// Commit a finished play (`s`) into the local Core Data ScoreData store:
// full-combo / perfect / rank / score / play-count for its difficulty, re-hash
// the checksum, stamp the play date, save. Ghidra: saveScoreData @ 0x28ca0.
void saveScoreData(PlayScore *s);

// Pre-save "did we beat the record" check: read the current stored best for
// `s`, set s->isNewHighScore (return YES) when the stored score is lower than
// `newScore`, then write the passed tallies/score/full-combo into `s`. Ghidra:
// updateHighScore @ 0x2930c.
BOOL updateHighScore(PlayScore *s,
                     unsigned newScore,
                     short cool,
                     short great,
                     short good,
                     short bad,
                     char fullCombo);

/**
 * @brief The app-wide event and notification centre: a guarded singleton @ DAT_00187bb8, touched
 * at launch, flushed on background or terminate, and poked on push.
 */
class neAppEventCenter {
public:
    /**
     * @brief The singleton instance.
     * @return The event centre.
     * @ghidraAddress 0xb150
     */
    static neAppEventCenter &shared();
    /**
     * @brief Reset the AC-viewer's pending selection to the "none" sentinels: music id -1 and
     * difficulty 0xffff. Done when the viewer is cancelled.
     *
     * Ghidra globals g_dwAcViewerSelMusicId @ 0x187bf8 and g_wAcViewerSelDifficulty @ 0x187bfc,
     * in the event-centre region; NEAppEventCenter_shared() is touched first to force init.
     */
    static void clearAcViewerSelection();

    /**
     * @brief The music id the arcade-viewer list is showing right now.
     *
     * Read by the AC-viewer option screen to build its header. Ghidra global g_dwAcViewerMusicId
     * @ 0x187bf0.
     * @return The current browsing music id, or -1 for none.
     */
    static int acViewerMusicId();
    /**
     * @brief The difficulty the arcade-viewer list is showing right now (Ghidra global
     * g_wAcViewerDifficulty @ 0x187bf4).
     * @return The current browsing difficulty.
     */
    static int acViewerDifficulty();
    /**
     * @brief Set the AC-viewer's current browsing selection.
     * @param musicId The music id being browsed.
     * @param difficulty The difficulty being browsed.
     */
    static void setAcViewerSelection(int musicId, int difficulty);
    /**
     * @brief The pending music id carried into the play scene, compared against the current pair
     * to decide continue versus play-from-start (Ghidra global g_dwAcViewerSelMusicId @ 0x187bf8).
     * @return The pending music id, or -1 for none.
     */
    static int acViewerSelMusicId();
    /**
     * @brief The pending difficulty carried into the play scene (Ghidra global
     * g_wAcViewerSelDifficulty @ 0x187bfc).
     * @return The pending difficulty.
     */
    static int acViewerSelDifficulty();
    /**
     * @brief Commit the current browsing pair as the pending one, done when the arcade-viewer
     * play button is pressed.
     */
    static void commitAcViewerSelection();
    /**
     * @brief Reset only the current AC-viewer browsing music id to the "none" sentinel (-1),
     * leaving the difficulty untouched.
     *
     * Done when the category list's back button cancels the viewer. Ghidra global
     * g_dwAcViewerMusicId @ 0x187bf0.
     */
    static void clearAcViewerCurrentMusic();

    // e-AMUSEMENT login context read by the music-checker score sync. The (not-yet-reconstructed)
    // login flow populates these; they sit in the event-center region. Ghidra globals g_pLinkRefId
    // @ 0x187be0 (event-center +0x28), g_pInputPassword @ 0x187be4 (+0x2c) and g_bRequireOtpInput
    // @ 0x187be9 (+0x31).

    /**
     * @brief The Core Data ref-id the arcade records key on.
     * @return The ref-id, or nil before a successful link.
     */
    static id linkRefId();
    /**
     * @brief The entered account password.
     * @return The password, or nil when none has been entered.
     */
    static NSString *inputPassword();
    /**
     * @brief Whether a one-time password must still be entered.
     * @return true when an OTP is still required.
     */
    static bool requireOtpInput();

    // Writers for the login context above, driven by the pop'n-link KID-input screen
    // (InputKIDViewCtrl): the decide button stashes the entered password and, on a successful link
    // POST, the returned ref-id and whether an OTP is still required.

    /**
     * @brief Stash the entered account password.
     * @param password The password.
     */
    static void setInputPassword(NSString *password);
    /**
     * @brief Stash the ref-id returned by a successful link POST.
     * @param refId The Core Data ref-id.
     */
    static void setLinkRefId(id refId);
    /**
     * @brief Record whether a one-time password must still be entered.
     * @param require true when an OTP is still required.
     */
    static void setRequireOtpInput(bool require);

    /**
     * @brief Whether the player has linked their pop'n-link (e-AMUSEMENT KID).
     *
     * This is what enables the score-checker and quiz buttons on the pop'n-link top screen; while
     * false the top screen forces the KID-input screen instead. An event-centre region global read
     * only after shared() has forced the singleton's init. Ghidra global g_bLinkButtonsEnabled,
     * read after NEAppEventCenter_shared() at 0xccacc, 0xcca48, 0xcd4e4 and 0xcd5a8.
     * @return true once the link is established.
     */
    static bool linkButtonsEnabled();
    /**
     * @brief Enable or disable the checker and quiz buttons.
     *
     * Set once a successful pop'n-link enables them, and cleared to force the KID-input screen
     * while the link POST is in flight. Written by InputKIDViewCtrl's decide button and
     * link-finished handler.
     * @param enabled true to enable the buttons.
     */
    static void setLinkButtonsEnabled(bool enabled);

    /**
     * @brief Open the event-centre session; called at launch.
     * @ghidraAddress 0x28c70
     */
    void begin();
    /**
     * @brief Flush pending events; called on background and terminate.
     * @ghidraAddress 0x28c9c
     */
    void flush();

    /**
     * @brief Record a finished play's result into the event centre so the result screen can read
     * it back.
     *
     * Looks up the stored high score for the current music and sheet, sets the "new record" flag
     * when @p score beats it, and stashes the tallies, the score and the full-combo flag. The play
     * task additionally writes the rank (+0x14) and max combo (+0x18) after this call. A thin
     * wrapper over updateHighScore() on this singleton.
     * @param score The final score.
     * @param cool The COOL tally.
     * @param great The GREAT tally.
     * @param good The GOOD tally.
     * @param bad The BAD tally.
     * @param fullCombo Whether the play was a full combo.
     * @return true when a new record was set.
     * @ghidraAddress 0x2930c
     */
    bool recordPlayResult(
        unsigned score, short cool, short great, short good, short bad, bool fullCombo);

    // First two fields of the singleton (DAT_00187bb8 / DAT_00187bbc): the last played music id
    // and sheet (difficulty), persisted via UserSettingData. m_lastMusic @ +0x00 is
    // g_pNeAppEventCenter (the result-record music id) and m_lastSheet @ +0x04 is g_wResultSheet
    // (the result-record difficulty) that PlayResultTask reads back.

    /**
     * @brief The last played music id (DAT_00187bb8, g_pNeAppEventCenter).
     * @return The result-record music id.
     */
    int lastMusic() const;
    /**
     * @brief The last played sheet (DAT_00187bbc, g_wResultSheet).
     * @return The result-record difficulty.
     */
    int lastSheet() const;
    /**
     * @brief Set the last played music id, writing g_pNeAppEventCenter (m_lastMusic @ +0x00).
     * @param music The music id.
     */
    void setLastMusic(int music);
    /**
     * @brief Set the last played sheet, writing g_wResultSheet (m_lastSheet @ +0x04).
     * @param sheet The difficulty.
     */
    void setLastSheet(int sheet);

    /**
     * @brief The guest / no-save run flag (g_bGuestNoSaveMode).
     *
     * Set true when a guided first-play tutorial starts and false on a normal music-select entry;
     * it gates whether stopAndSave persists a result.
     * @return true while the run must not be persisted.
     */
    bool guestNoSaveMode() const;
    /**
     * @brief Set the guest / no-save run flag.
     * @param guest true to suppress persisting the run's result.
     */
    void setGuestNoSaveMode(bool guest);

    /**
     * @brief Stamp the session start time into the +0x20 ivar (_startDate).
     *
     * A sibling of setEndDate() with the same lazy-release-then-retain-[NSDate date] shape; called
     * when the player-get login response is parsed. Under ARC the strong ivar store does the
     * release and retain.
     * @ghidraAddress 0x29274
     */
    void setStartDate();

    /**
     * @brief Stamp the session end time into the +0x24 ivar (_endDate).
     *
     * The binary lazily released any prior date and retained a fresh [NSDate date]; under ARC the
     * strong ivar assignment does that. Called at the end of the recommend-list download, so it
     * doubles as the recommend-list "last fetched" timestamp the refresh throttle reads.
     * @ghidraAddress 0x292c0
     */
    void setEndDate();
    /**
     * @brief The last recommend-list fetch time (_endDate @ +0x24).
     * @return The NSDate, or nil before the first fetch.
     */
    id recommendFetchDate() const {
        return _endDate;
    }
    /**
     * @brief The session start time (_startDate @ +0x20, DAT_00187bd8), read by the menu's
     * news-refresh throttle.
     * @return The NSDate, or nil before the session started.
     */
    id sessionStartDate() const {
        return _startDate;
    }

    /**
     * @brief Whether a remote push notification arrived and has not been consumed yet.
     *
     * The recommend-list refresh throttle treats a pending push as an immediate "stale" trigger.
     * @return true while a push is pending.
     */
    bool remoteNotifyPending() const;
    /**
     * @brief Set the pending-push flag.
     * @param pending true when a push has arrived and not been consumed.
     */
    void setRemoteNotifyPending(bool pending);

    // --- Just-finished play's result record ---
    // The play task fills these (recordPlayResult + direct stores of rank/combo);
    // the result screen (PlayResultTask, Ghidra resultTaskDraw @ 0x3dfe0)
    // snapshots them. Offsets are the DAT_00187bxx globals relative to this
    // singleton base (DAT_00187bb8 == +0x00); modelled as the named m_result
    // fields below.
    /**
     * @brief The just-finished play's COOL tally (DAT_00187bc0 low).
     * @return The COOL count.
     */
    short coolCount() const {
        return m_result.coolCount;
    }
    /**
     * @brief The just-finished play's GREAT tally (DAT_00187bc0 high).
     * @return The GREAT count.
     */
    short greatCount() const {
        return m_result.greatCount;
    }
    /**
     * @brief The just-finished play's GOOD tally (DAT_00187bc4 low).
     * @return The GOOD count.
     */
    short goodCount() const {
        return m_result.goodCount;
    }
    /**
     * @brief The just-finished play's BAD tally (DAT_00187bc4 high).
     * @return The BAD count.
     */
    short badCount() const {
        return m_result.badCount;
    }
    /**
     * @brief The just-finished play's score (DAT_00187bc8).
     * @return The score.
     */
    int playScore() const {
        return m_result.playScore;
    }
    /**
     * @brief The just-finished play's rank (DAT_00187bcc).
     * @return The rank, 0 best to 6 fail.
     */
    short playRank() const {
        return m_result.playRank;
    }
    /**
     * @brief The just-finished play's max combo (DAT_00187bd0, low 16 bits).
     * @return The max combo.
     */
    short maxCombo() const {
        return static_cast<short>(m_result.maxCombo);
    }
    /**
     * @brief Whether the just-finished play cleared (DAT_00187bd4).
     * @return true when the play cleared.
     */
    bool isCleared() const {
        return m_result.cleared != 0;
    }
    /**
     * @brief Whether the just-finished play set a new record (DAT_00187bea).
     * @return true on a new record.
     */
    bool isNewRecord() const {
        return m_resultExt.newRecord != 0;
    }

    /**
     * @brief The bundled-demo / sugoroku play flag (+0x33).
     *
     * PlayTask_init copies this raw byte into its own m_isDemoPlay to drive the tutorial and
     * auto-demo play path.
     * @return The raw flag byte.
     */
    unsigned char demoPlayFlag() const {
        return m_resultExt.demoPlayFlag;
    }
    /**
     * @brief Set the demo-play flag (+0x33) before spawning the guided PlayTask, so PlayTask_init
     * copies it into m_isDemoPlay (Ghidra: strb #1,[ec,#0x33] at MainTask::update 0x36d58).
     * @param flag The raw flag byte.
     */
    void setDemoPlayFlag(unsigned char flag) {
        m_resultExt.demoPlayFlag = flag;
    }

    // The play task writes the finished play's rank (+0x14, 2-byte) and max combo (+0x18, 4-byte)
    // directly after recordPlayResult so the result screen can read them back.

    /**
     * @brief Record the finished play's rank (DAT_00187bcc).
     * @param rank The rank, 0 best to 6 fail.
     */
    void setPlayRank(short rank) {
        m_result.playRank = rank;
    }
    /**
     * @brief Record the finished play's max combo (DAT_00187bd0).
     * @param combo The max combo.
     */
    void setMaxCombo(int combo) {
        m_result.maxCombo = combo;
    }

    /**
     * @brief Read the player's stored local best for this play's music and sheet.
     *
     * A thin wrapper over the free fetchScoreDataForMusic() on this singleton.
     * @param outScore Receives the stored score; may be nullptr.
     * @param outRank Receives the stored rank; may be nullptr.
     * @param outPlayCnt Receives the stored play count; may be nullptr.
     * @param outFullCombo Receives the stored full-combo flag; may be nullptr.
     * @param outPerfect Receives the stored perfect flag; may be nullptr.
     */
    void readStoredResult(
        int *outScore, short *outRank, int *outPlayCnt, bool *outFullCombo, bool *outPerfect);

    /**
     * @brief Commit this play's result into the local Core Data ScoreData store: the full-combo,
     * perfect, rank, score and play-count fields, then save.
     *
     * A thin wrapper over the free saveScoreData().
     */
    void commitResultToScoreData();

private:
    // The just-finished play's result record. In the binary these lived at fixed
    // byte offsets in the event-center singleton (DAT_00187bb8 + the +0xNN each
    // comment cites). Nothing overlays this object now (the score store copies
    // fields by name, so PlayScore no longer has to match this layout), so the
    // rebuild keeps only the real members. The login-context and AC-viewer globals
    // that shared the binary's reset block live as file-statics in
    // neEngineBridge.mm, reached through the static accessors above.
    struct PlayResult {            // binary +0x08..+0x1c
        short coolCount = 0;       // +0x08
        short greatCount = 0;      // +0x0a
        short goodCount = 0;       // +0x0c
        short badCount = 0;        // +0x0e
        int playScore = 0;         // +0x10
        short playRank = 0;        // +0x14
        int maxCombo = 0;          // +0x18 (read back as a short via maxCombo())
        unsigned char cleared = 0; // +0x1c doubles as the full-combo flag the store reads
    };
    struct PlayResultExt {              // binary +0x32..+0x33
        unsigned char newRecord = 0;    // +0x32 new-record flag (read by result Draw @ 0x3e094)
        unsigned char demoPlayFlag = 0; // +0x33 demo / sugoroku play flag (PlayTask_init copies it)
    };

    int m_lastMusic = 0;          // binary +0x00
    int m_lastSheet = 0;          // binary +0x04
    PlayResult m_result;          // binary +0x08
    __strong id _startDate = nil; // binary +0x20 session start (NSDate); setStartDate @ 0x29274
    __strong id _endDate = nil;   // binary +0x24 session end   (NSDate); setEndDate   @ 0x292c0
    PlayResultExt m_resultExt;    // binary +0x32
};

/**
 * @brief The scene manager owning the root view controller: a guarded singleton @ DAT_00187b74.
 */
class neSceneManager {
public:
    /**
     * @brief The singleton instance, lazily constructed via FUN_0002c5c0 (NESceneManager_init).
     * @return The scene manager.
     * @ghidraAddress 0xb194
     */
    static neSceneManager &shared();
    /**
     * @brief Store the app's root view controller.
     * @param viewController The root view controller.
     * @ghidraAddress 0x2c5b8
     */
    void attachRoot(UIViewController *viewController);

    /**
     * @brief The stored root view controller: the app's navigation host the title and menu flow
     * sends Goto*, Insert* and Delete* messages to.
     * @return The root view controller, or nil before attachRoot().
     * @ghidraAddress 0x2c5bc
     */
    static UIViewController *rootViewController();

    // Live drawable metrics (Ghidra globals DAT_00187b7c/78/80), updated by the GL view on layout;
    // used to place notes and sprites on screen.

    /**
     * @brief The live drawable width.
     * @return The width, in points.
     */
    static float screenWidth();
    /**
     * @brief The live drawable height.
     * @return The height, in points.
     */
    static float screenHeight();
    /**
     * @brief The live drawable scale.
     * @return The content scale.
     */
    static float screenScale();
    /**
     * @brief Record the live drawable metrics; called by the GL view on layout.
     * @param width The drawable width, in points.
     * @param height The drawable height, in points.
     * @param scale The content scale.
     */
    static void setScreenMetrics(float width, float height, float scale);

    /**
     * @brief The device-class flag (Ghidra global DAT_00187b84), set at launch alongside the
     * metrics.
     *
     * The boot logo setup uses it to pick phone- versus pad-sized branding assets, so it is
     * modelled as "is a pad-class display".
     * @return true when the flag is non-zero.
     */
    static bool isPadDisplay();
    /**
     * @brief Set the device-class flag.
     * @param isPad true for a pad-class display.
     */
    static void setPadDisplay(bool isPad);

    // The scene manager owns a small pool of shared "system" SEs (decide, cancel, ...), reloaded
    // on each scene change. A scene teardown releases the current pool, cleans up the mixer, then
    // reloads it for the next scene. Both operate on this singleton, DAT_00187b74.

    /**
     * @brief Release the shared system-SE pool and clean up the mixer.
     * @ghidraAddress 0x2c6bc
     */
    void releaseSystemSe();
    /**
     * @brief Load the shared system-SE pool for the incoming scene.
     * @ghidraAddress 0x2c5c8
     */
    void loadSystemSe();

    // Touch-sound ("hit sound") name tables owned by the scene manager. Both return a bridged
    // NSString, cast with __bridge on the Objective-C side, mirroring rootViewController().

    /**
     * @brief The bundle resource base name of the SE previewed for a touch-sound kind, used to
     * build the ".m4a" path loaded into the low-latency SE player.
     * @param soundNo The touch-sound kind index, 0..9.
     * @return A bridged NSString.
     */
    static void *hitSoundName(int soundNo);
    /**
     * @brief The user-facing display name of a touch-sound kind, shown in the touch-sound picker
     * rows.
     * @param soundNo The touch-sound kind index, 0..9.
     * @return A bridged NSString.
     */
    static void *normalSoundName(int soundNo);

private:
    // +0x00 the root UIViewController. __unsafe_unretained so this C++ singleton
    // stays a plain (trivial) type under ARC and does not own the VC (the
    // UIWindow owns it), matching the binary's non-retaining raw pointer store.
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
// classes rather than here. The actual resign work is
// NoteMng::onResignActivePushHook (FUN_00034510).
namespace neEngine {
void bootstrapB();           // Ghidra: NEEngine_bootstrapB (FUN_0001ba2c)
void bootstrapC(int flag);   // Ghidra: NEEngine_bootstrapC (FUN_0001796c)
void onDidEnterBackground(); // Ghidra: NEEngine_onDidEnterBackground
                             // (FUN_0001bdf8)

// Nudge the running play / arcade task toward its stop state. The task pointer
// is passed in by the caller (AppDelegate's _mainTask / _acMainTask); the
// foreground "main task" during play is a PlayTask (PlayTask::m_state), and the
// "acMainTask" slot holds the arcade AcViewerTask (AcViewerTask::m_state).
void stopMainTask(PlayTask *playTask);           // Ghidra: NEEngine_stopMainTask   (FUN_00030710)
void stopAcMainTask(AcViewerTask *acViewerTask); // Ghidra: NEEngine_stopAcMainTask (FUN_0002314c)

// Ask the running arcade AcViewerTask to leave play and exit back to the menu
// (sets its play state @ +0x20c := 8 and the board-up flag @ +0x1d9 := 1).
// Ghidra: requestGameExit (FUN_0002315c).
void acMainRequestGameExit(AcViewerTask *acViewerTask);
// Push the arcade-viewer option selections (hi-speed / pop-kun / hid-sud /
// ran-mir) into the live AcViewerTask (the arcade note-play task AppDelegate
// holds in its acMainTask property), re-seek its note stream and resume the
// render loop. Ghidra: applyGameplaySettings (FUN_00023850).
void acMainApplyGameplaySettings(AcViewerTask *task);

// Create + register the app's boot task at priority 3.
void startBootTask(); // Ghidra: operator_new(0x4c) + FUN_0002af58 +
                      // FUN_00027f08(_,3)
// Notify every foreground observer (observer list head @ DAT_00188464).
void notifyEnterForeground(); // Ghidra: FUN_000188ac walk

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

// True while the scene manager's system-SE slot `slot` is still sounding (slot
// 2 is the cancel/back SE the music-select teardown waits on). Ghidra:
// isSePlaying (FUN_0002c764), which probes the SE-handle table on the scene
// manager global.
bool isSePlaying(int slot);

// Height (in points) of the AEP-rendered content area, used to place UIKit
// overlays below the GL scene. Ghidra: neAepContentHeight.
int aepContentHeight();
} // namespace neEngine

// The UI scale = screenScale * 0.5, published by MainViewController::loadView
// (@0xb51c) and read back as a float by the tap hit-tests (binary: vldr.32,
// e.g. the menu update @0x6ae30). Ghidra: DAT_00187b80 (g_dwUiScale) — the `dw`
// name reflects only the 4-byte storage slot; the slot is semantically a float,
// so it is typed as one here and the readers do float maths directly rather
// than reinterpreting an int slot.
extern float g_uiScale;

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
