//
//  AcMainTask.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The arcade-mode
//  task (arcade select + sugoroku map + option select + note play through AcNoteMng).
//  AcMainTask_update (FUN_00099d18) is the app's largest function (~24 KB / ~4300
//  decompiled lines, heavily inlined); it is reconstructed in pieces from the on-disk
//  decompile (.decompile/AcMainTask_update.c). update() below is the touch/SE preamble
//  and the state dispatch; each state's inlined body is lifted into its own method as
//  it is reconstructed (see STUBS.md for which states remain).
//

#import "AcMainTask.h"

#include <new>
#include <cstring>
#include <ctime>

#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "CharaInfo.h"
#import "CharaManager.h"
#import "MainViewController.h"
#import "SkillData.h"
#import "TreasureMap.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

// Ghidra: AcMainTask_ctor (FUN_00099ab0) — base C_TASK ctor, the arcade RNG
// constructed in place at +0x4f4, then the play-data block (already zeroed by
// m_playData's initialiser) and three sentinels (@ +0x508 = -1, +0x62c = -0x63,
// +0x5a0 = 3).
AcMainTask::AcMainTask() {
    new (&field<uint8_t>(0x4f4)) Random();   // FUN_00062b20: construct the arcade RNG
    field<int>(0x508) = -1;      // no drag anchor yet
    field<int>(0x62c) = -0x63;   // stored as 0xffffff9d
    field<int>(0x5a0) = 3;
}

// Ghidra: AcMainTask_update (FUN_00099d18). Snapshot the touches (recording a drag
// anchor and classifying a tap), refresh the "scrolled past the end" flag, then
// dispatch on the play-data state (@ +0x9f8).
void AcMainTask::update(int /*deltaMs*/) {
    neGraphics &gfx = neGraphics::shared();

    // Touch preamble (Ghidra: the touch loop at 0x99e34..0x99e92). Walk the live
    // touches until one is meaningful:
    //  * a held (valid) touch latches the drag anchor (@ +0x508/+0x50c/+0x510) if none
    //    is set, and marks a drag in progress;
    //  * a released touch that barely moved from its start point (< 11 on each axis,
    //    compared against the raw stored coordinates as the binary does) is a tap.
    m_frameDragging = false;
    m_frameTapped = false;
    m_frameTapTouch = nullptr;
    for (int i = 0, n = gfx.activeTouchCount(); i < n; i++) {
        const neTouchPoint *t = gfx.touchAt(i);
        if (t->valid != 0) {
            if (field<int>(0x508) < 0) {
                field<int>(0x508) = t->id;
                field<int>(0x50c) = (int)((float)t->x / 65536.0f);   // Ghidra: FixedToFP
                field<int>(0x510) = (int)((float)t->y / 65536.0f);
            }
            m_frameDragging = true;
            break;
        }
        if (t->released != 0) {
            int dx = t->x - t->startX;
            if (dx < 0) {
                dx = -dx;
            }
            if (dx > 10) {
                break;   // moved too far horizontally: not a tap
            }
            int dy = t->y - t->startY;
            if (dy < 0) {
                dy = -dy;
            }
            m_frameTapped = (dy < 11);
            m_frameTapTouch = t;
            break;
        }
    }

    // "Scrolled past the last row" flag (@ +0x5f2): list offset >= content bottom.
    field<bool>(0x5f2) = (int)field<short>(0x63c) <= field<int>(0x624);

    switch (state()) {
    case 0:
        stateInit();
        break;
    case 1:
        stateFadeIn();
        break;
    case 2:
        stateTreasureCheck();
        break;
    default:
        break;
    }
}

// case 0 — build the select/map scene, then start the BGM if a treasure record is
// present (subMapId @ +0x620 >= 0); otherwise take the no-treasure path. Ghidra: the
// case 0 body at 0x99e92 (FUN_0009fc90 then playBgm:0.5 / LAB_0009aa74).
void AcMainTask::stateInit() {
    setupScene();   // FUN_0009fc90
    if (field<short>(0x620) >= 0) {
        AudioManager *audio = [AudioManager sharedManager];
        [audio playBgm:0.5f];   // Ghidra: playBgm:, arg 0x3fe00000 == 0.5
    } else {
        field<bool>(0x5ee) = false;   // the binary jumps to LAB_0009aa74 (no-treasure)
    }
}

// case 1 — set a 30-frame fade-out and jump it to fully-faded, restore the menu BGM
// stack, push the sugoroku map-select screen, then advance to the treasure check.
// Ghidra: case 1 (FUN_00010698(scene,2) == playTransition(2,30,0), FUN_00010758(scene,0)).
void AcMainTask::stateFadeIn() {
    AepManager &aep = AepManager::shared();
    aep.playTransition(2, 30, 0);   // FUN_00010698(scene, 2): fade-out, 30 frames
    aep.setTransitionFrame(0);      // FUN_00010758(scene, 0): jump to fully-faded

    AudioManager *audio = [AudioManager sharedManager];
    if ([audio isPushBgm]) {
        [audio popBgm];
    }
    [audio playBgm:0.5f];

    MainViewController *root =
        (__bridge MainViewController *)neSceneManager::rootViewController();
    [root GotoMapSelect];   // -[MainViewController GotoMapSelect] @ 0xc7d8
    state() = 2;
}

// case 2 — read the temp-treasure record; if a sub-map is pending (subMapId >= 0),
// cache it (@ +0x620), load the map, and start play, else keep waiting. Ghidra: case 2
// (UserSettingData treasureTmp; FUN_000a0b58; playBgm at LAB_0009a026).
void AcMainTask::stateTreasureCheck() {
    TreasureTmpData tmp = [UserSettingData treasureTmp];
    field<short>(0x620) = tmp.subMapId;
    if (tmp.subMapId >= 0) {
        loadTreasureMap();   // FUN_000a0b58
        AudioManager *audio = [AudioManager sharedManager];
        [audio playBgm:0.5f];
    }
}

