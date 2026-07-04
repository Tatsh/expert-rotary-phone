//
//  AcViewerTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The arcade-viewer
//  note-play task: it loads the chosen ac chart into AcNoteMng, builds the group-7
//  "arcade_viewer" HUD, runs the touch/flick play-state machine and, while playing,
//  drives AcNoteMng plus the note / life-gauge / HUD-digit draw passes.
//
//  See AcViewerTask.h for the naming note (Ghidra labels these acMainTask*; this is a
//  distinct class from the repo's sugoroku AcMainTask). Play-data is reached through the
//  named members declared in AcViewerTask.h (each at its binary-exact offset, cited there).
//

#import "AcViewerTask.h"

#include <cstring>
#include <new>

#import "AcMusicData.h"
#import "AcNoteMng.h"
#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "MainViewController.h"
#import "MenuMainTask.h"
#import "MusicManager.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

// Group-7 asset slot for the arcade viewer HUD.
static const int kAcvGroup = 7;

// The root nav host the play machine drives (GotoAcViewer / black-board overlay).
static MainViewController *AcvRootVC() {
    return (MainViewController *)neSceneManager::rootViewController();
}

// ===========================================================================
// Construction / teardown
// ===========================================================================

// Constructed by the engine (ctor/vtable @ 0x130bb8, not in this batch). The C_TASK
// base + the zeroed play-data blob (m_playData) are all the ctor needs here.
AcViewerTask::AcViewerTask() = default;

// @ 0x215d8 — task_delete is the compiler's deleting-destructor thunk (caSourceNode_dtor
// then operator delete). The real destructor body only chains to the C_TASK base: this
// task frees its HUD/textures/layers + AcNoteMng in cleanup() (state 9), so there is no
// per-member teardown here. ~C_TASK() (caSourceNode_dtor) runs implicitly after this.
AcViewerTask::~AcViewerTask() = default;

// ===========================================================================
// setup — Ghidra acMainTaskSetup (FUN_0002230c). Resolve the HUD handles, load the
// chart + BGM/SE, build the two AepLyrCtrl overlays, load the digit textures and
// register the per-layer HUD draw callback. Runs once (state 2 -> 3).
// ===========================================================================

// getUserNo layer-name table (Ghidra: DAT_00130bc4, 7 names) -> +0xb8. These are the
// HUD layers AcViewerHudDraw dispatches on (score / combo / title / gauge digits).
static const char *const kAcvUsrNames[7] = {
    "SCORE_NUM", "COMBO_NUM", "MUSIC_NAME", "MAX_COMBO_NUM",
    "GAUGE_NUM", "COOL_NUM", "GREAT_NUM"
};
// getFrmNo names (Ghidra: DAT_00130bf0, 9) -> +0x94.
static const char *const kAcvFrmNames[9] = {
    "NUM_00", "NUM_01", "NUM_02", "NUM_03", "NUM_04",
    "NUM_05", "NUM_06", "NUM_07", "NUM_08"
};
// Difficulty -> BAR_* time-line frame (Ghidra: PTR_s_BAR_EASY_00130be0).
static const char *const kAcvBarFrm[4] = { "BAR_EASY", "BAR_NORMAL", "BAR_HYPER", "BAR_EX" };

