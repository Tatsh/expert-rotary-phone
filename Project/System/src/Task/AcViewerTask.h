//
//  AcViewerTask.h
//  pop'n rhythmin
//
//  The ARCADE-VIEWER NOTE-PLAY task: the actual pop'n-style rhythm gameplay
//  screen reached from the "arcade viewer" (GotoAcViewer). It loads the chosen
//  ac chart, builds the group-7 "arcade_viewer" HUD, runs the touch/flick input
//  + play-state machine, and each frame drives the arcade note engine
//  (AcNoteMng) plus the note / life-gauge / HUD-digit draw passes.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  NAMING NOTE: Ghidra labels this class's methods acMainTask* (setup
//  FUN_0002230c, update FUN_00021678, dtor thunk task_delete FUN_000215d8)
//  because AppDelegate holds it in its `acMainTask` property (setAcMainTask:).
//  It is NOT the same class as the repo's existing AcMainTask (the arcade
//  sugoroku/treasure SELECT scene, ctor FUN_00099ab0, state @ +0x9f8, embedded
//  RNG @ +0x4f4): this task has a distinct vtable (@ 0x130bb8), its play state
//  lives @ +0x20c, and it drives AcNoteMng rather than the sugoroku map. It is
//  kept in its own file to avoid clobbering that class.
//
//  ---- work area (this class IS the ~0x214-byte play-data struct) ----
//  ne::C_TASK's base is exactly 0x28 bytes, so the members below land at their true
//  binary offsets. Every scalar the setup / draw / HUD passes reach by flat
//  `*(T*)(this+off)` in the binary is named and placed at its exact offset
//  (with a `// +0xNN` comment); genuine gaps are `_rsvd_NN[]` fillers. The
//  device-branched HUD layout block
//  (+0x110..+0x1c4 — pure-constant coordinate stores from DAT_0012e370 phone /
//  DAT_0012e394 pad) is fully reconstructed by setup() for all three form
//  factors; a handful of interior slots (+0x110/+0x134/+0x138/+0x140/+0x144)
//  are written but never read by any object in the image, so they carry
//  provisional names and a write-only note. The whole object is wiped
//  +0x28..+0x20c by
//  cleanup() (memset of 0x1e4 bytes); the play state
//  @ +0x20c survives.
//

#pragma once

#include <cstdint>

#include "C_TASK.h"

class AepLyrCtrl;
class neTextureForiOS;

// AcViewerTask::update play-state machine (m_state @+0x20c). Values and names are
// Ghidra's AcMainTaskState (ACST_*). The app-lifecycle bridge acts on three of
// them: stopAcMainTask (resign) sends Playing -> PauseMenuOpen (i.e. pauses the
// game), and requestGameExit sends it to ExitTransition. (The bridge's
// "AcMainTask" naming is a misnomer: AppDelegate's acMainTask slot holds the
// running AcViewerTask, which registers itself via setAcMainTask:self.)
enum AcViewerState : int {
    kAcvInit = 0,            // ACST_INIT: enter viewer, insert pad board, register task
    kAcvWaitMusicId = 1,     // ACST_WAIT_MUSIC_ID
    kAcvSetup = 2,           // ACST_SETUP
    kAcvStartTransition = 3, // ACST_START_TRANSITION
    kAcvWaitTransition = 4,  // ACST_WAIT_TRANSITION
    kAcvWaitSe = 5,          // ACST_WAIT_SE
    kAcvPlaying = 6,         // ACST_PLAYING
    kAcvPauseDelay = 7,      // ACST_PAUSE_DELAY
    kAcvExitTransition = 8,  // ACST_EXIT_TRANSITION (requestGameExit target)
    kAcvWaitExit = 9,        // ACST_WAIT_EXIT
    kAcvPause = 10,          // ACST_PAUSE
    kAcvScrub = 11,          // ACST_SCRUB
    kAcvPauseMenuOpen = 12,  // ACST_PAUSE_MENU_OPEN (stopAcMainTask target)
    kAcvPauseMenuInput = 13, // ACST_PAUSE_MENU_INPUT
    kAcvOptionOpen = 14,     // ACST_OPTION_OPEN
    kAcvOptionActive = 15,   // ACST_OPTION_ACTIVE
    kAcvExitToMenu = 16,     // ACST_EXIT_TO_MENU
    kAcvDone = 17,           // ACST_DONE
};

