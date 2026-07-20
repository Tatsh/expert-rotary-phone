//
//  AcViewerTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The
//  arcade-viewer note-play task: it loads the chosen ac chart into AcNoteMng,
//  builds the group-7 "arcade_viewer" HUD, runs the touch/flick play-state
//  machine and, while playing, drives AcNoteMng plus the note / life-gauge /
//  HUD-digit draw passes.
//
//  See AcViewerTask.h for the naming note (Ghidra labels these acMainTask*;
//  this is a distinct class from the repo's sugoroku AcMainTask). Play-data is
//  reached through the named members declared in AcViewerTask.h (each at its
//  binary-exact offset, cited there).
//

#import "AcViewerTask.h"

#include <cmath>
#include <cstring>
#include <new>

#import "AcMusicData.h"
#import "AcNoteMng.h"
#import "AcViewerOptionViewController.h"
#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "MainViewController.h"
#import "MenuMainTask.h"
#import "MusicManager.h"
#import "UserSettingData.h"
#import "neDebugLog.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

// Group-7 asset slot for the arcade viewer HUD.
constexpr int kAcvGroup = 7;

// The root nav host the play machine drives (GotoAcViewer / black-board
// overlay).
static MainViewController *AcvRootVC() {
    return static_cast<MainViewController *>(neSceneManager::rootViewController());
}

// ===========================================================================
// Construction / teardown
// ===========================================================================

// Constructed by the engine (ctor/vtable @ 0x130bb8, not in this batch). The
// ne::C_TASK base + the zeroed play-data blob (m_playData) are all the ctor needs
// here.
AcViewerTask::AcViewerTask() = default;

// @ 0x215d8 — task_delete is the compiler's deleting-destructor thunk
// (caSourceNode_dtor then operator delete). The real destructor body only
// chains to the ne::C_TASK base: this task frees its HUD/textures/layers +
// AcNoteMng in cleanup() (state 9), so there is no per-member teardown here.
// ~ne::C_TASK() (caSourceNode_dtor) runs implicitly after this.
AcViewerTask::~AcViewerTask() = default;

// ===========================================================================
// setup — Ghidra acMainTaskSetup (FUN_0002230c). Resolve the HUD handles, load
// the chart + BGM/SE, build the two AepLyrCtrl overlays, load the digit
// textures and register the per-layer HUD draw callback. Runs once (state 2 ->
// 3).
//
// DEVIATION: right after building the top layer (Ghidra
// 0x228a6..0x228bc), the binary also writes two fields on the PAUSE_LOOP layer
// object -- pauseLayer[+0x18] = 0 and pauseLayer[+0x1c] = m_pauseBtnHeight / 2 --
// which this reconstruction does not model, because those are internal AepLyrCtrl
// fields the class abstracts. Everything else here is instruction-faithful.
// ===========================================================================

// getUserNo layer-name table (Ghidra: DAT_00130bc4, 7 names) -> +0xb8. These
// are the HUD layers AcViewerHudDraw dispatches on (score / combo / title /
// gauge digits).
constexpr const char *const kAcvUsrNames[7] = {
    "SCORE_NUM", "COMBO_NUM", "MUSIC_NAME", "MAX_COMBO_NUM", "GAUGE_NUM", "COOL_NUM", "GREAT_NUM"};
// getFrmNo names (Ghidra: DAT_00130bf0, 9) -> +0x94.
constexpr const char *const kAcvFrmNames[9] = {
    "NUM_00", "NUM_01", "NUM_02", "NUM_03", "NUM_04", "NUM_05", "NUM_06", "NUM_07", "NUM_08"};
// Difficulty -> BAR_* time-line frame (Ghidra: PTR_s_BAR_EASY_00130be0).
constexpr const char *const kAcvBarFrm[4] = {"BAR_EASY", "BAR_NORMAL", "BAR_HYPER", "BAR_EX"};