void AcViewerTask::setup() {
    AepManager &aep = AepManager::shared();
    AcNoteMng &note = AcNoteMng::shared();
    AppDelegate *app = [AppDelegate appDelegate];

    m_screenWidth = aep.screenWidth();          // aepGetScreenWidth
    m_screenHeight = aep.screenHeight();         // aepGetScreenHeight
    m_uiScale = g_dwUiScale;
    m_comboDigitX = -1;                          // HUD combo digit screen x (HUD writes it)
    m_comboDigitY = -1;                          // HUD combo digit screen y

    // Player options snapshot.
    m_hiSpeed = [UserSettingData acvHiSpeed];    // +500
    m_popKun = [UserSettingData acvPopKun];
    m_hidSud = [UserSettingData acvHidSud];
    m_ranMir = [UserSettingData acvRanMir];
    m_difficulty = (int)(short)neAppEventCenter::acViewerDifficulty();
    m_padDisplay = neSceneManager::isPadDisplay() ? 1 : 0;

    // Lane remap for the RAN/MIR option, then load + init the chart.
    note.setupLaneMapping(m_ranMir);
    loadChart();                                 // FUN_0002316c

    // Total note count + the initial gauge value (0x100 == full at 256/1024 scale).
    m_totalNoteCount = (int16_t)note.getTotalNoteCount();
    m_gaugeValue = 0x100;

    // Per-lane scroll-speed table (@ +0x1cc[4]) derived from DAT_0012e350/0012e354 and
    // the note count. The exact fixed-point packing (___udivsi3 of value<<10) is
    // decompiler-obscured; reproduced best-effort per the two-branch shape of the loop.
    for (int i = 0; i < 4; i++) {
        // i<2: a negative constant rate; i>=2: scaled by the note count, floored at 1.
        int16_t v;
        if (i < 2) {
            v = 0;   // best-effort: the DAT_0012e350/54 constants are not recoverable here
        } else {
            v = 1;
        }
        m_scrollSpeed[i] = v;
    }

    // Load the "TIMING" arcade SE and the group-7 viewer Aep data.
    AudioManager *audio = [AudioManager sharedManager];
    NSString *sePath = [[NSBundle mainBundle] pathForResource:@"v12" ofType:@"m4a"];
    m_readySeId = (int)[audio loadSe:sePath isLoop:NO callName:nil group:1];

    const bool pad = (m_padDisplay != 0);
    AepLoadGroup(&aep, kAcvGroup, pad ? "arcade_viewer_ipad" : "arcade_viewer");

    // Two AepLyrCtrl overlays: the PAUSE_LOOP layer (+0x54) and the top banner (+0x58,
    // device-picked "TOP_960" / "TOP_1136" / "TOP_IPAD").
    AepLyrCtrl *pauseLayer = new AepLyrCtrl();
    m_pauseLayer = pauseLayer;
    pauseLayer->init(kAcvGroup, "PAUSE_LOOP", this, 0);   // order best-effort (overlay)

    const char *topName = "TOP_960";
    if (pad) {
        topName = "TOP_IPAD";
    } else if ([app displayType] == 2) {
        topName = "TOP_1136";
    }

    // Device-branched HUD layout constants (@ +0x110..+0x1c0 and the per-lane note-frame
    // table @ +0x158[9]). These are ~80 pure-constant stores from DAT_0012e370 (phone) /
    // DAT_0012e394 (pad); reconstructed as a documented seam per rule 7 (the values are
    // fixed layout coordinates, not behaviour). setup() writes them here before the top
    // layer is built. m_noteFieldX (+0x124) = m_noteClipTop (+0x120) + m_noteFieldY (+0x128).
    // (best-effort: full constant tables omitted — see the DAT_0012e3xx blocks.)
    m_noteFieldX = m_noteClipTop + m_noteFieldY;

    AepLyrCtrl *topLayer = new AepLyrCtrl();
    m_topLayer = topLayer;
    topLayer->init(kAcvGroup, topName, this, 0);   // order best-effort (overlay)

    // Resolve the HUD handles.
    m_effectCoolLyrNo = aep.getLyrNo(kAcvGroup, "EFFECT_COOL");
    m_effectCoolFrames = aep.layerFrameCount(m_effectCoolLyrNo);
    for (int i = 0; i < 7; i++) {
        m_usrNo[i] = aep.getUserNo(kAcvGroup, kAcvUsrNames[i]);
    }
    for (int i = 0; i < 9; i++) {
        m_numFrm[i] = aep.getFrameNo(kAcvGroup, kAcvFrmNames[i]);
    }
    m_gaugeLit02Frm = aep.getFrameNo(kAcvGroup, "GAUGE_02");
    m_gaugeLit01Frm = aep.getFrameNo(kAcvGroup, "GAUGE_01");
    m_gaugeEmpty02Frm = aep.getFrameNo(kAcvGroup, "GAUGE_OUT_02");
    m_gaugeEmpty01Frm = aep.getFrameNo(kAcvGroup, "GAUGE_OUT_01");
    m_musicOnFrm = aep.getFrameNo(kAcvGroup, "MUSIC_ON");
    m_musicOffFrm = aep.getFrameNo(kAcvGroup, "MUSIC_OFF");
    m_barFrm = aep.getFrameNo(kAcvGroup, kAcvBarFrm[m_difficulty]);
    m_timeLineFrm = aep.getFrameNo(kAcvGroup, "TIME_LINE");
    m_beatWhiteFrm = aep.getFrameNo(kAcvGroup, "BEAT_POPN_WHITE");
    m_beatBlueFrm = aep.getFrameNo(kAcvGroup, "BEAT_POPN_BLUE");

    // 10 HUD digit textures (@ +0x2c[10]) from the bundle (device-picked "ticket_num%d"
    // / "num_pointb_%d" name tables PTR_cf_ticket_num0 / PTR_cf_num_pointb_0).
    NSBundle *bundle = [NSBundle mainBundle];
    for (int i = 0; i < 10; i++) {
        neTextureForiOS *tex = new neTextureForiOS();
        m_digitTex[i] = tex;
        NSString *name = pad ? [NSString stringWithFormat:@"num_pointb_%d", i]
                             : [NSString stringWithFormat:@"ticket_num%d", i];
        tex->load([[bundle pathForResource:name ofType:@"png"] UTF8String]);
    }

    // Register the per-layer HUD draw callback (Ghidra: setAepCallbacks(aep, 7, 0x23359,
    // this) — 0x23359 is &AcViewerHudDraw in Thumb).
    // The callback's natural signature carries a packed-short rotation (param 11), so it is
    // reinterpret-cast to the generic AepGroupDrawFn at registration (same pattern as MainTask's
    // MusicSelAepDraw); the ABI is compatible (short passed in a 32-bit register slot).
    aep.setGroupDrawCallback(kAcvGroup, reinterpret_cast<AepGroupDrawFn>(&AcViewerHudDraw), this);
    m_hudReady = 1;   // HUD ready
}