class AcViewerTask : public ne::C_TASK {
public:
    // Constructed by the engine when the arcade viewer starts play (its
    // ctor/vtable live @ 0x130bb8; not part of this reconstruction batch).
    AcViewerTask();
    ~AcViewerTask() override;          // @ 0x215d8 (task_delete deleting-dtor: base + delete)
    void update(int deltaMs) override; // @ 0x21678  acMainTaskUpdate

    // Apply the arcade-viewer option sheet's selections (hi-speed / pop-kun /
    // hid-sud / ran-mir) to this task, rebuilding the lane map and re-seeking the
    // note stream when they change. The options view controller reaches it through
    // the neEngine::acMainApplyGameplaySettings forwarder. Ghidra: FUN_00023850.
    void applyGameplaySettings();

    // Play-state + board-up accessors for the app-lifecycle bridge
    // (neEngine::stopAcMainTask / acMainRequestGameExit). m_state @+0x20c is the
    // play-state machine; m_padBoardUp @+0x1d9 marks the pad board as already up.
    AcViewerState playState() const {
        return m_state;
    }
    void setPlayState(AcViewerState state) {
        m_state = state;
    }
    void setPadBoardUp(bool up) {
        m_padBoardUp = up ? 1 : 0;
    }

private:
    void setup();           // @ 0x2230c  acMainTaskSetup — resolve the HUD, load chart + SE
    void loadChart();       // @ 0x2316c  loadChartData — pick sheet by difficulty, init
                            // AcNoteMng
    void drawActiveNotes(); // @ 0x22cac  drawActiveNotes — blit every in-flight
                            // note + time line
    void drawLifeGauge();   // @ 0x23000  drawLifeGauge — blit the 24-cell life gauge

    // Frees the task's HUD/textures/layers + AcNoteMng teardown. Called from
    // state 9. Ghidra: AcMainTask::Cleanup.
    void cleanup(); // @ 0x22b44

    // The HUD draw callback reaches these same members through `context`; let it
    // in.
    static void AcViewerHudDraw(int child,
                                int frame,
                                int x,
                                int y,
                                int scaleX,
                                int scaleY,
                                int anchorX,
                                int anchorY,
                                int color,
                                int alpha,
                                int rotation,
                                uint32_t blend,
                                int *clipRect,
                                uint32_t priority,
                                void *context);