// ===========================================================================
// setupScene — Ghidra FUN_0009fc90. The arcade sugoroku scene builder.
// ===========================================================================

// Byte-verified layer names for the getLyrNo tables (Ghidra: DAT_001327d4 /
// DAT_001327e8 / DAT_0013280c / DAT_001328f4). Each resolves within asset group 5.
static const char *const kLyrSkillBoards[5] = {   // -> +0x21c (+0x230 frame counts)
    "SKILL_COM_BOARD", "RETIRE_COM_BOARD", "MUSIC_PEACE_LOCK1",
    "WALL_PEACE_LOCK1", "FRIEND_NAME_BOARD2"
};
static const char *const kLyrMusicPeace[9] = {    // -> +0x27c
    "MUSIC_PEACE00", "MUSIC_PEACE01", "MUSIC_PEACE02", "MUSIC_PEACE03",
    "MUSIC_PEACE04", "MUSIC_PEACE05", "MUSIC_PEACE06", "MUSIC_PEACE07", "MUSIC_PEACE08"
};
static const char *const kLyrWallPeace[9] = {     // -> +0x2a0
    "WALL_PEACE00", "WALL_PEACE01", "WALL_PEACE02", "WALL_PEACE03",
    "WALL_PEACE04", "WALL_PEACE05", "WALL_PEACE06", "WALL_PEACE07", "WALL_PEACE08"
};
static const char *const kLyrIconMental[4] = {    // -> +0x258 (+0x268 frame counts)
    "ICON_MENTAL00", "ICON_MENTAL01", "ICON_MENTAL02", "ICON_MENTAL03"
};

// getFrameNo names (Ghidra: DAT_00132904 / DAT_0013296c / DAT_00132998 /
// DAT_001329c0 / DAT_001329d0 / PTR_s_TRIANGLE01_05).
static const char *const kFrmBoard[26] = {        // -> +0x2d0
    "CHARA_KOMA00", "MUSIC_PEACE_BOARD_S", "JACKET_QUESTION", "JACKET_DISCOVERY",
    "BT_ROULETTE", "BT_ROULETTE_NO", "BT_ROULETTE_EVENT", "BT_ROULETTE_EVENT_NO",
    "BT_GATYA", "BT_GATYA01", "PAGE_BEFORE", "PAGE_NEXT", "WARNING", "BT_WALL_SAVE",
    "DEFENSE_01_00", "DEFENSE_01_01", "DEFENSE_01_02", "DEFENSE_01_03", "DEFENSE_01_04",
    "DEFENSE_00", "DEFENSE_02", "BT_SQUARE01_00",
    "DEFENSE_03_00", "DEFENSE_03_01", "DEFENSE_03_02", "DEFENSE_03_03"
};
static const char *const kFrmBase1[11] = {        // -> +0x338
    "BASE_00", "BASE_01", "BASE_02", "BASE_03", "BASE_04",
    "BASE_06_00", "BASE_06_01", "BASE_07_00", "BASE_07_01", "BASE_09", "BASE_10"
};
static const char *const kFrmBase08[10] = {       // -> +0x368
    "BASE_08_00", "BASE_08_01", "BASE_08_02", "BASE_08_03", "BASE_08_04",
    "BASE_08_05", "BASE_08_06", "BASE_08_07", "BASE_08_08", "BASE_08_09"
};
static const char *const kFrmBase05[4] = {        // -> +0x390
    "BASE_05_00", "BASE_05_01", "BASE_05_02", "BASE_05_03"
};
static const char *const kFrmTriangle0[6] = {     // -> +0x3a0 (interleaved with the below)
    "TRIANGLE00_05", "TRIANGLE00_04", "TRIANGLE00_03",
    "TRIANGLE00_02", "TRIANGLE00_01", "TRIANGLE00_00"
};
static const char *const kFrmTriangle1[6] = {     // -> +0x3b8
    "TRIANGLE01_05", "TRIANGLE01_04", "TRIANGLE01_03",
    "TRIANGLE01_02", "TRIANGLE01_01", "TRIANGLE01_00"
};

// getUserNo names (Ghidra: DAT_00132a00) -> +0x3d0.
static const char *const kUsrBoard[26] = {
    "S_POINT_NUM", "CHARACT00", "CHARACT01", "CHARACT02", "CHARACT04", "CHARACT05",
    "CHARACT_NAME00", "CHARACT_COMMENT00", "JACKET_QUESTION", "MUSIC_PEACE_BOARD_S",
    "JACKET01", "JACKET09", "WALL_QUESTION", "WALL_PEACE_BOARD_S", "WALL_PEACE",
    "WALL_PEACE01", "ROUL_NUM_BIG", "BT_GATYA", "CHARACT03", "PAGE_BEFORE", "WARNING",
    "TICKET_NUM00", "G_S_POINT_NUM", "STEPS_NUM00", "EVENT_INFO_IMG", "EVENT_INFO_TXT"
};

