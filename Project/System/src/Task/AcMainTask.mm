//
//  AcMainTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The
//  arcade-mode task (arcade select + sugoroku map + option select + note play
//  through AcNoteMng). AcMainTask_update (FUN_00099d18) is the app's largest
//  function (~24 KB / ~4300 decompiled lines, heavily inlined); it is
//  reconstructed in pieces from the on-disk decompile
//  (.decompile/AcMainTask_update.c). update() below is the touch/SE preamble
//  and the state dispatch; each state's inlined body is lifted into its own
//  method as it is reconstructed (see STUBS.md for which states remain).
//

#import "AcMainTask.h"

#include <algorithm>
#include <cstring>
#include <ctime>

#import "AepFrameDraw.h"
#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "CharaInfo.h"
#import "CharaManager.h"
#import "MainViewController.h"
#import "MusicData.h"
#import "MusicManager.h"
#import "RhUtil.h"
#import "SkillData.h"
#import "TreasureData+Store.h"
#import "TreasureData.h"
#import "TreasureMap.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

// Ghidra: AcMainTask_update (FUN_00099d18). Snapshot the touches (recording a
// drag anchor and classifying a tap), refresh the "scrolled past the end" flag,
// then dispatch on the play-data state (@ +0x9f8).
// @complete
void AcMainTask::update(int /*deltaMs*/) {
    neGraphics &gfx = neGraphics::shared();

    // Touch preamble (Ghidra: the touch loop at 0x99e34..0x99e92). Walk the live
    // touches until one is meaningful:
    //  * a held (valid) touch latches the drag anchor (@ +0x508/+0x50c/+0x510) if
    //  none
    //    is set, and marks a drag in progress;
    //  * a released touch that barely moved from its start point (< 11 on each
    //  axis,
    //    compared against the raw stored coordinates as the binary does) is a
    //    tap.
    m_frameDragging = false;
    m_frameTapped = false;
    m_frameTapTouch = nullptr;
    for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t->valid != 0) {
            if (m_dragAnchorId < 0) {
                m_dragAnchorId = t->id;
                // Disasm 0x99e3e: the anchor is stored as a plain float (vcvt.f32.s32
                // of the touch coord, vstr.32) -- NOT divided by 65536. The consuming
                // per-frame scroll-normalization lives in the not-yet-reconstructed
                // arcade states 0x10 / 0x4d: delta = ((float)touch - anchor) /
                // m_screenScale (NEON_ACCURACY.md #13).
                m_dragAnchorX = (float)t->x;
                m_dragAnchorY = (float)t->y;
            }
            m_frameDragging = true;
            break;
        }
        if (t->released != 0) {
            int dx = t->x - t->startX;
            if (dx < 0) {
                dx = -dx;
            }
            if (dx > NE_TAP_SLOP(10)) { // slop widened under ENABLE_PATCHES (NE_TAP_SLOP)
                break;                  // moved too far horizontally: not a tap
            }
            int dy = t->y - t->startY;
            if (dy < 0) {
                dy = -dy;
            }
            m_frameTapped = (dy < NE_TAP_SLOP(11));
            m_frameTapTouch = t;
            break;
        }
    }

    // "Scrolled past the last row" flag (@ +0x5f2): list offset >= content
    // bottom.
    m_scrolledPastEnd = (int)m_listBottom <= m_treasurePoint;

    switch (m_state) {
    case 0:
        stateInit();
        break;
    case 1:
        stateFadeIn();
        break;
    case 2:
        stateTreasureCheck();
        break;
    case 0x10:
        // Sugoroku map-drag state: the reconstructed sub-pass here is the per-frame
        // drag-scroll normalization (NEON_ACCURACY.md #13, disasm prologue at
        // 0x9a6ba). The remainder of this state's body (board redraw / input
        // arbitration) is not yet reconstructed.
        applyDragScroll(gfx);
        break;
    case 0x4d:
        // Same drag-scroll block, interleaved into state 0x4d at 0x9cb56
        // (byte-identical).
        applyDragScroll(gfx);
        break;
    default:
        break;
    }
}

// Per-frame drag / rubber-band scroll normalization. Ground truth is the
// disassembly (0x9a6ba, byte-identical at 0x9cb56) — the decompiler garbles the
// vcvt/vsub NEON here. The live drag delta (in screen units) is subtracted from
// the accumulated scroll, the result is clamped to the map's scroll box, and
// any overshoot past the clamp is banked into a rubber-band accumulator
// (m_scrollRubberX/Y) so the view springs back.
// @complete
void AcMainTask::applyDragScroll(neGraphics &gfx) {
    if (m_dragAnchorId < 0) {
        return;
    }
    const neTouchPoint *t = gfx.findTouchById(m_dragAnchorId);
    if (!t) {
        return;
    }

    // Drag delta from the latched anchor, converted to logical screen units. The
    // binary does vcvt.f32.s32 on the raw touch coords, subtracts the float
    // anchor, then divides by m_screenScale (vdiv) — no 65536 fixed-point scaling
    // anywhere.
    const float dX = ((float)t->x - m_dragAnchorX) / m_screenScale;
    const float dY = ((float)t->y - m_dragAnchorY) / m_screenScale;

    // Proposed scroll positions, minus whatever is already banked in the
    // rubber-band. The clamp comparisons in the binary use the truncated
    // (int)->(float) round-trip of these values, so mirror the int cast before
    // comparing.
    const int nx = (int)((m_scrollX - dX) - m_scrollRubberX);
    const int ny = (int)((m_scrollY - dY) - m_scrollRubberY);

    int fx;
    if ((float)nx > m_clampCentreX2) {
        m_scrollRubberX += (float)nx - m_clampCentreX2;
        fx = (int)m_clampCentreX2;
    } else if ((float)nx < m_clampCentreX) {
        m_scrollRubberX += (float)nx - m_clampCentreX;
        fx = (int)m_clampCentreX;
    } else {
        fx = nx;
    }

    int fy;
    if ((float)ny > m_clampMaxY) {
        m_scrollRubberY += (float)ny - m_clampMaxY;
        fy = (int)m_clampMaxY;
    } else if ((float)ny < m_clampMinY) {
        m_scrollRubberY += (float)ny - m_clampMinY;
        fy = (int)m_clampMinY;
    } else {
        fy = ny;
    }

    // Publish the clamped screen-space base the board draw subtracts from every
    // layer.
    m_scrollBaseX = m_scrollX - (float)fx;
    m_scrollBaseY = m_scrollY - (float)fy;
}

// case 0 — build the select/map scene, then start the BGM if a treasure record
// is present (subMapId @ +0x620 >= 0); otherwise take the no-treasure path.
// Ghidra: the case 0 body at 0x99e92 (FUN_0009fc90 then playBgm:0.5 /
// LAB_0009aa74).
// @complete
void AcMainTask::stateInit() {
    setupScene(); // FUN_0009fc90
    if (m_subMapId >= 0) {
        AudioManager *audio = [AudioManager sharedManager];
        [audio playBgm:0.5f]; // Ghidra: playBgm:, arg 0x3fe00000 == 0.5
    } else {
        m_bgmActive = false; // the binary jumps to LAB_0009aa74 (no-treasure)
    }
}

// case 1 — set a 30-frame fade-out and jump it to fully-faded, restore the menu
// BGM stack, push the sugoroku map-select screen, then advance to the treasure
// check. Ghidra: case 1 (setAepTransitionMode(scene, 2) = FUN_00010698,
// setTransitionFrame(scene, 0) = FUN_00010758).
// @complete
void AcMainTask::stateFadeIn() {
    AepManager &aep = AepManager::shared();
    aep.setAepTransitionMode(2); // FUN_00010698(scene, 2): fade-out, 30 frames
    aep.setTransitionFrame(0);   // FUN_00010758(scene, 0): jump to fully-faded

    AudioManager *audio = [AudioManager sharedManager];
    if ([audio isPushBgm]) {
        [audio popBgm];
    }
    [audio playBgm:0.5f];

    MainViewController *root = (MainViewController *)neSceneManager::rootViewController();
    [root GotoMapSelect]; // -[MainViewController GotoMapSelect] @ 0xc7d8
    m_state = 2;
}

// case 2 — read the temp-treasure record; if a sub-map is pending (subMapId >=
// 0), cache it (@ +0x620), load the map, and start play, else keep waiting.
// Ghidra: case 2 (UserSettingData treasureTmp; FUN_000a0b58; playBgm at
// LAB_0009a026).
// @complete
void AcMainTask::stateTreasureCheck() {
    TreasureTmpData tmp = [UserSettingData treasureTmp];
    m_subMapId = tmp.subMapId;
    if (tmp.subMapId >= 0) {
        loadTreasureMap(); // FUN_000a0b58
        AudioManager *audio = [AudioManager sharedManager];
        [audio playBgm:0.5f];
    }
}

// ===========================================================================
// setupScene — Ghidra FUN_0009fc90. The arcade sugoroku scene builder.
// ===========================================================================

// Byte-verified layer names for the getLyrNo tables (Ghidra: DAT_001327d4 /
// DAT_001327e8 / DAT_0013280c / DAT_001328f4). Each resolves within asset
// group 5.
static const char *const kLyrSkillBoards[5] = { // -> +0x21c (+0x230 frame counts)
    "SKILL_COM_BOARD",
    "RETIRE_COM_BOARD",
    "MUSIC_PEACE_LOCK1",
    "WALL_PEACE_LOCK1",
    "FRIEND_NAME_BOARD2"};
static const char *const kLyrMusicPeace[9] = { // -> +0x27c
    "MUSIC_PEACE00",
    "MUSIC_PEACE01",
    "MUSIC_PEACE02",
    "MUSIC_PEACE03",
    "MUSIC_PEACE04",
    "MUSIC_PEACE05",
    "MUSIC_PEACE06",
    "MUSIC_PEACE07",
    "MUSIC_PEACE08"};
static const char *const kLyrWallPeace[9] = { // -> +0x2a0
    "WALL_PEACE00",
    "WALL_PEACE01",
    "WALL_PEACE02",
    "WALL_PEACE03",
    "WALL_PEACE04",
    "WALL_PEACE05",
    "WALL_PEACE06",
    "WALL_PEACE07",
    "WALL_PEACE08"};
static const char *const kLyrIconMental[4] = { // -> +0x258 (+0x268 frame counts)
    "ICON_MENTAL00",
    "ICON_MENTAL01",
    "ICON_MENTAL02",
    "ICON_MENTAL03"};

// getFrameNo names (Ghidra: DAT_00132904 / DAT_0013296c / DAT_00132998 /
// DAT_001329c0 / DAT_001329d0 / PTR_s_TRIANGLE01_05).
static const char *const kFrmBoard[26] = { // -> +0x2d0
    "CHARA_KOMA00",  "MUSIC_PEACE_BOARD_S", "JACKET_QUESTION",   "JACKET_DISCOVERY",
    "BT_ROULETTE",   "BT_ROULETTE_NO",      "BT_ROULETTE_EVENT", "BT_ROULETTE_EVENT_NO",
    "BT_GATYA",      "BT_GATYA01",          "PAGE_BEFORE",       "PAGE_NEXT",
    "WARNING",       "BT_WALL_SAVE",        "DEFENSE_01_00",     "DEFENSE_01_01",
    "DEFENSE_01_02", "DEFENSE_01_03",       "DEFENSE_01_04",     "DEFENSE_00",
    "DEFENSE_02",    "BT_SQUARE01_00",      "DEFENSE_03_00",     "DEFENSE_03_01",
    "DEFENSE_03_02", "DEFENSE_03_03"};
static const char *const kFrmBase1[11] = { // -> +0x338
    "BASE_00",
    "BASE_01",
    "BASE_02",
    "BASE_03",
    "BASE_04",
    "BASE_06_00",
    "BASE_06_01",
    "BASE_07_00",
    "BASE_07_01",
    "BASE_09",
    "BASE_10"};
static const char *const kFrmBase08[10] = { // -> +0x368
    "BASE_08_00",
    "BASE_08_01",
    "BASE_08_02",
    "BASE_08_03",
    "BASE_08_04",
    "BASE_08_05",
    "BASE_08_06",
    "BASE_08_07",
    "BASE_08_08",
    "BASE_08_09"};
static const char *const kFrmBase05[4] = { // -> +0x390
    "BASE_05_00",
    "BASE_05_01",
    "BASE_05_02",
    "BASE_05_03"};
static const char *const kFrmTriangle0[6] = { // -> +0x3a0 (interleaved with the below)
    "TRIANGLE00_05",
    "TRIANGLE00_04",
    "TRIANGLE00_03",
    "TRIANGLE00_02",
    "TRIANGLE00_01",
    "TRIANGLE00_00"};
static const char *const kFrmTriangle1[6] = { // -> +0x3b8
    "TRIANGLE01_05",
    "TRIANGLE01_04",
    "TRIANGLE01_03",
    "TRIANGLE01_02",
    "TRIANGLE01_01",
    "TRIANGLE01_00"};

// getUserNo names (Ghidra: DAT_00132a00) -> +0x3d0.
static const char *const kUsrBoard[26] = {
    "S_POINT_NUM",         "CHARACT00",          "CHARACT01",
    "CHARACT02",           "CHARACT04",          "CHARACT05",
    "CHARACT_NAME00",      "CHARACT_COMMENT00",  "JACKET_QUESTION",
    "MUSIC_PEACE_BOARD_S", "JACKET01",           "JACKET09",
    "WALL_QUESTION",       "WALL_PEACE_BOARD_S", "WALL_PEACE",
    "WALL_PEACE01",        "ROUL_NUM_BIG",       "BT_GATYA",
    "CHARACT03",           "PAGE_BEFORE",        "WARNING",
    "TICKET_NUM00",        "G_S_POINT_NUM",      "STEPS_NUM00",
    "EVENT_INFO_IMG",      "EVENT_INFO_TXT"};

// The 29 roulette overlay layers + their ordering-table priorities (Ghidra:
// PTR_s_ROULETTE_START_OPEN_00132830 + DAT_0012f8a0) -> +0x2c.
static const char *const kRouletteNames[29] = {"ROULETTE_START_OPEN",
                                               "ROULETTE_START_ROOP",
                                               "ROULETTE_START_OPEN_EVENT",
                                               "ROULETTE_START_ROOP_EVENT",
                                               "ROULETTE_EFF",
                                               "SELECTION_CHARA_OPEN",
                                               "SELECTION_CHARA_CLOSE",
                                               "SUGO_COMMENT_BOARD",
                                               "MUSIC_PEACE_OPEN",
                                               "WALL_PEACE_OPEN",
                                               "GOAL_OPEN",
                                               "GET_MUSIC",
                                               "GET_WALL",
                                               "GATSHA_OPEN",
                                               "WALL_SAVE_COM",
                                               "EFF_SKILL2",
                                               "EFF_SKILL_KOUKA2",
                                               "EFF_WARP_3",
                                               "SELECT_ARROW",
                                               "LIFTING_MUSIC",
                                               "LIFTING_WALL",
                                               "LIFTING_MAP",
                                               "LIFTING_AREA",
                                               "LIFTING_GAOL_BOARD_01_02",
                                               "LIFTING_GAOL_BOARD_02_02",
                                               "LIFTING_GAOL_BOARD_03_02",
                                               "EVENT_TXT_1136",
                                               "EVENT_INFO_OPEN",
                                               "ICON_REVERSE"};
static const int kRouletteOrder[29] = {20, 20, 20, 20, 19, 15, 15, 25, 11, 11, 23, 23, 23, 14, 7,
                                       31, 32, 31, 16, 23, 23, 23, 23, 23, 23, 23, 22, 6,  22};

// 4 sugoroku arrows (Ghidra: PTR_s_SUGOROKU_ARROW01_001328a4) -> +0xc0, order
// 0x1d.
static const char *const kArrowNames[4] = {
    "SUGOROKU_ARROW01", "SUGOROKU_ARROW03", "SUGOROKU_ARROW02", "SUGOROKU_ARROW00"};

// The 8 select-panel layers -> +0xa0. Two device-branched name tables (Ghidra:
// DAT_001328d4 default / DAT_001328b4 tall-phone) share one order table
// (DAT_0012f914).
static const char *const kPanelNamesDefault[8] = { // 640/960 assets
    "IMG960",
    "CHARACTER_SELECTION640_OPEN",
    "CHARACTER_SELECTION640_OUT",
    "CHARACTER_CHANGE640",
    "COLLECTION_SELECT_640_OPEN",
    "COLLECTION_SELECT_640_OUT",
    "MUSIC_PEACE_S_960_OPEN",
    "WALL_PEACE_S_960_OPEN"};
static const char *const kPanelNamesTall[8] = { // 1136 assets (tall phone, dt==2)
    "IMG1136",
    "CHARACTER_SELECTION1136_OPEN",
    "CHARACTER_SELECTION1136_OUT",
    "CHARACTER_CHANGE1136",
    "COLLECTION_SELECT_1136_OPEN",
    "COLLECTION_SELECT_1136_OUT",
    "MUSIC_PEACE_S_1136_OPEN",
    "WALL_PEACE_S_1136_OPEN"};
static const int kPanelOrder[8] = {28, 17, 17, 17, 13, 13, 12, 12};