void AcViewerTask::setup() {
    AepManager &aep = AepManager::shared();
    AcNoteMng &note = AcNoteMng::shared();
    AppDelegate *app = [AppDelegate appDelegate];

    m_screenWidth = aep.screenWidth();   // aepGetScreenWidth
    m_screenHeight = aep.screenHeight(); // aepGetScreenHeight
    // g_uiScale is the UI scale (screenScale * 0.5) published by
    // MainViewController::loadView; compute the same value directly here,
    // matching MainTask/PlayTask.
    m_uiScale = neSceneManager::screenScale() * 0.5f;
    m_comboDigitX = -1; // HUD combo digit screen x (HUD writes it)
    m_comboDigitY = -1; // HUD combo digit screen y

    // Player options snapshot.
    m_hiSpeed = [UserSettingData acvHiSpeed]; // +500
    m_popKun = [UserSettingData acvPopKun];
    m_hidSud = [UserSettingData acvHidSud];
    m_ranMir = [UserSettingData acvRanMir];
    m_difficulty = static_cast<int>(static_cast<short>(neAppEventCenter::acViewerDifficulty()));
    m_padDisplay = neSceneManager::isPadDisplay();

    // Lane remap for the RAN/MIR option, then load + init the chart.
    note.setupLaneMapping(m_ranMir);
    loadChart(); // FUN_0002316c

    // Total note count + the initial gauge value (0x100 == full at 256/1024
    // scale).
    m_totalNoteCount = static_cast<int16_t>(note.getTotalNoteCount());
    m_gaugeValue = 0x100;

    // Per-lane scroll-speed table (@ +0x1cc[4]). Each entry is a packed
    // (numerator, denominator) pair; the numerator is taken to 1024x fixed point
    // (<< 10) and divided by a per-lane denominator. The two low lanes use a
    // fixed negative rate; the two high lanes scale inversely with the chart's
    // note count and are floored at 1. Table @ DAT_0012e350.
    static constexpr int kScrollSpeedTable[4][2] = {{3, 2}, {1, 2}, {9, 6}, {18, 6}};
    for (int i = 0; i < 4; i++) {
        const int numerator = kScrollSpeedTable[i][0] << 10;
        const int denominator = kScrollSpeedTable[i][1];
        int16_t speed;
        if (i < 2) {
            // Fixed rate: numerator / (denominator * 30), negated.
            speed = static_cast<int16_t>(-(numerator / (denominator * 30)));
        } else {
            // Inversely proportional to the note count, floored at 1.
            const int16_t scaled =
                static_cast<int16_t>(numerator / (denominator * m_totalNoteCount));
            speed = scaled <= 1 ? 1 : scaled;
        }
        m_scrollSpeed[i] = speed;
    }

    // Load the "TIMING" arcade SE and the group-7 viewer Aep data.
    AudioManager *audio = [AudioManager sharedManager];
    NSString *sePath = [[NSBundle mainBundle] pathForResource:@"v12" ofType:@"m4a"];
    m_readySeId = static_cast<int>([audio loadSe:sePath isLoop:NO callName:nil group:1]);

    const bool pad = m_padDisplay;
    aep.loadAepDataDefaultPath(kAcvGroup, pad ? "arcade_viewer_ipad" : "arcade_viewer");

    // Two AepLyrCtrl overlays: the PAUSE_LOOP layer (+0x54) and the top banner
    // (+0x58, device-picked "TOP_960" / "TOP_1136" / "TOP_IPAD").
    AepLyrCtrl *pauseLayer = new AepLyrCtrl();
    m_pauseLayer = pauseLayer;
    pauseLayer->init(kAcvGroup, "PAUSE_LOOP", this, 9); // draw order 9

    const char *topName = "TOP_960";
    if (pad) {
        topName = "TOP_IPAD";
    } else if ([app displayType] == DisplayTypePhoneRetinaTall) {
        topName = "TOP_1136";
    }

    // Device-branched HUD layout constants (@ +0x110..+0x1c0) plus the per-lane
    // note-frame x table (@ +0x158[9]), written before the top layer is built.
    // There are three form factors: iPad (pad), tall iPhone (displayType == DisplayTypePhoneRetinaTall,
    // the 1136 screen), and the normal 960 iPhone. The per-lane note-frame
    // tables are DAT_0012e370 (phone) / DAT_0012e394 (pad).
    static constexpr int kLaneFrmPhone[9] = {78, 138, 199, 260, 320, 381, 441, 502, 561};
    static constexpr int kLaneFrmPad[9] = {284, 405, 526, 647, 768, 889, 1010, 1132, 1250};
    if (pad) {
        m_pauseBtnTopY = 0;
        m_pauseBtnHeight = -176;
        m_seekScale = 3;
        m_xScrubScale = 1;
        m_noteClipTop = 456;
        m_noteFieldY = 1154;
        m_seekGaugeSplitY = 1760;
        m_scrubZoneTopY = 336;
        m_effectNoteWidth = 128;
        m_effectNoteInsetY = 96;
        m_effectNoteHeight = 32;
        m_effectSpriteWidth = 124;
        m_effectSpriteInsetX = 16;
        m_coolLayerArgA = 132;
        m_coolLayerArgB = 116;
        m_playTouchW = 210;
        m_playTouchH = 230;
        m_gaugeLowerY = 1866;
        m_gaugeUpperY = 1842;
        m_gaugeBaseX = 192;
        m_gaugeStrideX = 48;
        m_timeLineX = 228;
        m_timeLineY = 1784;
        m_barWidth = 1078;
        m_digitScaleX = 60;
        m_digitScaleY = 72;
        m_digitAdvance = 48;
        m_pauseBtnY[0] = 806;
        m_pauseBtnY[1] = 1398;
        m_pauseBtnY[2] = 1096;
        m_pauseBtnRowH = 188;
        m_exitTouchX = 1028;
        m_exitTouchY = 160;
        m_exitTouchW = 340;
        m_exitTouchH = 136;
        for (int i = 0; i < 9; i++) {
            m_laneFrm[i] = kLaneFrmPad[i];
        }
    } else {
        const bool tall = ([app displayType] == DisplayTypePhoneRetinaTall); // 1136 screen vs 960
        m_pauseBtnTopY = tall ? 88 : 0;
        m_pauseBtnHeight = tall ? 0 : -176;
        m_seekScale = 5;
        m_xScrubScale = 2;
        m_noteClipTop = tall ? 286 : 198;
        m_noteFieldY = 574;
        m_seekGaugeSplitY = tall ? 912 : 822;
        m_scrubZoneTopY = tall ? 134 : 132;
        m_effectNoteWidth = 64;
        m_effectNoteInsetY = 48;
        m_effectNoteHeight = 16;
        m_effectSpriteWidth = 62;
        m_effectSpriteInsetX = 8;
        m_coolLayerArgA = 66;
        m_coolLayerArgB = 58;
        m_playTouchW = 105;
        m_playTouchH = 115;
        m_gaugeLowerY = tall ? 899 : 897;
        m_gaugeUpperY = tall ? 887 : 885;
        m_gaugeBaseX = 31;
        m_gaugeStrideX = 24;
        m_timeLineX = 50;
        m_timeLineY = tall ? 861 : 859;
        m_barWidth = 539;
        m_digitScaleX = 32;
        m_digitScaleY = 36;
        m_digitAdvance = 22;
        m_pauseBtnY[0] = 404;
        m_pauseBtnY[1] = 774;
        m_pauseBtnY[2] = 584;
        m_pauseBtnRowH = 94;
        m_exitTouchX = 425;
        m_exitTouchY = tall ? 18 : 16;
        m_exitTouchW = tall ? 134 : 132;
        m_exitTouchH = 115;
        for (int i = 0; i < 9; i++) {
            m_laneFrm[i] = kLaneFrmPhone[i];
        }
    }
    // m_noteFieldX (+0x124) = m_noteClipTop (+0x120) + m_noteFieldY (+0x128).
    m_noteFieldX = m_noteClipTop + m_noteFieldY;

    AepLyrCtrl *topLayer = new AepLyrCtrl();
    m_topLayer = topLayer;
    topLayer->init(kAcvGroup, topName, this, 15); // draw order 15

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

    // 10 HUD digit textures (@ +0x2c[10]) from the bundle (device-picked
    // "ticket_num%d" / "num_pointb_%d" name tables PTR_cf_ticket_num0 /
    // PTR_cf_num_pointb_0).
    NSBundle *bundle = [NSBundle mainBundle];
    for (int i = 0; i < 10; i++) {
        neTextureForiOS *tex = new neTextureForiOS();
        m_digitTex[i] = tex;
        NSString *name = pad ? [NSString stringWithFormat:@"num_pointb_%d", i] :
                               [NSString stringWithFormat:@"ticket_num%d", i];
        tex->load([[bundle pathForResource:name ofType:@"png"] UTF8String]);
    }

    // Register the per-layer HUD draw callback (Ghidra: setAepCallbacks(aep, 7,
    // 0x23359, this) — 0x23359 is &AcViewerTask::AcViewerHudDraw in Thumb). Its signature
    // matches AepGroupDrawFn exactly so no reinterpret_cast is needed. A previous
    // int16_t rotation (param 11) was NOT ABI-compatible: params 9+ are passed on
    // the stack on arm64, so a 2-byte rotation shifted every following slot and
    // corrupted `context`, crashing the callback on a garbage `this`.
    aep.setGroupDrawCallback(kAcvGroup, &AcViewerTask::AcViewerHudDraw, this);
    m_hudReady = true; // HUD ready
}