// The 29 roulette overlay layers + their ordering-table priorities (Ghidra:
// PTR_s_ROULETTE_START_OPEN_00132830 + DAT_0012f8a0) -> +0x2c.
static const char *const kRouletteNames[29] = {
    "ROULETTE_START_OPEN", "ROULETTE_START_ROOP", "ROULETTE_START_OPEN_EVENT",
    "ROULETTE_START_ROOP_EVENT", "ROULETTE_EFF", "SELECTION_CHARA_OPEN",
    "SELECTION_CHARA_CLOSE", "SUGO_COMMENT_BOARD", "MUSIC_PEACE_OPEN", "WALL_PEACE_OPEN",
    "GOAL_OPEN", "GET_MUSIC", "GET_WALL", "GATSHA_OPEN", "WALL_SAVE_COM", "EFF_SKILL2",
    "EFF_SKILL_KOUKA2", "EFF_WARP_3", "SELECT_ARROW", "LIFTING_MUSIC", "LIFTING_WALL",
    "LIFTING_MAP", "LIFTING_AREA", "LIFTING_GAOL_BOARD_01_02", "LIFTING_GAOL_BOARD_02_02",
    "LIFTING_GAOL_BOARD_03_02", "EVENT_TXT_1136", "EVENT_INFO_OPEN", "ICON_REVERSE"
};
static const int kRouletteOrder[29] = {
    20, 20, 20, 20, 19, 15, 15, 25, 11, 11, 23, 23, 23, 14, 7, 31, 32, 31, 16,
    23, 23, 23, 23, 23, 23, 23, 22, 6, 22
};

// 4 sugoroku arrows (Ghidra: PTR_s_SUGOROKU_ARROW01_001328a4) -> +0xc0, order 0x1d.
static const char *const kArrowNames[4] = {
    "SUGOROKU_ARROW01", "SUGOROKU_ARROW03", "SUGOROKU_ARROW02", "SUGOROKU_ARROW00"
};

// The 8 select-panel layers -> +0xa0. Two device-branched name tables (Ghidra:
// DAT_001328d4 default / DAT_001328b4 tall-phone) share one order table
// (DAT_0012f914).
static const char *const kPanelNamesDefault[8] = {   // 640/960 assets
    "IMG960", "CHARACTER_SELECTION640_OPEN", "CHARACTER_SELECTION640_OUT",
    "CHARACTER_CHANGE640", "COLLECTION_SELECT_640_OPEN", "COLLECTION_SELECT_640_OUT",
    "MUSIC_PEACE_S_960_OPEN", "WALL_PEACE_S_960_OPEN"
};
static const char *const kPanelNamesTall[8] = {      // 1136 assets (tall phone, dt==2)
    "IMG1136", "CHARACTER_SELECTION1136_OPEN", "CHARACTER_SELECTION1136_OUT",
    "CHARACTER_CHANGE1136", "COLLECTION_SELECT_1136_OPEN", "COLLECTION_SELECT_1136_OUT",
    "MUSIC_PEACE_S_1136_OPEN", "WALL_PEACE_S_1136_OPEN"
};
static const int kPanelOrder[8] = { 28, 17, 17, 17, 13, 13, 12, 12 };