void AcMainTask::setupScene() {
    // Cache the audio manager for the BGM prep at the tail (Ghidra: local_174).
    AudioManager *audio = [AudioManager sharedManager];

    // Snapshot the pending-treasure record up front; only its subMapId is used
    // here.
    TreasureTmpData tmp = [UserSettingData treasureTmp];

    // Rebuild the character lists (Ghidra: the lazy gCharaManager guard
    // FUN_0002980c, then CharaManager_reload FUN_000b85bc).
    gCharaManager.reload();

    // Cache the scene manager at this+0x28 (every resolve below reads it) and the
    // pad-vs-phone flag at this+0x5f7 (Ghidra: NESceneManager_shared +
    // DAT_00187b84).
    AepManager &aep = AepManager::shared();
    m_aep = &aep;
    neSceneManager::shared();
    m_padDisplay = neSceneManager::isPadDisplay() ? 1 : 0;

    // Player progress snapshot.
    m_treasurePoint = [UserSettingData treasurePoint];
    m_charaTicket = [UserSettingData charaTicket];
    m_charaId = [UserSettingData charaId];

    // Character-panel scroll extent: the available list is laid out 6 per row.
    // The binary computes this at 0x9fd94..0x9fdca: (float)count (vcvt.f32.u32),
    // divided by 6.0f (vmov #0x40c00000 / vdiv.f32), plus 0.5f (vmov #0x3f000000
    // / vadd.f32), then truncated back with vcvt.s32.f32 — i.e. the count rounded
    // to the nearest whole number of rows, stored at +0x638.
    NSArray *available = gCharaManager.availableInfos();
    m_availableInfos = (__bridge void *)available; // cached raw (unretained), as the binary does
    const int availableCount = (int)available.count;
    m_charaRowCount = (int)((float)availableCount / 6.0f + 0.5f);

    // Working copy of the owned-character set (+1 retained; released on the next
    // rebuild). Ghidra: release the old, then gotCharaArray mutableCopy.
    if (m_gotCharaArray) {
        (void)(__bridge_transfer id)m_gotCharaArray;
        m_gotCharaArray = nullptr;
    }
    m_gotCharaArray = (__bridge_retained void *)[[UserSettingData gotCharaArray] mutableCopy];

    // Resolve the active character's skill record (Ghidra:
    // availableInfoForCharaId, then GetSkillDataStruct on its skillId).
    const short charaId = [UserSettingData charaId];
    CharaInfo *info = gCharaManager.availableInfoForCharaId(charaId);
    m_skillInfo = (__bridge void *)info;
    m_skillData = GetSkillDataStruct((int)info.skillId);

    // Clear the 0x3c-byte selection-index scratch to -1 (Ghidra: memset +0x474).
    std::memset(&m_selScratch[0], 0xff, 0x3c);

    // Cache the fade-overlay quad extents + the screen scale (Ghidra:
    // FUN_0000f498 / FUN_0000f4a4 / DAT_00187b80).
    m_overlayW = aep.transitionOverlayWidth();
    m_overlayH = aep.transitionOverlayHeight();
    neSceneManager::shared();
    m_screenScale = neSceneManager::screenScale();

    computeStepValues(); // FUN_000a1950 — fills the per-skill step table at
                         // +0x578

    m_subMapId = tmp.subMapId;
    m_rankBadgeType = 0xff;

    // Seed the arcade RNG with wall-clock time (Ghidra: time(0) -> FUN_00062b5c).
    m_rng.setSeed((unsigned)time(nullptr));

    // Device-branched layout constants. this+0x5f7 == 0 is a phone; the extra
    // this+0x614/0x618 seed applies only to a tall (displayType 2) phone.
    const bool pad = (m_padDisplay != 0);
    if (!pad) {
        if ([[AppDelegate appDelegate] displayType] == 2) {
            m_layoutAnchorZ = 0x6a;
            m_field618 = 0x9e;
        }
        m_bgTileW = 0x280;
        m_bgTileH = 0x470;
        m_selSceneLayout[0] = 0x1a6;
        m_selSceneLayout[1] = -0x149;
        m_selSceneLayout[2] = 0xd0;
        m_selSceneLayout[3] = 0x8a;
        m_selSceneLayout[4] = 0x15;
        m_selSceneLayout[5] = -0xdd;
        m_selSceneLayout[6] = 0x9c;
        m_selSceneLayout[7] = 0x34;
        m_selSceneLayout[8] = 0x11;
        m_selSceneLayout[9] = 0xe9;
        m_selSceneLayout[10] = 0x1c1;
        m_selSceneLayout[13] = -0x7c;
        m_selSceneLayout[14] = 0xb4;
        m_selSceneLayout[15] = 0x7c;
        m_dlgLayoutA[0] = 0x94;
        m_dlgLayoutA[1] = 0x334;
        m_dlgLayoutA[2] = 0x168;
        m_dlgLayoutA[3] = 0x7d;
        m_dlgLayoutA[4] = 0x136;
        m_dlgLayoutA[5] = 0x2a8;
        m_dlgLayoutA[6] = 0x110;
        m_dlgLayoutA[7] = 0x60;
        m_dlgLayoutA[8] = 0x22;
        m_dlgLayoutA[9] = 0x2a8;
        m_dlgLayoutA[10] = 0x110;
        m_dlgLayoutA[11] = 0x60;
        m_dlgPanelW = 0x1dc;
        m_dlgPanelH = 0xe2;
        m_dlgBtn1X = 0xf5;
        m_dlgBtn1Y = 0x70;
        m_dlgBtn1W = 0xe6;
        m_dlgBtn1H = 0x5c;
        m_dlgBtn2X = 5;
        m_dlgBtn2Y = 0x70;
        m_dlgBtn2W = 0xe6;
        m_dlgBtn2H = 0x5c;
        m_dlgLayout954 = 0x20;
        m_dlgLayoutB[0] = 0;
        m_dlgLayoutB[1] = 0;
        m_dlgLayoutB[2] = 0x8c;
        m_dlgLayoutB[3] = 0x50;
        m_dlgLayoutB[4] = 0;
        m_dlgLayoutB[5] = 0;
        m_dlgLayoutB[6] = 0x8c;
        m_dlgLayoutB[7] = 0x50;
        m_dlgLayoutB[8] = 0;
        m_dlgLayoutB[9] = 0;
        m_dlgLayoutB[10] = 0x8c;
        m_dlgLayoutB[11] = 0x50;
        m_dlgLayoutB[12] = 0xcd;
        m_dlgLayoutB[13] = m_layoutAnchorZ + 0x35a;
        m_dlgLayoutB[14] = 0xf0;
        m_dlgLayoutB[15] = 0x5c;
    } else {
        m_bgTileW = 0x300;
        m_bgTileH = 0x400;
        m_selSceneLayout[0] = 0x4de;
        m_selSceneLayout[1] = -0xda;
        m_selSceneLayout[2] = 0x122;
        m_selSceneLayout[3] = 0xda;
        m_selSceneLayout[4] = 10;
        m_selSceneLayout[5] = -0x170;
        m_selSceneLayout[6] = 0xeb;
        m_selSceneLayout[7] = 0x5c;
        m_selSceneLayout[8] = 3;
        m_selSceneLayout[9] = 0x119;
        m_selSceneLayout[11] = 0x22f;
        m_selSceneLayout[12] = 0x345;
        m_selSceneLayout[13] = -0xba;
        m_selSceneLayout[14] = 0x116;
        m_selSceneLayout[15] = 0xba;
        m_dlgLayoutA[0] = 0xfe;
        m_dlgLayoutA[1] = 0x6b0;
        m_dlgLayoutA[2] = 0x168;
        m_dlgLayoutA[3] = 0x7d;
        m_dlgLayoutA[4] = 0x19e;
        m_dlgLayoutA[5] = 0x620;
        m_dlgLayoutA[6] = 0x110;
        m_dlgLayoutA[7] = 0x60;
        m_dlgLayoutA[8] = 0x88;
        m_dlgLayoutA[9] = 0x620;
        m_dlgLayoutA[10] = 0x110;
        m_dlgLayoutA[11] = 0x60;
        m_dlgPanelW = 0x329;
        m_dlgPanelH = 0x183;
        m_dlgBtn1X = 0x1b0;
        m_dlgBtn1Y = 0xd7;
        m_dlgBtn1W = 0x150;
        m_dlgBtn1H = 0x6e;
        m_dlgBtn2X = 0x22;
        m_dlgBtn2Y = 0xd7;
        m_dlgBtn2W = 0x150;
        m_dlgBtn2H = 0x6e;
        m_dlgLayout954 = 0x30;
        m_dlgLayoutB[0] = 0x119;
        const int y = m_overlayH - 0xba; // iVar5 in the decompile
        m_dlgLayoutB[1] = y;
        m_dlgLayoutB[2] = 0x116;
        m_dlgLayoutB[3] = 0xba;
        m_dlgLayoutB[4] = 0x22f;
        m_dlgLayoutB[5] = y;
        m_dlgLayoutB[6] = 0x116;
        m_dlgLayoutB[7] = 0xba;
        m_dlgLayoutB[8] = 0x345;
        m_dlgLayoutB[9] = y;
        m_dlgLayoutB[10] = 0x116;
        m_dlgLayoutB[11] = 0xba;
        m_dlgLayoutB[12] = 0x1ee;
        m_dlgLayoutB[13] = 0x5c8;
        m_dlgLayoutB[14] = 0x230;
        m_dlgLayoutB[15] = 0x8c;
    }

    buildSelectListLayout(); // FUN_000a21a8

    // Load the sugoroku asset group into slot 5 (Ghidra: FUN_0000f758).
    aep.loadAepDataDefaultPath(5, pad ? "sugoroku_ipad" : "sugoroku");

    setupResolveHandles();
    setupBuildOverlays();
    setupLoadTextures();

    // Prime the mode-select BGM (Ghidra: appAppSupportDirectory +
    // bgm01_modesel.m4a).
    NSString *bgmPath =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:@"bgm01_modesel.m4a"];
    if ([audio isPushBgm]) {
        [audio popBgm];
    }
    [audio loadBgm:bgmPath isLoop:YES];
    [audio setBgmVolume:[UserSettingData bgmVolume]];

    // Unlock the board-8 bonus treasure, load the pending map, seed its scroll,
    // then install the group-5 draw callback (Ghidra: FUN_000a345c / FUN_000a0b58
    // / FUN_000a3550 / FUN_0000f9b0 with the render routine FUN_000a3724).
    AcMainUnlockBonusTreasure();
    loadTreasureMap();
    refreshMapScroll(0);
    aep.setGroupDrawCallback(5, &AcMainSugorokuDraw, this);
}

// Resolve the ~50 layer / frame / user handle tables into the this+0x21c..
// arrays (Ghidra: the getLyrNo/layerFrameCount/getFrameNo/getUserNo loops of
// FUN_0009fc90). This hoists all of the binary's interleaved resolve loops ahead
// of the overlay construction; the handle resolves read only the loaded AEP and
// write task arrays, so the reorder is behaviour-preserving (loop counts,
// offsets, the pad-only BT_ROULETTE_MOVE gate, and the interleaved TRIANGLE00 /
// TRIANGLE01 pairing were all byte-verified).
// @complete
void AcMainTask::setupResolveHandles() {
    AepManager &aep = *m_aep;

    for (int i = 0; i < 5; i++) {
        const int lyr = aep.getLyrNo(5, kLyrSkillBoards[i]);
        m_skillBoardLyr[i] = lyr;
        m_skillBoardFrames[i] = aep.layerFrameCount(lyr);
    }
    for (int i = 0; i < 9; i++) {
        m_musicPeaceLyr[i] = aep.getLyrNo(5, kLyrMusicPeace[i]);
    }
    m_musicPeaceFrames = aep.layerFrameCount(m_musicPeaceLyr[0]);
    for (int i = 0; i < 9; i++) {
        m_wallPeaceLyr[i] = aep.getLyrNo(5, kLyrWallPeace[i]);
    }
    m_wallPeaceFrames = aep.layerFrameCount(m_wallPeaceLyr[0]);
    for (int i = 0; i < 4; i++) {
        const int lyr = aep.getLyrNo(5, kLyrIconMental[i]);
        m_iconMentalLyr[i] = lyr;
        m_iconMentalFrames[i] = aep.layerFrameCount(lyr);
    }

    for (int i = 0; i < 26; i++) {
        m_boardFrame[i] = aep.getFrameNo(5, kFrmBoard[i]);
    }
    for (int i = 0; i < 11; i++) {
        m_base1Frame[i] = aep.getFrameNo(5, kFrmBase1[i]);
    }
    if (m_padDisplay != 0) { // pad only
        m_rouletteMoveFrame = aep.getFrameNo(5, "BT_ROULETTE_MOVE");
    }
    for (int i = 0; i < 10; i++) {
        m_base08Frame[i] = aep.getFrameNo(5, kFrmBase08[i]);
    }
    for (int i = 0; i < 4; i++) {
        m_base05Frame[i] = aep.getFrameNo(5, kFrmBase05[i]);
    }
    for (int i = 0; i < 6; i++) { // interleaved TRIANGLE00 / TRIANGLE01
        m_triangle0Frame[i] = aep.getFrameNo(5, kFrmTriangle0[i]);
        m_triangle1Frame[i] = aep.getFrameNo(5, kFrmTriangle1[i]);
    }

    for (int i = 0; i < 26; i++) {
        m_boardUserNo[i] = aep.getUserNo(5, kUsrBoard[i]);
    }
}

// Build the ~35 AepLyrCtrl overlay objects (roulette / arrows / panels), then
// apply the by-hand tweaks the scene makes to a couple of roulette layers
// (Ghidra: the operator_new(0x60)+ctor+init loops of FUN_0009fc90 and the
// +0x3c/+0x44/+0x18/+0x1c stores). Counts (29/4/8), store bases
// (+0x2c/+0xc0/+0xa0), the order tables, the pad panel-skip and tall-name
// selection, the roulette[1]/[3] frameCount/playSpeed tweak, and the eight
// anchor indices were byte-verified against disassembly and the order globals.
// @complete
void AcMainTask::setupBuildOverlays() {
    const bool pad = (m_padDisplay != 0);

    // 29 roulette layers -> +0x2c: new(0x60)+ctor+init(5, name, owner=this,
    // order).
    for (int i = 0; i < 29; i++) {
        AepLyrCtrl *layer = new AepLyrCtrl();
        m_rouletteLayers[i] = layer;
        layer->init(5, kRouletteNames[i], this, kRouletteOrder[i]);
    }
    // 4 arrows -> +0xc0, order 0x1d.
    for (int i = 0; i < 4; i++) {
        AepLyrCtrl *layer = new AepLyrCtrl();
        m_arrowLayers[i] = layer;
        layer->init(5, kArrowNames[i], this, 0x1d);
    }
    // 8 select panels -> +0xa0. The tall-phone name table is used only for a tall
    // (displayType 2) phone; on a pad the two COLLECTION_SELECT panels (i == 4/5)
    // are skipped entirely.
    const bool tall = ([[AppDelegate appDelegate] displayType] == 2) && !pad;
    const char *const *panelNames = tall ? kPanelNamesTall : kPanelNamesDefault;
    for (int i = 0; i < 8; i++) {
        if (!pad || (i != 4 && i != 5)) {
            AepLyrCtrl *layer = new AepLyrCtrl();
            m_panelLayers[i] = layer;
            layer->init(5, panelNames[i], this, kPanelOrder[i]);
        }
    }

    // Hand-tune two roulette layers: shorten roulette[1] by one frame and set
    // roulette[3] to (roulette[1] original length - 2) at 0.8 alpha.
    AepLyrCtrl *roul1 = m_rouletteLayers[1]; // roulette index 1
    AepLyrCtrl *roul3 = m_rouletteLayers[3]; // roulette index 3
    const int roul1Frames = roul1->frameCount();
    roul1->frameCount() = roul1Frames - 1;
    roul3->frameCount() = roul1Frames - 2;
    roul3->playSpeed() = 0.8f; // 0x3f4ccccd

    // Anchor eight specific roulette layers to the layout base (origin x cleared
    // @ +0x18, origin y = raw m_layoutAnchorZ @ +0x1c); indices derived from the
    // +0x18/+0x1c store offsets.
    static const int kAnchorIndex[8] = {8, 9, 5, 6, 10, 11, 12, 14};
    const int anchor = m_layoutAnchorZ;
    for (int i = 0; i < 8; i++) {
        m_rouletteLayers[kAnchorIndex[i]]->setRouletteAnchor(anchor);
    }
}