// ===========================================================================
// loadChart — Ghidra loadChartData (FUN_0002316c). Fetch the AcMusicData for
// the selected song, async-load its BGM, pick the sheet by difficulty and hand
// it to AcNoteMng::initPlayData.
// ===========================================================================
void AcViewerTask::loadChart() {
    AudioManager *audio = [AudioManager sharedManager];
    AcNoteMng &note = AcNoteMng::shared();

    AcMusicData *acMusic =
        [[MusicManager getInstance] getAcMusicData:neAppEventCenter::acViewerMusicId()];

    // Cache the display music name (+0x1e4, +1 retained); its length picks the
    // HUD title offsets (+0x1e8 x-advance / +0x1c4 baseline).
    if (m_songTitle) {
        static_cast<void>((__bridge_transfer id)m_songTitle);
        m_songTitle = nullptr;
    }
    NSString *name = [acMusic musicName];
    m_songTitle = (__bridge_retained void *)name;

    const bool pad = m_padDisplay;
    if (name.length < 0x14) {
        m_titleXAdvance = pad ? 0x2a : 0x1c;
        m_titleBaselineY = pad ? -34 : -20; // 0xffffffde / 0xffffffec
    } else {
        m_titleXAdvance = pad ? 0x18 : 0x10;
        m_titleBaselineY = pad ? -20 : -12; // 0xffffffec / 0xfffffff4
    }

    [audio stopBgm:0.0f]; // FUN_0002316c: stopBgm:(SEL)0x0 -> fadeSeconds 0.0
                          // (immediate)
    // Ghidra: the async BGM load is a dispatch_async(^{...}) block (@ 0x237bc)
    // posted to the global queue; it streams the song's BGM in the background
    // while play sets up. The block (disasm 0x237bc): getBackTrack:m_difficulty
    // (r2 <- [self + 0x1dc]) -> loadBgmData:isLoop:NO (r3 == 0) -> playBgm:1.0f
    // (r2 == 0x3f800000 at 0x237f6), then sets the bgm-ready flag (+0x1d5).
    const int difficulty = m_difficulty;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      NSData *track = [acMusic getBackTrack:difficulty];
      [audio loadBgmData:track isLoop:NO];
      [audio playBgm:1.0f];
      m_hudArmed = true; // +0x1d5 (strb 1 at block tail)
    });

    // Release the previous sheet, pick the new one by difficulty (0 easy / 1
    // normal / 2 hyper / 3 ex), retain it, and init the note timeline at the
    // chosen hi-speed.
    if (m_sheet) {
        static_cast<void>((__bridge_transfer id)m_sheet);
        m_sheet = nullptr;
    }
    NSData *sheet;
    switch (m_difficulty) {
    case 0:
        sheet = [acMusic sheetEasy];
        break;
    case 2:
        sheet = [acMusic sheetHyper];
        break;
    case 3:
        sheet = [acMusic sheetEx];
        break;
    default:
        sheet = [acMusic sheetNormal];
        break;
    }
    m_sheet = (__bridge_retained void *)sheet;
    note.initPlayDataWithData(sheet, m_hiSpeed);
}

// ===========================================================================
// drawActiveNotes — Ghidra drawActiveNotes (FUN_00022cac). Blit each in-flight
// note at its lane/scroll position, count the ones that reached the judge line
// into the combo/gauge, then blit the moving time-line marker.
//
// DEVIATION: two mismatches against the binary remain.
//   1. Approaching-note sprite: the binary branches on the POP-KUN option
//      (m_popKun @ +0x1f8, Ghidra 0x22ea0..0x22eca) and blits a different
//      sprite/frame table when POP-KUN is on; this reconstruction always uses the
//      BEAT_POPN_WHITE/BLUE frames regardless, so the POP-KUN draw path is not
//      reconstructed.
//   2. Time-line denominator: the binary reads the runtime global at 0x16ebd8
//      (ldr [.., #0xfa28], Ghidra 0x22f80) for `total`; the reconstruction instead
//      uses the literal 0x16ebd8 (the address, not its contents), which is wrong --
//      `total` should be the value of that global (a zero-initialised engine
//      variable set during play).
// ===========================================================================
void AcViewerTask::drawActiveNotes() {
    AepManager &aep = AepManager::shared();
    AcNoteMng &note = AcNoteMng::shared();

    const int count = note.countActiveNotes();
    const uint32_t now = static_cast<uint32_t>(note.getCurrentPosition());

    int clip[4] = {0, m_noteClipTop, m_screenWidth, m_screenHeight};

    for (int i = 0; i < count; i++) {
        AcNoteObject n;
        note.getNoteObject(&n, i);
        const int laneFrame = m_laneFrm[n.lane];

        // The note's on-screen Y is a linear function of its scroll position
        // (Ghidra 0x22d94..0x22e0e / 0x22eda..0x22f3c): base m_noteFieldX, plus
        // m_noteFieldY * drawY scaled by DAT_00022ff8 = -1/1024, minus half the
        // effect-note height to centre the sprite.
        const int noteY =
            static_cast<int>(static_cast<float>(m_noteFieldX) +
                             static_cast<float>(m_noteFieldY) * n.drawY * (-1.0f / 1024.0f) -
                             static_cast<float>(m_effectNoteHeight / 2));

        if (n.tick < now) {
            // Note has passed the spawn point: scroll it toward the judge line. The
            // frame steps at DAT_00022ffc = 1/16 of the elapsed ticks, +0.5 bias
            // (Ghidra 0x22d70..0x22d8a). While still within the layer's frame count
            // it is drawn as the EFFECT_COOL layer.
            const int frame = static_cast<int>(static_cast<float>(now - n.tick) * 0.0625f + 0.5f);
            if (frame < m_effectCoolFrames) {
                // drawLayer args (0xfd64 callee map): x = per-lane note frame
                // (@+0x158[lane]), y = the scroll-derived noteY; scale 100/100,
                // anchorX = m_coolLayerArgB, anchorY = 100, color=0, colorHi=1,
                // loopFlags = m_coolLayerArgA, blend=0x200, colorRGB=0xffffff,
                // clip={0,top,w,h}, ctx=null, priority=0xb, visFlag=1.
                aep.drawLayer(m_effectCoolLyrNo,
                              frame,
                              laneFrame,
                              noteY,
                              100,
                              100,
                              0,
                              m_coolLayerArgB,
                              100,
                              0,
                              1,
                              m_coolLayerArgA,
                              0x200,
                              0xffffff,
                              clip,
                              nullptr,
                              0xb,
                              1);
                // First time a note crosses the line (and not in HID/SUD hidden state),
                // add to the combo counter (@ +0x1ca, saturated to 0x3ff) and mark the
                // note handled (bit 6). Ghidra: +0x1d2 combo step / acNoteSetNoteFlag.
                if (!m_paused && !m_pauseMenuOpen && (n.flags & 0x40) == 0) {
                    int c = static_cast<int>(m_scrollSpeed[3]) + static_cast<int>(m_gaugeValue);
                    if (c < 0) {
                        c = 0;
                    }
                    if (c > 0x3ff) {
                        c = 0x3ff;
                    }
                    m_gaugeValue = static_cast<int16_t>(c);
                    note.setNoteFlag(i, 0x40);
                }
            }
        } else {
            // Note still approaching: pick the POPN white/blue sprite and blit it at
            // its scroll-derived (lane x, noteY). The HID/SUD option hides notes
            // outside the visible band by scroll position: HID (m_hidSud bit 0) hides
            // notes whose drawY is below 192, SUD (m_hidSud bit 1) above 337 (Ghidra
            // 0x22e70..0x22e9e; DAT_00022ff0/ff4 = 192.0/337.0).
            bool hidden = false;
            if (((m_hidSud | 2) == 3) && n.drawY < 192.0f) {
                hidden = true;
            }
            if (((m_hidSud & ~1) == 2) && n.drawY > 337.0f) {
                hidden = true;
            }
            if (!hidden) {
                const int frm = (n.lane & 1) ? m_beatBlueFrm : m_beatWhiteFrm; // blue / white
                // drawAepFrameEx (AepDrawSpriteHandle takes an int percentage scale,
                // so 100, not the 0x42c80000 float bits the binary pushes): x =
                // per-lane frame, y = noteY, scale 100/100, color 100, blend 0x20,
                // colorMul 0xffffff, clip, prio 0xb, p19 1. Ghidra 0x22f46.
                drawAepFrameEx(&aep,
                               frm,
                               laneFrame,
                               noteY,
                               100,
                               100,
                               0,
                               0,
                               0,
                               100,
                               0,
                               0x20,
                               0xffffff,
                               clip,
                               0xb,
                               1);
            }
        }
    }

    // Running judged total -> the combo readout (@ +0x102).
    m_judgeTotal = static_cast<int16_t>(note.getJudgeTotal());

    // The time-line marker sweeps left->right across the song: x = barWidth * pos
    // / total.
    const int total = 0x16ebd8; // DAT_0016ebd8 (chart length denominator)
    const int barW = m_barWidth;
    const int cur = note.getCurrentPosition();
    int lineClip[4] = {m_timeLineX, m_timeLineY, (total ? barW * cur / total : 0), m_screenHeight};
    drawAepFrameEx(&aep,
                   m_timeLineFrm,
                   m_timeLineX,
                   m_timeLineY,
                   100,
                   100,
                   0,
                   0,
                   0,
                   100,
                   0,
                   0x20,
                   0xffffff,
                   lineClip,
                   0xc,
                   1);
}