void AcMainTask::setupScene() {
    // Cache the audio manager for the BGM prep at the tail (Ghidra: local_174).
    AudioManager *audio = [AudioManager sharedManager];

    // Snapshot the pending-treasure record up front; only its subMapId is used here.
    TreasureTmpData tmp = [UserSettingData treasureTmp];

    // Rebuild the character lists (Ghidra: the lazy gCharaManager guard FUN_0002980c,
    // then CharaManager_reload FUN_000b85bc).
    gCharaManager.reload();

    // Cache the scene manager at this+0x28 (every resolve below reads it) and the
    // pad-vs-phone flag at this+0x5f7 (Ghidra: NESceneManager_shared + DAT_00187b84).
    AepManager &aep = AepManager::shared();
    field<AepManager *>(0x28) = &aep;
    neSceneManager::shared();
    field<unsigned char>(0x5f7) = neSceneManager::isPadDisplay() ? 1 : 0;

    // Player progress snapshot.
    field<int>(0x624)   = [UserSettingData treasurePoint];
    field<short>(0x622) = [UserSettingData charaTicket];
    field<short>(0x5fc) = [UserSettingData charaId];

    // Character-panel scroll extent: the available list is laid out 6 per row. The
    // binary derives this through a paired FixedToFP/FPToFixed (a 6.0 lane + a 0.5
    // bias, @0x9fde..) whose exact fixed-point packing is decompiler-obscured; the
    // recovered result is the rounded row count. (Best-effort per rule 7.)
    NSArray *available = gCharaManager.availableInfos();
    field<void *>(0x634) = (__bridge void *)available;  // cached raw (unretained), as the binary does
    const int availableCount = (int)available.count;
    field<int>(0x638) = (int)((float)availableCount / 6.0f + 0.5f);

    // Working copy of the owned-character set (+1 retained; released on the next
    // rebuild). Ghidra: release the old, then gotCharaArray mutableCopy.
    if (field<void *>(0x630)) {
        (void)(__bridge_transfer id)field<void *>(0x630);
        field<void *>(0x630) = nullptr;
    }
    field<void *>(0x630) =
        (__bridge_retained void *)[[UserSettingData gotCharaArray] mutableCopy];

    // Resolve the active character's skill record (Ghidra: availableInfoForCharaId,
    // then GetSkillDataStruct on its skillId).
    const short charaId = [UserSettingData charaId];
    CharaInfo *info = gCharaManager.availableInfoForCharaId(charaId);
    field<void *>(0x8a4) = (__bridge void *)info;
    field<const SkillDataStruct *>(0x8a8) = GetSkillDataStruct((int)info.skillId);

    // Clear the 0x3c-byte selection-index scratch to -1 (Ghidra: memset +0x474).
    std::memset(&field<uint8_t>(0x474), 0xff, 0x3c);

    // Cache the fade-overlay quad extents + the screen scale (Ghidra: FUN_0000f498 /
    // FUN_0000f4a4 / DAT_00187b80).
    field<int>(0x524) = aep.transitionOverlayWidth();
    field<int>(0x528) = aep.transitionOverlayHeight();
    neSceneManager::shared();
    field<float>(0x52c) = neSceneManager::screenScale();

    computeStepValues();   // FUN_000a1950 — fills the per-skill step table at +0x578

    field<short>(0x620)         = tmp.subMapId;
    field<unsigned char>(0x8b0) = 0xff;

    // Seed the arcade RNG with wall-clock time (Ghidra: time(0) -> FUN_00062b5c).
    rng().setSeed((unsigned)time(nullptr));

    // Device-branched layout constants. this+0x5f7 == 0 is a phone; the extra
    // this+0x614/0x618 seed applies only to a tall (displayType 2) phone.
    const bool pad = (field<unsigned char>(0x5f7) != 0);
    if (!pad) {
        if ([[AppDelegate appDelegate] displayType] == 2) {
            field<int>(0x614) = 0x6a;
            field<int>(0x618) = 0x9e;
        }
        field<int>(0x530) = 0x280;  field<int>(0x534) = 0x470;  field<int>(0x538) = 0x1a6;
        field<int>(0x53c) = -0x149; field<int>(0x540) = 0xd0;   field<int>(0x544) = 0x8a;
        field<int>(0x548) = 0x15;   field<int>(0x54c) = -0xdd;  field<int>(0x550) = 0x9c;
        field<int>(0x554) = 0x34;   field<int>(0x558) = 0x11;   field<int>(0x55c) = 0xe9;
        field<int>(0x560) = 0x1c1;  field<int>(0x56c) = -0x7c;  field<int>(0x570) = 0xb4;
        field<int>(0x574) = 0x7c;
        field<int>(0x958) = 0x94;   field<int>(0x95c) = 0x334;  field<int>(0x960) = 0x168;
        field<int>(0x964) = 0x7d;   field<int>(0x968) = 0x136;  field<int>(0x96c) = 0x2a8;
        field<int>(0x970) = 0x110;  field<int>(0x974) = 0x60;   field<int>(0x978) = 0x22;
        field<int>(0x97c) = 0x2a8;  field<int>(0x980) = 0x110;  field<int>(0x984) = 0x60;
        field<int>(0x990) = 0x1dc;  field<int>(0x994) = 0xe2;   field<int>(0x998) = 0xf5;
        field<int>(0x99c) = 0x70;   field<int>(0x9a0) = 0xe6;   field<int>(0x9a4) = 0x5c;
        field<int>(0x9a8) = 5;      field<int>(0x9ac) = 0x70;   field<int>(0x9b0) = 0xe6;
        field<int>(0x9b4) = 0x5c;   field<int>(0x954) = 0x20;   field<int>(0x9b8) = 0;
        field<int>(0x9bc) = 0;      field<int>(0x9c0) = 0x8c;   field<int>(0x9c4) = 0x50;
        field<int>(0x9c8) = 0;      field<int>(0x9cc) = 0;      field<int>(0x9d0) = 0x8c;
        field<int>(0x9d4) = 0x50;   field<int>(0x9d8) = 0;      field<int>(0x9dc) = 0;
        field<int>(0x9e0) = 0x8c;   field<int>(0x9e4) = 0x50;   field<int>(0x9e8) = 0xcd;
        field<int>(0x9ec) = field<int>(0x614) + 0x35a;
        field<int>(0x9f0) = 0xf0;   field<int>(0x9f4) = 0x5c;
    } else {
        field<int>(0x530) = 0x300;  field<int>(0x534) = 0x400;  field<int>(0x538) = 0x4de;
        field<int>(0x53c) = -0xda;  field<int>(0x540) = 0x122;  field<int>(0x544) = 0xda;
        field<int>(0x548) = 10;     field<int>(0x54c) = -0x170; field<int>(0x550) = 0xeb;
        field<int>(0x554) = 0x5c;   field<int>(0x558) = 3;      field<int>(0x55c) = 0x119;
        field<int>(0x564) = 0x22f;  field<int>(0x568) = 0x345;  field<int>(0x56c) = -0xba;
        field<int>(0x570) = 0x116;  field<int>(0x574) = 0xba;
        field<int>(0x958) = 0xfe;   field<int>(0x95c) = 0x6b0;  field<int>(0x960) = 0x168;
        field<int>(0x964) = 0x7d;   field<int>(0x968) = 0x19e;  field<int>(0x96c) = 0x620;
        field<int>(0x970) = 0x110;  field<int>(0x974) = 0x60;   field<int>(0x978) = 0x88;
        field<int>(0x97c) = 0x620;  field<int>(0x980) = 0x110;  field<int>(0x984) = 0x60;
        field<int>(0x990) = 0x329;  field<int>(0x994) = 0x183;  field<int>(0x998) = 0x1b0;
        field<int>(0x99c) = 0xd7;   field<int>(0x9a0) = 0x150;  field<int>(0x9a4) = 0x6e;
        field<int>(0x9a8) = 0x22;   field<int>(0x9ac) = 0xd7;   field<int>(0x9b0) = 0x150;
        field<int>(0x9b4) = 0x6e;   field<int>(0x954) = 0x30;   field<int>(0x9b8) = 0x119;
        const int y = field<int>(0x528) - 0xba;   // iVar5 in the decompile
        field<int>(0x9bc) = y;      field<int>(0x9c0) = 0x116;  field<int>(0x9c4) = 0xba;
        field<int>(0x9c8) = 0x22f;  field<int>(0x9cc) = y;      field<int>(0x9d0) = 0x116;
        field<int>(0x9d4) = 0xba;   field<int>(0x9d8) = 0x345;  field<int>(0x9dc) = y;
        field<int>(0x9e0) = 0x116;  field<int>(0x9e4) = 0xba;   field<int>(0x9e8) = 0x1ee;
        field<int>(0x9ec) = 0x5c8;  field<int>(0x9f0) = 0x230;  field<int>(0x9f4) = 0x8c;
    }

    buildSelectListLayout();   // FUN_000a21a8

    // Load the sugoroku asset group into slot 5 (Ghidra: FUN_0000f758).
    AepLoadGroup(&aep, 5, pad ? "sugoroku_ipad" : "sugoroku");

    setupResolveHandles();
    setupBuildOverlays();
    setupLoadTextures();

    // Prime the mode-select BGM (Ghidra: appAppSupportDirectory + bgm01_modesel.m4a).
    NSString *bgmPath = [[AppDelegate appAppSupportDirectory]
        stringByAppendingPathComponent:@"bgm01_modesel.m4a"];
    if ([audio isPushBgm]) {
        [audio popBgm];
    }
    [audio loadBgm:bgmPath isLoop:YES];
    [audio setBgmVolume:[UserSettingData bgmVolume]];

    // Unlock the board-8 bonus treasure, load the pending map, seed its scroll, then
    // install the group-5 draw callback (Ghidra: FUN_000a345c / FUN_000a0b58 /
    // FUN_000a3550 / FUN_0000f9b0 with the render routine FUN_000a3724).
    AcMainUnlockBonusTreasure();
    loadTreasureMap();
    refreshMapScroll(0);
    aep.setGroupDrawCallback(5, &AcMainSugorokuDraw, this);
}