    // ================= work-area layout (offsets are binary-exact)
    // =================
    ne::C_TASK *m_stateTask = nullptr;    // +0x28 play-state sub-task (deleted in cleanup)
    neTextureForiOS *m_digitTex[10] = {}; // +0x2c HUD digit textures ticket_num/num_pointb
    AepLyrCtrl *m_pauseLayer = nullptr;   // +0x54 PAUSE_LOOP overlay
    AepLyrCtrl *m_topLayer = nullptr;     // +0x58 TOP_* banner overlay
    int m_effectCoolLyrNo = 0;            // +0x5c EFFECT_COOL layer number
    int m_effectCoolFrames = 0;           // +0x60 EFFECT_COOL layer frame count
#ifndef ENABLE_PATCHES
    uint8_t unused_64[0x6c - 0x64] = {}; // +0x64 unused 8-byte gap (Ghidra: no AcViewerTask access)
#endif
    int m_gaugeLit02Frm = 0;   // +0x6c GAUGE_02 (lit, lower cells)
    int m_gaugeLit01Frm = 0;   // +0x70 GAUGE_01 (lit, upper cells)
    int m_gaugeEmpty02Frm = 0; // +0x74 GAUGE_OUT_02 (empty, lower cells)
    int m_gaugeEmpty01Frm = 0; // +0x78 GAUGE_OUT_01 (empty, upper cells)
    int m_musicOnFrm = 0;      // +0x7c MUSIC_ON marker frame
    int m_musicOffFrm = 0;     // +0x80 MUSIC_OFF marker frame
    int m_barFrm = 0;          // +0x84 difficulty BAR_* time-line frame
    int m_timeLineFrm = 0;     // +0x88 TIME_LINE sweep marker frame
    int m_beatWhiteFrm = 0;    // +0x8c BEAT_POPN_WHITE note frame
    int m_beatBlueFrm = 0;     // +0x90 BEAT_POPN_BLUE note frame
    int m_numFrm[9] = {};      // +0x94 NUM_00..NUM_08 digit frames
    int m_usrNo[7] = {};       // +0xb8 HUD layer user numbers (draw dispatch)
    int m_readySeId = 0;       // +0xd4 arcade timing-SE source id
    int m_readySeInst = 0;     // +0xd8 ready-SE playing instance
    int m_dragTouchId = -1;    // +0xdc active drag-scrub touch id (-1 = none)
    float m_dragStartX = 0.0f; // +0xe0 drag anchor scaled start x
    float m_dragStartY = 0.0f; // +0xe4 drag anchor scaled start y
    float m_dragLastX = 0.0f;  // +0xe8 last frame's scaled x
    float m_dragLastY = 0.0f;  // +0xec last frame's scaled y
    float m_dragAccumX = 0.0f; // +0xf0 accumulated scaled dx
    float m_seekCoef = 0.0f;   // +0xf4 accumulated scaled dy*10 (the seek
                               //        coefficient; * m_seekScale in the
                               //        case-0xb live seek)
    bool m_moved = false;      // +0xf8 per-frame touch "moved" flag
#ifndef ENABLE_PATCHES
    uint8_t _pad_f9[0xfc - 0xf9] = {}; // +0xf9 alignment pad before m_pauseTime (no access)
#endif
    int m_pauseTime = 0;          // +0xfc pause-time position snapshot
    int16_t m_totalNoteCount = 0; // +0x100 total note count (HUD 4-digit)
    int16_t m_judgeTotal = 0;     // +0x102 running judged total (HUD 4-digit)
    int m_screenWidth = 0;        // +0x104 aep screen width
    int m_screenHeight = 0;       // +0x108 aep screen height
    float m_uiScale = 0.0f;       // +0x10c UI scale (g_uiScale = screenScale * 0.5)
    // ---- device-branched HUD layout constants (+0x110..+0x1c4, documented seam)
    // ----
    // +0x110/+0x134/+0x138/+0x140/+0x144 are written by setup() as part of the
    // contiguous layout block but are never read back by any object in the
    // shipped image (verified by a whole-image field-access scan); they are kept
    // as real fields so the stores stay faithful, with provisional names.
    int m_pauseBtnTopY = 0;      // +0x110 pause-button top y (write-only)
    int m_pauseBtnHeight = 0;    // +0x114 pause-menu button full height (halved in the y-band test)
    int m_seekScale = 0;         // +0x118 resume-seek scale constant (setup
                                 //        writes 5 phone / 3 ipad); converted to
                                 //        float and multiplied by the seek math
    int m_xScrubScale = 0;       // +0x11c x-scrub scale (drag dx -> gauge base)
    int m_noteClipTop = 0;       // +0x120 note-field clip top / y
    int m_noteFieldX = 0;        // +0x124 note-field x (= m_noteClipTop + m_noteFieldY)
    int m_noteFieldY = 0;        // +0x128 note-field y
    int m_seekGaugeSplitY = 0;   // +0x12c drag start-Y split: >= gauge scrub, < seek scrub
    int m_scrubZoneTopY = 0;     // +0x130 top Y of the scrub zone (drag start-Y >= this)
    int m_effectNoteWidth = 0;   // +0x134 effect-note width (write-only)
    int m_effectNoteInsetY = 0;  // +0x138 effect-note inset y (write-only)
    int m_effectNoteHeight = 0;  // +0x13c effect-note height (halved to centre the sprite)
    int m_effectSpriteWidth = 0; // +0x140 effect-sprite width (write-only)
    int m_effectSpriteInsetX = 0; // +0x144 effect-sprite inset x (write-only)
    int m_coolLayerArgA = 0;      // +0x148 EFFECT_COOL drawLayer anchorX
    int m_coolLayerArgB = 0;      // +0x14c EFFECT_COOL drawLayer anchorY
    int m_playTouchW = 0;         // +0x150 in-play song-select touch rect width
    int m_playTouchH = 0;         // +0x154 in-play song-select touch rect height
    int m_laneFrm[9] = {};        // +0x158 per-lane note frame table
    int m_gaugeLowerY = 0;        // +0x17c gauge lower-cell y
    int m_gaugeUpperY = 0;        // +0x180 gauge upper-cell y
    int m_gaugeBaseX = 0;         // +0x184 gauge first-cell x
    int m_gaugeStrideX = 0;       // +0x188 gauge per-cell x stride
    int m_timeLineX = 0;          // +0x18c time-line marker x
    int m_timeLineY = 0;          // +0x190 time-line marker y
    int m_barWidth = 0;           // +0x194 time-line bar width (sweep denominator)
    int m_digitScaleX = 0;        // +0x198 HUD digit blit scale x
    int m_digitScaleY = 0;        // +0x19c HUD digit blit scale y
    int m_digitAdvance = 0;       // +0x1a0 HUD digit right-to-left x advance
    // The pause-menu buttons (case 0xd, x-agnostic y-band hit-test): [0] options
    // @0x1a4, [1] resume @0x1a8, [2] quit @0x1ac; each band is [anchor+height/2,
    // +height/2+rowHeight].
    int m_pauseBtnY[3] = {};  // +0x1a4/+0x1a8/+0x1ac button y anchors
    int m_pauseBtnRowH = 0;   // +0x1b0 button row height
    int m_exitTouchX = 0;     // +0x1b4 in-play exit/pause button rect x
    int m_exitTouchY = 0;     // +0x1b8 in-play exit/pause button rect y
    int m_exitTouchW = 0;     // +0x1bc in-play exit/pause button rect w
    int m_exitTouchH = 0;     // +0x1c0 in-play exit/pause button rect h
    int m_titleBaselineY = 0; // +0x1c4 HUD title baseline y bias
    int16_t m_gaugeBase = 0;  // +0x1c8 life-gauge base value
    int16_t m_gaugeValue = 0; // +0x1ca life-gauge / combo value (0x100 == full)
    // +0x1cc scroll-speed table [4]; the 4th slot (+0x1d2) doubles as the
    // combo-step addend read by drawActiveNotes (setup writes all four in one
    // loop).
    int16_t m_scrollSpeed[4] = {}; // +0x1cc per-lane scroll-speed table
    bool m_hudReady = false;       // +0x1d4 HUD resolved / ready
    bool m_hudArmed = false;       // +0x1d5 HUD armed (transition done)
    bool m_paused = false;         // +0x1d6 note playback paused / muted
    bool m_pauseMenuOpen = false;  // +0x1d7 pause-menu open
    bool m_padDisplay = false;     // +0x1d8 pad-class display
    // +0x1d9 pad-only flag: the black board is up / the pad viewer is already
    // set up (Ghidra calls it bIpadSubMode). ACST_INIT skips GotoAcViewer +
    // InsertBlackBoard when it is set; ACST_WAIT_TRANSITION gates the ready-SE on
    // it; requestGameExit raises it so the exit transition does not re-insert the
    // board; Cleanup preserves it across the play-data wipe (hence "survives").
    bool m_padBoardUp = false;
#ifndef ENABLE_PATCHES
    uint8_t _pad_1da[0x1dc - 0x1da] = {}; // +0x1da alignment pad before m_difficulty (no access)
#endif
    int m_difficulty = 0;             // +0x1dc selected difficulty (0 easy..3 ex)
    void *m_sheet = nullptr;          // +0x1e0 chart sheet NSData (strong, ARC-bridged)
    void *m_songTitle = nullptr;      // +0x1e4 song-title NSString (strong, ARC-bridged)
    int m_titleXAdvance = 0;          // +0x1e8 HUD title x-advance (by name length)
    int m_comboDigitX = 0;            // +0x1ec cached combo-digit x; also the
                                      //        in-play song-select touch rect origin x
    int m_comboDigitY = 0;            // +0x1f0 cached combo-digit y; also the
                                      //        in-play song-select touch rect origin y
    int m_hiSpeed = 0;                // +0x1f4 hi-speed option (+500)
    int m_popKun = 0;                 // +0x1f8 pop-kun option
    int m_hidSud = 0;                 // +0x1fc hid/sud option (read as uint32 mask)
    int m_ranMir = 0;                 // +0x200 ran/mir lane-remap option
    int m_endHoldCounter = 0;         // +0x204 end-of-song hold frame counter
    void *m_optionVC = nullptr;       // +0x208 option-sheet controller (strong, ARC-bridged)
    AcViewerState m_state = kAcvInit; // +0x20c play-state machine (AcViewerState)
    uint8_t _reservedTail[0x214 - 0x210] = {}; // +0x210 object tail
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