// ===========================================================================
// drawLifeGauge — Ghidra drawLifeGauge (FUN_00023000). Blit the 24-cell life
// gauge: each cell shows its empty frame, and cells below the current fill
// level show the lit frame nudged in by 2px (phone) / 4px (pad). The fill level
// is (base+combo)*0x18/0x400.
// ===========================================================================
void AcViewerTask::drawLifeGauge() {
    AepManager &aep = AepManager::shared();

    int value = static_cast<int>(m_gaugeBase) + static_cast<int>(m_gaugeValue);
    if (value < 0) {
        value = 0;
    }
    // lit = value * 24 / 1024, clamped to [0, 24].
    int lit = value < 0x3ff ? (value * 0x18) / 0x400 : 0x18;
    if (lit < 0) {
        lit = 0;
    }
    if (lit > 0x17) {
        lit = 0x18;
    }

    const bool pad = m_padDisplay;
    const int nudge = pad ? 4 : 2;

    for (int cell = 0; cell < 0x18; cell++) {
        // Cells 0..15 use the "01" (lower) set, 16..23 use the "02" (upper) set.
        const bool lower = cell < 0x10;
        const int emptyFrm = lower ? m_gaugeEmpty02Frm : m_gaugeEmpty01Frm; // GAUGE_OUT_01/02
        const int x = m_gaugeStrideX * cell + m_gaugeBaseX;
        const int y = lower ? m_gaugeLowerY : m_gaugeUpperY;
        drawAepFrameEx(
            &aep, emptyFrm, x, y, 100, 100, 0, 0, 0, 100, 0, 0x20, 0xffffff, nullptr, 0xd, 1);

        if (cell < lit) {
            const int litFrm = lower ? m_gaugeLit02Frm : m_gaugeLit01Frm; // GAUGE_02/01 lit
            drawAepFrameEx(&aep,
                           litFrm,
                           x + nudge,
                           y + nudge,
                           100,
                           100,
                           0,
                           0,
                           0,
                           100,
                           0,
                           0x20,
                           0xffffff,
                           nullptr,
                           0xc,
                           1);
        }
    }
}

// ===========================================================================
// cleanup — Ghidra AcMainTask::Cleanup (@ 0x22b44). Free the arcade-viewer play
// resources and wipe the play-data region so a later attempt starts clean.
// Called from update() state 9 once the fade-out has completed. Every field
// below is a named member of the play-data block (each at its binary-exact
// offset), matching the setup()/loadChart() idiom; the freed sub-objects were
// all allocated in setup().
//
// The only field that survives the wipe is the pad "board up" byte (@ +0x1d9):
// it is saved before the memset and restored afterwards, but only on the pad
// display.
// ===========================================================================
void AcViewerTask::cleanup() {
    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];

    // The play-state sub-task (@ +0x28, the first word of the play-data block):
    // delete it through its virtual destructor. (Modelled as a ne::C_TASK sub-object;
    // the exact subclass is not recovered here — the vtbl-slot-1
    // deleting-destructor confirms it is deleted.)
    if (ne::C_TASK *stateTask = m_stateTask) {
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

    // The two AepLyrCtrl overlays (@ +0x54 PAUSE_LOOP, +0x58 top banner): unlink
    // from the Aep layer list, then delete.
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

    // Free the group-7 arcade_viewer Aep textures. Ghidra: releaseAepTexture(aep,
    // 7).
    aep.releaseAepTexture(kAcvGroup);

    // Release the cached sheet + song-title strong refs (ARC: __bridge_transfer
    // balances the +1 retains loadChart() took at +0x1e0 / +0x1e4, then nil the
    // ivars).
    if (m_sheet) {
        static_cast<void>((__bridge_transfer id)m_sheet); // sheet NSData
        m_sheet = nullptr;
    }
    if (m_songTitle) {
        static_cast<void>((__bridge_transfer id)m_songTitle); // song-title NSString
        m_songTitle = nullptr;
    }

    // Stop + release the arcade timing SE (source id @ +0xd4) and the song BGM.
    [audio stopSe:m_readySeId];
    [audio releaseSe:nil resourceId:m_readySeId];
    [audio releaseBgm];

    // Release the arcade option-sheet controller (@ +0x208, ARC:
    // __bridge_transfer + nil).
    if (m_optionVC) {
        static_cast<void>((__bridge_transfer id)m_optionVC);
        m_optionVC = nullptr;
    }

    // Wipe the play-data region [m_stateTask .. m_state): everything setup() and
    // loadChart() populate, stopping before the play-state field so it survives.
    // Preserve the pad "board up" byte (@ +0x1d9) across the wipe, but only on the
    // pad display (Ghidra: g_bIsPadDisplay after NESceneManager_shared()). The span
    // is taken from the member addresses (0x1e4 on the faithful layout) so it stays
    // correct when the dead scratch fields are dropped under ENABLE_PATCHES.
    const unsigned char boardUp = m_padBoardUp;
    const auto wipeSize = static_cast<size_t>(reinterpret_cast<char *>(&m_state) -
                                              reinterpret_cast<char *>(&m_stateTask));
    memset(&m_stateTask, 0, wipeSize);
    if (neSceneManager::isPadDisplay()) {
        m_padBoardUp = boardUp;
    }
}