// ===========================================================================
// loadChart — Ghidra loadChartData (FUN_0002316c). Fetch the AcMusicData for the
// selected song, async-load its BGM, pick the sheet by difficulty and hand it to
// AcNoteMng::initPlayData.
// ===========================================================================
void AcViewerTask::loadChart() {
    AudioManager *audio = [AudioManager sharedManager];
    AcNoteMng &note = AcNoteMng::shared();

    AcMusicData *acMusic = [[MusicManager getInstance] getAcMusicData:neAppEventCenter::acViewerMusicId()];

    // Cache the display music name (+0x1e4, +1 retained); its length picks the HUD title
    // offsets (+0x1e8 x-advance / +0x1c4 baseline).
    if (m_songTitle) {
        (void)(__bridge_transfer id)m_songTitle;
        m_songTitle = nullptr;
    }
    NSString *name = [acMusic musicName];
    m_songTitle = (__bridge_retained void *)name;

    const bool pad = (m_padDisplay != 0);
    if (name.length < 0x14) {
        m_titleXAdvance = pad ? 0x2a : 0x1c;
        m_titleBaselineY = pad ? -34 : -20;   // 0xffffffde / 0xffffffec
    } else {
        m_titleXAdvance = pad ? 0x18 : 0x10;
        m_titleBaselineY = pad ? -20 : -12;   // 0xffffffec / 0xfffffff4
    }

    [audio stopBgm:0.0f];   // FUN_0002316c: stopBgm:(SEL)0x0 -> fadeSeconds 0.0 (immediate)
    // Ghidra: the async BGM load is a dispatch_async(^{...}) block (@ 0x237bc) posted to the
    // global queue; it streams the song's BGM in the background while play sets up. The block
    // (disasm 0x237bc): getBackTrack:m_difficulty -> loadBgmData:isLoop:NO -> playBgm:1.0f,
    // then sets the bgm-ready flag (+0x1d5). playBgm: fade value best-effort (1.0f imm arg).
    const int difficulty = m_difficulty;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSData *track = [acMusic getBackTrack:difficulty];
        [audio loadBgmData:track isLoop:NO];
        [audio playBgm:1.0f];
        m_hudArmed = 1;   // +0x1d5 (strb 1 at block tail)
    });

    // Release the previous sheet, pick the new one by difficulty (0 easy / 1 normal /
    // 2 hyper / 3 ex), retain it, and init the note timeline at the chosen hi-speed.
    if (m_sheet) {
        (void)(__bridge_transfer id)m_sheet;
        m_sheet = nullptr;
    }
    NSData *sheet;
    switch (m_difficulty) {
    case 0:  sheet = [acMusic sheetEasy];   break;
    case 2:  sheet = [acMusic sheetHyper];  break;
    case 3:  sheet = [acMusic sheetEx];     break;
    default: sheet = [acMusic sheetNormal]; break;
    }
    m_sheet = (__bridge_retained void *)sheet;
    note.initPlayDataWithData(sheet, m_hiSpeed);
}