// Resolve the ~50 layer / frame / user handle tables into the this+0x21c.. arrays
// (Ghidra: the getLyrNo/layerFrameCount/getFrameNo/getUserNo loops of FUN_0009fc90).
void AcMainTask::setupResolveHandles() {
    AepManager &aep = *field<AepManager *>(0x28);

    for (int i = 0; i < 5; i++) {
        const int lyr = aep.getLyrNo(5, kLyrSkillBoards[i]);
        field<int>(0x21c + i * 4) = lyr;
        field<int>(0x230 + i * 4) = aep.layerFrameCount(lyr);
    }
    for (int i = 0; i < 9; i++) {
        field<int>(0x27c + i * 4) = aep.getLyrNo(5, kLyrMusicPeace[i]);
    }
    field<int>(0x2c4) = aep.layerFrameCount(field<int>(0x27c));
    for (int i = 0; i < 9; i++) {
        field<int>(0x2a0 + i * 4) = aep.getLyrNo(5, kLyrWallPeace[i]);
    }
    field<int>(0x2c8) = aep.layerFrameCount(field<int>(0x2a0));
    for (int i = 0; i < 4; i++) {
        const int lyr = aep.getLyrNo(5, kLyrIconMental[i]);
        field<int>(0x258 + i * 4) = lyr;
        field<int>(0x268 + i * 4) = aep.layerFrameCount(lyr);
    }

    for (int i = 0; i < 26; i++) field<int>(0x2d0 + i * 4) = aep.getFrameNo(5, kFrmBoard[i]);
    for (int i = 0; i < 11; i++) field<int>(0x338 + i * 4) = aep.getFrameNo(5, kFrmBase1[i]);
    if (field<unsigned char>(0x5f7) != 0) {   // pad only
        field<int>(0x364) = aep.getFrameNo(5, "BT_ROULETTE_MOVE");
    }
    for (int i = 0; i < 10; i++) field<int>(0x368 + i * 4) = aep.getFrameNo(5, kFrmBase08[i]);
    for (int i = 0; i < 4;  i++) field<int>(0x390 + i * 4) = aep.getFrameNo(5, kFrmBase05[i]);
    for (int i = 0; i < 6;  i++) {   // interleaved TRIANGLE00 / TRIANGLE01
        field<int>(0x3a0 + i * 4) = aep.getFrameNo(5, kFrmTriangle0[i]);
        field<int>(0x3b8 + i * 4) = aep.getFrameNo(5, kFrmTriangle1[i]);
    }

    for (int i = 0; i < 26; i++) field<int>(0x3d0 + i * 4) = aep.getUserNo(5, kUsrBoard[i]);
}

