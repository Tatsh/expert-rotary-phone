//
//  AcViewerTask.h
//  pop'n rhythmin
//
//  The ARCADE-VIEWER NOTE-PLAY task: the actual pop'n-style rhythm gameplay screen
//  reached from the "arcade viewer" (GotoAcViewer). It loads the chosen ac chart,
//  builds the group-7 "arcade_viewer" HUD, runs the touch/flick input + play-state
//  machine, and each frame drives the arcade note engine (AcNoteMng) plus the note /
//  life-gauge / HUD-digit draw passes. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin.
//
//  NAMING NOTE: Ghidra labels this class's methods acMainTask* (setup FUN_0002230c,
//  update FUN_00021678, dtor thunk task_delete FUN_000215d8) because AppDelegate holds
//  it in its `acMainTask` property (setAcMainTask:). It is NOT the same class as the
//  repo's existing AcMainTask (the arcade sugoroku/treasure SELECT scene, ctor
//  FUN_00099ab0, state @ +0x9f8, embedded RNG @ +0x4f4): this task has a distinct
//  vtable (@ 0x130bb8), its play state lives @ +0x20c, and it drives AcNoteMng rather
//  than the sugoroku map. It is kept in its own file to avoid clobbering that class.
//
//  ---- work area (this class IS the ~0x214-byte play-data struct) ----
//  C_TASK's base is exactly 0x28 bytes, so the members below land at their true binary
//  offsets. Every scalar the setup / draw / HUD passes reach by flat `*(T*)(this+off)`
//  in the binary is named and placed at its exact offset (with a `// +0xNN` comment);
//  genuine gaps are `_rsvd_NN[]` fillers. The device-branched HUD layout block
//  (+0x110..+0x1c4 — ~80 pure-constant coordinate stores from DAT_0012e370 phone /
//  DAT_0012e394 pad) is only partly reached by name (the note-field / gauge / time-line /
//  digit geometry accessors); its un-accessed interior is kept as documented reserved
//  fillers (the ROLES and control flow that read the named members are exact). The whole
//  object is wiped +0x28..+0x20c by cleanup() (memset of 0x1e4 bytes); the play state
//  @ +0x20c survives.
//

#pragma once

#include <cstdint>

#include "C_TASK.h"

class AepLyrCtrl;
class neTextureForiOS;
class AcViewerTask;   // (defined below) — named here so the neEngine bridge hook can befriend it

// The neEngineBridge apply-settings hook (options sheet CONTINUE / BACK): pushes the recovered
// option selections + re-seek into this task, writing its private option / seek fields directly.
// Befriended below so it reaches them like the HUD callback does. Ghidra: FUN_00023850.
namespace neEngine { void acMainApplyGameplaySettings(AcViewerTask *task); }

// The registered group-7 per-layer HUD draw callback (score / combo / music-title /
// gauge-digit blitter). It is a C function-pointer callback installed by setup() via
// setAepCallbacks(aep, 7, &AcViewerHudDraw, this); the trailing `context` is the owning
// AcViewerTask. Ghidra: aepHudDrawCallback (registered id 0x23359). @ 0x23358
void AcViewerHudDraw(int child, int frame, int x, int y, int scaleX, int scaleY,
                     int anchorX, int anchorY, int color, int alpha, int16_t rotation,
                     int blend, int *p13, int p14, void *context);

class AcViewerTask : public C_TASK {
public:
    // Constructed by the engine when the arcade viewer starts play (its ctor/vtable
    // live @ 0x130bb8; not part of this reconstruction batch).
    AcViewerTask();
    ~AcViewerTask() override;            // @ 0x215d8 (task_delete deleting-dtor: base + delete)
    void update(int deltaMs) override;   // @ 0x21678  acMainTaskUpdate

private:
    void setup();          // @ 0x2230c  acMainTaskSetup — resolve the HUD, load chart + SE
    void loadChart();      // @ 0x2316c  loadChartData — pick sheet by difficulty, init AcNoteMng
    void drawActiveNotes();// @ 0x22cac  drawActiveNotes — blit every in-flight note + time line
    void drawLifeGauge();  // @ 0x23000  drawLifeGauge — blit the 24-cell life gauge

    // Frees the task's HUD/textures/layers + AcNoteMng teardown. Called from state 9.
    // Ghidra: AcMainTask::Cleanup.
    void cleanup();        // @ 0x22b44