// ===========================================================================
// drawActiveNotes — Ghidra drawActiveNotes (FUN_00022cac). Blit each in-flight note
// at its lane/scroll position, count the ones that reached the judge line into the
// combo/gauge, then blit the moving time-line marker.
// ===========================================================================
void AcViewerTask::drawActiveNotes() {
    AepManager &aep = AepManager::shared();
    AcNoteMng &note = AcNoteMng::shared();

    const int count = note.countActiveNotes();
    const uint32_t now = (uint32_t)note.getCurrentPosition();

    int clip[4] = { 0, m_noteClipTop, m_screenWidth, m_screenHeight };

    for (int i = 0; i < count; i++) {
        AcNoteObject n;
        note.getNoteObject(&n, i);
        const int laneFrame = m_laneFrm[n.lane];

        if (n.tick < now) {
            // Note has passed the spawn point: scroll it toward the judge line. The exact
            // fixed-point scroll math (DAT_00022ffc scale + 0.5 bias) is decompiler-
            // obscured; modelled best-effort. When it is still above the layer's frame
            // count it is drawn as the EFFECT_COOL layer.
            const int frame = (int)((float)(now - n.tick) * 1.0f + 0.5f);
            if (frame < m_effectCoolFrames) {
                // FUN_00022cac drawLayer args: x = per-lane note frame (@+0x158[lane]); y is the
                // NEON-computed lane position (best-effort here). Constants are binary-exact:
                // scale 100/100, loopFlags/p9 = m_coolLayerArg{A,B}, p10=100, color=0, colorHi=1,
                // blend=0x200, p15=0xffffff, clip={0,top,w,h}, ctx=null, p17=0xb, p19=1.
                aep.drawLayer(m_effectCoolLyrNo, frame,
                              m_laneFrm[n.lane], m_noteFieldY,
                              100, 100, 0, m_coolLayerArgA, m_coolLayerArgB, 100,
                              0, 1, 0x200, 0xffffff, clip, nullptr, 0xb, 1);
                // First time a note crosses the line (and not in HID/SUD hidden state),
                // add to the combo counter (@ +0x1ca, saturated to 0x3ff) and mark the
                // note handled (bit 6). Ghidra: +0x1d2 combo step / acNoteSetNoteFlag.
                if (m_paused == 0 && m_pauseMenuOpen == 0 && (n.flags & 0x40) == 0) {
                    int c = (int)m_scrollSpeed[3] + (int)m_gaugeValue;
                    if (c < 0) { c = 0; }
                    if (c > 0x3ff) { c = 0x3ff; }
                    m_gaugeValue = (int16_t)c;
                    note.setNoteFlag(i, 0x40);
                }
            }
        } else {
            // Note still approaching: pick the POPN white/blue sprite (or the pop-kun
            // sprite when the POPKUN option is on) and blit it via drawAepFrameEx at its
            // computed lane x (best-effort on the NEON transform). HID/SUD gating on
            // +0x1fc hides notes outside the visible band.
            const bool visible =
                (((uint32_t)m_hidSud | 2) != 3) || (((uint32_t)m_hidSud & ~1u) != 2);
            if (visible) {
                int frm;
                if (m_popKun == 0) {
                    frm = (n.lane & 1) ? m_beatBlueFrm : m_beatWhiteFrm;  // blue / white
                } else {
                    frm = (n.lane & 1) ? m_beatBlueFrm : m_beatWhiteFrm;  // pop-kun variant
                }
                // FUN_00022cac note-sprite draw: x = per-lane frame (@+0x158[lane]); y + anchors are
                // NEON-computed (best-effort here). Constants are binary-exact: scale 100.0/100.0f,
                // rotation 0, color 100, alpha 0, blend 0x20, colorMul 0xffffff, clip, prio 0xb, p19 1.
                drawAepFrameEx(&aep, frm, m_laneFrm[n.lane], m_noteFieldY,
                               0x42c80000, 0x42c80000, 0, 0, 0,
                               100, 0, 0x20, 0xffffff, clip, 0xb, 1);
            }
        }
    }

    // Running judged total -> the combo readout (@ +0x102).
    m_judgeTotal = (int16_t)note.getJudgeTotal();

    // The time-line marker sweeps left->right across the song: x = barWidth * pos / total.
    const int total = 0x16ebd8;   // DAT_0016ebd8 (chart length denominator)
    const int barW = m_barWidth;
    const int cur = note.getCurrentPosition();
    int lineClip[4] = { m_timeLineX, m_timeLineY,
                        (total ? barW * cur / total : 0), m_screenHeight };
    drawAepFrameEx(&aep, m_timeLineFrm, m_timeLineX, m_timeLineY,
                   0x42c80000, 0x42c80000, 0, 0, 0, 100, 0, 0x20, 0xffffff, lineClip, 0xc, 1);
}