// ===========================================================================
// update — Ghidra acMainTaskUpdate (FUN_00021678). Per-frame: snapshot touch
// (drag anchor / flick), then run the play-state machine (@ +0x20c). While
// playing (state 6) it drives AcNoteMng and the note/gauge draw passes.
// ===========================================================================
//
// OFFSET NOTE: Ghidra models update()'s object through a nested struct field10
// at +0x28, so its "fieldNN_0xMM" accessors are RELATIVE to +0x28.
// setup()/loadChart()/the draw + HUD passes use flat absolute offsets. This
// reconstruction uses absolute offsets throughout, so the play-flags Ghidra
// shows as field65_0x1ac..+3 are +0x1d4..+0x1d7 here (confirmed: setup() writes
// the HUD-ready byte at absolute +0x1d4, drawActiveNotes reads the mute flags
// at +0x1d6/+0x1d7). Key resolved fields:
//   +0x1d4 HUD ready   +0x1d5 HUD armed   +0x1d6 paused   +0x1d7 pause-menu
//   open +0x1d8 pad display +0x1d9 pad board up +0xd4 ready-SE id +0xd8
//   ready-SE instance +0xfc pause-time snapshot +0x204 end-hold frame counter
//   +0x10c screen scale.
//
// DEVIATION: in state 9, when the transition is not yet done, the
// binary branches to the shared draw tail (Ghidra: bne 0x22276) so
// updateAndDrawAepLayers + the note/gauge draw passes still run that frame (only the
// state-advance store at 0x22272 is skipped). This reconstruction instead returns
// early, skipping the per-frame AEP draw during the teardown transition. Every other
// state and the touch preamble are instruction-faithful.
//
void AcViewerTask::update(int /*deltaMs*/) {
    AepManager &aep = AepManager::shared();
    AudioManager *audio = [AudioManager sharedManager];
    AcNoteMng &note = AcNoteMng::shared();
    neGraphics &gfx = neGraphics::shared();

    m_moved = false; // per-frame "moved" flag (field17_0xd0; recomputed)

    // --- Touch preamble (Ghidra: the drag/tap classifier at 0x21704..0x21880,
    // recovered from the disassembly of FUN_00021678). While the HUD is up
    // (m_hudReady @+0x1d4) it tracks a single drag anchor: when idle it latches
    // the first valid touch as the anchor (recording the scaled start/last
    // position and zeroing the accumulators); each following frame it accumulates
    // the scaled delta (m_dragAccumX += dx, m_seekCoef += dy*10) and sets m_moved
    // if anything moved. On release the anchor is dropped and, if the touch
    // barely moved (|scaled(start)-scaled(up)| <= 10 in x, < 11 in y), it becomes
    // a TAP whose scaled up-position is the hit-test point for the case 6 / 0xb /
    // 0xd rect tests. scaled(v) = (int)((float)v / m_uiScale). The accumulators
    // feed the case-0xb seek-scrub.
    bool flick = false, released = false;
    int flickX = 0, flickY = 0;
    if (m_hudReady) {
        const float scale = m_uiScale;
        const int n = gfx.activeTouchCount();
        if (m_dragTouchId < 0) {
            // Idle: latch the first valid touch as the drag anchor.
            for (int i = 0; i < n; i++) {
                const neTouchPoint *t = gfx.touchAt(i);
                if (t == nullptr || t->valid == 0) {
                    continue;
                }
                m_dragTouchId = t->id;
                const float sx = static_cast<float>(t->x) / scale;
                const float sy = static_cast<float>(t->y) / scale;
                m_dragStartX = sx;
                m_dragStartY = sy;
                m_dragLastX = sx;
                m_dragLastY = sy;
                m_dragAccumX = 0.0f;
                m_seekCoef = 0.0f;
                break;
            }
        } else {
            const neTouchPoint *t = gfx.findTouchById(m_dragTouchId);
            if (t == nullptr) {
                // The tracked touch vanished: drop the anchor.
                m_dragTouchId = -1;
                m_dragStartX = 0.0f;
                m_dragStartY = 0.0f;
                m_dragAccumX = 0.0f;
                m_seekCoef = 0.0f;
            } else {
                const float sx = static_cast<float>(t->x) / scale;
                const float sy = static_cast<float>(t->y) / scale;
                m_dragAccumX += sx - m_dragLastX;
                m_seekCoef += (sy - m_dragLastY) * 10.0f;
                m_dragLastX = sx;
                m_dragLastY = sy;
                if (m_dragAccumX != 0.0f || m_seekCoef != 0.0f) {
                    m_moved = true;
                }
                if (t->released != 0) {
                    m_dragTouchId = -1;
                    released = true;
                    const int upX = static_cast<int>(sx), upY = static_cast<int>(sy);
                    const int dnX = static_cast<int>(static_cast<float>(t->startX) / scale);
                    const int dnY = static_cast<int>(static_cast<float>(t->startY) / scale);
                    const int adx = (dnX - upX) < 0 ? (upX - dnX) : (dnX - upX);
                    const int ady = (dnY - upY) < 0 ? (upY - dnY) : (dnY - upY);
                    if (adx <= 10 && ady < 11) {
                        flick = true;
                        flickX = upX;
                        flickY = upY;
                    }
                }
            }
        }
    }

#if RHYDBG
    // Arcade Viewer goes black on iPad. State 4 (WAIT_TRANSITION) waits on
    // m_hudArmed (Ghidra isVisible, +0x1d5), which is only set at the tail of the
    // async BGM-load block in setup(); if that never lands, the black board (case
    // 0) never fades. Log the state + gates on change to see where it stalls.
    {
        static int s_acvLastState = -1;
        if (static_cast<int>(m_state) != s_acvLastState) {
            neDebugLog("AcViewer state=%d hudReady=%d hudArmed=%d pad=%d transDone=%d padBoard=%d",
                       static_cast<int>(m_state),
                       static_cast<int>(m_hudReady),
                       static_cast<int>(m_hudArmed),
                       neSceneManager::isPadDisplay() ? 1 : 0,
                       aep.isTransitionDone(),
                       static_cast<int>(m_padBoardUp));
            s_acvLastState = static_cast<int>(m_state);
        }
    }
#endif

    // Default to the current state: the shared `m_state = next` at the bottom
    // commits for every path that breaks, and the wait states (e.g. case 4 while
    // the transition runs) break WITHOUT assigning next. Leaving `next`
    // uninitialised corrupted m_state to garbage (RHYDBG showed state=3260),
    // resetting the task every frame. In the binary those wait paths goto the draw
    // tail and skip the state commit; initialising next = m_state is equivalent.
    AcViewerState next = m_state;
    switch (m_state) {
    case kAcvInit:
        // Enter the arcade viewer nav screen (and, on pad, insert the black board),
        // then register this task on the AppDelegate.
        [AcvRootVC() GotoAcViewer];
        if (neSceneManager::isPadDisplay() && !m_padBoardUp) {
            [AcvRootVC() InsertBlackBoard];
        }
        [[AppDelegate appDelegate] setAcMainTask:this];
        next = kAcvWaitMusicId;
        break;
    case kAcvWaitMusicId:
        // Wait for a valid song id (set when the viewer picks a song).
        next = (neAppEventCenter::acViewerMusicId() < 0) ? kAcvExitToMenu : kAcvSetup;
        break;
    case kAcvSetup:
        setup();
        next = kAcvStartTransition;
        [[fallthrough]];
    case kAcvStartTransition:
        // Fade the HUD in and play the top banner.
        aep.setAepTransitionMode(1); // Ghidra: setAepTransitionMode(aep, 1)
        m_topLayer->play();
        next = kAcvWaitTransition;
        [[fallthrough]];
    case kAcvWaitTransition:
        if (!m_hudArmed || !aep.isTransitionDone()) {
            break; // still transitioning
        }
        // On phone (or once the pad board is up) fire the ready SE, then advance.
        if (!neSceneManager::isPadDisplay() || m_padBoardUp) {
            m_readySeInst = static_cast<int>([[AudioManager sharedManager] playSe:0
                                                                       resourceId:m_readySeId]);
        }
        next = kAcvWaitSe;
        break;
    case kAcvWaitSe:
        // When the ready SE finishes, start note playback.
        if ([[AudioManager sharedManager] isPlayingSe:m_readySeInst] == 0) {
            note.startPlayback();
            next = kAcvPlaying;
        }
        if (neSceneManager::isPadDisplay()) {
            [AcvRootVC() FadeOutBlackBoard];
        }
        break;
    case kAcvPlaying: { // *** PLAYING ***
        if (neSceneManager::isPadDisplay() && [AcvRootVC() acMusicSelViewing] == 1) {
            next = kAcvPause;
            break;
        }
        note.update();
        // DAT_00173e70 is the engine's global "chart finished" flag (raised when
        // the type-6 end marker is reached). On finish, reset the end-hold counter
        // (@ +0x204) and go to the end-hold state. Otherwise a TAP is hit-tested by
        // position (Ghidra: two pointInRect calls, FUN_0002d974): a tap inside the
        // play/song-select rect opens the song-select (state 10); a tap on the
        // exit/pause button opens the pause menu (0xc).
        if (g_bAcNoteFinished) {
            m_endHoldCounter = 0;
            next = kAcvPauseDelay;
        } else if (flick &&
                   neGraphics::pointInRect(
                       flickX, flickY, m_comboDigitX, m_comboDigitY, m_playTouchW, m_playTouchH)) {
            next = kAcvPause;
        } else if (flick &&
                   neGraphics::pointInRect(
                       flickX, flickY, m_exitTouchX, m_exitTouchY, m_exitTouchW, m_exitTouchH)) {
            next = kAcvPauseMenuOpen;
        } else {
            break;
        }
        break;
    }
    case kAcvPauseDelay: {
        // End-of-song hold: after ~30 frames, pause + snapshot and go to the pause
        // state.
        int t = m_endHoldCounter;
        if (t > 0x1e) {
            note.Pause();
            m_pauseTime = note.getCurrentPosition();
            m_paused = true;
            next = kAcvPauseMenuOpen;
            t = m_endHoldCounter;
        }
        m_endHoldCounter = t + 1;
        break;
    }
    case kAcvExitTransition:
        // Teardown transition out.
        note.resetPlayFlag();
        aep.setAepTransitionMode(2); // Ghidra: setAepTransitionMode(aep, 2)
        next = kAcvWaitExit;
        break;
    case kAcvWaitExit:
        if (aep.isTransitionDone()) {
            cleanup(); // AcMainTask::Cleanup — free HUD/textures/AcNoteMng
            next = kAcvInit;
        } else {
            return;
        }
        break;
    case kAcvPause:
        // Song-select viewing: pause + snapshot, then wait to resume.
        note.Pause();
        m_pauseTime = note.getCurrentPosition();
        m_paused = true;
        next = kAcvScrub;
        break;
    case kAcvScrub: {
        // Paused-for-song-select / seek-scrub (Ghidra 0x21bd4, disasm-recovered).
        // The drag anchor's scaled start-Y picks the interaction: at/below
        // m_scrubZoneTopY is the scrub zone (>= m_seekGaugeSplitY = gauge scrub,
        // else seek scrub); above it, a tap resumes play or opens the pause menu.
        next = kAcvScrub;
        // (A) iPad resume-at-top: only when NOT paused (rarely fires; normally
        // m_paused=1 here).
        if (neSceneManager::isPadDisplay() && !m_paused) {
            note.resume();
            m_paused = false;
            next = kAcvPlaying;
        }
        if (released) {
            // (B) release side: snapshot the seek base, or quantize the gauge scrub.
            if (m_dragStartY >= static_cast<float>(m_scrubZoneTopY)) {
                if (m_dragStartY >= static_cast<float>(m_seekGaugeSplitY)) {
                    // (C) gauge quantize: v -> 0..24 steps (v*24/1023, magic 0x80200803),
                    // each 42.5 units, capped at 1023 (constants byte-verified).
                    int v =
                        static_cast<uint16_t>(m_gaugeBase) + static_cast<uint16_t>(m_gaugeValue);
                    if (v & 0x8000) {
                        v = 0;
                    }
                    v = static_cast<int16_t>(v);
                    int q = (v * 24) / 1023;
                    if (q < 0) {
                        q = 0;
                    } else if (q > 24) {
                        q = 24;
                    }
                    const float f = (q < 24) ? static_cast<float>(q) * 42.5f : 1023.0f;
                    m_gaugeValue = static_cast<int16_t>(static_cast<int>(std::ceil(f)));
                    m_gaugeBase = 0;
                } else {
                    m_pauseTime = note.getCurrentPosition(); // snapshot the seek base
                }
            }
            // fall through to the tap tests (E)
        } else if (m_dragTouchId >= 0 && m_moved) {
            // (D) mid-drag live scrub
            if (m_dragStartY >= static_cast<float>(m_scrubZoneTopY)) {
                if (m_dragStartY >= static_cast<float>(m_seekGaugeSplitY)) {
                    m_gaugeBase = static_cast<int16_t>(static_cast<int>(
                        m_dragAccumX * static_cast<float>(m_xScrubScale))); // x-scrub
                } else {
                    // live seek: re-init the chart then seek to base + accumulated
                    // dy*scale. The 2nd arg is the hi-speed setting index (+0x1f4),
                    // used by initPlayData as kAcHiSpeed[index]; verified from the
                    // r2 <- [this + 0x1f4] load at this call site (Update 0x220ce)
                    // and the matching one in loadChart (0x2333e).
                    note.initPlayDataWithData((__bridge NSData *)m_sheet, m_hiSpeed);
                    int seek =
                        static_cast<int>(static_cast<float>(static_cast<uint32_t>(m_pauseTime)) +
                                         m_seekCoef * static_cast<float>(m_seekScale));
                    if (seek < 0) {
                        seek = 0;
                    }
                    note.seekTo(static_cast<uint32_t>(seek));
                }
            }
            break; // mid-drag returns without the tap tests
        }
        // (E) tap tests -- only a tap above the scrub zone.
        if (flick && m_dragStartY < static_cast<float>(m_scrubZoneTopY)) {
            if (neGraphics::pointInRect(
                    flickX, flickY, m_comboDigitX, m_comboDigitY, m_playTouchW, m_playTouchH)) {
                note.resume();
                m_paused = false;
                next = kAcvPlaying;
            } else if (neGraphics::pointInRect(flickX,
                                               flickY,
                                               m_exitTouchX,
                                               m_exitTouchY,
                                               m_exitTouchW,
                                               m_exitTouchH)) {
                next = kAcvPauseMenuOpen;
            }
        }
        break;
    }
    case kAcvPauseMenuOpen:
        // Pause menu: freeze play (if not already), play the pause overlay (phone)
        // or the black board (pad), and wait for the resume/quit tap.
        if (!m_paused) {
            note.Pause();
            m_pauseTime = note.getCurrentPosition();
        }
        m_pauseMenuOpen = true;
        if (!neSceneManager::isPadDisplay()) {
            m_pauseLayer->playOnce(); // +0x54 once (Ghidra AepLyrCtrl::Play @ 0x21f5e)
        } else {
            [AcvRootVC() GotoAcViewer];
        }
        next = kAcvPauseMenuInput;
        break;
    case kAcvPauseMenuInput: {
        // Pause menu (Ghidra 0x21cf2): three x-agnostic vertical button bands,
        // y-only hit-tested against the tap. m_pauseBtnY[0]=options, [1]=resume,
        // [2]=quit; each band is [anchor + height/2, anchor + height/2 + rowH].
        // Reaches the draw tail (the binary keeps drawing behind the menu), so
        // `next` is set on every path.
        next = kAcvPauseMenuInput; // stay unless a button is hit / the pad overlay is dismissed
        const int h = m_pauseBtnHeight / 2;
        const int rowH = m_pauseBtnRowH;
        const bool isPad = neSceneManager::isPadDisplay();
        bool handled = false;
        auto inBand = [&](int anchor) {
            return flickY >= anchor + h && flickY <= anchor + h + rowH;
        };
        auto padResumeToViewer = [&]() { // shared pad "close menu, resume" path
            [AcvRootVC() GotoAcViewer];
            m_pauseLayer->reset();
            m_pauseMenuOpen = false;
            note.resume();
            m_paused = false;
            next = kAcvPlaying;
        };
        if (flick) {
            if (inBand(m_pauseBtnY[0])) { // options
                if (isPad) {
                    neEngine::playSystemSe(1);
                    padResumeToViewer();
                } else {
                    next = kAcvOptionOpen;
                }
                handled = true;
            } else if (inBand(m_pauseBtnY[2])) { // quit
                neEngine::playSystemSe(1);
                if (isPad) {
                    padResumeToViewer();
                } else {
                    next = kAcvExitTransition;
                }
                handled = true;
            } else if (inBand(m_pauseBtnY[1])) { // resume
                m_pauseLayer->reset();
                m_pauseMenuOpen = false;
                if (m_paused) {
                    next = kAcvScrub;
                } else {
                    note.resume();
                    m_paused = false;
                    next = kAcvPlaying;
                }
                handled = true;
            }
        }
        // Pad tail: auto-resume once the song-select overlay is no longer showing.
        if (!handled && isPad && [AcvRootVC() acMusicSelViewing] == 0) {
            m_pauseMenuOpen = false;
            note.resume();
            m_paused = false;
            next = kAcvPlaying;
        }
        break;
    }
    case kAcvOptionOpen: {
        // Open the arcade option sheet (hi-speed / pop-kun / hid-sud / ran-mir).
        // Release any previous controller (@ +0x208), build a fresh
        // AcViewerOptionViewController bound to this task, fire the open SE +
        // animation, and resume the nav loop.
        if (m_optionVC) {
            static_cast<void>((__bridge_transfer id)m_optionVC);
            m_optionVC = nullptr;
        }
        AcViewerOptionViewController *optVC =
            [[AcViewerOptionViewController alloc] initForAcMain:this];
        m_optionVC = (__bridge_retained void *)optVC;
        [optVC startOpenAnimationForAcMain];
        [AcvRootVC() ResumeLoop];
        next = kAcvOptionActive;
        break;
    }
    case kAcvExitToMenu:
        // No song selected: fade the pad board, clear the AppDelegate task and hand
        // back to the mode menu.
        if (neSceneManager::isPadDisplay()) {
            [AcvRootVC() FadeOutBlackBoard];
        }
        [[AppDelegate appDelegate] setAcMainTask:nil];
        m_padBoardUp = false;
        kill(); // +0x24 = 1
        {
            MenuMainTask *menu = new MenuMainTask();
            menu->setPriority(3);
        }
        m_state = kAcvDone;
        return;
    default:
        break;
    }
    m_state = next;

    // Draw tail: update+draw all Aep layers, then (once the HUD is up and armed)
    // the note field and life gauge.
    static_cast<void>(audio);
    AepLyrCtrl::updateAndDrawAepLayers(0); // Ghidra: FUN_0002c924
    if (m_hudArmed && m_hudReady) {
        drawActiveNotes();
        drawLifeGauge();
    }
}

