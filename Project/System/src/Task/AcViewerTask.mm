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
//  distinct class from the repo's sugoroku AcMainTask). All play-data access is by the
//  binary's flat byte offsets from `this` (cited inline) through field<T>().
//

#import "AcViewerTask.h"

#include <new>

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

    field<int>(0x104) = aep.screenWidth();     // aepGetScreenWidth
    field<int>(0x108) = aep.screenHeight();     // aepGetScreenHeight
    field<int>(0x10c) = g_dwUiScale;
    field<int>(0x1ec) = -1;                     // HUD combo digit screen x (HUD writes it)
    field<int>(0x1f0) = -1;                     // HUD combo digit screen y

    // Player options snapshot.
    field<int>(0x1f4) = [UserSettingData acvHiSpeed];   // +500
    field<int>(0x1f8) = [UserSettingData acvPopKun];
    field<int>(0x1fc) = [UserSettingData acvHidSud];
    field<int>(0x200) = [UserSettingData acvRanMir];
    field<int>(0x1dc) = (int)(short)g_wAcViewerDifficulty;
    field<unsigned char>(0x1d8) = neSceneManager::isPadDisplay() ? 1 : 0;

    // Lane remap for the RAN/MIR option, then load + init the chart.
    note.setupLaneMapping(field<int>(0x200));
    loadChart();                                 // FUN_0002316c

    // Total note count + the initial gauge value (0x100 == full at 256/1024 scale).
    field<int16_t>(0x100) = (int16_t)note.getTotalNoteCount();
    field<int16_t>(0x1ca) = 0x100;

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
        field<int16_t>(0x1cc + i * 2) = v;
    }

    // Load the "TIMING" arcade SE and the group-7 viewer Aep data.
    AudioManager *audio = [AudioManager sharedManager];
    NSString *sePath = [[NSBundle mainBundle] pathForResource:@"v12" ofType:@"m4a"];
    field<int>(0xd4) = (int)[audio loadSe:sePath isLoop:NO callName:nil group:1];

    const bool pad = (field<unsigned char>(0x1d8) != 0);
    AepLoadGroup(&aep, kAcvGroup, pad ? "arcade_viewer_ipad" : "arcade_viewer");

    // Two AepLyrCtrl overlays: the PAUSE_LOOP layer (+0x54) and the top banner (+0x58,
    // device-picked "TOP_960" / "TOP_1136" / "TOP_IPAD").
    AepLyrCtrl *pauseLayer = new AepLyrCtrl();
    field<AepLyrCtrl *>(0x54) = pauseLayer;
    pauseLayer->init(kAcvGroup, "PAUSE_LOOP", this);

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
    // layer is built. field<int>(0x124) = field<int>(0x120) + field<int>(0x128).
    // (best-effort: full constant tables omitted — see the DAT_0012e3xx blocks.)
    field<int>(0x124) = field<int>(0x120) + field<int>(0x128);

    AepLyrCtrl *topLayer = new AepLyrCtrl();
    field<AepLyrCtrl *>(0x58) = topLayer;
    topLayer->init(kAcvGroup, topName, this);

    // Resolve the HUD handles.
    field<int>(0x5c) = aep.getLyrNo(kAcvGroup, "EFFECT_COOL");
    field<int>(0x60) = aep.layerFrameCount(field<int>(0x5c));
    for (int i = 0; i < 7; i++) {
        field<int>(0xb8 + i * 4) = aep.getUserNo(kAcvGroup, kAcvUsrNames[i]);
    }
    for (int i = 0; i < 9; i++) {
        field<int>(0x94 + i * 4) = aep.getFrameNo(kAcvGroup, kAcvFrmNames[i]);
    }
    field<int>(0x6c) = aep.getFrameNo(kAcvGroup, "GAUGE_02");
    field<int>(0x70) = aep.getFrameNo(kAcvGroup, "GAUGE_01");
    field<int>(0x74) = aep.getFrameNo(kAcvGroup, "GAUGE_OUT_02");
    field<int>(0x78) = aep.getFrameNo(kAcvGroup, "GAUGE_OUT_01");
    field<int>(0x7c) = aep.getFrameNo(kAcvGroup, "MUSIC_ON");
    field<int>(0x80) = aep.getFrameNo(kAcvGroup, "MUSIC_OFF");
    field<int>(0x84) = aep.getFrameNo(kAcvGroup, kAcvBarFrm[field<int>(0x1dc)]);
    field<int>(0x88) = aep.getFrameNo(kAcvGroup, "TIME_LINE");
    field<int>(0x8c) = aep.getFrameNo(kAcvGroup, "BEAT_POPN_WHITE");
    field<int>(0x90) = aep.getFrameNo(kAcvGroup, "BEAT_POPN_BLUE");

    // 10 HUD digit textures (@ +0x2c[10]) from the bundle (device-picked "ticket_num%d"
    // / "num_pointb_%d" name tables PTR_cf_ticket_num0 / PTR_cf_num_pointb_0).
    NSBundle *bundle = [NSBundle mainBundle];
    for (int i = 0; i < 10; i++) {
        neTextureForiOS *tex = new neTextureForiOS();
        field<neTextureForiOS *>(0x2c + i * 4) = tex;
        NSString *name = pad ? [NSString stringWithFormat:@"num_pointb_%d", i]
                             : [NSString stringWithFormat:@"ticket_num%d", i];
        tex->load([[bundle pathForResource:name ofType:@"png"] UTF8String]);
    }

    // Register the per-layer HUD draw callback (Ghidra: setAepCallbacks(aep, 7, 0x23359,
    // this) — 0x23359 is &AcViewerHudDraw in Thumb).
    aep.setGroupDrawCallback(kAcvGroup, &AcViewerHudDraw, this);
    field<unsigned char>(0x1d4) = 1;   // HUD ready
}