// ===========================================================================
// drawLifeGauge — Ghidra drawLifeGauge (FUN_00023000). Blit the 24-cell life gauge:
// each cell shows its empty frame, and cells below the current fill level show the lit
// frame nudged in by 2px (phone) / 4px (pad). The fill level is (base+combo)*0x18/0x400.
// ===========================================================================
void AcViewerTask::drawLifeGauge() {
    AepManager &aep = AepManager::shared();

    int value = (int)m_gaugeBase + (int)m_gaugeValue;
    if (value < 0) { value = 0; }
    // lit = value * 24 / 1024, clamped to [0, 24].
    int lit = value < 0x3ff ? (value * 0x18) / 0x400 : 0x18;
    if (lit < 0) { lit = 0; }
    if (lit > 0x17) { lit = 0x18; }

    const bool pad = (m_padDisplay != 0);
    const int nudge = pad ? 4 : 2;

    for (int cell = 0; cell < 0x18; cell++) {
        // Cells 0..15 use the "01" (lower) set, 16..23 use the "02" (upper) set.
        const bool lower = cell < 0x10;
        const int emptyFrm = lower ? m_gaugeEmpty02Frm : m_gaugeEmpty01Frm;  // GAUGE_OUT_01/02
        const int x = m_gaugeStrideX * cell + m_gaugeBaseX;
        const int y = lower ? m_gaugeLowerY : m_gaugeUpperY;
        drawAepFrameEx(&aep, emptyFrm, x, y, 0x42c80000, 0x42c80000,
                       0, 0, 0, 100, 0, 0x20, 0xffffff, nullptr, 0xd, 1);

        if (cell < lit) {
            const int litFrm = lower ? m_gaugeLit02Frm : m_gaugeLit01Frm;  // GAUGE_02/01 lit
            drawAepFrameEx(&aep, litFrm, x + nudge, y + nudge, 0x42c80000, 0x42c80000,
                           0, 0, 0, 100, 0, 0x20, 0xffffff, nullptr, 0xc, 1);
        }
    }
}

// ===========================================================================
// cleanup — Ghidra AcMainTask::Cleanup (@ 0x22b44). Free the arcade-viewer play
// resources and wipe the play-data region so a later attempt starts clean. Called from
// update() state 9 once the fade-out has completed. Every field below is a named member
// of the play-data block (each at its binary-exact offset), matching the setup()/loadChart()
// idiom; the freed sub-objects were all allocated in setup().
//
// The only field that survives the wipe is the pad "board up" byte (@ +0x1d9): it is
// saved before the memset and restored afterwards, but only on the pad display.
// ===========================================================================
void AcViewerTask::cleanup() {
    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];

    // The play-state sub-task (@ +0x28, the first word of the play-data block): delete it
    // through its virtual destructor. (Modelled as a C_TASK sub-object; the exact subclass
    // is not recovered here — the vtbl-slot-1 deleting-destructor confirms it is deleted.)
    if (C_TASK *stateTask = m_stateTask) {
        delete stateTask;
        m_stateTask = nullptr;
    }

    // The 10 HUD digit textures (@ +0x2c[10], allocated in setup()).
    for (int i = 0; i < 10; i++) {
        if (neTextureForiOS *tex = m_digitTex[i]) {
            delete tex;
            m_digitTex[i] = nullptr;
        }
    }

    // The two AepLyrCtrl overlays (@ +0x54 PAUSE_LOOP, +0x58 top banner): unlink from the
    // Aep layer list, then delete.
    if (AepLyrCtrl *pauseLayer = m_pauseLayer) {
        pauseLayer->unlink();
        delete pauseLayer;
        m_pauseLayer = nullptr;
    }
    if (AepLyrCtrl *topLayer = m_topLayer) {
        topLayer->unlink();
        delete topLayer;
        m_topLayer = nullptr;
    }

    // Free the group-7 arcade_viewer Aep textures. Ghidra: releaseAepTexture(aep, 7).
    aep.unloadGroup(kAcvGroup);

    // Release the cached sheet + song-title strong refs (ARC: __bridge_transfer balances
    // the +1 retains loadChart() took at +0x1e0 / +0x1e4, then nil the ivars).
    if (m_sheet) {
        (void)(__bridge_transfer id)m_sheet;   // sheet NSData
        m_sheet = nullptr;
    }
    if (m_songTitle) {
        (void)(__bridge_transfer id)m_songTitle;   // song-title NSString
        m_songTitle = nullptr;
    }

    // Stop + release the arcade timing SE (source id @ +0xd4) and the song BGM.
    [audio stopSe:m_readySeId];
    [audio releaseSe:nil resourceId:m_readySeId];
    [audio releaseBgm];

    // Release the arcade option-sheet controller (@ +0x208, ARC: __bridge_transfer + nil).
    if (m_optionVC) {
        (void)(__bridge_transfer id)m_optionVC;
        m_optionVC = nullptr;
    }

    // Wipe the whole play-data region (@ +0x28..+0x20b, up to state @ +0x20c). Preserve
    // the pad "board up" byte (@ +0x1d9) across the wipe, but only on the pad display
    // (Ghidra: g_bIsPadDisplay after NESceneManager_shared()).
    const unsigned char boardUp = m_padBoardUp;
    memset(reinterpret_cast<char *>(this) + 0x28, 0, 0x1e4);
    if (neSceneManager::isPadDisplay()) {
        m_padBoardUp = boardUp;
    }
}