// Build the ~35 AepLyrCtrl overlay objects (roulette / arrows / panels), then apply
// the by-hand tweaks the scene makes to a couple of roulette layers (Ghidra: the
// operator_new(0x60)+ctor+init loops of FUN_0009fc90 and the +0x3c/+0x44/+0x18/+0x1c
// stores).
void AcMainTask::setupBuildOverlays() {
    const bool pad = (field<unsigned char>(0x5f7) != 0);

    // 29 roulette layers -> +0x2c: new(0x60)+ctor+init(5, name, owner=this, order).
    for (int i = 0; i < 29; i++) {
        AepLyrCtrl *layer = new AepLyrCtrl();
        field<AepLyrCtrl *>(0x2c + i * 4) = layer;
        layer->init(5, kRouletteNames[i], this, kRouletteOrder[i]);
    }
    // 4 arrows -> +0xc0, order 0x1d.
    for (int i = 0; i < 4; i++) {
        AepLyrCtrl *layer = new AepLyrCtrl();
        field<AepLyrCtrl *>(0xc0 + i * 4) = layer;
        layer->init(5, kArrowNames[i], this, 0x1d);
    }
    // 8 select panels -> +0xa0. The tall-phone name table is used only for a tall
    // (displayType 2) phone; on a pad the two COLLECTION_SELECT panels (i == 4/5) are
    // skipped entirely.
    const bool tall = ([[AppDelegate appDelegate] displayType] == 2) && !pad;
    const char *const *panelNames = tall ? kPanelNamesTall : kPanelNamesDefault;
    for (int i = 0; i < 8; i++) {
        if (!pad || (i != 4 && i != 5)) {
            AepLyrCtrl *layer = new AepLyrCtrl();
            field<AepLyrCtrl *>(0xa0 + i * 4) = layer;
            layer->init(5, panelNames[i], this, kPanelOrder[i]);
        }
    }

    // Hand-tune two roulette layers: shorten roulette[1] by one frame and set
    // roulette[3] to (roulette[1] original length - 2) at 0.8 alpha.
    AepLyrCtrl *roul1 = field<AepLyrCtrl *>(0x30);  // roulette index 1
    AepLyrCtrl *roul3 = field<AepLyrCtrl *>(0x38);  // roulette index 3
    const int roul1Frames = roul1->frameCount();
    roul1->frameCount() = roul1Frames - 1;
    roul3->frameCount() = roul1Frames - 2;
    roul3->alpha() = 0.8f;   // 0x3f4ccccd

    // Anchor eight specific roulette layers to the layout base (y cleared, z = raw
    // field<int>(0x614)); indices derived from the +0x18/+0x1c store offsets.
    static const int kAnchorIndex[8] = { 8, 9, 5, 6, 10, 11, 12, 14 };
    const int anchor = field<int>(0x614);
    for (int i = 0; i < 8; i++) {
        field<AepLyrCtrl *>(0x2c + kAnchorIndex[i] * 4)->setRouletteAnchor(anchor);
    }
}

// Load the scene's textures: the two bundled circles, the active character's board
// sprite, the three 10-digit number sets, and the 12 event icons (Ghidra: the
// operator_new(0x18)+ctor+load blocks of FUN_0009fc90). The number-set names came
// from verified CFString tables (PTR_cf_num_points0 / PTR_cf_num_roulette_0 /
// PTR_cf_ticket_num0); they are literal "num_points0".."9" etc.
void AcMainTask::setupLoadTextures() {
    NSBundle *bundle = [NSBundle mainBundle];

    // circle / blind_circle -> +0xd4 / +0xe4.
    neTextureForiOS *circleTex = new neTextureForiOS();
    field<neTextureForiOS *>(0xd4) = circleTex;
    circleTex->load([[bundle pathForResource:@"circle" ofType:@"png"] UTF8String]);

    neTextureForiOS *blindTex = new neTextureForiOS();
    field<neTextureForiOS *>(0xe4) = blindTex;
    blindTex->load([[bundle pathForResource:@"blind_circle" ofType:@"png"] UTF8String]);

    // The active character's board sprite from the downloadable support dir -> +0xdc.
    neTextureForiOS *charaTex = new neTextureForiOS();
    field<neTextureForiOS *>(0xdc) = charaTex;
    NSString *charaFile =
        [NSString stringWithFormat:@"sugo_chara%03d.png", (int)[UserSettingData charaId]];
    NSString *charaPath =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:charaFile];
    charaTex->load([charaPath UTF8String]);

    // 10 digit glyphs each for points (+0xfc), roulette (+0x124) and ticket (+0x14c).
    for (int i = 0; i < 10; i++) {
        neTextureForiOS *pointsTex = new neTextureForiOS();
        field<neTextureForiOS *>(0xfc + i * 4) = pointsTex;
        pointsTex->load([[bundle pathForResource:[NSString stringWithFormat:@"num_points%d", i]
                                           ofType:@"png"] UTF8String]);

        neTextureForiOS *roulTex = new neTextureForiOS();
        field<neTextureForiOS *>(0x124 + i * 4) = roulTex;
        roulTex->load([[bundle pathForResource:[NSString stringWithFormat:@"num_roulette_%d", i]
                                         ofType:@"png"] UTF8String]);

        neTextureForiOS *ticketTex = new neTextureForiOS();
        field<neTextureForiOS *>(0x14c + i * 4) = ticketTex;
        ticketTex->load([[bundle pathForResource:[NSString stringWithFormat:@"ticket_num%d", i]
                                           ofType:@"png"] UTF8String]);
    }

    // 12 event icons ("event_0_%03d@2x") -> +0x1ec.
    for (int i = 0; i < 12; i++) {
        neTextureForiOS *eventTex = new neTextureForiOS();
        field<neTextureForiOS *>(0x1ec + i * 4) = eventTex;
        eventTex->load([[bundle pathForResource:[NSString stringWithFormat:@"event_0_%03d@2x", i]
                                          ofType:@"png"] UTF8String]);
    }
}

// ===========================================================================
// loadTreasureMap — Ghidra FUN_000a0b58. Load the pending sugoroku map, snapshot
// the record + progress, rebuild the board scroll, and push the board BGM.
// ===========================================================================

// Ghidra: FUN_000ce1a8 — the "read count" (number of board-story pages) for a
// sugoroku sub-map. Only boards 6x and 8x (sub 0..2) have pages; everything else is
// 0. Tables byte-verified at DAT_0012fb90 / DAT_0012fb9c.
static int TreasureReadCount(short subMapId) {
    static const int kBoard6[3] = { 41, 35, 47 };   // DAT_0012fb90
    static const int kBoard8[3] = { 64, 72, 71 };   // DAT_0012fb9c
    const int board = subMapId / 10;
    const int sub   = subMapId - board * 10;
    if (board == 8) {
        if ((unsigned)sub < 3) return kBoard8[sub];
    } else if (board == 6 && (unsigned)sub < 3) {
        return kBoard6[sub];
    }
    return 0;
}