// ===========================================================================
// AcViewerHudDraw — Ghidra aepHudDrawCallback. @ 0x23358. The group-7 per-layer
// user-draw callback: dispatch on the layer's user number (resolved into
// +0xb8..+0xd0) and blit that HUD element (music title, combo/score/gauge digit
// runs, COOL/GREAT).
// ===========================================================================
void AcViewerTask::AcViewerHudDraw(int child,
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
                                   void *context) {
    static_cast<void>(frame);
    AepManager &aep = AepManager::shared();
    AcViewerTask *self = static_cast<AcViewerTask *>(context);

    // Digit-run blitter shared by the count cases: draw `n` digits of `val`
    // right-to-left from the m_digitTex[] set, advancing x by -m_digitAdvance
    // each step.
    auto drawDigits = [&](int val, int n) {
        int cx = x;
        for (int k = 0; k < n; k++) {
            neTextureForiOS_draw(&aep,
                                 self->m_digitTex[val % 10],
                                 0,
                                 0,
                                 self->m_digitScaleX,
                                 self->m_digitScaleY,
                                 cx,
                                 y,
                                 scaleX,
                                 scaleY,
                                 rotation,
                                 anchorX,
                                 anchorY,
                                 color,
                                 alpha,
                                 blend,
                                 0xffffff,
                                 nullptr,
                                 priority,
                                 1);
            cx -= self->m_digitAdvance;
            val /= 10;
        }
    };

    if (self->m_usrNo[0] == child) {
        // SCORE layer -> the difficulty bar frame (@ +0x84) at the scaled anchor.
        drawAepFrameEx(&aep,
                       self->m_barFrm,
                       x,
                       y,
                       scaleX,
                       scaleY,
                       rotation,
                       anchorX,
                       anchorY,
                       color,
                       alpha,
                       blend,
                       0xffffff,
                       clipRect,
                       0xe,
                       1);
    } else if (self->m_usrNo[1] == child) {
        // COMBO layer -> cache the combo-digit screen origin (@ +0x1ec/+0x1f0) for
        // drawActiveNotes, then draw the MUSIC_ON / MUSIC_OFF marker per the mute
        // flag.
        self->m_comboDigitY = y - (anchorY * scaleY) / 100;
        const int dy = !self->m_padDisplay ? -0xc : -0x18; // phone vs pad offset
        self->m_comboDigitX = (x - (anchorX * scaleX) / 100) + dy;
        const int frm = !self->m_paused ? self->m_musicOffFrm : self->m_musicOnFrm;
        drawAepFrameEx(&aep,
                       frm,
                       x,
                       y,
                       scaleX,
                       scaleY,
                       rotation,
                       anchorX,
                       anchorY,
                       color,
                       alpha,
                       blend,
                       0xffffff,
                       clipRect,
                       0xe,
                       1);
    } else if (self->m_usrNo[2] == child) {
        // MUSIC_NAME layer -> blit the cached song-title string (@ +0x1e4) at the
        // HUD baseline (Ghidra: aepManagerReset_a text blit with size @ +0x1e8, y
        // bias @ +0x1c4).
        NSString *title = (__bridge NSString *)self->m_songTitle;
        aep.DrawText(title.UTF8String,
                     self->m_titleXAdvance,
                     x,
                     y + self->m_titleBaselineY,
                     1,
                     100,
                     0xffffff,
                     0xe);
    } else if (self->m_usrNo[5] == child) {
        // COOL count layer -> 3 digits from the engine's COOL counter
        // (DAT_0016ebe0).
        AcNoteMng::shared();
        drawDigits(static_cast<int>(g_dwAcCoolCount), 3);
    } else if (self->m_usrNo[6] == child) {
        // GREAT count layer -> 2 digits from the GREAT counter (DAT_0016ebe4).
        AcNoteMng::shared();
        drawDigits(static_cast<int>(g_dwAcGreatCount), 2);
    } else if (self->m_usrNo[4] == child) {
        // Note-count layer -> 4 digits of the total note count (@ +0x100).
        drawDigits(static_cast<int>(self->m_totalNoteCount), 4);
    } else if (self->m_usrNo[3] == child) {
        // Judged-total layer -> 4 digits of the running judge total (@ +0x102).
        drawDigits(static_cast<int>(self->m_judgeTotal), 4);
    }
}