// ===========================================================================
// update — Ghidra acMainTaskUpdate (FUN_00021678). Per-frame: snapshot touch (drag
// anchor / flick), then run the play-state machine (@ +0x20c). While playing (state 6)
// it drives AcNoteMng and the note/gauge draw passes.
// ===========================================================================
//
// OFFSET NOTE: Ghidra models update()'s object through a nested struct field10 at +0x28,
// so its "fieldNN_0xMM" accessors are RELATIVE to +0x28. setup()/loadChart()/the draw +
// HUD passes use flat absolute offsets. This reconstruction uses absolute offsets
// throughout, so the play-flags Ghidra shows as field65_0x1ac..+3 are +0x1d4..+0x1d7
// here (confirmed: setup() writes the HUD-ready byte at absolute +0x1d4, drawActiveNotes
// reads the mute flags at +0x1d6/+0x1d7). Key resolved fields:
//   +0x1d4 HUD ready   +0x1d5 HUD armed   +0x1d6 paused   +0x1d7 pause-menu open
//   +0x1d8 pad display +0x1d9 pad board up +0xd4 ready-SE id +0xd8 ready-SE instance
//   +0xfc pause-time snapshot +0x204 end-hold frame counter +0x10c screen scale.
//
void AcViewerTask::update(int /*deltaMs*/) {
    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];
    AcNoteMng &note = AcNoteMng::shared();
    neGraphics &gfx = neGraphics::shared();

    m_moved = 0;   // per-frame "moved" flag (field17_0xd0; recomputed)

    // --- Touch preamble (Ghidra: the drag/flick classifier at 0x216f6..0x21880). While
    // the HUD is up (ready byte @ +0x1d4) it latches a drag anchor on a held touch, or
    // resolves a flick on a released touch. The scaled-coordinate NEON math (FixedToFP /
    // screen-scale divide @ +0x10c / FloatVectorSub) is decompiler-obscured; reconstructed
    // best-effort as a boolean "flick this frame".
    bool flick = false;
    int flickX = 0, flickY = 0;
    if (m_hudReady != 0) {
        const int n = gfx.activeTouchCount();
        for (int i = 0; i < n; i++) {
            const neTouchPoint *t = gfx.touchAt(i);
            if (t == nullptr) { continue; }
            if (t->released != 0) {
                flick = true;
                // +0x10c holds the UI-scale word; the touch classifier reads it as a float
                // divisor (same bytes setup() wrote as g_dwUiScale).
                const float scale = reinterpret_cast<float &>(m_uiScale);
                flickX = (int)((float)t->x / scale);
                flickY = (int)((float)t->y / scale);
                break;
            }
        }
    }

    int next;
    switch (m_state) {
    case 0:
        // Enter the arcade viewer nav screen (and, on pad, insert the black board), then
        // register this task on the AppDelegate.
        [AcvRootVC() GotoAcViewer];
        if (neSceneManager::isPadDisplay() && m_padBoardUp == 0) {
            [AcvRootVC() InsertBlackBoard];
        }
        [[AppDelegate appDelegate] setAcMainTask:this];
        next = 1;
        break;
    case 1:
        // Wait for a valid song id (set when the viewer picks a song).
        next = (neAppEventCenter::acViewerMusicId() < 0) ? 0x10 : 2;
        break;
    case 2:
        setup();
        m_state = 3;
        [[fallthrough]];
    case 3:
        // Fade the HUD in and play the top banner.
        aep.playTransition(1, 0, 0);   // setAepTransitionMode(aep, 1)
        m_topLayer->play();
        m_state = 4;
        [[fallthrough]];
    case 4:
        if (m_hudArmed == 0 || !aep.isTransitionDone()) {
            break;   // still transitioning
        }
        // On phone (or once the pad board is up) fire the ready SE, then advance.
        if (!neSceneManager::isPadDisplay() || m_padBoardUp != 0) {
            m_readySeInst = (int)[[AudioManager sharedManager] playSe:0 resourceId:m_readySeId];
        }
        next = 5;
        break;
    case 5:
        // When the ready SE finishes, start note playback.
        if ([AcvRootVC() isPlayingSe:m_readySeInst] == 0) {
            note.startPlayback();
            m_state = 6;
        }
        if (neSceneManager::isPadDisplay()) {
            [AcvRootVC() FadeOutBlackBoard];
        }
        break;
    case 6: {   // *** PLAYING ***
        if (neSceneManager::isPadDisplay() && [AcvRootVC() acMusicSelViewing] == 1) {
            next = 10;
            break;
        }
        note.update();
        // DAT_00173e70 is the engine's global "chart finished" flag (raised when the type-6
        // end marker is reached). On finish, reset the end-hold counter (@ +0x204) and go to
        // the end-hold state; otherwise a flick over the note field opens the song-select.
        if (g_bAcNoteFinished) {
            m_endHoldCounter = 0;
            next = 7;
        } else if (flick && [AcvRootVC() acMusicSelViewing]) {
            next = 10;
        } else {
            break;
        }
        break;
    }
    case 7: {
        // End-of-song hold: after ~30 frames, pause + snapshot and go to the pause state.
        int t = m_endHoldCounter;
        if (t > 0x1e) {
            note.pause();
            m_pauseTime = note.getCurrentPosition();
            m_paused = 1;
            m_state = 0xc;
            t = m_endHoldCounter;
        }
        m_endHoldCounter = t + 1;
        break;
    }
    case 8:
        // Teardown transition out.
        note.resetPlayFlag();
        aep.playTransition(2, 0, 0);   // setAepTransitionMode(aep, 2)
        next = 9;
        break;
    case 9:
        if (aep.isTransitionDone()) {
            cleanup();   // AcMainTask::Cleanup — free HUD/textures/AcNoteMng
            next = 0;
        } else {
            return;
        }
        break;
    case 10:
        // Song-select viewing: pause + snapshot, then wait to resume.
        note.pause();
        m_pauseTime = note.getCurrentPosition();
        m_paused = 1;
        next = 0xb;
        break;
    case 0xb:
        // Resume once the viewer is no longer showing the song-select.
        if (neSceneManager::isPadDisplay() && m_paused != 0) {
            note.resume();
            m_paused = 0;
            m_state = 6;
        }
        break;
    case 0xc:
        // Pause menu: freeze play (if not already), play the pause overlay (phone) or the
        // black board (pad), and wait for the resume/quit tap.
        if (m_paused == 0) {
            note.pause();
            m_pauseTime = note.getCurrentPosition();
        }
        m_pauseMenuOpen = 1;
        if (!neSceneManager::isPadDisplay()) {
            m_pauseLayer->play();
        } else {
            [AcvRootVC() GotoAcViewer];
        }
        next = 0xd;
        break;
    case 0xd:
        // Wait in the pause menu (resume / retry / quit hit-testing lives here; the
        // per-button rect math is best-effort). On resume, restart the note engine.
        if (flick) {
            m_pauseLayer->reset();
            m_pauseMenuOpen = 0;
            note.resume();
            m_paused = 0;
            m_state = 6;
        }
        return;
    case 0xe: {
        // Open the arcade option sheet (hi-speed / pop-kun / hid-sud / ran-mir). Release any
        // previous controller (@ +0x208), build a fresh AcViewerOptionViewController bound to
        // this task, fire the open SE + animation, and resume the nav loop.
        if (m_optionVC) {
            (void)(__bridge_transfer id)m_optionVC;
            m_optionVC = nullptr;
        }
        id optVC = [[AcViewerOptionViewController alloc] initForAcMain:this];
        m_optionVC = (__bridge_retained void *)optVC;
        [optVC startOpenAnimationForAcMain];
        [AcvRootVC() ResumeLoop];
        next = 0xf;
        break;
    }
    case 0x10:
        // No song selected: fade the pad board, clear the AppDelegate task and hand back to
        // the mode menu.
        if (neSceneManager::isPadDisplay()) {
            [AcvRootVC() FadeOutBlackBoard];
        }
        [[AppDelegate appDelegate] setAcMainTask:nil];
        m_padBoardUp = 0;
        kill();   // +0x24 = 1
        {
            MenuMainTask *menu = new MenuMainTask();
            menu->setPriority(3);
        }
        m_state = 0x11;
        return;
    default:
        break;
    }
    m_state = next;

    // Draw tail: update+draw all Aep layers, then (once the HUD is up and armed) the
    // note field and life gauge.
    (void)audio;
    updateAndDrawAepLayers(0);
    if (m_hudArmed != 0 && m_hudReady != 0) {
        drawActiveNotes();
        drawLifeGauge();
    }
    (void)flickX; (void)flickY;
}