// ===========================================================================
// loadChart — Ghidra loadChartData (FUN_0002316c). Fetch the AcMusicData for the
// selected song, async-load its BGM, pick the sheet by difficulty and hand it to
// AcNoteMng::initPlayData.
// ===========================================================================
void AcViewerTask::loadChart() {
    AudioManager *audio = [AudioManager sharedManager];
    AcNoteMng &note = AcNoteMng::shared();

    id acMusic = [[MusicManager getInstance] getAcMusicData:g_dwAcViewerMusicId];

    // Cache the display music name (+0x1e4, +1 retained); its length picks the HUD title
    // offsets (+0x1e8 x-advance / +0x1c4 baseline).
    if (field<void *>(0x1e4)) {
        (void)(__bridge_transfer id)field<void *>(0x1e4);
        field<void *>(0x1e4) = nullptr;
    }
    NSString *name = [acMusic musicName];
    field<void *>(0x1e4) = (__bridge_retained void *)name;

    const bool pad = (field<unsigned char>(0x1d8) != 0);
    if (name.length < 0x14) {
        field<int>(0x1e8) = pad ? 0x2a : 0x1c;
        field<int>(0x1c4) = pad ? -22 : -20;
    } else {
        field<int>(0x1e8) = pad ? 0x18 : 0x10;
        field<int>(0x1c4) = pad ? -12 : -12;
    }

    [audio stopBgm];
    // Ghidra: the async BGM load is a dispatch_async(^{...}) block (LAB_000237bc) posted
    // to the global queue; it streams the song's BGM in the background while play sets up.
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // @ 0x237bc — load this song's arcade BGM off the main thread (best-effort: the
        // block captures the AudioManager + AcMusicData and calls its BGM loader).
        [audio loadBgmForAcMusic:acMusic];
    });

    // Release the previous sheet, pick the new one by difficulty (0 easy / 1 normal /
    // 2 hyper / 3 ex), retain it, and init the note timeline at the chosen hi-speed.
    if (field<void *>(0x1e0)) {
        (void)(__bridge_transfer id)field<void *>(0x1e0);
        field<void *>(0x1e0) = nullptr;
    }
    NSData *sheet;
    switch (field<int>(0x1dc)) {
    case 0:  sheet = [acMusic sheetEasy];   break;
    case 2:  sheet = [acMusic sheetHyper];  break;
    case 3:  sheet = [acMusic sheetEx];     break;
    default: sheet = [acMusic sheetNormal]; break;
    }
    field<void *>(0x1e0) = (__bridge_retained void *)sheet;
    note.initPlayDataWithData(sheet, field<int>(0x1f4));
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

    int clip[4] = { 0, field<int>(0x120), field<int>(0x104), field<int>(0x108) };

    for (int i = 0; i < count; i++) {
        AcNoteObject n;
        note.getNoteObject(&n, i);
        const int laneFrame = field<int>(0x158 + n.lane * 4);

        if (n.tick < now) {
            // Note has passed the spawn point: scroll it toward the judge line. The exact
            // fixed-point scroll math (DAT_00022ffc scale + 0.5 bias) is decompiler-
            // obscured; modelled best-effort. When it is still above the layer's frame
            // count it is drawn as the EFFECT_COOL layer.
            const int frame = (int)((float)(now - n.tick) * 1.0f + 0.5f);
            if (frame < field<int>(0x60)) {
                aep.drawLayer(field<int>(0x5c), frame,
                              field<int>(0x124), field<int>(0x128),
                              100, 100, 0, field<int>(0x148), field<int>(0x14c),
                              /*root flags placeholder*/ 0);
                // First time a note crosses the line (and not in HID/SUD hidden state),
                // add to the combo counter (@ +0x1ca, saturated to 0x3ff) and mark the
                // note handled (bit 6). Ghidra: +0x1d2 combo step / acNoteSetNoteFlag.
                if (field<char>(0x1d6) == 0 && field<char>(0x1d7) == 0 && (n.flags & 0x40) == 0) {
                    int c = (int)field<int16_t>(0x1d2) + (int)field<int16_t>(0x1ca);
                    if (c < 0) { c = 0; }
                    if (c > 0x3ff) { c = 0x3ff; }
                    field<int16_t>(0x1ca) = (int16_t)c;
                    note.setNoteFlag(i, 0x40);
                }
            }
        } else {
            // Note still approaching: pick the POPN white/blue sprite (or the pop-kun
            // sprite when the POPKUN option is on) and blit it via drawAepFrameEx at its
            // computed lane x (best-effort on the NEON transform). HID/SUD gating on
            // +0x1fc hides notes outside the visible band.
            const bool visible =
                ((field<uint32_t>(0x1fc) | 2) != 3) || ((field<uint32_t>(0x1fc) & ~1u) != 2);
            if (visible) {
                int frm;
                if (field<int>(0x1f8) == 0) {
                    frm = (n.lane & 1) ? field<int>(0x90) : field<int>(0x8c);  // blue / white
                } else {
                    frm = (n.lane & 1) ? field<int>(0x90) : field<int>(0x8c);  // pop-kun variant
                }
                drawAepFrameEx(&aep, frm, /*x*/ field<int>(0x124), /*y*/ 0x42c80000, 0x42c80000,
                               0, 0, /*w/h*/ 100, 0, 0x20, 0xffffff, clip, 0xb, 1);
            }
        }
    }

    // Running judged total -> the combo readout (@ +0x102).
    field<int16_t>(0x102) = (int16_t)note.getJudgeTotal();

    // The time-line marker sweeps left->right across the song: x = barWidth * pos / total.
    const int total = 0x16ebd8;   // DAT_0016ebd8 (chart length denominator)
    const int barW = field<int>(0x194);
    const int cur = note.getCurrentPosition();
    int lineClip[4] = { field<int>(0x18c), field<int>(0x190),
                        (total ? barW * cur / total : 0), field<int>(0x108) };
    drawAepFrameEx(&aep, field<int>(0x88), field<int>(0x18c), field<int>(0x190),
                   0x42c80000, 0x42c80000, 0, 0, 0, 100, 0, 0x20, 0xffffff, lineClip, 0xc, 1);
}