    // The HUD draw callback reaches these same members through `context`; let it in.
    friend void AcViewerHudDraw(int child, int frame, int x, int y, int scaleX, int scaleY,
                                int anchorX, int anchorY, int color, int alpha, int16_t rotation,
                                int blend, int *p13, int p14, void *context);

    // The apply-settings bridge hook writes the option / seek fields below directly.
    friend void neEngine::acMainApplyGameplaySettings(AcViewerTask *task);

    // ================= work-area layout (offsets are binary-exact) =================
    C_TASK          *m_stateTask = nullptr;          // +0x28 play-state sub-task (deleted in cleanup)
    neTextureForiOS *m_digitTex[10] = {};            // +0x2c HUD digit textures ticket_num/num_pointb
    AepLyrCtrl      *m_pauseLayer = nullptr;         // +0x54 PAUSE_LOOP overlay
    AepLyrCtrl      *m_topLayer = nullptr;           // +0x58 TOP_* banner overlay
    int              m_effectCoolLyrNo = 0;          // +0x5c EFFECT_COOL layer number
    int              m_effectCoolFrames = 0;         // +0x60 EFFECT_COOL layer frame count
    uint8_t          _rsvd_64[0x6c - 0x64] = {};     // +0x64
    int              m_gaugeLit02Frm = 0;            // +0x6c GAUGE_02 (lit, lower cells)
    int              m_gaugeLit01Frm = 0;            // +0x70 GAUGE_01 (lit, upper cells)
    int              m_gaugeEmpty02Frm = 0;          // +0x74 GAUGE_OUT_02 (empty, lower cells)
    int              m_gaugeEmpty01Frm = 0;          // +0x78 GAUGE_OUT_01 (empty, upper cells)
    int              m_musicOnFrm = 0;               // +0x7c MUSIC_ON marker frame
    int              m_musicOffFrm = 0;              // +0x80 MUSIC_OFF marker frame
    int              m_barFrm = 0;                   // +0x84 difficulty BAR_* time-line frame
    int              m_timeLineFrm = 0;              // +0x88 TIME_LINE sweep marker frame
    int              m_beatWhiteFrm = 0;             // +0x8c BEAT_POPN_WHITE note frame
    int              m_beatBlueFrm = 0;              // +0x90 BEAT_POPN_BLUE note frame
    int              m_numFrm[9] = {};               // +0x94 NUM_00..NUM_08 digit frames
    int              m_usrNo[7] = {};                // +0xb8 HUD layer user numbers (draw dispatch)
    int              m_readySeId = 0;                // +0xd4 arcade timing-SE source id
    int              m_readySeInst = 0;              // +0xd8 ready-SE playing instance
    uint8_t          _rsvd_dc[0xf4 - 0xdc] = {};     // +0xdc
    float            m_seekCoef = 0.0f;              // +0xf4 resume-seek linear-combine coefficient
                                                     //        (float; multiplied by m_seekScale in
                                                     //        applyGameplaySettings' seek math)
    uint8_t          m_moved = 0;                    // +0xf8 per-frame touch "moved" flag
    uint8_t          _rsvd_f9[0xfc - 0xf9] = {};     // +0xf9
    int              m_pauseTime = 0;                // +0xfc pause-time position snapshot
    int16_t          m_totalNoteCount = 0;           // +0x100 total note count (HUD 4-digit)
    int16_t          m_judgeTotal = 0;               // +0x102 running judged total (HUD 4-digit)
    int              m_screenWidth = 0;              // +0x104 aep screen width
    int              m_screenHeight = 0;             // +0x108 aep screen height
    int              m_uiScale = 0;                  // +0x10c UI scale (g_dwUiScale; read as float in update)
    // ---- device-branched HUD layout constants (+0x110..+0x1c4, documented seam) ----
    uint8_t          _rsvd_110[0x118 - 0x110] = {};  // +0x110
    int              m_seekScale = 0;                // +0x118 resume-seek scale constant (setup
                                                     //        writes 5 phone / 3 ipad); read as a
                                                     //        fixed-point value by the seek math
    uint8_t          _rsvd_11c[0x120 - 0x11c] = {};  // +0x11c setup writes 2 phone / 1 ipad here
                                                     //        (paired with m_seekScale; role best-effort)
    int              m_noteClipTop = 0;              // +0x120 note-field clip top / y
    int              m_noteFieldX = 0;               // +0x124 note-field x (= m_noteClipTop + m_noteFieldY)
    int              m_noteFieldY = 0;               // +0x128 note-field y
    uint8_t          _rsvd_12c[0x148 - 0x12c] = {};  // +0x12c
    int              m_coolLayerArgA = 0;            // +0x148 EFFECT_COOL drawLayer arg (role best-effort)
    int              m_coolLayerArgB = 0;            // +0x14c EFFECT_COOL drawLayer arg (role best-effort)
    uint8_t          _rsvd_150[0x158 - 0x150] = {};  // +0x150
    int              m_laneFrm[9] = {};              // +0x158 per-lane note frame table
    int              m_gaugeLowerY = 0;              // +0x17c gauge lower-cell y
    int              m_gaugeUpperY = 0;              // +0x180 gauge upper-cell y
    int              m_gaugeBaseX = 0;               // +0x184 gauge first-cell x
    int              m_gaugeStrideX = 0;             // +0x188 gauge per-cell x stride
    int              m_timeLineX = 0;                // +0x18c time-line marker x
    int              m_timeLineY = 0;                // +0x190 time-line marker y
    int              m_barWidth = 0;                 // +0x194 time-line bar width (sweep denominator)
    int              m_digitScaleX = 0;              // +0x198 HUD digit blit scale x
    int              m_digitScaleY = 0;              // +0x19c HUD digit blit scale y
    int              m_digitAdvance = 0;             // +0x1a0 HUD digit right-to-left x advance
    uint8_t          _rsvd_1a4[0x1c4 - 0x1a4] = {};  // +0x1a4
    int              m_titleBaselineY = 0;           // +0x1c4 HUD title baseline y bias
    int16_t          m_gaugeBase = 0;                // +0x1c8 life-gauge base value
    int16_t          m_gaugeValue = 0;               // +0x1ca life-gauge / combo value (0x100 == full)
    // +0x1cc scroll-speed table [4]; the 4th slot (+0x1d2) doubles as the combo-step
    // addend read by drawActiveNotes (setup writes all four in one loop).
    int16_t          m_scrollSpeed[4] = {};          // +0x1cc per-lane scroll-speed table
    uint8_t          m_hudReady = 0;                 // +0x1d4 HUD resolved / ready
    uint8_t          m_hudArmed = 0;                 // +0x1d5 HUD armed (transition done)
    uint8_t          m_paused = 0;                   // +0x1d6 note playback paused / muted
    uint8_t          m_pauseMenuOpen = 0;            // +0x1d7 pause-menu open
    uint8_t          m_padDisplay = 0;               // +0x1d8 pad-class display
    uint8_t          m_padBoardUp = 0;               // +0x1d9 pad "board up" (survives cleanup wipe)
    uint8_t          _rsvd_1da[0x1dc - 0x1da] = {};  // +0x1da
    int              m_difficulty = 0;               // +0x1dc selected difficulty (0 easy..3 ex)
    void            *m_sheet = nullptr;              // +0x1e0 chart sheet NSData (strong, ARC-bridged)
    void            *m_songTitle = nullptr;          // +0x1e4 song-title NSString (strong, ARC-bridged)
    int              m_titleXAdvance = 0;            // +0x1e8 HUD title x-advance (by name length)
    int              m_comboDigitX = 0;              // +0x1ec cached combo-digit screen x
    int              m_comboDigitY = 0;              // +0x1f0 cached combo-digit screen y
    int              m_hiSpeed = 0;                  // +0x1f4 hi-speed option (+500)
    int              m_popKun = 0;                   // +0x1f8 pop-kun option
    int              m_hidSud = 0;                   // +0x1fc hid/sud option (read as uint32 mask)
    int              m_ranMir = 0;                   // +0x200 ran/mir lane-remap option
    int              m_endHoldCounter = 0;           // +0x204 end-of-song hold frame counter
    void            *m_optionVC = nullptr;           // +0x208 option-sheet controller (strong, ARC-bridged)
    int              m_state = 0;                    // +0x20c play-state machine field
    uint8_t          _reservedTail[0x214 - 0x210] = {}; // +0x210 object tail
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