// Load the scene's textures: the two bundled circles, the active character's
// board sprite, the three 10-digit number sets, and the 12 event icons (Ghidra:
// the operator_new(0x18)+ctor+load blocks of FUN_0009fc90). The number-set
// names came from verified CFString tables (PTR_cf_num_points0 /
// PTR_cf_num_roulette_0 / PTR_cf_ticket_num0); they are literal
// "num_points0".."9" etc. (the binary passes those literal CFString arrays; the
// stringWithFormat regeneration below yields the identical names). Store offsets
// (+0xd4/+0xe4/+0xdc/+0xfc/+0x124/+0x14c/+0x1ec), the per-iteration digit order,
// and the "event_0_%03d@2x" ×12 loop were byte-verified against disassembly.
// @complete
void AcMainTask::setupLoadTextures() {
    NSBundle *bundle = [NSBundle mainBundle];

    // circle / blind_circle -> +0xd4 / +0xe4.
    neTextureForiOS *circleTex = new neTextureForiOS();
    m_circleTex = circleTex;
    circleTex->load([[bundle pathForResource:@"circle" ofType:@"png"] UTF8String]);

    neTextureForiOS *blindTex = new neTextureForiOS();
    m_blindCircleTex = blindTex;
    blindTex->load([[bundle pathForResource:@"blind_circle" ofType:@"png"] UTF8String]);

    // The active character's board sprite from the downloadable support dir ->
    // +0xdc.
    neTextureForiOS *charaTex = new neTextureForiOS();
    m_charaTex = charaTex;
    NSString *charaFile =
        [NSString stringWithFormat:@"sugo_chara%03d.png", (int)[UserSettingData charaId]];
    NSString *charaPath =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:charaFile];
    charaTex->load([charaPath UTF8String]);

    // 10 digit glyphs each for points (+0xfc), roulette (+0x124) and ticket
    // (+0x14c).
    for (int i = 0; i < 10; i++) {
        neTextureForiOS *pointsTex = new neTextureForiOS();
        m_pointsDigitTex[i] = pointsTex;
        pointsTex->load([[bundle pathForResource:[NSString stringWithFormat:@"num_points%d", i]
                                          ofType:@"png"] UTF8String]);

        neTextureForiOS *roulTex = new neTextureForiOS();
        m_roulDigitTex[i] = roulTex;
        roulTex->load([[bundle pathForResource:[NSString stringWithFormat:@"num_roulette_%d", i]
                                        ofType:@"png"] UTF8String]);

        neTextureForiOS *ticketTex = new neTextureForiOS();
        m_ticketDigitTex[i] = ticketTex;
        ticketTex->load([[bundle pathForResource:[NSString stringWithFormat:@"ticket_num%d", i]
                                          ofType:@"png"] UTF8String]);
    }

    // 12 event icons ("event_0_%03d@2x") -> +0x1ec.
    for (int i = 0; i < 12; i++) {
        neTextureForiOS *eventTex = new neTextureForiOS();
        m_eventTex[i] = eventTex;
        eventTex->load([[bundle pathForResource:[NSString stringWithFormat:@"event_0_%03d@2x", i]
                                         ofType:@"png"] UTF8String]);
    }
}

// ===========================================================================
// loadTreasureMap — Ghidra FUN_000a0b58. Load the pending sugoroku map,
// snapshot the record + progress, rebuild the board scroll, and push the board
// BGM.
// ===========================================================================

// Ghidra: FUN_000ce1a8 — the "read count" (number of board-story pages) for a
// sugoroku sub-map. Only boards 6x and 8x (sub 0..2) have pages; everything
// else is 0. Tables byte-verified at DAT_0012fb90 / DAT_0012fb9c.
// @complete
static int TreasureReadCount(short subMapId) {
    static const int kBoard6[3] = {41, 35, 47}; // DAT_0012fb90
    static const int kBoard8[3] = {64, 72, 71}; // DAT_0012fb9c
    const int board = subMapId / 10;
    const int sub = subMapId - board * 10;
    if (board == 8) {
        if ((unsigned)sub < 3) {
            return kBoard8[sub];
        }
    } else if (board == 6 && (unsigned)sub < 3) {
        return kBoard6[sub];
    }
    return 0;
}

// Sub-map board number (subMapId/10) -> board-background / board-BGM asset
// numbers. Only indices 0..4 and 7 are reachable (the 0x9f bitmask gate); both
// tables are the identity there. Byte-verified at DAT_0012f934 / DAT_0012f946.
static const short kMapBgNumber[9] = {0, 1, 2, 3, 4, -1, -1, 7, -1};
static const short kMapBgmNumber[9] = {0, 1, 2, 3, 4, 0, 6, 7, 8};

void AcMainTask::loadTreasureMap() {
    const short subMapId = m_subMapId;
    if (subMapId < 0) {
        return; // nothing pending (subMapId == -1)
    }

    // Drop the previous owned-character working copy (+0x630, +1 retained).
    if (m_gotCharaArray) {
        (void)(__bridge_transfer id)m_gotCharaArray;
        m_gotCharaArray = nullptr;
    }

    const int bgIndex = subMapId / 10; // board number (Ghidra: local_110)

    // Reset the per-map play flags + counters.
    std::memset(&m_selScratch[0], 0xff, 0x3c);
    m_flag5ec = 0;
    m_flag5ed = 0;
    m_bgmActive = 1;
    m_field5f3 = 0;
    // The binary zeroes +0x5ef with one 32-bit store (Ghidra loadTreasureMap
    // @ 0xa0c34: str.w r1(=0), [r4,#0x5ef]); it spans these four named bytes.
    m_warpFlash = 0;
    m_warpAnim = 0;
    _rsvd_5f1[0] = 0;
    m_scrolledPastEnd = 0;

    // Re-snapshot player progress.
    m_treasurePoint = [UserSettingData treasurePoint];
    m_charaTicket = [UserSettingData charaTicket];
    m_gotCharaArray = (__bridge_retained void *)[[UserSettingData gotCharaArray] mutableCopy];
    m_charaId = [UserSettingData charaId];
    m_rankBadgeType = 0xff;
    m_friendOpacity = 100;

    // Board-story read progress (Ghidra: FUN_000ce1a8 count, then
    // treasureReadNo:).
    const int readCount = TreasureReadCount(subMapId);
    m_readCount = readCount;
    if (readCount < 1) {
        m_readNo = -1;
    } else {
        m_readNo = [UserSettingData treasureReadNo:subMapId];
    }

    // Stop every scene layer built by setupScene before the map rebuild (Ghidra:
    // the FUN_0002cb5c loops over the roulette / panel / arrow slots + the bg
    // layer).
    for (AepLyrCtrl *l : m_rouletteLayers) {
        if (l) {
            l->stopPlay(); // 29 roulette
        }
    }
    for (AepLyrCtrl *l : m_panelLayers) {
        if (l) {
            l->stopPlay(); // 8 panels
        }
    }
    for (AepLyrCtrl *l : m_arrowLayers) {
        if (l) {
            l->stopPlay(); // 4 arrows
        }
    }
    if (m_boardBgLayer) {
        m_boardBgLayer->stopPlay();
    }

    // Re-read the pending record (its non-position fields are copied in below).
    TreasureTmpData tmp = [UserSettingData treasureTmp];

    // Free the previous map object (Ghidra: FUN_000ce2e4 pre-step + dtor
    // FUN_000ce330
    // + operator delete; modelled as `delete`).
    if (TreasureMap *old = m_map) {
        delete old;
        m_map = nullptr;
    }

    // Load "map_%03d.map" for this sub-map.
    NSString *mapName = [NSString stringWithFormat:@"map_%03d", (int)subMapId];
    NSString *mapPath = [[NSBundle mainBundle] pathForResource:mapName ofType:@"map"];
    TreasureMap *map = new TreasureMap(); // FUN_000ce2b0
    m_map = map;
    map->load([mapPath UTF8String]); // FUN_000ce340

    // Copy the map header into play data.
    const int nodeCount = map->nodeCount();
    m_nodeCount = (uint16_t)nodeCount;
    m_nodes = map->nodes();
    m_edgeCount = map->field5c();
    m_edgesPtr = map->field58();

    // Choose the current board position: the pending record's node id, or the
    // map's start node when it is out of range (id <= 0 or >= node count).
    if (tmp.raw0x04 <= 0 || tmp.raw0x04 >= nodeCount) {
        tmp.raw0x04 = map->startSubId();
    }

    // Current node screen origin (tile size 0x1a == 26 px) + the "reached" flag.
    const TreasureMap::Node *cur = map->findArea(tmp.raw0x04); // FUN_000ce934
    m_curNode = cur;
    m_playerX = (float)((cur ? cur->x : 0) * 0x1a);
    m_playerY = (float)((cur ? cur->y : 0) * 0x1a);
    m_boardMoveState = (tmp.raw0x10 == 2) ? (unsigned)tmp.raw0x10 : 0u;
    m_bonusCount = tmp.mainMapId;
    m_treasureRaw06 = tmp.raw0x06;
    std::memcpy(&m_boardVisited[0], tmp.raw0x35,
                15); // board-visited bitmap (0x894..0x8a2)

    // --- Scroll bounding box + rubber-band clamp (Ghidra: the NEON block at
    // 0xa0f88..0xa10d2). The node bounding box gives the board content rect;
    // the camera scroll position is then clamped into a rect inset by half the
    // transition-overlay viewport (+0x524/+0x528) and padded by fixed margins.
    // The four box lanes {originX, originY, contentW, contentH} are converted
    // together (vcvt.f32.s32 q1, q8) and stored at +0x4c8. Tile size 26; content
    // padding +104 (x) / +128 (y); the ±268 X pan margin is DAT_000a1290
    // (-268 / +268); the device Y margins are DAT_000a148c..0xa1498.
    const TreasureMap::Node *nodes = map->nodes();
    int minX = 0, maxX = 0, minY = 0, maxY = 0;
    if (nodes && nodeCount > 0) {
        minX = maxX = nodes[0].x;
        minY = maxY = nodes[0].y;
        for (int i = 1; i < nodeCount; i++) {
            const int x = nodes[i].x, y = nodes[i].y;
            if (x > maxX) {
                maxX = x;
            }
            if (x < minX) {
                minX = x;
            }
            if (y > maxY) {
                maxY = y;
            }
            if (y < minY) {
                minY = y;
            }
        }
    }
    const float originX = (float)(minX * 0x1a);
    const float originY = (float)(minY * 0x1a);
    const float contentW = (float)((maxX - minX) * 0x1a + 0x68); // +104
    const float contentH = (float)((maxY - minY) * 0x1a + 0x80); // +128
    m_scrollBoxOriginX = originX;
    m_scrollBoxOriginY = originY;
    m_scrollBoxW = contentW;
    m_scrollBoxH = contentH;

    const float halfW = (float)(m_overlayW / 2);
    const float halfH = (float)(m_overlayH / 2);
    const bool pad = (m_padDisplay != 0);
    const float marginTop = pad ? 380.0f : 480.0f; // DAT_000a148c / DAT_000a1490
    const float marginBot = pad ? 480.0f : 300.0f; // DAT_000a1494 / DAT_000a1498

    // Clamp centres/edges. The max centre and max Y are floored at the min
    // centre / min Y (the vcmpe/vmov.mi rubber-band that keeps the range valid
    // when the content is narrower or shorter than the viewport).
    const float minCentreX = originX + halfW - 268.0f;
    const float maxCentreX = originX + contentW - halfW + 268.0f;
    const float clampMinY = originY + halfH - marginTop;
    const float clampMaxY = std::max(originY + contentH - halfH + marginBot, clampMinY);
    m_clampCentreX = minCentreX;
    m_clampCentreX2 = std::max(maxCentreX, minCentreX);
    m_clampMinY = clampMinY;
    m_clampMaxY = clampMaxY;

    // Scroll position: the current node's pixel position (tile 26, +52 x / +64 y
    // biases), clamped into [minCentreX, maxCentreX] x [clampMinY, clampMaxY].
    const float scrollXRaw = (float)((cur ? cur->x : 0) * 0x1a + 0x34); // +52
    const float scrollYRaw = (float)((cur ? cur->y : 0) * 0x1a + 0x40); // +64
    m_scrollX = std::min(std::max(scrollXRaw, minCentreX), m_clampCentreX2);
    m_scrollY = std::min(std::max(scrollYRaw, clampMinY), clampMaxY);
    unloadMapBgGroup(); // FUN_000a4e84 — drop the previous board bg before
                        // loading the new one

    // --- Board background: load the board-bg layer group + build its AepLyrCtrl.
    // Only reachable board indices (bit set in the 0x9f mask) get a background.
    if ((0x9f >> (bgIndex & 0xff)) & 1) {
        NSString *bgGroupName;
        NSString *bgLoopName;
        if (!pad) {
            bgGroupName =
                [NSString stringWithFormat:@"sugoroku_bg%02d", (int)kMapBgNumber[bgIndex]];
            bgLoopName =
                ([[AppDelegate appDelegate] displayType] == 2) ? @"BG_LOOP1136" : @"BG_LOOP960";
        } else {
            bgGroupName =
                [NSString stringWithFormat:@"sugoroku_bg%02d_ipad", (int)kMapBgNumber[bgIndex]];
            bgLoopName = @"BG_LOOP";
        }
        AepManager &aep = *m_aep;
        aep.loadAepDataDefaultPath(6, [bgGroupName UTF8String]); // FUN_0000f758 slot 6
        AepLyrCtrl *bgLayer = new AepLyrCtrl();
        m_boardBgLayer = bgLayer;
        bgLayer->init(6, [bgLoopName UTF8String], this, 0x24);
    }

    // Board-bg texture (+0xd8): "sugoroku_bg%02d(~iPad)" for this board index.
    if (neTextureForiOS *oldBg = m_boardBgTex) {
        delete oldBg;
        m_boardBgTex = nullptr;
    }
    neTextureForiOS *bgTex = new neTextureForiOS();
    m_boardBgTex = bgTex;
    NSString *bgTexName = pad ? [NSString stringWithFormat:@"sugoroku_bg%02d~iPad", bgIndex] :
                                [NSString stringWithFormat:@"sugoroku_bg%02d", bgIndex];
    bgTex->load([[[NSBundle mainBundle] pathForResource:bgTexName ofType:@"png"] UTF8String]);

    // Remaining record fields + the board character/panel builders.
    m_rouletteMode = tmp.raw0x44;
    m_field8b8 = (char)tmp.raw0x52;
    m_field8b9 = (char)tmp.raw0x51;
    buildMapCharaLayers(); // FUN_000a2264
    buildMapPanelLayers(); // FUN_000a2650

    // Cache the map's display name (+0x944, +1 retained), replacing any previous.
    if (m_mapName) {
        (void)(__bridge_transfer id)m_mapName;
        m_mapName = nullptr;
    }
    m_mapName = (__bridge_retained void *)[NSString stringWithUTF8String:(const char *)tmp.raw0x28];

    // Push + load the board treasure BGM ("bgm04_tre_%02d.m4a").
    AudioManager *audio = [AudioManager sharedManager];
    NSString *bgmName =
        [NSString stringWithFormat:@"bgm04_tre_%02d.m4a", (int)kMapBgmNumber[bgIndex]];
    NSString *bgmPath =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:bgmName];
    [audio pushBgm];
    [audio loadBgm:bgmPath isLoop:YES];
    m_boardBgmLoaded = 0xff;
}

// ===========================================================================
// computeStepValues — Ghidra FUN_000a1950. Fill the 7-entry per-skill "steps"
// table at +0x578. The board-visited flags at +0x894 / +0x895 pick a base value
// per index; the current roulette mode (short @ +0x8ac) then overrides (modes
// 0..6 -> a fixed 1..7) or scales it (mode 0xe -> x2, mode 0xf -> x3). Any
// other mode leaves the board-derived base unchanged.
// ===========================================================================

// Byte-verified base tables (both are word/int arrays: the loads at 0xa1976 /
// 0xa1986 are `ldr.w`, not byte loads — Ghidra mistyped the first as
// undefined1).
//   +0x894 >= 1 -> kStepBoardA (DAT_0012f97c, verified 0x12f97c)
//   +0x895 >= 1 -> kStepBoardB (UNK_0012f998, verified 0x12f998)
static const int kStepBoardA[7] = {1, 2, 1, 3, 1, 2, 3};
static const int kStepBoardB[7] = {4, 5, 4, 6, 4, 5, 6};

// @complete
void AcMainTask::computeStepValues() {
    for (int i = 0; i < 7; i++) {
        // Board-derived base (computed for every index, though modes 0..6 discard
        // it below — matching the binary, which evaluates the base before the tbb).
        int value;
        if ((signed char)m_boardVisited[0] >= 1) {
            value = kStepBoardA[i];
        } else if ((signed char)m_boardVisited[1] >= 1) {
            value = kStepBoardB[i];
        } else {
            value = i + 1;
        }

        switch (m_rouletteMode) {
        case 0:
            value = 1;
            break;
        case 1:
            value = 2;
            break;
        case 2:
            value = 3;
            break;
        case 3:
            value = 4;
            break;
        case 4:
            value = 5;
            break;
        case 5:
            value = 6;
            break;
        case 6:
            value = 7;
            break;
        case 0xe:
            value = value << 1;
            break; // double
        case 0xf:
            value = value * 3;
            break; // triple
        default:
            break; // modes 7..0xd and >0xf keep the base
        }

        m_stepValues[i] = value;
    }
}

// ===========================================================================
// buildSelectListLayout — Ghidra FUN_000a21a8. Despite the declared name this
// loads the 15 roulette / board sound effects into the SE-handle table at
// +0x438 (one loadSe per name). Only se12_roulturn (index 1) is looped;
// callName is nil and the SE group is 1.
// @complete
// ===========================================================================

// Byte-verified SE resource names (Ghidra: PTR_cf_se11_roulapp_00132ae0, an
// array of 15 ASCII CFStrings, dataPtrs verified contiguous @ 0x10a6a4). Note
// the two warp variants (se17_warp AND se17b_warp) and the gap from se23
// straight to se25.
static const char *const kRouletteSeNames[15] = {"se11_roulapp",
                                                 "se12_roulturn",
                                                 "se13_roulstop",
                                                 "se14_move",
                                                 "se15_skill",
                                                 "se16_wana",
                                                 "se17_warp",
                                                 "se17b_warp",
                                                 "se18_shield",
                                                 "se19_peace",
                                                 "se20_peaceopen",
                                                 "se21_itemget",
                                                 "se22_goal",
                                                 "se23_gacha",
                                                 "se25_quiz_x"};