// Sub-map board number (subMapId/10) -> board-background / board-BGM asset numbers.
// Only indices 0..4 and 7 are reachable (the 0x9f bitmask gate); both tables are the
// identity there. Byte-verified at DAT_0012f934 / DAT_0012f946.
static const short kMapBgNumber[9]  = { 0, 1, 2, 3, 4, -1, -1, 7, -1 };
static const short kMapBgmNumber[9] = { 0, 1, 2, 3, 4,  0,  6, 7,  8 };

void AcMainTask::loadTreasureMap() {
    const short subMapId = field<short>(0x620);
    if (subMapId < 0) {
        return;   // nothing pending (subMapId == -1)
    }

    // Drop the previous owned-character working copy (+0x630, +1 retained).
    if (field<void *>(0x630)) {
        (void)(__bridge_transfer id)field<void *>(0x630);
        field<void *>(0x630) = nullptr;
    }

    const int bgIndex = subMapId / 10;   // board number (Ghidra: local_110)

    // Reset the per-map play flags + counters.
    std::memset(&field<uint8_t>(0x474), 0xff, 0x3c);
    field<unsigned char>(0x5ec) = 0;
    field<unsigned char>(0x5ed) = 0;
    field<unsigned char>(0x5ee) = 1;
    field<int>(0x5f3) = 0;
    field<int>(0x5ef) = 0;

    // Re-snapshot player progress.
    field<int>(0x624)   = [UserSettingData treasurePoint];
    field<short>(0x622) = [UserSettingData charaTicket];
    field<void *>(0x630) =
        (__bridge_retained void *)[[UserSettingData gotCharaArray] mutableCopy];
    field<short>(0x5fc) = [UserSettingData charaId];
    field<unsigned char>(0x8b0) = 0xff;
    field<int>(0x61c) = 100;

    // Board-story read progress (Ghidra: FUN_000ce1a8 count, then treasureReadNo:).
    const int readCount = TreasureReadCount(subMapId);
    field<int>(0x8c0) = readCount;
    if (readCount < 1) {
        field<int>(0x8bc) = -1;
    } else {
        field<int>(0x8bc) = [UserSettingData treasureReadNo:subMapId];
    }

    // Stop every scene layer built by setupScene before the map rebuild (Ghidra: the
    // FUN_0002cb5c loops over the roulette / panel / arrow slots + the bg layer).
    for (int off = 0x2c; off < 0xa0; off += 4) {   // 29 roulette
        if (AepLyrCtrl *l = field<AepLyrCtrl *>(off)) l->stopPlay();
    }
    for (int off = 0xa0; off < 0xc0; off += 4) {    // 8 panels
        if (AepLyrCtrl *l = field<AepLyrCtrl *>(off)) l->stopPlay();
    }
    for (int off = 0xc0; off < 0xd0; off += 4) {    // 4 arrows
        if (AepLyrCtrl *l = field<AepLyrCtrl *>(off)) l->stopPlay();
    }
    if (AepLyrCtrl *bg = field<AepLyrCtrl *>(0xd0)) bg->stopPlay();

    // Re-read the pending record (its non-position fields are copied in below).
    TreasureTmpData tmp = [UserSettingData treasureTmp];

    // Free the previous map object (Ghidra: FUN_000ce2e4 pre-step + dtor FUN_000ce330
    // + operator delete; modelled as `delete`).
    if (TreasureMap *old = field<TreasureMap *>(0x4b0)) {
        delete old;
        field<TreasureMap *>(0x4b0) = nullptr;
    }

    // Load "map_%03d.map" for this sub-map.
    NSString *mapName = [NSString stringWithFormat:@"map_%03d", (int)subMapId];
    NSString *mapPath = [[NSBundle mainBundle] pathForResource:mapName ofType:@"map"];
    TreasureMap *map = new TreasureMap();   // FUN_000ce2b0
    field<TreasureMap *>(0x4b0) = map;
    map->load([mapPath UTF8String]);         // FUN_000ce340

    // Copy the map header into play data.
    const int nodeCount = map->nodeCount();
    field<uint16_t>(0x4c4)     = (uint16_t)nodeCount;
    field<const void *>(0x4b4) = map->nodes();
    field<int16_t>(0x4c6)      = map->field5c();
    field<int>(0x4b8)          = map->field58();

    // Choose the current board position: the pending record's node id, or the map's
    // start node when it is out of range (id <= 0 or >= node count).
    if (tmp.raw0x04 <= 0 || tmp.raw0x04 >= nodeCount) {
        tmp.raw0x04 = map->startSubId();
    }

    // Current node screen origin (tile size 0x1a == 26 px) + the "reached" flag.
    const TreasureMap::Node *cur = map->findArea(tmp.raw0x04);   // FUN_000ce934
    field<const void *>(0x4bc) = cur;
    field<float>(0x5cc) = (float)((cur ? cur->x : 0) * 0x1a);
    field<float>(0x5d0) = (float)((cur ? cur->y : 0) * 0x1a);
    field<unsigned>(0x5d4) = (tmp.raw0x10 == 2) ? (unsigned)tmp.raw0x10 : 0u;
    field<int>(0x628)   = tmp.mainMapId;
    field<short>(0x4f0) = tmp.raw0x06;
    std::memcpy(&field<uint8_t>(0x894), tmp.raw0x35, 15);   // board-visited bitmap (0x894..0x8a2)

    // --- Scroll bounding box + clamp. The node bounding box drives the scroll rect;
    // the exact NEON lane composition of the origin/size/centre/clamp vectors (Ghidra:
    // the FloatVectorAdd/Sub chain @ 0xa0d..0xa1050) is decompiler-obscured, so the
    // geometry below is a documented best-effort (tile size 26, the +104/0x34/0x40
    // paddings, the half-viewport from +0x524/+0x528, and the byte-verified ±268 and
    // device-margin constants). FUN_000a4e84 applies the final clamp.
    const TreasureMap::Node *nodes = map->nodes();
    int minX = 0, maxX = 0, minY = 0, maxY = 0;
    if (nodes && nodeCount > 0) {
        minX = maxX = nodes[0].x;
        minY = maxY = nodes[0].y;
        for (int i = 1; i < nodeCount; i++) {
            const int x = nodes[i].x, y = nodes[i].y;
            if (x > maxX) maxX = x;
            if (x < minX) minX = x;
            if (y > maxY) maxY = y;
            if (y < minY) minY = y;
        }
    }
    const float xOrigin  = (float)(minX * 0x1a);
    const float yOrigin  = (float)(minY * 0x1a);
    const float contentW = (float)((maxX - minX) * 0x1a + 0x68);   // +104
    const float halfW = (float)(field<int>(0x524) / 2);
    const float halfH = (float)(field<int>(0x528) / 2);
    const bool  pad = (field<unsigned char>(0x5f7) != 0);
    const float marginTop = pad ? 380.0f : 480.0f;   // DAT_000a148c / DAT_000a1490
    const float marginBot = pad ? 480.0f : 300.0f;   // DAT_000a1494 / DAT_000a1498
    const float centreX = xOrigin + halfW + 268.0f;  // DAT_000a1294
    field<float>(0x4c8) = xOrigin;
    field<float>(0x4cc) = yOrigin;
    field<float>(0x4d0) = contentW;
    field<float>(0x4e0) = centreX;
    field<float>(0x4e4) = yOrigin + halfH - marginTop;
    field<float>(0x4e8) = centreX;
    field<float>(0x4ec) = yOrigin + halfH + marginBot;
    field<float>(0x4d8) = xOrigin + (float)((cur ? cur->x * 0x1a : 0) + 0x34);
    field<float>(0x4dc) = yOrigin + (float)((cur ? cur->y * 0x1a : 0) + 0x40);
    applyMapScrollBounds(field<float>(0x4dc));   // FUN_000a4e84

    // --- Board background: load the board-bg layer group + build its AepLyrCtrl. Only
    // reachable board indices (bit set in the 0x9f mask) get a background.
    if ((0x9f >> (bgIndex & 0xff)) & 1) {
        NSString *bgGroupName;
        NSString *bgLoopName;
        if (!pad) {
            bgGroupName = [NSString stringWithFormat:@"sugoroku_bg%02d", (int)kMapBgNumber[bgIndex]];
            bgLoopName  = ([[AppDelegate appDelegate] displayType] == 2) ? @"BG_LOOP1136" : @"BG_LOOP960";
        } else {
            bgGroupName = [NSString stringWithFormat:@"sugoroku_bg%02d_ipad", (int)kMapBgNumber[bgIndex]];
            bgLoopName  = @"BG_LOOP";
        }
        AepManager &aep = *field<AepManager *>(0x28);
        AepLoadGroup(&aep, 6, [bgGroupName UTF8String]);   // FUN_0000f758 slot 6
        AepLyrCtrl *bgLayer = new AepLyrCtrl();
        field<AepLyrCtrl *>(0xd0) = bgLayer;
        bgLayer->init(6, [bgLoopName UTF8String], this, 0x24);
    }

    // Board-bg texture (+0xd8): "sugoroku_bg%02d(~iPad)" for this board index.
    if (neTextureForiOS *oldBg = field<neTextureForiOS *>(0xd8)) {
        delete oldBg;
        field<neTextureForiOS *>(0xd8) = nullptr;
    }
    neTextureForiOS *bgTex = new neTextureForiOS();
    field<neTextureForiOS *>(0xd8) = bgTex;
    NSString *bgTexName = pad
        ? [NSString stringWithFormat:@"sugoroku_bg%02d~iPad", bgIndex]
        : [NSString stringWithFormat:@"sugoroku_bg%02d", bgIndex];
    bgTex->load([[[NSBundle mainBundle] pathForResource:bgTexName ofType:@"png"] UTF8String]);

    // Remaining record fields + the board character/panel builders.
    field<short>(0x8ac) = tmp.raw0x44;
    field<char>(0x8b8)  = (char)tmp.raw0x52;
    field<char>(0x8b9)  = (char)tmp.raw0x51;
    buildMapCharaLayers();   // FUN_000a2264
    buildMapPanelLayers();   // FUN_000a2650

    // Cache the map's display name (+0x944, +1 retained), replacing any previous.
    if (field<void *>(0x944)) {
        (void)(__bridge_transfer id)field<void *>(0x944);
        field<void *>(0x944) = nullptr;
    }
    field<void *>(0x944) =
        (__bridge_retained void *)[NSString stringWithUTF8String:(const char *)tmp.raw0x28];

    // Push + load the board treasure BGM ("bgm04_tre_%02d.m4a").
    AudioManager *audio = [AudioManager sharedManager];
    NSString *bgmName =
        [NSString stringWithFormat:@"bgm04_tre_%02d.m4a", (int)kMapBgmNumber[bgIndex]];
    NSString *bgmPath = [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:bgmName];
    [audio pushBgm];
    [audio loadBgm:bgmPath isLoop:YES];
    field<unsigned char>(0x5d8) = 0xff;
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