// ===========================================================================
// drawLifeGauge — Ghidra drawLifeGauge (FUN_00023000). Blit the 24-cell life gauge:
// each cell shows its empty frame, and cells below the current fill level show the lit
// frame nudged in by 2px (phone) / 4px (pad). The fill level is (base+combo)*0x18/0x400.
// ===========================================================================
void AcViewerTask::drawLifeGauge() {
    AepManager &aep = AepManager::shared();

    int value = (int)field<int16_t>(0x1c8) + (int)field<int16_t>(0x1ca);
    if (value < 0) { value = 0; }
    // lit = value * 24 / 1024, clamped to [0, 24].
    int lit = value < 0x3ff ? (value * 0x18) / 0x400 : 0x18;
    if (lit < 0) { lit = 0; }
    if (lit > 0x17) { lit = 0x18; }

    const bool pad = (field<unsigned char>(0x1d8) != 0);
    const int nudge = pad ? 4 : 2;

    for (int cell = 0; cell < 0x18; cell++) {
        // Cells 0..15 use the "01" (lower) set, 16..23 use the "02" (upper) set.
        const bool lower = cell < 0x10;
        const int emptyFrm = lower ? field<int>(0x74) : field<int>(0x78);   // GAUGE_OUT_01/02
        const int x = field<int>(0x188) * cell + field<int>(0x184);
        const int y = lower ? field<int>(0x17c) : field<int>(0x180);
        drawAepFrameEx(&aep, emptyFrm, x, y, 0x42c80000, 0x42c80000,
                       0, 0, 0, 100, 0, 0x20, 0xffffff, nullptr, 0xd, 1);

        if (cell < lit) {
            const int litFrm = lower ? field<int>(0x6c) : field<int>(0x70);  // GAUGE_02/01 lit
            drawAepFrameEx(&aep, litFrm, x + nudge, y + nudge, 0x42c80000, 0x42c80000,
                           0, 0, 0, 100, 0, 0x20, 0xffffff, nullptr, 0xc, 1);
        }
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

    field<unsigned char>(0xf8) = 0;   // per-frame "moved" flag (field17_0xd0; recomputed)

    // --- Touch preamble (Ghidra: the drag/flick classifier at 0x216f6..0x21880). While
    // the HUD is up (ready byte @ +0x1d4) it latches a drag anchor on a held touch, or
    // resolves a flick on a released touch. The scaled-coordinate NEON math (FixedToFP /
    // screen-scale divide @ +0x10c / FloatVectorSub) is decompiler-obscured; reconstructed
    // best-effort as a boolean "flick this frame".
    bool flick = false;
    int flickX = 0, flickY = 0;
    if (field<unsigned char>(0x1d4) != 0) {
        const int n = gfx.activeTouchCount();
        for (int i = 0; i < n; i++) {
            const neTouchPoint *t = gfx.touchAt(i);
            if (t == nullptr) { continue; }
            if (t->released != 0) {
                flick = true;
                flickX = (int)((float)t->x / field<float>(0x10c));
                flickY = (int)((float)t->y / field<float>(0x10c));
                break;
            }
        }
    }

    int next;
    switch (state()) {
    case 0:
        // Enter the arcade viewer nav screen (and, on pad, insert the black board), then
        // register this task on the AppDelegate.
        [AcvRootVC() GotoAcViewer];
        if (neSceneManager::isPadDisplay() && field<char>(0x1d9) == 0) {
            [AcvRootVC() InsertBlackBoard];
        }
        [[AppDelegate appDelegate] setAcMainTask:this];
        next = 1;
        break;
    case 1:
        // Wait for a valid song id (set when the viewer picks a song).
        next = ((int)g_dwAcViewerMusicId < 0) ? 0x10 : 2;
        break;
    case 2:
        setup();
        state() = 3;
        [[fallthrough]];
    case 3:
        // Fade the HUD in and play the top banner.
        aep.playTransition(1, 0, 0);   // setAepTransitionMode(aep, 1)
        field<AepLyrCtrl *>(0x58)->play();
        state() = 4;
        [[fallthrough]];
    case 4:
        if (field<char>(0x1d5) == 0 || !aep.isTransitionDone()) {
            break;   // still transitioning
        }
        // On phone (or once the pad board is up) fire the ready SE, then advance.
        if (!neSceneManager::isPadDisplay() || field<char>(0x1d9) != 0) {
            field<int>(0xd8) = (int)[AcvRootVC() playSe:0 resourceId:field<int>(0xd4)];
        }
        next = 5;
        break;
    case 5:
        // When the ready SE finishes, start note playback.
        if ([AcvRootVC() isPlayingSe:field<int>(0xd8)] == 0) {
            note.startPlayback();
            state() = 6;
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
            field<int>(0x204) = 0;
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
        int t = field<int>(0x204);
        if (t > 0x1e) {
            note.pause();
            field<int>(0xfc) = note.getCurrentPosition();
            field<char>(0x1d6) = 1;
            state() = 0xc;
            t = field<int>(0x204);
        }
        field<int>(0x204) = t + 1;
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
        field<int>(0xfc) = note.getCurrentPosition();
        field<char>(0x1d6) = 1;
        next = 0xb;
        break;
    case 0xb:
        // Resume once the viewer is no longer showing the song-select.
        if (neSceneManager::isPadDisplay() && field<char>(0x1d6) != 0) {
            note.resume();
            field<char>(0x1d6) = 0;
            state() = 6;
        }
        break;
    case 0xc:
        // Pause menu: freeze play (if not already), play the pause overlay (phone) or the
        // black board (pad), and wait for the resume/quit tap.
        if (field<char>(0x1d6) == 0) {
            note.pause();
            field<int>(0xfc) = note.getCurrentPosition();
        }
        field<char>(0x1d7) = 1;
        if (!neSceneManager::isPadDisplay()) {
            field<AepLyrCtrl *>(0x54)->play();
        } else {
            [AcvRootVC() GotoAcViewer];
        }
        next = 0xd;
        break;
    case 0xd:
        // Wait in the pause menu (resume / retry / quit hit-testing lives here; the
        // per-button rect math is best-effort). On resume, restart the note engine.
        if (flick) {
            field<AepLyrCtrl *>(0x54)->reset();
            field<char>(0x1d7) = 0;
            note.resume();
            field<char>(0x1d6) = 0;
            state() = 6;
        }
        return;
    case 0xe: {
        // Open the arcade option sheet (hi-speed / pop-kun / hid-sud / ran-mir). Release any
        // previous controller (@ +0x208), build a fresh AcViewerOptionViewController bound to
        // this task, fire the open SE + animation, and resume the nav loop.
        if (field<void *>(0x208)) {
            (void)(__bridge_transfer id)field<void *>(0x208);
            field<void *>(0x208) = nullptr;
        }
        id optVC = [[AcViewerOptionViewController alloc] initForAcMain:this];
        field<void *>(0x208) = (__bridge_retained void *)optVC;
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
        field<char>(0x1d9) = 0;
        kill();   // +0x24 = 1
        {
            MenuMainTask *menu = new MenuMainTask();
            menu->setPriority(3);
        }
        state() = 0x11;
        return;
    default:
        break;
    }
    state() = next;

    // Draw tail: update+draw all Aep layers, then (once the HUD is up and armed) the
    // note field and life gauge.
    (void)audio;
    updateAndDrawAepLayers(0);
    if (field<char>(0x1d5) != 0 && field<char>(0x1d4) != 0) {
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
                     int blend, int p13, int p14, void *context) {
    (void)frame;
    AepManager &aep = AepManager::shared();
    AcViewerTask *self = static_cast<AcViewerTask *>(context);
    char *pd = reinterpret_cast<char *>(self);
    auto F = [&](int off) -> int { return *reinterpret_cast<int *>(pd + off); };

    // Digit-run blitter shared by the count cases: draw `n` digits of `val` right-to-left
    // from the +0x2c digit-texture set, advancing x by -F(0x1a0) each step.
    auto drawDigits = [&](int val, int n) {
        int cx = x;
        for (int k = 0; k < n; k++) {
            neTextureForiOS_draw(&aep, *reinterpret_cast<void **>(pd + 0x2c + (val % 10) * 4),
                                 0, 0, F(0x198), F(0x19c), cx, y, scaleX, scaleY, rotation,
                                 anchorX, anchorY, color, alpha, blend, 0xffffff, 0, p14, 1);
            cx -= F(0x1a0);
            val /= 10;
        }
    };

    if (F(0xb8) == child) {
        // SCORE layer -> the difficulty bar frame (@ +0x84) at the scaled anchor.
        drawAepFrameEx(&aep, F(0x84), x, y, scaleX, scaleY, rotation, anchorX, anchorY,
                       color, alpha, blend, 0xffffff, p13, 0xe, 1);
    } else if (F(0xbc) == child) {
        // COMBO layer -> cache the combo-digit screen origin (@ +0x1ec/+0x1f0) for
        // drawActiveNotes, then draw the MUSIC_ON / MUSIC_OFF marker per the mute flag.
        *reinterpret_cast<int *>(pd + 0x1f0) = y - (anchorY * scaleY) / 100;
        const int dy = (unsigned char)F(0x1d8) == 0 ? -0xc : -0x18;   // phone vs pad offset
        *reinterpret_cast<int *>(pd + 0x1ec) = (x - (anchorX * scaleX) / 100) + dy;
        const int frm = *reinterpret_cast<char *>(pd + 0x1d6) == 0 ? F(0x80) : F(0x7c);
        drawAepFrameEx(&aep, frm, x, y, scaleX, scaleY, rotation, anchorX, anchorY,
                       color, alpha, blend, 0xffffff, p13, 0xe, 1);
    } else if (F(0xc0) == child) {
        // MUSIC_NAME layer -> blit the cached song-title string (@ +0x1e4) at the HUD
        // baseline (Ghidra: aepManagerReset_a text blit with size @ +0x1e8, y bias @ +0x1c4).
        NSString *title = (__bridge NSString *)*reinterpret_cast<void **>(pd + 0x1e4);
        AepDrawText(&aep, title.UTF8String, F(0x1e8), x, y + F(0x1c4), 1, 100, 0xffffff, 0xe);
    } else if (F(0xcc) == child) {
        // COOL count layer -> 3 digits from the engine's COOL counter (DAT_0016ebe0).
        AcNoteMng::shared();
        drawDigits((int)g_dwAcCoolCount, 3);
    } else if (F(0xd0) == child) {
        // GREAT count layer -> 2 digits from the GREAT counter (DAT_0016ebe4).
        AcNoteMng::shared();
        drawDigits((int)g_dwAcGreatCount, 2);
    } else if (F(0xc8) == child) {
        // Note-count layer -> 4 digits of the total note count (@ +0x100).
        drawDigits((int)*reinterpret_cast<int16_t *>(pd + 0x100), 4);
    } else if (F(0xc4) == child) {
        // Judged-total layer -> 4 digits of the running judge total (@ +0x102).
        drawDigits((int)*reinterpret_cast<int16_t *>(pd + 0x102), 4);
    }
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