// @ 0xe2c54 — roulette result-item caption by index (nullptr when index >= 12).
// The sugoroku roulette-result draw (AcMainSugorokuDraw, FUN_000a3724) looks
// the hit item's description up here. Byte-verified from the 12-entry const
// table PTR_s__00133fac (its UTF-8 string pointers @ 0x115434..0x1156b4).
// @complete
static const char *getStringByIndex12(unsigned index) {
    static const char *const kItemDescriptions[12] = {
        u8"ルーレットが超ゆっくりになるよ♪ 狙った目を出すチャンス！",
        u8"ルーレットがゆっくりになるよ♪ 狙った目を出すチャンス！",
        u8"進むマスがマップから消えるよ♪",
        u8"戻るマスがマップから消えるよ♪",
        u8"一時停止マスがマップから消えるよ♪",
        u8"マップから全ての罠マスが消えるよ♪",
        u8"マップから赤色の罠マスが消えるよ♪",
        u8"マップから青色の罠マスが消えるよ♪",
        u8"マップから緑色の罠マスが消えるよ♪",
        u8"マップから黄色の罠マスが消えるよ♪",
        u8"ゴールでタッチサウンドが貰える確率がアップ♪",
        u8"ルーレットに必要なトレジャーポイントが少なくなるよ♪",
    };
    if (index < 12) {
        return kItemDescriptions[index];
    }
    return nullptr;
}

void AcMainTask::buildSelectListLayout() {
    AudioManager *audio = [AudioManager sharedManager];
    for (int i = 0; i < 15; i++) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@(kRouletteSeNames[i])
                                                         ofType:@"m4a"];
        m_rouletteSe[i] = (int)[audio loadSe:path isLoop:(i == 1) callName:nil group:1];
    }
}

// ===========================================================================
// buildMapCharaLayers — Ghidra FUN_000a2264 (called by loadTreasureMap).
// Rebuild the per-board music / wallpaper "piece" unlock tables from the
// persisted Core Data TreasureData records, then OR in the pending record's own
// masks for the current board.
//
// The tables live at this+0x28 + {0x6b4, 0x720, 0x78c, 0x7f8}, i.e.
// this-relative +0x6dc (music), +0x748 (wallpaper), +0x7b4 (music dup) and
// +0x820 (wallpaper dup). Each is a 9x3 int grid indexed by mainMapId*0xc +
// subMapId*4 (mainMapId is the board 0..8, subMapId the 0..2 sub-index). The
// binary writes the music and wallpaper values into BOTH their primary and
// duplicate tables each iteration.
// @complete
// ===========================================================================
void AcMainTask::buildMapCharaLayers() {
    TreasureTmpData tmp = [UserSettingData treasureTmp];

    // The binary only zeroes the first two tables (0xd8 bytes @ +0x6dc); the two
    // duplicate tables are left to be overwritten row-by-row. Reproduce exactly.
    std::memset(&m_musicPieceTable[0], 0, 0xd8);

    NSArray<TreasureData *> *all =
        [TreasureData getAllTreasureData:[[AppDelegate appDelegate] managedObjectContext]];
    for (TreasureData *rec in all) {
        const int idx = rec.mainMapId.intValue * 0xc + rec.subMapId.intValue * 4;
        const int music = rec.musicPiece.intValue;
        const int wall = rec.wallPaperPiece.intValue;
        m_musicPieceTable[idx / 4] = music;    // music table
        m_wallPieceTable[idx / 4] = wall;      // wallpaper table
        m_musicPieceTableDup[idx / 4] = music; // music table (duplicate, as the binary writes)
        m_wallPieceTableDup[idx / 4] = wall;   // wallpaper table (duplicate)
    }

    // OR the pending record's own unlock masks into the current board's slot. The
    // binary computes the index straight from the board-encoded subMapId
    // (+0x620): (sm/10)*-0x1c + sm*4, which is exactly (sm/10)*0xc + (sm%10)*4
    // for sm >= 0.
    const short sm = m_subMapId;
    const int curIdx = (sm / 10) * -0x1c + sm * 4;
    reinterpret_cast<uint32_t &>(m_musicPieceTable[curIdx / 4]) |=
        (uint32_t)tmp.raw0x08; // music mask
    reinterpret_cast<uint32_t &>(m_wallPieceTable[curIdx / 4]) |=
        (uint32_t)tmp.raw0x0c; // wallpaper mask
}

// ===========================================================================
// buildMapPanelLayers — Ghidra FUN_000a2650 (called by loadTreasureMap).
// Despite the declared name this (re)loads the goal-character portrait texture
// into +0xe0. The whole rebuild is gated by the high byte of the pending
// record's raw0x4d field (offset 0x50): when it is non-zero the routine is a
// no-op. Otherwise it frees any previous texture and, if a goal character is
// present (raw0x20[0] != 0), loads "sugo_chara%03d.png" for chara id raw0x12
// from the app-support directory.
// @complete
// ===========================================================================
void AcMainTask::buildMapPanelLayers() {
    TreasureTmpData tmp = [UserSettingData treasureTmp];

    // Byte 3 of raw0x4d (record offset 0x50) is the enable gate (Ghidra:
    // field19_0x4d._3_1_). Non-zero -> leave the current texture untouched.
    if ((uint8_t)((uint32_t)tmp.raw0x4d >> 24) != 0) {
        return;
    }

    // Free the previously loaded portrait (Ghidra: the vtable[1] deleting dtor).
    if (neTextureForiOS *old = m_goalCharaTex) {
        delete old;
        m_goalCharaTex = nullptr;
    }

    // No goal character on this record -> nothing more to load.
    if (tmp.raw0x20[0] == 0) {
        return;
    }

    neTextureForiOS *tex = new neTextureForiOS();
    m_goalCharaTex = tex;
    NSString *file = [NSString stringWithFormat:@"sugo_chara%03d.png", (int)(short)tmp.raw0x12];
    NSString *path = [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:file];
    tex->load([path UTF8String]);
}

// ===========================================================================
// AcMainUnlockBonusTreasure — Ghidra FUN_000a345c. Called from setupScene()
// before the map load. Unlock the board-8 / sub-0 bonus treasure record once
// the player owns the prerequisite purchased songs: at least one song from
// group A AND at least one from group B must be present on disk (their
// purchased ".orb" file exists).
// ===========================================================================

// Byte-verified prerequisite song ids (Ghidra: DAT_0012f9e0 / DAT_0012f9f0,
// each four consecutive int32 ids). getPathFromPurchased: is queried per id and
// probed on disk.
static const int kBonusPrereqSongsA[4] = {
    // DAT_0012f9e0
    200000204,
    200000205,
    200000206,
    200000207 // 0x0bebc2cc..0x0bebc2cf
};
static const int kBonusPrereqSongsB[4] = {
    // DAT_0012f9f0
    200000208,
    200000209,
    200000210,
    200000211 // 0x0bebc2d0..0x0bebc2d3
};

// @complete
void AcMainUnlockBonusTreasure() {
    NSManagedObjectContext *context = [[AppDelegate appDelegate] managedObjectContext];

    // Already unlocked (board 8, sub 0)? Nothing to do.
    if ([TreasureData getTreasureData:8 subMapId:0 inManagedObjectContext:context] != nil) {
        return;
    }

    // The binary dispatches getPathFromPurchased: straight on the MusicManager
    // classref
    // (@ 0x15be34); the existing MusicManager reconstruction models it as an
    // instance method on the singleton, so query it through getInstance to stay
    // consistent.
    MusicManager *music = [MusicManager getInstance];

    // Require any one purchased song from group A to be present first.
    for (int i = 0; i < 4; i++) {
        NSString *pathA = [music getPathFromPurchased:kBonusPrereqSongsA[i]];
        if (!RhFileExists(pathA)) {
            continue;
        }
        // Group A satisfied: now require any one from group B as well.
        for (int j = 0; j < 4; j++) {
            NSString *pathB = [music getPathFromPurchased:kBonusPrereqSongsB[j]];
            if (RhFileExists(pathB)) {
                [TreasureData addRecordWithMainMapId:8 subMapId:0 inManagedObjectContext:context];
                return;
            }
        }
        // Group A present but no group-B song owned — the binary stops after the
        // first matching group-A song (it does not keep scanning group A).
        return;
    }
}

// The map's 9 music panels are laid out in a fixed non-sequential order; this
// maps a panel's display slot to its index in the treasure-music array. Ghidra:
// FUN_000ce0c8 (linear search of DAT_0012faa0, byte-verified
// {0,3,4,5,6,1,2,7,8}).
// @complete
static int MapPanelOrder(int displaySlot) {
    static const int kOrder[9] = {0, 3, 4, 5, 6, 1, 2, 7, 8};
    for (int i = 0; i < 9; i++) {
        if (kOrder[i] == displaySlot) {
            return i;
        }
    }
    return -1;
}

// Ghidra: FUN_000a3550. Despite the seam name, this reloads the 9 jacket
// textures for the map's music panels: drop the old textures (+0x1a4[9]) and
// the cached song array
// (+0x640), re-fetch the treasure-music list, then load each visible panel's
// artwork (the panels are drawn in the MapPanelOrder permutation). `mode` pages
// the list (only page 0 fits the 9 panels, matching the < 9 guard).
// @complete
void AcMainTask::refreshMapScroll(int mode) {
    for (int i = 0; i < 9; i++) {
        if (neTextureForiOS *tex = m_jacketTex[i]) {
            delete tex;
            m_jacketTex[i] = nullptr;
        }
    }
    if (m_treasureMusicArray) {
        (void)(__bridge_transfer id)m_treasureMusicArray;
        m_treasureMusicArray = nullptr;
    }

    NSArray<MusicData *> *songs = [[MusicManager getInstance] getTreasureMusicDataArray];
    m_treasureMusicArray = (__bridge_retained void *)songs;
    const int count = (int)songs.count;

    for (int slot = mode * 9; slot < count && slot < 9; slot++) {
        MusicData *md = songs[MapPanelOrder(slot)];
        neTextureForiOS *tex = new neTextureForiOS();
        m_jacketTex[slot] = tex;
        tex->loadFromImageData((__bridge const void *)[md artwork2xData]); // FUN_00011cbc
    }
}

// Ghidra: FUN_000a4e84 — unlink + delete the board background layer (+0xd0) and
// unload its asset group (6). loadTreasureMap calls this before loading the
// next board's bg.
// @complete
void AcMainTask::unloadMapBgGroup() {
    if (AepLyrCtrl *bg = m_boardBgLayer) {
        bg->unlink(); // FUN_0002ca9c
        delete bg;
        m_boardBgLayer = nullptr;
    }
    m_aep->releaseAepTexture(6); // FUN_0000f988
}