// ===========================================================================
// AcViewerHudDraw — Ghidra aepHudDrawCallback. @ 0x23358. The group-7 per-layer user-draw
// callback: dispatch on the layer's user number (resolved into +0xb8..+0xd0) and blit that
// HUD element (music title, combo/score/gauge digit runs, COOL/GREAT).
// ===========================================================================
void AcViewerHudDraw(int child, int frame, int x, int y, int scaleX, int scaleY,
                     int anchorX, int anchorY, int color, int alpha, int16_t rotation,
                     int blend, int *p13, int p14, void *context) {
    (void)frame;
    AepManager &aep = AepManager::shared();
    AcViewerTask *self = static_cast<AcViewerTask *>(context);

    // Digit-run blitter shared by the count cases: draw `n` digits of `val` right-to-left
    // from the m_digitTex[] set, advancing x by -m_digitAdvance each step.
    auto drawDigits = [&](int val, int n) {
        int cx = x;
        for (int k = 0; k < n; k++) {
            neTextureForiOS_draw(&aep, self->m_digitTex[val % 10],
                                 0, 0, self->m_digitScaleX, self->m_digitScaleY, cx, y,
                                 scaleX, scaleY, rotation, anchorX, anchorY, color, alpha,
                                 blend, 0xffffff, 0, p14, 1);
            cx -= self->m_digitAdvance;
            val /= 10;
        }
    };

    if (self->m_usrNo[0] == child) {
        // SCORE layer -> the difficulty bar frame (@ +0x84) at the scaled anchor.
        drawAepFrameEx(&aep, self->m_barFrm, x, y, scaleX, scaleY, rotation, anchorX, anchorY,
                       color, alpha, blend, 0xffffff, p13, 0xe, 1);
    } else if (self->m_usrNo[1] == child) {
        // COMBO layer -> cache the combo-digit screen origin (@ +0x1ec/+0x1f0) for
        // drawActiveNotes, then draw the MUSIC_ON / MUSIC_OFF marker per the mute flag.
        self->m_comboDigitY = y - (anchorY * scaleY) / 100;
        const int dy = self->m_padDisplay == 0 ? -0xc : -0x18;   // phone vs pad offset
        self->m_comboDigitX = (x - (anchorX * scaleX) / 100) + dy;
        const int frm = self->m_paused == 0 ? self->m_musicOffFrm : self->m_musicOnFrm;
        drawAepFrameEx(&aep, frm, x, y, scaleX, scaleY, rotation, anchorX, anchorY,
                       color, alpha, blend, 0xffffff, p13, 0xe, 1);
    } else if (self->m_usrNo[2] == child) {
        // MUSIC_NAME layer -> blit the cached song-title string (@ +0x1e4) at the HUD
        // baseline (Ghidra: aepManagerReset_a text blit with size @ +0x1e8, y bias @ +0x1c4).
        NSString *title = (__bridge NSString *)self->m_songTitle;
        AepDrawText(&aep, title.UTF8String, self->m_titleXAdvance, x, y + self->m_titleBaselineY,
                    1, 100, 0xffffff, 0xe);
    } else if (self->m_usrNo[5] == child) {
        // COOL count layer -> 3 digits from the engine's COOL counter (DAT_0016ebe0).
        AcNoteMng::shared();
        drawDigits((int)g_dwAcCoolCount, 3);
    } else if (self->m_usrNo[6] == child) {
        // GREAT count layer -> 2 digits from the GREAT counter (DAT_0016ebe4).
        AcNoteMng::shared();
        drawDigits((int)g_dwAcGreatCount, 2);
    } else if (self->m_usrNo[4] == child) {
        // Note-count layer -> 4 digits of the total note count (@ +0x100).
        drawDigits((int)self->m_totalNoteCount, 4);
    } else if (self->m_usrNo[3] == child) {
        // Judged-total layer -> 4 digits of the running judge total (@ +0x102).
        drawDigits((int)self->m_judgeTotal, 4);
    }
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