// Ghidra: applyGameplaySettings (FUN_00023850). Push the arcade-viewer option
// selections into the work area, rebuild the lane map / re-seek the note stream
// when hi-speed or ran/mir changed, and resume the render loop. The options
// sheet reaches it through the neEngine::acMainApplyGameplaySettings forwarder.
void AcViewerTask::applyGameplaySettings() {
    // Copy the pop-kun / hid-sud selections straight into the work area.
    m_popKun = [UserSettingData acvPopKun];
    m_hidSud = [UserSettingData acvHidSud];

    AcNoteMng &nm = AcNoteMng::shared();

    const int hiSpeed = [UserSettingData acvHiSpeed];
    const int ranMir = [UserSettingData acvRanMir];

    // Rebuild the lane-remap table whenever the ran/mir selection changed.
    if (ranMir != m_ranMir) {
        nm.setupLaneMapping(ranMir);
    }

    // Re-init the play data and re-seek only when hi-speed or ran/mir actually
    // changed vs the stored values (decompile bVar5 logic: bVar5 =
    // hiSpeed==m_hiSpeed; if bVar5 it then compares ran/mir — i.e. proceed iff
    // hiSpeed changed OR ran/mir changed).
    const bool hiSpeedChanged = (hiSpeed != m_hiSpeed);
    const bool ranMirChanged = (ranMir != m_ranMir);
    if (hiSpeedChanged || ranMirChanged) {
        // Snapshot the seek-math inputs (the decompile captures +0xf4/+0xfc/+0x118
        // here, before the re-init) then commit the new selections.
        const float seekCoef = m_seekCoef; // +0xf4
        const int pauseTime = m_pauseTime; // +0xfc  (position snapshot at pause)
        const int seekScale = m_seekScale; // +0x118

        m_hiSpeed = hiSpeed;
        m_ranMir = ranMir;

        // Re-parse the chart with the new hi-speed (arg shape matches
        // acNoteMngInitPlayData
        // @ 0x7a774 — the sheet NSData @ +0x1e0 and the hi-speed step). m_sheet is
        // the bridged, task-owned chart data, so a non-owning __bridge cast is
        // correct here.
        nm.initPlayDataWithData((__bridge NSData *)m_sheet, hiSpeed);

        // Resume-seek target: the binary computes (0x2391c-0x2392e)
        //   (int)( (float)pauseTime + seekCoef * (float)seekScale )
        // with plain int->float conversions (vcvt.f32.u32 on pauseTime,
        // vcvt.f32.s32 on seekScale, vcvt.s32.f32 on the result). This models the
        // arithmetic as a long combine rather than the NEON float intrinsics.
        // Clamp >= 0 as the binary.
        long seekPos = static_cast<long>(pauseTime) +
                       static_cast<long>(seekCoef * static_cast<float>(seekScale));
        if (seekPos < 0) {
            seekPos = 0;
        }
        nm.seekTo(static_cast<uint32_t>(seekPos));
    }

    // Resume the render loop; on phone advance the play-state machine into its
    // resume state.
    [neSceneManager::rootViewController() performSelector:@selector(ResumeLoop)];
    if (!neSceneManager::isPadDisplay()) {
        m_state = kAcvPauseMenuInput; // +0x20c
    }
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