// Ghidra: a sibling of FUN_000a4e84 called from sugorokuTaskDispose. It
// unlink+deletes the board-background layer (+0xd0) and releases its AEP texture
// group via AepManager::releaseAepTexture(6) — exactly unloadMapBgGroup's body
// (verified faithful @ 0xa4e84: +0xd0 null-check, unlink @ 0x2ca9c, virtual
// delete, then releaseAepTexture(6) @ 0xf988). It delegates there rather than
// duplicate the body; both are null-checked and idempotent, matching the binary
// running both on teardown.
// @complete
void AcMainTask::sugorokuReleaseGoalLayer() {
    unloadMapBgGroup();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sugoroku board draw / logic helpers  (Ghidra 0xa14a0 – 0xa5740).
// All are file-static (anonymous namespace = internal linkage).  They were
// erroneously placed in a fabricated SugorokuMainTask class by a prior agent;
// they belong here, operating on AcMainTask *.
// ═══════════════════════════════════════════════════════════════════════════════

#import "TreasureTmpData.h"
#include <cmath>  // cosf, sinf, M_PI
#include <cstdio> // snprintf

namespace {

// ── sprite draw helper
// ──────────────────────────────────────────────────────── Reorders Ghidra
// call-site arg order  (u,v,w,h,x,y,sx,sy,ex,ey,extra,color,
// rotation,blend0,colorMul,blend1,priority) into neSpriteDrawParams field order
// (u,v,x,y,sx,sy,w,h,ex,ey,color,rotation,blend0,blend1,colorMul,extra,
// clip,priority).
void drawSprite(AepManager *mgr,
                neTextureForiOS *tex,
                int u,
                int v,
                int w,
                int h,
                int x,
                int y,
                int sx,
                int sy,
                int ex,
                int ey,
                int extra,
                int color,
                int rotation,
                int blend0,
                int colorMul,
                int blend1,
                int priority) {
    neSpriteDrawParams p;
    p.u = u;
    p.v = v;
    p.w = w;
    p.h = h;
    p.x = x;
    p.y = y;
    p.sx = sx;
    p.sy = sy;
    p.ex = ex;
    p.ey = ey;
    p.extra = extra;
    p.color = static_cast<uint32_t>(color);
    p.rotation = rotation;
    p.blend0 = static_cast<short>(blend0);
    p.colorMul = static_cast<uint32_t>(colorMul);
    p.blend1 = static_cast<short>(blend1);
    p.clip = nullptr;
    p.priority = priority;
    tex->draw(mgr->orderingTable(), p);
}

// ── cross-file helpers (TODO: promote to their own .h/.mm when decompiled) ───

// Ghidra: FUN_??? — 2-D AABB overlap cull used by sugorokuDrawBoard.
// Tests whether node box [x0..extX] × [y0..y1] overlaps camera rect
// [camL..camR] × [camT..camH].  The call site passes x0 twice (NEON artefact);
// only x0, extX, y0 and y1 carry real information.
bool isWithinRange2D(float x0,
                     float /*x1*/,
                     float extX,
                     float y0,
                     float y1,
                     float camL,
                     float camT,
                     float camR,
                     float camH) {
    return x0 < camR && extX > camL && y0 < camH && y1 > camT;
}

// Ghidra: FUN_000a2... — maps a sugoroku square id to its wall-nail texture
// index via a fixed 9-entry lookup table (DAT_0012faa0 = {0,3,4,5,6,1,2,7,8});
// returns the matching index, or -1 when the id is not present. (Not identity —
// ids 1/2 and 3..6 are permuted, so the wall-nail sprite order differs from the
// raw id order.)
// @complete
short findTreasureMapIndexById(int id) {
    static const int kWallNailIdTable[9] = {0, 3, 4, 5, 6, 1, 2, 7, 8};
    for (int i = 0; i < 9; ++i) {
        if (kWallNailIdTable[i] == id) {
            return static_cast<short>(i);
        }
    }
    return -1;
}

// sugorokuReleaseGoalLayer is a real member (see above, next to
// unloadMapBgGroup) — it needs the task's private layer/aep, so it is a method,
// not a file-static helper.

// Ghidra: FUN_??? — the binary frees the TreasureMap's node/connect buffers
// (fields +0x14/+0x16) and re-zeroes its header before disposeTreasureMap runs.
// In this reconstruction that teardown is entirely owned by ~TreasureMap
// (reset(): it frees m_nodes/m_field58), which `delete m_map` in
// sugorokuTaskDispose invokes. Re-freeing them here would double-free, so this
// is intentionally folded into the destructor and the call site relies on
// `delete m_map` alone.

} // namespace

// ═══════════════════════════════════════════════════════════════════════════════
// Sugoroku board draw / logic — the group-5 render callback's inlined
// sub-passes. These operate on the arcade task's own work area, so they are
// real AcMainTask members (Ghidra placed them as free functions taking the task
// pointer; the declared "SugorokuMainTask" a prior agent invented was a
// mis-attribution).
// ═══════════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════════
// 1.  sugorokuDrawSkillPanel — Ghidra: FUN_000a14a0
// ════════════════════════════════════════════════════════════════════════════
// Draw the skill-selection overlay centred on the player sprite and return
// which button was tapped this frame: 0 = left button, 1 = right button,
// -1 = no hit.
//
// NOT @complete — touch handling deviates from the disassembly. Ghidra
// FUN_000a14a0 takes the touch point as its second parameter (r1, stored @
// sp+0x44) and performs a single tap-distance test on raw coordinates (0xa1674:
// x@+0xc, startX@+0x4; `subs; abs; cmp #0xa; bgt` reject when > 10 px), not the
// internal `activeTouchCount()`/`touchAt(i)` loop below. The binary's coords are
// raw pixels, so the `tp->x >> 16` shifts and the `11 << 16` thresholds here are
// wrong for this routine (the 16.16 handling was carried over from elsewhere).
// The AEP draw, DrawText labels, button geometry (iVar7-0xbb/iVar10-0xbc and
// iVar7+0x3f) and the 0/1/-1 returns were all verified faithful.
int AcMainTask::sugorokuDrawSkillPanel() {
    AepManager *mgr = m_aep;
    const neGraphics &gfx = neGraphics::shared();
    float scale = gfx.contentScale();

    // Player board → screen position.
    float scrollOffX = m_scrollX - m_scrollBaseX;
    float scrollOffY = m_scrollY - m_scrollBaseY;
    int halfW = m_overlayW / 2;
    int halfH = m_overlayH / 2;
    int iVar7 = (int)(m_playerX - scrollOffX + (float)halfW);
    int iVar10 = (int)(m_playerY - scrollOffY + (float)halfH);

    // Draw skill panel AEP art (FUN_000a14a0 step).
    drawAepFrame(mgr, m_skillBoardLyr[0], iVar7 + 52, iVar10 - 300, 0x20, 0x22);

    // Skill name label (from the active character's skill record).
    __unsafe_unretained id skillObj = (__bridge id)m_skillInfo;
    if (skillObj) {
        NSString *nameStr = [skillObj skillName];
        if (nameStr) {
            mgr->DrawText(
                [nameStr UTF8String], 0x1e, iVar7 + 52, iVar10 - 0x11a, 1, 100, 0x59514f, 0x13);
        }
    }

    // Skill-data name string (skillData[0]) + skill points (short at
    // skillData+4).
    const void *descPtr = m_skillData;
    if (descPtr) {
        __unsafe_unretained id skillDataName =
            *reinterpret_cast<__unsafe_unretained const id *>(descPtr);
        if (skillDataName) {
            mgr->DrawText([skillDataName UTF8String],
                          0x14,
                          iVar7 + 52,
                          iVar10 - 0xed,
                          1,
                          100,
                          0x59514f,
                          0x13);
        }

        int pts = *reinterpret_cast<const short *>(reinterpret_cast<const char *>(descPtr) + 4);
        char ptsBuf[16];
        snprintf(ptsBuf, sizeof(ptsBuf), "%d pt", pts);
        mgr->DrawText(ptsBuf, 0x12, iVar7 + 52, iVar10 - 0xca, 1, 100, 0xe10000, 0x13);
    }

    // Touch hit-test.
    float hw = 230.0f * scale, hh = 92.0f * scale;
    int n = gfx.activeTouchCount();
    for (int i = 0; i < n; i++) {
        const neTouchPoint *tp = gfx.touchAt(i);
        if (!tp || !tp->released) {
            continue;
        }
        int tx = tp->x >> 16; // 16.16 fixed-point → integer pixel
        int ty = tp->y >> 16;
        // Tap test: finger displacement < 11 px (coords are 16.16).
        int adx = tp->x - tp->startX;
        if (adx < 0) {
            adx = -adx;
        }
        int ady = tp->y - tp->startY;
        if (ady < 0) {
            ady = -ady;
        }
        // slop was hard-coded to 11px here; gate it like the other sites so the
        // faithful build keeps the binary's raw fixed 0xb (NE_TAP_SLOP).
        if (adx >= NE_TAP_SLOP(11) || ady >= NE_TAP_SLOP(11)) {
            continue;
        }
        // Button 1 (left).
        if (neGraphics::pointInRect(tx,
                                    ty,
                                    (int)((iVar7 - 0xbb) * scale),
                                    (int)((iVar10 - 0xbc) * scale),
                                    (int)hw,
                                    (int)hh)) {
            return 0;
        }
        // Button 2 (right).
        if (neGraphics::pointInRect(tx,
                                    ty,
                                    (int)((iVar7 + 0x3f) * scale),
                                    (int)((iVar10 - 0xbc) * scale),
                                    (int)hw,
                                    (int)hh)) {
            return 1;
        }
    }
    return -1;
}

// ════════════════════════════════════════════════════════════════════════════
// 2.  sugorokuDrawButtonHitTest — Ghidra: FUN_000a178c
// ════════════════════════════════════════════════════════════════════════════
// Draw a generic two-button dialog panel (layerId @ +0x220, layout data @
// +0x990..+0x9b4) and return: 1 = button 1 hit, -1 = button 2 hit, 0 = miss.
//
// NOT @complete — touch handling deviates from the disassembly, as with
// sugorokuDrawSkillPanel. Ghidra FUN_000a178c takes the touch point as its
// second parameter (r1, tested @ 0xa1810 on raw coords: `subs; abs; cmp #0xa;
// bgt` reject when > 10 px, returning -1) rather than looping over
// `activeTouchCount()`/`touchAt(i)`. The binary's coords are raw pixels, so the
// `tp->x >> 16` shifts here are wrong. The panel draw (drawLayer at
// overlayW/2, overlayH/2 - panelH/2, frame = panelW/2) and both button
// hit-rects (m_dlgBtn1*/m_dlgBtn2* @ +0x998..+0x9b4) were verified faithful.
int AcMainTask::sugorokuDrawButtonHitTest() {
    AepManager *mgr = m_aep;
    const neGraphics &gfx = neGraphics::shared();
    float scale = gfx.contentScale();

    int panelW = m_dlgPanelW;
    int panelH = m_dlgPanelH;
    int iVar5 = m_overlayW / 2;              // half-screen width
    int iVar6 = m_overlayH / 2 - panelH / 2; // panel top Y

    // Draw panel: AEP layer handle @ +0x220, frame = panelW/2.
    mgr->drawLayer(m_skillBoardLyr[1],
                   panelW / 2,
                   iVar5,
                   iVar6,
                   100,
                   100,
                   0,
                   0,
                   0,
                   100,
                   0,
                   0,
                   0x20,
                   0,
                   nullptr,
                   nullptr,
                   0x20,
                   1);

    // Touch hit-test.
    int n = gfx.activeTouchCount();
    for (int i = 0; i < n; i++) {
        const neTouchPoint *tp = gfx.touchAt(i);
        if (!tp || !tp->released) {
            continue;
        }
        int tx = tp->x >> 16;
        int ty = tp->y >> 16;
        // Button 1.
        if (neGraphics::pointInRect(tx,
                                    ty,
                                    (int)((iVar5 - panelW / 2 + m_dlgBtn1X) * scale),
                                    (int)((m_dlgBtn1Y + iVar6) * scale),
                                    (int)(m_dlgBtn1W * scale),
                                    (int)(m_dlgBtn1H * scale))) {
            return 1;
        }
        // Button 2.
        if (neGraphics::pointInRect(tx,
                                    ty,
                                    (int)((iVar5 - panelW / 2 + m_dlgBtn2X) * scale),
                                    (int)((m_dlgBtn2Y + iVar6) * scale),
                                    (int)(m_dlgBtn2W * scale),
                                    (int)(m_dlgBtn2H * scale))) {
            return -1;
        }
    }
    return 0;
}

// ════════════════════════════════════════════════════════════════════════════
// 3.  sugorokuEasePositionPairA — Ghidra: FUN_000a19dc
// ════════════════════════════════════════════════════════════════════════════
// Ease the scroll position (+0x4d8/+0x4dc) toward the target (+0x5a4/+0x5a8)
// using stored velocities (+0x5ac/+0x5b0).  Returns true while still moving.
// @complete
// Disasm 0xa19dc: the move/snap test compares the MAGNITUDE of the velocity
// against the MAGNITUDE of the remaining distance -- both operands pass through
// a conditional `vneg` (abs), so it is `|vel| < |target - pos|` (0xa19f0 vneg s0
// side, 0xa1a14 vneg d4 = target-pos side, then `vcmpe s2,s8` / `bpl` snap). The
// decompiler folds both abs into a single `-vel < pos-target`, which is a
// mis-sign; the abs form below is the faithful one. Under the arm-time invariant
// sign(vel) == sign(target-pos) the two forms disagree, so this matters.
bool AcMainTask::sugorokuEasePositionPairA() {
    // X axis.
    float velX = m_scrollVelX;
    float posX = m_scrollX;
    float targetX = m_scrollTargetX;
    if (std::fabs(velX) < std::fabs(targetX - posX)) {
        m_scrollX = posX + velX;
    } else {
        m_scrollX = targetX;
        m_scrollVelX = 0.0f;
        velX = 0.0f;
    }
    // Y axis.
    float velY = m_scrollVelY;
    float posY = m_scrollY;
    float targetY = m_scrollTargetY;
    bool yDone;
    if (std::fabs(velY) < std::fabs(targetY - posY)) {
        m_scrollY = posY + velY;
        yDone = false;
    } else {
        m_scrollY = targetY;
        m_scrollVelY = 0.0f;
        yDone = true;
    }
    // True while either axis is still moving (bitwise OR matches Ghidra).
    return static_cast<bool>((velX != 0.0f) | static_cast<unsigned>(!yDone && velY != 0.0f));
}

// ════════════════════════════════════════════════════════════════════════════
// 4.  sugorokuEasePositionPairB — Ghidra: FUN_000a1ac8
// ════════════════════════════════════════════════════════════════════════════
// Ease the player board position (+0x5cc/+0x5d0) toward its target
// (+0x5bc/+0x5c0) using stored velocities (+0x5c4/+0x5c8).
// Returns true while still moving.
// @complete
// Disasm 0xa1ac8: byte-identical to sugorokuEasePositionPairA on the shifted
// offsets; the move/snap test is `|vel| < |target - pos|` (both operands abs via
// conditional `vneg` at 0xa1ae6 / 0xa1b00, then `vcmpe s2,s8` / `bpl`). Fixed
// from the decompiler's mis-signed `-vel < pos-target`.
bool AcMainTask::sugorokuEasePositionPairB() {
    // X axis.
    float velX = m_playerVelX;
    float posX = m_playerX;
    float targetX = m_playerTargetX;
    if (std::fabs(velX) < std::fabs(targetX - posX)) {
        m_playerX = posX + velX;
    } else {
        m_playerX = targetX;
        m_playerVelX = 0.0f;
        velX = 0.0f;
    }
    // Y axis.
    float velY = m_playerVelY;
    float posY = m_playerY;
    float targetY = m_playerTargetY;
    bool yDone;
    if (std::fabs(velY) < std::fabs(targetY - posY)) {
        m_playerY = posY + velY;
        yDone = false;
    } else {
        m_playerY = targetY;
        m_playerVelY = 0.0f;
        yDone = true;
    }
    return static_cast<bool>((velX != 0.0f) | static_cast<unsigned>(!yDone && velY != 0.0f));
}

// A music/wallpaper "piece" square is unlocked when the per-character piece
// grid (9 characters x 3 slots, indexed by the pending sub-map's character id)
// has the node's field8 bit set. Ghidra address form: task + (charId/10)*-0x1c
// + charId*4 + gridBase, i.e. grid[(charId/10)*3 + charId%10] tested against (1
// << field8).
static bool sugorokuPieceUnlocked(const int *grid, int charId, int bitIndex) {
    const int idx = charId - (charId / 10) * 7; // == (charId/10)*3 + charId%10
    return (grid[idx] & (1 << (bitIndex & 0xff))) != 0;
}

// ════════════════════════════════════════════════════════════════════════════
// 5.  sugorokuDrawSquareText — Ghidra: FUN_000a1bb4
// ════════════════════════════════════════════════════════════════════════════
// Per square type, resolve one of three outcomes: draw the character-message
// asset (readCount-gated), draw the node's own embedded label (node->text), or
// draw nothing. The character-message text comes from getCharacterAssetName (a
// content asset that returns null in this build, so that path draws nothing);
// node->text is the runtime map-loaded label.
//
// The text-x / slot index at +0x88c is a FLOAT (writer @ 0x9a528 does
// vcvt.f32.s32 + vstr.32; this reader does vldr.32 then vcvt.s32.f32 to truncate
// @ 0xa1be2), so m_squareFrameIdx is a float truncated to int here. All nine
// node-type branches, the tbb table (types 6/7 map to the wall/music tables @
// +0x748/+0x6dc), the story-ready gate (readCount @ +0x8c0 / readNo @ +0x8bc),
// and the text draw (m_squareTextY - 31.0f, constants 0x1b / 0x2e / 0x615245 /
// 0x18 / 100) were verified faithful. The getTreasureMapValue_fb54(0, ...) call
// is fine: the binary passes m_map (@ +0x4b0) but FUN_000cea50 ignores it.
// @complete
void AcMainTask::sugorokuDrawSquareText() {
    if (m_field5f3 != 0) {
        return; // suppressed while task+0x5f3 is set
    }
    const TreasureMap::Node *node = m_curNode;
    if (!node) {
        return;
    }

    // +0x88c is a float slot; the binary truncates it to int (vcvt.s32.f32 @
    // 0xa1be2) for the text-x / slot index.
    int iVar8 = static_cast<int>(m_squareFrameIdx); // task+0x88c
    enum { kNone, kCharAsset, kNodeText } pick = kNone;

    // A character message shows only once the board-story page counter
    // (readCount) has advanced past the last-read page (readNo).
    const bool storyReady = (m_readCount > 0) && (m_readCount > m_readNo);

    switch (node->type) {
    case 2: // board-story square
        pick = (m_readCount >= 1) ? (storyReady ? kCharAsset : kNone) : kNodeText;
        break;
    case 3: // bonus: message live when roulette == 0x12 or HUD state 2
        pick = (m_rouletteMode == 0x12 || m_hudState == 2) ? (storyReady ? kCharAsset : kNone) :
                                                             kNodeText;
        break;
    case 4: // treasure: message live when roulette == 0x12 or HUD state 3
        pick = (m_rouletteMode == 0x12 || m_hudState == 3) ? (storyReady ? kCharAsset : kNone) :
                                                             kNodeText;
        break;
    case 5: { // sub-map flag: message when the flag value matches the current
              // state
        int v = getTreasureMapValue_fb54(0, node->field8);
        int st = m_hudState;
        bool matched = (st == 6 && v == 0) || (st == 7 && v == 1) || (st == 8 && v == 2) ||
                       (st == 9 && v == 3) || (st == 5);
        pick = matched ? (storyReady ? kCharAsset : kNone) : kNodeText;
        break;
    }
    case 6: // wallpaper-piece square (grid @ 0x748): label shown only while
        // locked
        pick =
            sugorokuPieceUnlocked(m_wallPieceTable, m_subMapId, node->field8) ? kNone : kNodeText;
        break;
    case 7: // music-piece square (grid @ 0x6dc): label shown only while locked
        pick =
            sugorokuPieceUnlocked(m_musicPieceTable, m_subMapId, node->field8) ? kNone : kNodeText;
        break;
    case 9: // goal-lock: character-message live once the goal is cleared (HUD
        // state 4)
        pick = (m_hudState == 4) ? (storyReady ? kCharAsset : kNone) : kNodeText;
        break;
    case 10: { // friend-meet: node label while the meet is pending and not yet
               // consumed
        TreasureTmpData tmp = [UserSettingData treasureTmp];
        bool consumed = ((tmp.raw0x4d >> 24) & 0xff) != 0; // field19_0x4d, byte 3
        pick = (m_goalCharaTex && !consumed) ? kNodeText : kNone;
        break;
    }
    default: // types 0/1/8/...: the node's own label if present
        pick = kNodeText;
        break;
    }

    const char *text = nullptr;
    unsigned style = 1; // uVar7: 1 for node text, 0 for character asset
    if (pick == kCharAsset) {
        text = getCharacterAssetName((int)m_subMapId, iVar8);
        if (!text) {
            return; // content asset absent in this build
        }
        iVar8 -= 0xe6;
        style = 0;
    } else if (pick == kNodeText) {
        if (node->text[0] == '\0') {
            return; // empty label -> nothing to draw
        }
        text = node->text;
        style = 1;
    } else {
        return;
    }

    drawAepTextMultiline(
        text, iVar8, (int)(m_squareTextY - 31.0f), style, 0x1b, 0x2e, 0x615245, 0x18, 100);
}

// ════════════════════════════════════════════════════════════════════════════
// 6.  sugorokuSaveTreasureProgress — Ghidra: FUN_000a1ddc
// ════════════════════════════════════════════════════════════════════════════
// Flush the in-flight TreasureTmpData to Core-Data (TreasureData) for the
// square that was just visited.  Called when the board-walk animation ends.
//
// The new fast value is read as a 32-bit word at treasureTmp struct offset +0x4c
// (disasm 0xa2044; decompile TStack_78._76_4_), the min-keep logic, the goal-type
// branch (m_goalType @ +0x8b1), the clear/friend-meet increments, the +0x08 /
// +0x0c OR-in masks, and the save-failure NSDetailedErrorsKey walk (empty loop
// body @ 0xa210a..0xa215c) were all verified faithful.
// @complete
void AcMainTask::sugorokuSaveTreasureProgress() {
    TreasureTmpData tmp = [UserSettingData treasureTmp];
    short subId = static_cast<short>(tmp.subMapId);
    if (subId < 0) {
        return;
    }

    NSManagedObjectContext *ctx = [AppDelegate appDelegate].managedObjectContext;
    [ctx reset];

    TreasureData *td = [TreasureData getTreasureData:subId / 10
                                            subMapId:subId % 10
                              inManagedObjectContext:ctx];
    if (!td) {
        return;
    }

    td.musicPiece = @([td.musicPiece intValue] | (int)tmp.raw0x08);
    td.wallPaperPiece = @([td.wallPaperPiece intValue] | (int)tmp.raw0x0c);

    // Goal type: task[0x8b1] == 2 → sound ticket; 1 → chara ticket.
    uint8_t goalType = m_goalType;
    if (goalType == 2) {
        td.goalTouchSound = @([td.goalTouchSound intValue] + 1);
    } else if (goalType == 1) {
        td.goalCharaTicket = @([td.goalCharaTicket intValue] + 1);
    }

    td.clearCnt = @([td.clearCnt intValue] + 1);

    // Keep the best (minimum) fast-record score. The binary reads the new value
    // as a 32-bit word at struct offset +0x4c (@ 0xa2044 ldr [sp,#0xc0]), which
    // straddles the top byte of raw0x49 and the low three bytes of raw0x4d in
    // this packed record.
    int32_t newFast;
    memcpy(&newFast, reinterpret_cast<const uint8_t *>(&tmp) + 0x4c, sizeof(newFast));
    int existFast = [td.fastRecord intValue];
    td.fastRecord = @(existFast < newFast ? existFast : static_cast<int>(newFast));

    // Friend-meet flag: byte 3 of raw0x4d.
    if ((tmp.raw0x4d >> 24) & 0xFF) {
        td.friendMeetCnt = @([td.friendMeetCnt intValue] + 1);
    }

    NSError *saveErr = nil;
    if (![ctx save:&saveErr]) {
        // On save failure the binary walks the validation sub-errors under
        // NSDetailedErrorsKey (@ 0xa210a..0xa215c). The enumeration body is empty
        // in the shipped code (the per-error diagnostic log compiled out, like the
        // project's neDebugLog convention), so this only touches the collection.
        NSArray *detailedErrors = saveErr.userInfo[NSDetailedErrorsKey];
        if (detailedErrors.count != 0) {
            for (__unused NSError *detail in detailedErrors) {
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════════════════
// 7.  sugorokuSetupScrollBounds — Ghidra: FUN_000a2544
// ════════════════════════════════════════════════════════════════════════════
// Snap the player draw position (+0x5cc/+0x5d0) to the node tile centre,
// compute a clamped scroll target (+0x5a4/+0x5a8) and arm the ease velocities
// (+0x5ac/+0x5b0) so the viewport glides there.
// @complete
void AcMainTask::sugorokuSetupScrollBounds() {
    const TreasureMap::Node *node = m_curNode;
    if (!node) {
        return;
    }

    float nodeX = static_cast<float>(node->x * 0x1a); // tile → pixel
    float nodeY = static_cast<float>(node->y * 0x1a);

    // Snap player board position.
    m_playerX = nodeX;
    m_playerY = nodeY;

    // Clamped scroll target: add small offset then clamp to map bounds.
    float minX = m_clampCentreX;
    float maxX = m_clampCentreX2;
    float minY = m_clampMinY;
    float maxY = m_clampMaxY;

    float targetX = nodeX + 52.0f;
    if (targetX < minX) {
        targetX = minX;
    }
    if (targetX > maxX) {
        targetX = maxX;
    }

    float targetY = nodeY + 64.0f;
    if (targetY < minY) {
        targetY = minY;
    }
    if (targetY > maxY) {
        targetY = maxY;
    }

    m_scrollTargetX = targetX;
    m_scrollTargetY = targetY;

    // Arm velocities: ±10 px/frame toward target.
    m_scrollVelX = (m_scrollX < targetX) ? 10.0f : -10.0f;
    m_scrollVelY = (m_scrollY < targetY) ? 10.0f : -10.0f;

    m_scrollAccumX = 0.0f;
    m_scrollAccumY = 0.0f;
}

// ════════════════════════════════════════════════════════════════════════════
// 8.  sugorokuLoadWallTextures — Ghidra: FUN_000a2b64
// ════════════════════════════════════════════════════════════════════════════
// Replace the 9 wall-nail textures (+0x1c8) for the given wallpaper page.
// Old textures are deleted before loading the new set.
// Disasm 0xa2caa: the binary calls neTextureForiOS::load unconditionally with
// the resolved path; the `if (path)` guard below is a benign defensive addition
// (path is nil only when the resource is missing).
// @complete
void AcMainTask::sugorokuLoadWallTextures(int page) {
    // Delete existing wall textures.
    for (int i = 0; i < 9; i++) {
        neTextureForiOS *&slot = m_wallNailTex[i];
        if (slot) {
            delete slot;
            slot = nullptr;
        }
    }
    int base = page * 9;
    for (int i = 0; i < 9; i++) {
        short idx = findTreasureMapIndexById(base + i);
        neTextureForiOS *t = new neTextureForiOS();
        m_wallNailTex[i] = t;
        NSString *name = [NSString stringWithFormat:@"sugo_wall_nail_%02d", (int)idx];
        NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"png"];
        if (path) {
            t->load([path UTF8String]);
        }
    }
}

// ════════════════════════════════════════════════════════════════════════════
// 9.  sugorokuTaskDispose — Ghidra: FUN_000a2d00
// ════════════════════════════════════════════════════════════════════════════
// Full teardown of the sugoroku board scene: delete all textures and layers,
// unload assets, release sound effects, then kill this task and activate the
// next one (+0x948).
//
// Disasm 0xa2fe2 gates BOTH the kill flag (`strb #1,[+0x24]`) and
// next->setPriority(3) inside the `if (m_nextTask != null)` check (reproduced
// below). All delete/unlink loops, slot ranges (0x35..0x3e, digits
// 0xfc/0x124/0x14c, 0x69..0x86, layers roulette/arrows/panels), the group-5/6
// releases, the 15 SE releases, and the map disposal were verified faithful (the
// FUN_000ce2e4 pre-step is folded into ~TreasureMap as documented).
// @complete
void AcMainTask::sugorokuTaskDispose() {
    AudioManager *audioMgr = [AudioManager sharedManager];

    // 1. Delete the scene sprite textures (offsets 0xd4..0xf8): the named
    //    circle/board-bg/chara/goal/blind textures plus the five reserve slots.
    auto dropTex = [](neTextureForiOS *&s) {
        if (s) {
            delete s;
            s = nullptr;
        }
    };
    dropTex(m_circleTex);
    dropTex(m_boardBgTex);
    dropTex(m_charaTex);
    dropTex(m_goalCharaTex);
    dropTex(m_blindCircleTex);
    for (neTextureForiOS *&s : m_reserveTex) {
        dropTex(s);
    }

    // 2. Delete the three 10-glyph digit texture sets (points / roulette /
    // ticket).
    for (neTextureForiOS *&s : m_pointsDigitTex) {
        dropTex(s);
    }
    for (neTextureForiOS *&s : m_roulDigitTex) {
        dropTex(s);
    }
    for (neTextureForiOS *&s : m_ticketDigitTex) {
        dropTex(s);
    }

    // 3. Delete the music-jacket (9), wall-nail (9) and event (12) textures
    //    (Ghidra slot range 0x69..0x86 == byte offsets 0x1a4..0x218).
    for (neTextureForiOS *&s : m_jacketTex) {
        dropTex(s);
    }
    for (neTextureForiOS *&s : m_wallNailTex) {
        dropTex(s);
    }
    for (neTextureForiOS *&s : m_eventTex) {
        dropTex(s);
    }

    // 4. Release character-select textures.
    charaSelectReleaseTextures(this);

    // 5. Unlink + delete AEP layer slots (Ghidra loop order preserved:
    //    roulette, then arrows, then panels).
    auto dropLayer = [](AepLyrCtrl *&lyr) {
        if (lyr) {
            lyr->unlink();
            delete lyr;
            lyr = nullptr;
        }
    };
    for (AepLyrCtrl *&lyr : m_rouletteLayers) {
        dropLayer(lyr); // offsets 0x2c..0x9c
    }
    for (AepLyrCtrl *&lyr : m_arrowLayers) {
        dropLayer(lyr); // offsets 0xc0..0xcc
    }
    for (AepLyrCtrl *&lyr : m_panelLayers) {
        dropLayer(lyr); // offsets 0xa0..0xbc
    }

    // 6. Unload AEP asset group 5.
    m_aep->releaseAepTexture(5);

    // 7. Release the board-background / "goal" AEP layer (group 6).
    sugorokuReleaseGoalLayer();

    // 8. Delete the TreasureMap. The binary calls a separate resetTreasureMapData
    // that
    //    frees the map's node/connect buffers before disposal; here ~TreasureMap
    //    (invoked by delete) owns that teardown, so calling it again would
    //    double-free.
    if (m_map) {
        delete m_map;
        m_map = nullptr;
    }

    // 9. Release Objective-C objects stored in the blob (null the raw slots, as
    // the
    //    binary does — the retained references were already dropped by the flow
    //    above).
    m_mapName = nullptr;
    m_gotCharaArray = nullptr;
    m_treasureMusicArray = nullptr;

    // 10. Release sound effects (15 IDs at +0x438). The IDs are stored as int
    //     (4 bytes, matching the 32-bit ILP32 loadSe return).
    for (int se : m_rouletteSe) {
        [audioMgr releaseSe:nil resourceId:static_cast<RSND_SOURCE_ID>(static_cast<uint32_t>(se))];
    }

    // 11. Release / reload system SEs.
    neSceneManager::shared().releaseSystemSe();
    [audioMgr cleanupSe];
    neSceneManager::shared().loadSystemSe();

    // 12. If a next task is queued (+0x948), kill this task and activate it. The
    //     binary gates BOTH the kill flag (strb #1,[+0x24]) and the next task's
    //     setPriority(3) on the null check (@ 0xa2fe6); when there is no next
    //     task neither runs.
    if (C_TASK *next = static_cast<C_TASK *>(m_nextTask)) {
        kill();
        next->setPriority(3);
    }
}

// ════════════════════════════════════════════════════════════════════════════
// 10.  sugorokuDrawBoard — Ghidra: FUN_000a303c
// ════════════════════════════════════════════════════════════════════════════
// Cull and draw all board squares, edges, the player sprite and the HUD for
// the current frame.
// @complete
void AcMainTask::sugorokuDrawBoard() {
    AepManager *mgr = m_aep;

    float scrollOffX = m_scrollX - m_scrollBaseX;
    float scrollOffY = m_scrollY - m_scrollBaseY;
    int screenW = m_overlayW; // full screen width
    int screenH = m_overlayH;
    int halfW = screenW / 2;
    int halfH = screenH / 2;

    // Camera AABB (in board-pixel space).
    float camL = scrollOffX - (float)halfW;
    float camR = scrollOffX + (float)halfW;
    float camT = scrollOffY - (float)halfH;
    float camH = scrollOffY + (float)halfH;

    // Draw squares.
    const TreasureMap::Node *nodes = m_nodes;
    int nodeCount = m_nodeCount;
    for (int i = 0; i < nodeCount; i++) {
        const TreasureMap::Node *n = nodes + i; // stride 0x120
        float nx = (float)(n->x * 26);
        float ny = (float)(n->y * 26);
        if (isWithinRange2D(nx, nx, nx + 104.0f, ny, ny + 128.0f, camL, camT, camR, camH)) {
            sugorokuDrawSquare(n);
        }
    }

    // Draw edges.
    const TreasureMap::ConnectStruct *edges =
        reinterpret_cast<const TreasureMap::ConnectStruct *>(static_cast<intptr_t>(m_edgesPtr));
    int edgeCount = static_cast<int>(m_edgeCount);
    for (int i = 0; i < edgeCount; i++) {
        const TreasureMap::ConnectStruct *e = edges + i;
        float ax = (float)(e->a->x * 26), ay = (float)(e->a->y * 26);
        float bx = (float)(e->b->x * 26), by = (float)(e->b->y * 26);
        float minX = ax < bx ? ax : bx, maxX = ax > bx ? ax : bx;
        float minY = ay < by ? ay : by, maxY = ay > by ? ay : by;
        if (isWithinRange2D(
                minX, minX, maxX + 104.0f, minY, maxY + 128.0f, camL, camT, camR, camH)) {
            sugorokuDrawPath(e);
        }
    }

    sugorokuDrawPlayerAndUi();

    // Overlay frame: pad-only roulette-move hint, drawn at the select-scene
    // layout anchor (m_selSceneLayout[0], [1] + overlayH), size 0x20 x 0x1a.
    if (m_padDisplay && m_bonusCount > 0) {
        drawAepFrame(mgr,
                     m_rouletteMoveFrame,
                     m_selSceneLayout[0],
                     m_selSceneLayout[1] + screenH,
                     0x20,
                     0x1a);
    }

    // HUD frame: a 4-way pick on (hudState < 2, unsigned) x (scrolledPastEnd),
    // choosing boardFrame[4..7]; drawn unconditionally at the same layout anchor.
    {
        int frame;
        if ((uint32_t)m_hudState < 2) {
            frame = m_scrolledPastEnd ? m_boardFrame[6] : m_boardFrame[7];
        } else {
            frame = m_scrolledPastEnd ? m_boardFrame[4] : m_boardFrame[5];
        }
        drawAepFrame(mgr, frame, m_selSceneLayout[0], m_selSceneLayout[1] + screenH, 0x20, 0x1a);
    }

    // Notice layer: drawn at m_selSceneLayout[9], [13] + overlayH, size 0x20 x
    // 0x1b.
    if (m_boardVisited[6]) {
        drawAepFrame(
            mgr, m_boardFrame[21], m_selSceneLayout[9], m_selSceneLayout[13] + screenH, 0x20, 0x1b);
    }
}

// ════════════════════════════════════════════════════════════════════════════
// 11.  sugorokuDrawBackground — Ghidra: FUN_000a3308
// ════════════════════════════════════════════════════════════════════════════
// Draw the scrolling background tile for the current scroll position, apply
// the transition fade overlay, and drive the background animation layer.
// @complete
void AcMainTask::sugorokuDrawBackground() {
    AepManager *mgr = m_aep;
    neTextureForiOS *bgTex = m_boardBgTex;
    if (!bgTex) {
        return;
    }

    int scrollX = (int)(m_scrollX - m_scrollBaseX);
    int screenW = m_overlayW;
    bool fadeFl = m_padDisplay != 0;
    int sx = fadeFl ? 201 : 100;
    int sy = fadeFl ? 200 : 100;
    int bgW = m_bgTileW;
    int bgH = m_bgTileH;

    // Two-tile horizontal wrap.
    for (int i = 0; i < 2; i++) {
        int x = screenW * i + (screenW / 2 - scrollX);
        if (x < 0) {
            x = screenW - ((-x) % (screenW * 2));
        } else {
            x = (x % (screenW * 2)) - screenW;
        }
        drawSprite(
            mgr, bgTex, 0, 0, bgW, bgH, x, 0, sx, sy, 0, 0, 0, 100, 0, 0x20, 0xffffff, 0, 0x25);
    }

    // Transition overlay fade.
    int alpha = m_transitionAlpha;
    if (m_fadeDir == 0) {
        if (alpha >= 1) {
            alpha -= 4;
        }
    } else {
        if (alpha < 0x34) {
            alpha += 4;
        }
    }
    m_transitionAlpha = alpha;
    if (alpha > 0) {
        drawAepTransitionOverlay(mgr, alpha);
    }

    // Background animation layer (+0x9c): play/reset driven by board state.
    AepLyrCtrl *bgLyr = m_rouletteLayers[28];
    if (bgLyr) {
        int bgState = m_boardMoveState;
        if ((uint32_t)(bgState - 1) < 2) { // unsigned: idle state 0 falls to the reset branch
            if (!bgLyr->isAnimating()) {
                bgLyr->play();
            }
        } else {
            if (bgLyr->isAnimating()) {
                bgLyr->reset();
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════════════════
// 12.  sugorokuDrawSquare — Ghidra: FUN_000a4eb4
// ════════════════════════════════════════════════════════════════════════════
// Select the AEP frame sprite for node type, then draw it at the node's
// board-pixel position adjusted for the current scroll.
// @complete
void AcMainTask::sugorokuDrawSquare(const TreasureMap::Node *node) {
    AepManager *mgr = m_aep;
    int scrollOffX = (int)(m_scrollX - m_scrollBaseX);
    int scrollOffY = (int)(m_scrollY - m_scrollBaseY);
    int screenW = m_overlayW;
    int screenH = m_overlayH;
    int type = node->type;

    // "Active move" override: while a move is in progress (flag byte @ task+0x8a2
    // > 0), every walkable square (not player-start, not warp) shows the
    // move-hint frame.
    if ((int8_t)m_boardVisited[14] > 0 && type != 1 && type != 8) {
        drawAepFrame(mgr,
                     m_base1Frame[2],
                     node->x * 26 - scrollOffX + screenW / 2,
                     node->y * 26 - 32 - scrollOffY + screenH / 2,
                     0x20,
                     0x22);
        return;
    }

    int frameHandle = m_base1Frame[2]; // default (type 2 and any unmet condition -> 0x340)
    switch (type) {
    case 0:
        frameHandle = m_base1Frame[0];
        break; // start
    case 1:
        frameHandle = m_base1Frame[1];
        break; // player-start
    case 3:    // bonus: locked frame unless the bonus is live (roulette 0x12 or HUD
               // state 2)
        if (m_rouletteMode != 0x12 && m_hudState != 2) {
            frameHandle = m_base1Frame[3];
        }
        break;
    case 4: // treasure: locked frame unless the treasure is live (roulette 0x12
        // or state 3)
        if (m_rouletteMode != 0x12 && m_hudState != 3) {
            frameHandle = m_base1Frame[4];
        }
        break;
    case 5: { // sub-map flag: flag sprite unless the flag value matches the
              // current state
        int v = getTreasureMapValue_fb54(0, node->field8);
        int st = m_hudState;
        bool matched = (st == 6 && v == 0) || (st == 7 && v == 1) || (st == 8 && v == 2) ||
                       (st == 9 && v == 3) || (st == 5);
        if (!matched) {
            if (v < 0) {
                v = 0;
            }
            frameHandle = m_base05Frame[v];
        }
        break;
    }
    case 6: // wallpaper-piece square (grid @ 0x748): filled vs empty frame by
        // unlock bit
        frameHandle = sugorokuPieceUnlocked(m_wallPieceTable, m_subMapId, node->field8) ?
                          m_base1Frame[6] :
                          m_base1Frame[5];
        break;
    case 7: // music-piece square (grid @ 0x6dc): filled vs empty frame by unlock
        // bit
        frameHandle = sugorokuPieceUnlocked(m_musicPieceTable, m_subMapId, node->field8) ?
                          m_base1Frame[8] :
                          m_base1Frame[7];
        break;
    case 8: // warp: warp-index sprite, but only until the warp animation settles
        // (<2)
        if ((int8_t)m_boardVisited[10] < 2) {
            int warpIdx = node->field8;
            if (warpIdx < 0) {
                warpIdx = 0;
            }
            if (warpIdx > 9) {
                warpIdx = 9;
            }
            frameHandle = m_base08Frame[warpIdx];
        }
        break;
    case 9: // goal-lock: locked frame unless already cleared (HUD state 4)
        if (m_hudState != 4) {
            frameHandle = m_base1Frame[9];
        }
        break;
    case 10: // friend-meet: draw the overlay, then the base frame
        sugorokuDrawFriendMeet();
        frameHandle = m_base1Frame[10];
        break;
    default:
        break; // type 2 etc.: keep the default frame m_base1Frame[2]
    }

    if (frameHandle) {
        drawAepFrame(mgr,
                     frameHandle,
                     node->x * 26 - scrollOffX + screenW / 2,
                     node->y * 26 - 32 - scrollOffY + screenH / 2,
                     0x20,
                     0x22);
    }
}

// ════════════════════════════════════════════════════════════════════════════
// 13.  sugorokuDrawPath — Ghidra: FUN_000a50dc
// ════════════════════════════════════════════════════════════════════════════
// Draw the arrow chain connecting edge->a to edge->b.  Vertical edges use 6
// arrows; horizontal edges use 4 arrows.  Back-links use a separate sprite set.
// @complete
void AcMainTask::sugorokuDrawPath(const TreasureMap::ConnectStruct *edge) {
    AepManager *mgr = m_aep;
    int scrollOffX = (int)(m_scrollX - m_scrollBaseX);
    int scrollOffY = (int)(m_scrollY - m_scrollBaseY);
    int halfW = m_overlayW / 2;
    int halfH = m_overlayH / 2;

    const TreasureMap::Node *nodeA = edge->a;
    const TreasureMap::Node *nodeB = edge->b;
    bool sameRow = edge->sameRow;

    // Back-link arrows use a different sprite set (+0x3b8 vs +0x3a0).
    const int *arr = (nodeB->backLink == nodeA) ? &m_triangle1Frame[0] : &m_triangle0Frame[0];

    if (!sameRow) {
        // Vertical path (nodeA and nodeB are in different rows, Y changes). The
        // binary spaces the 6 arrows by a fixed ±24 px (0x41c00000) at multipliers
        // 0..5 (the sign gives the direction), NOT an interpolated node-distance
        // step.
        int rot, startY, step;
        int startX = nodeA->x * 26 + 0x28 - scrollOffX + halfW;
        if (nodeA->y < nodeB->y) { // down
            rot = 0;
            startY = nodeA->y * 26 + 0x60 - scrollOffY + halfH;
            step = 24;
        } else { // up
            rot = 0xb4;
            startY = nodeA->y * 26 + 8 - scrollOffY + halfH;
            step = -24;
        }
        for (int j = 0; j < 6; j++) {
            int ay = startY + step * j;
            AepDrawSpriteHandle(mgr,
                                arr[j],
                                startX + 0xb,
                                ay + 0xc,
                                100,
                                100,
                                rot,
                                0xc,
                                0xc,
                                100,
                                0,
                                8,
                                0xffffff,
                                nullptr,
                                0x23,
                                1);
        }
    } else {
        // Horizontal path (nodeA and nodeB are in the same row, X changes). Fixed
        // ±25 px (0x41c80000) spacing at multipliers 0..3; the 4 arrows come from
        // sprite slots arr[1..4] (the binary indexes arr[j+1], not arr[j]).
        int rot, startX, step;
        int startY = nodeA->y * 26 + 0x34 - scrollOffY + halfH;
        if (nodeA->x < nodeB->x) { // right
            rot = -0x5a;
            startX = nodeA->x * 26 + 0x69 - scrollOffX + halfW;
            step = 25;
        } else { // left
            rot = 0x5a;
            startX = nodeA->x * 26 - 0x18 - scrollOffX + halfW;
            step = -25;
        }
        for (int j = 0; j < 4; j++) {
            int ax = startX + step * j;
            AepDrawSpriteHandle(mgr,
                                arr[j + 1],
                                ax + 0xb,
                                startY + 0xc,
                                100,
                                100,
                                rot,
                                0xc,
                                0xc,
                                100,
                                0,
                                8,
                                0xffffff,
                                nullptr,
                                0x23,
                                1);
        }
    }
}

// ════════════════════════════════════════════════════════════════════════════
// 14.  sugorokuDrawPlayerAndUi — Ghidra: FUN_000a52f0
// ════════════════════════════════════════════════════════════════════════════
// Draw the player sprite (with warp-spin or board-enter bounce), the rank
// badge, the event badge, the roulette result frame and the 4 hit-flash layers.
// @complete
void AcMainTask::sugorokuDrawPlayerAndUi() {
    AepManager *mgr = m_aep;

    float scrollOffX = m_scrollX - m_scrollBaseX;
    float scrollOffY = m_scrollY - m_scrollBaseY;
    int halfW = m_overlayW / 2;
    int halfH = m_overlayH / 2;
    int screenX = (int)(m_playerX - scrollOffX + (float)halfW);
    int screenY = (int)(m_playerY - scrollOffY + (float)halfH);
    int iVar6 = screenX + 0x34; // player draw X (offset from board node centre)

    // Warp / board-entry horizontal scale (squish animation).
    int warpSX = 30;
    if (m_warpAnim != 0) {
        // Bounce using the active roulette layer's frame counter. Ghidra
        // sugorokuDrawPlayerAndUi @ 0xa53a4: ldr r0,[this,#0x70] (m_rouletteLayers[17]),
        // then ldr [r0,#0x3c] (frame count) and vldr.32 [r0,#0x40] (current frame).
        AepLyrCtrl *lyr = m_rouletteLayers[17];
        int frameTotal = lyr->frameCount() - 1; // +0x3c nFrameCount
        // The binary truncates the float play head to an int before the multiply
        // (Ghidra @ 0xa53b0: vcvt.s32.f32, then vcvt.f64.s32 into the *6pi term).
        int frame = static_cast<int>(lyr->curFrame()); // +0x40 flCurFrame
        double angle = (frameTotal > 0) ?
                           (double)frame * (6.0 * M_PI) / (double)frameTotal // DAT_000a5710 == 6*pi
                           :
                           0.0;
        warpSX = (int)(cosf((float)angle) * 30.0f);
    }
    // Reverse horizontal scale when moving right (board-state bit).
    if ((m_boardMoveState & ~1) == 2) {
        warpSX = -warpSX;
    }

    // Player sprite (hidden during warp flash).
    if (m_warpFlash == 0) {
        drawSprite(mgr,
                   m_charaTex,
                   0,
                   0,
                   0x228,
                   0x228,
                   iVar6,
                   screenY,
                   warpSX,
                   0x1e,
                   0,
                   0x114,
                   0x114,
                   100,
                   0,
                   0x20,
                   0xffffff,
                   0,
                   0x21);
    }

    // Rank badge (types 0..3, stored at +0x8b0; hidden if type >= 4 or during
    // warp flash).
    uint8_t badgeType = m_rankBadgeType;
    if (badgeType < 4 && m_warpFlash == 0) {
        int badgeLyrHandle = m_iconMentalLyr[(int)badgeType];
        int badgeFrameCnt = m_iconMentalFrames[(int)badgeType];
        int &frameCtr = m_animFrameCtr;
        int frame = (badgeFrameCnt > 0) ? (frameCtr % badgeFrameCnt) : 0;
        mgr->drawLayer(badgeLyrHandle,
                       frame,
                       screenX + 0x7a,
                       screenY - 100,
                       100,
                       100,
                       0,
                       0,
                       0,
                       100,
                       0,
                       0,
                       0x20,
                       0,
                       nullptr,
                       nullptr,
                       0x20,
                       1);
        frameCtr++;
    }

    // Event badge (+0x89b).
    if (m_boardVisited[7]) {
        int evHandle = m_boardFrame[20];
        AepDrawSpriteHandle(mgr,
                            evHandle,
                            screenX + 0x43,
                            screenY + 0x28,
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
                            0x20,
                            1);
    }

    // Roulette result frame (+0x8ac, visible when player is idle).
    if (m_warpFlash == 0) {
        // +0x8ac is a signed 16-bit field (Ghidra @ 0xa552a/0xa553c: ldrsh.w);
        // assigning the int16_t to int sign-extends exactly like the binary's load.
        int roulVal = m_rouletteMode;
        if (roulVal >= -1) {
            AepLyrCtrl *resultLyr = m_rouletteLayers[15];
            if (!resultLyr || !resultLyr->isAnimating()) {
                int rHandle = -1; // no match / not-found frame -> skip (binary: -1 < handle)
                switch (roulVal) {
                case 10:
                    rHandle = m_boardFrame[14];
                    break;
                case 11:
                    rHandle = m_boardFrame[15];
                    break;
                case 12:
                    rHandle = m_boardFrame[16];
                    break;
                case 13:
                    rHandle = m_boardFrame[17];
                    break;
                case 16:
                    rHandle = m_boardFrame[19];
                    break;
                case 19:
                    rHandle = m_boardFrame[18];
                    break;
                case 20:
                    rHandle = m_boardFrame[22];
                    break;
                case 21:
                    rHandle = m_boardFrame[23];
                    break;
                case 22:
                    rHandle = m_boardFrame[24];
                    break;
                case 23:
                    rHandle = m_boardFrame[25];
                    break;
                default:
                    break;
                }
                if (rHandle >= 0) {
                    AepDrawSpriteHandle(mgr,
                                        rHandle,
                                        screenX - 8,
                                        screenY + 0x28,
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
                                        0x20,
                                        1);
                }
            }
        }
    }

    // 4 hit-flash animation layers (+0xc0..+0xcf); position each to its
    // screen slot while it is playing.
    for (int i = 0; i < 4; i++) {
        AepLyrCtrl *lyr = m_arrowLayers[i];
        if (!lyr || !lyr->isAnimating()) {
            continue;
        }
        int lx, ly;
        switch (i) {
        case 0:
            ly = screenY + 0x3c;
            lx = screenX - 0x94;
            break;
        case 1:
            ly = screenY + 0x3c;
            lx = screenX + 0xfc;
            break;
        case 2:
            ly = screenY - 0xaa;
            lx = iVar6;
            break;
        case 3:
            ly = screenY + 0x118;
            lx = iVar6;
            break;
        default:
            lx = ly = 0;
            break;
        }
        lyr->setPosition(lx, ly);
    }
}

// ════════════════════════════════════════════════════════════════════════════
// 15.  sugorokuDrawFriendMeet — Ghidra: FUN_000a5740
// ════════════════════════════════════════════════════════════════════════════
// If a friend sprite is loaded (+0xe0), draw it at the current node's screen
// position with a cos/sin scale bounce, then fade it out.  Also overlay the
// friend's name label.
//
// NOT @complete — node source deviates. Ghidra FUN_000a5740 takes the node as
// its second parameter (r1); its only caller, sugorokuDrawSquare's type-10 case
// (0xa50bc, `mov r0,r8; bl 0xa5740`), leaves r1 holding the friend-meet square
// being drawn. The code below instead reads m_curNode (the player's node) and
// adds a null-node fallback the binary lacks (0xa579c dereferences r1
// unconditionally). For a friend square != the player node these differ. The
// cos/sin bounce (frame @ +0x5e8, cos<15 / sin>=15, x30.0), the name truncation
// (4 chars + ".."), and the fade-out (opacity-5 floored at 0) were verified
// faithful.
void AcMainTask::sugorokuDrawFriendMeet() {
    neTextureForiOS *friendTex = m_goalCharaTex;
    if (!friendTex) {
        return;
    }
    int opacity = m_friendOpacity;
    if (!opacity) {
        return;
    }

    int scrollOffX = (int)(m_scrollX - m_scrollBaseX);
    int scrollOffY = (int)(m_scrollY - m_scrollBaseY);
    int screenW = m_overlayW;
    int screenH = m_overlayH;

    const TreasureMap::Node *node = m_curNode;
    int iVar7 = node ? node->x * 26 + 0x34 - scrollOffX + screenW / 2 : screenW / 2;
    int iVar6 = node ? node->y * 26 - scrollOffY + screenH / 2 : screenH / 2;

    // Cos/sin bounce animation (30 frames: first 15 = cos, next 15 = sin).
    int frame = m_friendAnimFrame;
    float animVal;
    if (frame < 15) {
        animVal = cosf((float)((double)frame * M_PI / 15.0));
    } else {
        animVal = sinf((float)((double)(frame - 15) * M_PI / 15.0));
    }
    int animScale = (int)(animVal * 30.0f);

    AepManager *mgr = m_aep;
    drawSprite(mgr,
               friendTex,
               0,
               0,
               0x228,
               0x228,
               iVar7,
               iVar6,
               animScale,
               0x1e,
               0,
               0x114,
               0x114,
               opacity,
               100 - opacity,
               0x20,
               0xffffff,
               0,
               0x21);

    // Name label.
    __unsafe_unretained NSString *nameStr = (__bridge NSString *)m_mapName;
    if (nameStr) {
        mgr->drawLayer(m_skillBoardLyr[4],
                       0,
                       iVar7,
                       iVar6 + 0x5a,
                       100,
                       100,
                       0,
                       0,
                       0,
                       100,
                       0,
                       0,
                       1,
                       0x20,
                       nullptr,
                       nullptr,
                       0x20,
                       1);

        const char *utf8 = [nameStr UTF8String];
        char buf[8] = {};
        size_t len = utf8 ? strnlen(utf8, 4) : 0;
        memcpy(buf, utf8, len);
        // Truncate to 4 visible chars + "..".
        if (utf8 && strlen(utf8) > 4) {
            buf[4] = '.';
            buf[5] = '.';
            buf[6] = '\0';
        }
        mgr->DrawText(buf, 0x12, iVar7, iVar6 + 0x4e, 1, 100, 0x615245, 0x1f);
    }

    // Fade out.
    int v = opacity - 5;
    m_friendOpacity = (v < 1) ? 0 : v;
}

// Ghidra: charaSelectDrawAndInput (FUN_000a3724) — the group-5 per-element draw
// callback for the sugoroku board / chara-select screen. A 26-branch routine
// dispatched on the resolved user number (m_boardUserNo[]): the chara-thumbnail
// grid (with the hit-flash select layer), chara name + skill
// name/description/info text, the music/wall collection-piece grids keyed on
// the treasure-map unlock bitfields, single-texture panels, the list scroll
// bar, the pulsing collection-complete badge, and the roulette-result
// icon/caption. `context` is the AcMainTask, reached through its named members.
// The step-value slot is m_stepValues[m_stepValueIndex] (+0x594, verified at
// 0xa48e4), and the chara-thumbnail texture index is idxBase (0..5, verified at
// 0xa3bb6 / 0xa3bbe with the curr/prev selection gate at 0xa3b9e); the
// highlight uses the same 6-per-page list layout as the verified row-count
// (count / 6). The panel-position stores (m_charaPanelX/Y @ +0x60c/+0x610,
// m_skillPanelX/Y @ +0x604/+0x608, index-14 baseX/Y) use the binary's signed
// divide-by-100 (magic reciprocal 0x51eb851f @ 0xa3aca / 0xa3c88 / 0xa469c), not
// a 16.16 shift; the only FixedToFP round-trip (index 9/13 grid @ 0xa3f66) is an
// int<->float identity for the draw ABI, not a scale. The chara-select highlight
// keys on object identity (info.charaId == m_charaId @ 0xa3a84), not on any
// incoming coordinate. All 26 branches, offsets, digit-run bounds, and constants
// were verified faithful against disassembly.
// @complete
void AcMainSugorokuDraw(int child,
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
                        uint32_t p17,
                        void *context) {
    (void)frame;
    (void)clipRect;
    AcMainTask *self = static_cast<AcMainTask *>(context);
    AepManager *aep = self->m_aep;

    auto numDigits = [](int v) {
        int n = 1;
        while (v > 9) {
            n++;
            v /= 10;
        }
        return n;
    };
    // A right-to-left digit run from a texture atlas (glyph w x h), stepping x by
    // -step.
    auto drawDigits =
        [&](neTextureForiOS **atlas, int value, int count, int px, int step, int gw, int gh) {
            for (int k = 0; k < count; k++) {
                neTextureForiOS_draw(aep,
                                     atlas[value % 10],
                                     0,
                                     0,
                                     gw,
                                     gh,
                                     px,
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
                                     p17,
                                     1);
                px -= step;
                value /= 10;
            }
        };

    // ---- treasure-point / ticket / bonus digit readouts
    // -----------------------------------
    if (self->m_boardUserNo[0] == child) { // treasure point (4 digits)
        int v = self->m_treasurePoint;
        if (v > 9999) {
            v = 9999;
        }
        drawDigits(self->m_pointsDigitTex, v, 4, x, self->m_dlgLayout954, 0x22, 0x26);
        return;
    }
    if (self->m_boardUserNo[23] == child) { // bonus count (ticket glyphs)
        // Disasm +0x42c (0xa3806): 2 digits from x-7, step 0x20 (loop init -7, exit
        // at -0x47).
        drawDigits(self->m_ticketDigitTex, self->m_bonusCount, 2, x - 7, 0x20, 0x20, 0x24);
        return;
    }
    if (self->m_boardUserNo[21] == child) { // owned chara tickets (<=99)
        int v = self->m_charaTicket;
        if (v > 99) {
            v = 99;
        }
        // Disasm +0x424 (0xa38a6): 2 digits (loop init 0, exit at -0x40), step
        // 0x20.
        drawDigits(self->m_ticketDigitTex, v, 2, x, 0x20, 0x20, 0x24);
        return;
    }
    if (self->m_boardUserNo[22] == child) { // roulette-result digit
        const int val = self->m_rouletteDigit;
        const int n = numDigits(val);
        drawDigits(self->m_pointsDigitTex, val, n, x + n * 0x20 - 0x30, 0x20, 0x22, 0x26);
        return;
    }
    if (self->m_boardUserNo[16] == child) { // per-skill step value (roulette digits)
        // Ghidra 0xa48e4: the slot is m_stepValues[m_stepValueIndex], where the
        // index (+0x594) cycles 0..6 each frame — the spinning roulette readout.
        int val = self->m_stepValues[self->m_stepValueIndex];
        const int n = numDigits(val);
        if (n >= 1) {
            drawDigits(self->m_roulDigitTex, val, n, x + (n == 2 ? 0x1c : -2), 0x3c, 0x3c, 0x48);
        }
        return;
    }

    // ---- chara-select thumbnail grid (left / right columns)
    // -------------------------------
    auto drawCharaColumn = [&](int base, bool leftCol) {
        int cx = x;
        for (int i = 0; i < 3; i++) {
            const int idxBase = leftCol ? i : i + 3;
            neTextureForiOS *tex;
            if (self->m_charaColLeft < self->m_charaColRight) {
                tex = (base == self->m_boardUserNo[2] || base == self->m_boardUserNo[4]) ?
                          self->m_charaPageCurrTex[idxBase] :
                          self->m_charaPagePrevTex[idxBase];
            } else {
                tex = self->m_charaPagePrevTex[idxBase];
            }
            neTextureForiOS_draw(aep,
                                 tex,
                                 0,
                                 0,
                                 0xc4,
                                 0xc4,
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
                                 p17,
                                 1);
            // Highlight the currently-selected chara with the hit-flash layer.
            const int listIdx = idxBase + self->m_charaColLeft * 6;
            NSArray *avail = (__bridge NSArray *)self->m_availableInfos;
            if ((unsigned)listIdx < [avail count]) {
                CharaInfo *info = avail[listIdx];
                if (info && (int)info.charaId == self->m_charaId) {
                    AepLyrCtrl *hl = self->m_rouletteLayers[18];
                    if (!hl->isAnimating() && !self->m_panelLayers[2]->isAnimating() &&
                        !self->m_panelLayers[3]->isAnimating()) {
                        hl->play();
                    }
                    hl->setPosition(cx + 8, y - 100);
                }
            }
            if (i == 2) {
                if (leftCol) {
                    self->m_charaPanelX = x - (anchorX * scaleX) / 100;
                    self->m_charaPanelY = y - (anchorY * scaleY) / 100;
                } else {
                    self->m_skillPanelX = x - (scaleX * anchorX) / 100;
                    self->m_skillPanelY = y - (scaleY * anchorY) / 100;
                }
                return;
            }
            cx += (scaleX * 0xc4) / 100;
        }
    };
    if (self->m_boardUserNo[2] == child || self->m_boardUserNo[4] == child) {
        drawCharaColumn(child, true);
        return;
    }
    if (self->m_boardUserNo[1] == child || self->m_boardUserNo[5] == child) {
        drawCharaColumn(child, false);
        return;
    }

    // ---- chara name / skill text
    // ----------------------------------------------------------
    if (self->m_boardUserNo[6] == child) { // selected chara name
        if (self->m_skillCharaId < 0) {
            return;
        }
        CharaInfo *info = gCharaManager.availableInfoForCharaId(self->m_skillCharaId);
        aep->DrawText(info.charaName.UTF8String, 0x23, x, y - 0xf, 1, color, 0, p17);
        return;
    }
    if (self->m_boardUserNo[7] == child) { // skill name / id / description
        if (self->m_skillCharaId < 0) {
            return;
        }
        CharaInfo *info = gCharaManager.availableInfoForCharaId(self->m_skillCharaId);
        const SkillDataStruct *sd = GetSkillDataStruct((int)info.skillId);
        aep->DrawText("SKILL", 0xe, x, y - 0x5f, 1, color, 0x59514f, p17);
        aep->DrawText(info.skillName.UTF8String, 0x20, x, y - 0x4e, 1, color, 0x59514f, p17);
        aep->DrawText(sd->description.UTF8String, 0x19, x, y - 0x22, 1, color, 0x7fb4, p17);
        drawAepTextMultiline(
            info.info.UTF8String, x, y + 0x1f, 1, 0x16, 0x1c, 0x59514f, p17, color);
        return;
    }

    // ---- music / wall collection grids (treasure-map piece unlock state)
    // -------------------
    auto pieceCount = [](const int *table, int mapIdx, int col) {
        int n = 0;
        for (int b = 0; b < 3; b++) {
            if (table[mapIdx * 3 + col] & (1 << b)) {
                n++;
            }
        }
        return n;
    };
    auto drawPieceGrid = [&](const int *pieceTable,
                             neTextureForiOS **panelTex,
                             int panelW,
                             int panelScale,
                             int *anchorOut) {
        for (int i = 0; i < 9; i++) {
            const int mapIdx = findTreasureMapIndexById(i);
            int lit = 0;
            for (int c = 0; c < 3; c++) {
                lit += pieceCount(pieceTable, mapIdx, c);
            }
            const int cy = (i / 3) * 0xcc + y;
            const int cx = (i % 3) * 200 + x;
            const int frameNo = (lit == 0) ? self->m_boardFrame[0] :
                                (lit < 9)  ? self->m_boardFrame[1] :
                                             -1;
            if (frameNo >= 0) {
                drawAepFrameEx(aep,
                               frameNo,
                               cx,
                               cy,
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
                               p17,
                               1);
            }
            neTextureForiOS_draw(aep,
                                 panelTex[i],
                                 0,
                                 0,
                                 panelW,
                                 panelW,
                                 cx - anchorX,
                                 cy - anchorY,
                                 panelScale,
                                 panelScale,
                                 rotation,
                                 0,
                                 0,
                                 color,
                                 alpha,
                                 blend,
                                 0xffffff,
                                 nullptr,
                                 p17,
                                 1);
            if (anchorOut) {
                anchorOut[i * 2] = cx;
                anchorOut[i * 2 + 1] = cy;
            }
        }
    };
    if (self->m_boardUserNo[8] == child) { // music-piece grid
        drawPieceGrid(self->m_musicPieceTableDup, self->m_jacketTex, 0x168, 0x26, nullptr);
        return;
    }
    if (self->m_boardUserNo[12] == child) { // wall-piece grid
        // Disasm +0x400 (0xa45c4): the wall-piece panel scale is 0x64 (100), not
        // 0x26 like music.
        drawPieceGrid(self->m_wallPieceTableDup, self->m_wallNailTex, 0x88, 0x64, nullptr);
        return;
    }

    // ---- collection frame grids + anchor cache (index 9 music, 13 wall)
    // ------------------- Ghidra +0x3f4 / +0x404: a 3x3 grid of the collection
    // frame m_boardFrame[1]; each cell's anchored position (cx-anchorX,
    // cy-anchorY) is cached for the result-popup overlays. The
    // FixedToFP/FPToFixed here are int<->float identity round-trips (no scaling).
    if (self->m_boardUserNo[9] == child || self->m_boardUserNo[13] == child) {
        int *anchorCache =
            (self->m_boardUserNo[9] == child) ? self->m_musicAnchor : self->m_wallAnchor;
        for (int i = 0; i < 9; i++) {
            const int cx = (i % 3) * 200 + x;
            const int cy = (i / 3) * 0xcc + y;
            drawAepFrameEx(aep,
                           self->m_boardFrame[1],
                           cx,
                           cy,
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
                           p17,
                           1);
            anchorCache[i * 2] = cx - anchorX;
            anchorCache[i * 2 + 1] = cy - anchorY;
        }
        return;
    }

    // ---- "new chara available" button (index 17): two-frame icon
    // -------------------------- Ghidra +0x414: m_boardFrame[8] when >=5 tickets
    // AND all charas collected, else [9].
    if (self->m_boardUserNo[17] == child) {
        const bool available =
            self->m_charaTicket >= 5 &&
            countAvailableCharacters((__bridge NSArray *)self->m_gotCharaArray) == 0;
        drawAepFrameEx(aep,
                       self->m_boardFrame[available ? 8 : 9],
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
                       p17,
                       1);
        return;
    }

    // ---- music collection result popup (index 11, +0x3fc)
    // --------------------------------- Ghidra +0x3fc: the selected music jacket
    // + per-piece reveal layers, playing the reveal SE (m_rouletteSe[9] @+0x45c)
    // once (while m_rouletteSeInst is idle/-1) when a newly-collected piece
    // appears, then a final overlay. In each 3-slot piece word, bit b =
    // collected, bit b+8 = already revealed. iPad nudges positions; all scales
    // are integer (scale*N)/100 (no NEON).
    if (self->m_boardUserNo[11] == child) {
        int px = x, py = y;
        if (self->m_padDisplay != 0) {
            px = x + 1;
            py = y - 5;
        }
        neTextureForiOS_draw(aep,
                             self->m_jacketTex[self->m_selMusicPanel],
                             0,
                             0,
                             0x168,
                             0x168,
                             px,
                             py,
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
                             p17,
                             1);
        const int yAdj = (scaleY * 0xe) / 100;
        const int mapIdx = findTreasureMapIndexById(self->m_selMusicPanel);
        const int rowY = y - 0x10;
        bool anyMissing = false, anyNew = false;
        for (int i = 0; i < 9; i++) {
            const uint32_t bits = (uint32_t)self->m_musicPieceTableDup[mapIdx * 3 + i / 3];
            int frameNo = 0;
            bool draw = false;
            if ((bits & (1u << (i % 3))) == 0) { // not collected
                anyMissing = true;
                draw = true;
            } else if ((bits & (1u << (i % 3 + 8))) == 0) { // collected, not yet revealed
                frameNo = self->m_pieceRevealFrame;
                if (self->m_rouletteSeInst < 0) {
                    self->m_rouletteSeInst =
                        (int)[[AudioManager sharedManager] playSe:0
                                                       resourceId:self->m_rouletteSe[9]];
                }
                anyNew = true;
                draw = (frameNo >= 0);
            }
            if (draw) {
                int lx, ly;
                if (self->m_padDisplay == 0) { // phone
                    lx = x - 0xe;
                    ly = rowY;
                } else { // pad
                    ly = (i == 7 ? py - 2 : py) + yAdj;
                    lx = px - (scaleX * 0xe) / 100;
                }
                self->m_aep->drawLayer(self->m_musicPeaceLyr[i],
                                       frameNo,
                                       lx,
                                       ly,
                                       scaleX,
                                       scaleY,
                                       rotation,
                                       anchorX,
                                       anchorY,
                                       color,
                                       alpha,
                                       1,
                                       blend,
                                       0xffffff,
                                       nullptr,
                                       nullptr,
                                       9,
                                       1);
            }
        }
        if (!anyMissing && !anyNew) {
            return;
        }
        self->m_aep->drawLayer(self->m_skillBoardLyr[2],
                               anyMissing ? 0 : self->m_musicResultFrame,
                               x - 0xc,
                               rowY,
                               scaleX,
                               scaleY,
                               rotation,
                               anchorX,
                               anchorY,
                               color,
                               alpha,
                               1,
                               blend,
                               0xffffff,
                               nullptr,
                               nullptr,
                               8,
                               1);
        return;
    }

    // ---- wall collection result popup (index 14, +0x408)
    // ---------------------------------- Ghidra +0x408: the full-board
    // background, then per-piece reveal layers (m_wallPeaceLyr) with the same SE
    // + reveal-bit logic, then a final overlay. The ONE float NEON in this set:
    // on iPad the piece layers are scaled by 1.6949 (DAT_000a4a10 = 0x3FD8F27C,
    // byte-verified) -> zoom = (int)(scale * 1.6949f) + 1.
    if (self->m_boardUserNo[14] == child) {
        neTextureForiOS_draw(aep,
                             self->m_reserveTex[0],
                             0,
                             0,
                             0x280,
                             0x3c0,
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
                             nullptr,
                             p17,
                             1);
        const int zoomX = (int)((float)scaleX * 1.6949f) + 1;
        const int zoomY = (int)((float)scaleY * 1.6949f) + 1;
        const int baseX = x - (anchorX * scaleX) / 100;
        const int baseY = y - (anchorY * scaleY) / 100;
        const int mapIdx = findTreasureMapIndexById(self->m_rouletteMapId);
        bool anyMissing = false, anyNew = false;
        for (int i = 0; i < 9; i++) {
            const uint32_t bits = (uint32_t)self->m_wallPieceTableDup[mapIdx * 3 + i / 3];
            int frameNo = 0;
            bool draw = false;
            if ((bits & (1u << (i % 3))) == 0) {
                anyMissing = true;
                draw = true;
            } else if ((bits & (1u << (i % 3 + 8))) == 0) {
                frameNo = self->m_pieceRevealFrame;
                if (self->m_rouletteSeInst < 0) {
                    self->m_rouletteSeInst =
                        (int)[[AudioManager sharedManager] playSe:0
                                                       resourceId:self->m_rouletteSe[9]];
                }
                anyNew = true;
                draw = (frameNo >= 0);
            }
            if (draw) {
                int lx, ly, sx, sy, ax, ay;
                if (self->m_padDisplay == 0) { // phone
                    lx = baseX - 7;
                    ly = baseY - 7;
                    sx = 100;
                    sy = 100;
                    ax = 0;
                    ay = 0;
                } else { // pad
                    lx = (i == 3) ? x + 2 : x;
                    ly = (i == 3) ? y - 2 : y;
                    sx = zoomX;
                    sy = zoomY;
                    ax = anchorX - 0x7e;
                    ay = anchorY - 0xbc;
                }
                self->m_aep->drawLayer(self->m_wallPeaceLyr[i],
                                       frameNo,
                                       lx,
                                       ly,
                                       sx,
                                       sy,
                                       rotation,
                                       ax,
                                       ay,
                                       color,
                                       alpha,
                                       1,
                                       blend,
                                       0xffffff,
                                       nullptr,
                                       nullptr,
                                       9,
                                       1);
            }
        }
        if (!anyMissing && !anyNew) {
            return;
        }
        self->m_aep->drawLayer(self->m_skillBoardLyr[3],
                               anyMissing ? 0 : self->m_wallResultFrame,
                               baseX,
                               baseY,
                               100,
                               100,
                               rotation,
                               0,
                               0,
                               color,
                               alpha,
                               1,
                               blend,
                               0xffffff,
                               nullptr,
                               nullptr,
                               8,
                               1);
        return;
    }

    // ---- single-texture panels (LAB_000a3d1a tail)
    // ----------------------------------------
    struct {
        int usr;
        int slot;
        int w;
        int h;
    } kPanels[] = {
        {self->m_boardUserNo[3], 0x2, 0x228, 0x228},  // m_reserveTex[2]-ish chara backing
        {self->m_boardUserNo[10], 0x3, 0x168, 0x168}, // small panel
        {self->m_boardUserNo[15], 0x4, 0x280, 0x3c0}, // full-board bg
        {self->m_boardUserNo[18], 0x1, 0x228, 0x228}, // list panel
    };
    for (auto &pnl : kPanels) {
        if (pnl.usr == child) {
            neTextureForiOS_draw(aep,
                                 self->m_reserveTex[pnl.slot],
                                 0,
                                 0,
                                 pnl.w,
                                 pnl.h,
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
                                 nullptr,
                                 p17,
                                 1);
            return;
        }
    }

    // ---- scroll bar / collection-complete pulse badge
    // -------------------------------------
    if (self->m_boardUserNo[19] == child) { // list scroll bar
        if (self->m_charaColLeft > 0) {
            drawAepFrameEx(aep,
                           self->m_boardFrame[10],
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
                           p17,
                           1);
        }
        drawAepFrameEx(aep,
                       self->m_boardFrame[11],
                       self->m_dlgLayoutA[6] + x + 4,
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
                       p17,
                       1);
        return;
    }
    if (self->m_boardUserNo[20] == child) { // collection-complete badge (pulsing)
        int phase = self->m_badgePulse;
        const int a = phase < 0x32 ? 100 : phase < 100 ? phase * -2 + 200 : phase * 2 - 200;
        self->m_badgePulse = (phase + 2) % 0x97;
        if (self->m_charaTicket < 5) {
            return;
        }
        if (countAvailableCharacters((__bridge NSArray *)self->m_gotCharaArray) != 0) {
            return;
        }
        drawAepFrameEx(aep,
                       self->m_boardFrame[12],
                       x - 10,
                       y + 10,
                       scaleX,
                       scaleY,
                       rotation,
                       anchorX,
                       anchorY,
                       a,
                       100 - a,
                       blend,
                       0xffffff,
                       0,
                       p17,
                       1);
        return;
    }

    // ---- roulette result panel / caption
    // --------------------------------------------------
    auto inRange12 = [](int i) { return i >= 0 && i < 12; };
    if (self->m_boardUserNo[24] == child) { // roulette-result event icon
        if (!inRange12(self->m_hudState)) {
            return;
        }
        neTextureForiOS_draw(aep,
                             self->m_eventTex[self->m_hudState],
                             0,
                             0,
                             0x280,
                             0xd0,
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
                             nullptr,
                             p17,
                             1);
        return;
    }
    if (self->m_boardUserNo[25] == child) { // roulette-result caption text
        if (!inRange12(self->m_hudState)) {
            return;
        }
        const char *desc = getStringByIndex12((unsigned)self->m_hudState);
        aep->DrawText(desc, 0x16, x, y - 10, 1, color, 0xffffff, p17);
        return;
    }
}
