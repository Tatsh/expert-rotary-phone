// AcMainTask's scene builder: the byte-verified asset-name tables, setupScene itself, and the
// three passes it delegates to for handle resolution, overlay construction and texture loading.
//
// This is a body fragment, not a translation unit. See AcMainTaskWalk.mm.inc for why these are
// included into AcMainTask.mm rather than compiled separately, and why the suffix is .mm.inc.

// Byte-verified layer names for the getLyrNo tables (Ghidra: DAT_001327d4 /
// DAT_001327e8 / DAT_0013280c / DAT_001328f4). Each resolves within asset
// group 5.
constexpr const char *const kLyrSkillBoards[5] = { // -> +0x21c (+0x230 frame counts)
    "SKILL_COM_BOARD",
    "RETIRE_COM_BOARD",
    "MUSIC_PEACE_LOCK1",
    "WALL_PEACE_LOCK1",
    "FRIEND_NAME_BOARD2"};
constexpr const char *const kLyrMusicPeace[9] = { // -> +0x27c
    "MUSIC_PEACE00",
    "MUSIC_PEACE01",
    "MUSIC_PEACE02",
    "MUSIC_PEACE03",
    "MUSIC_PEACE04",
    "MUSIC_PEACE05",
    "MUSIC_PEACE06",
    "MUSIC_PEACE07",
    "MUSIC_PEACE08"};
constexpr const char *const kLyrWallPeace[9] = { // -> +0x2a0
    "WALL_PEACE00",
    "WALL_PEACE01",
    "WALL_PEACE02",
    "WALL_PEACE03",
    "WALL_PEACE04",
    "WALL_PEACE05",
    "WALL_PEACE06",
    "WALL_PEACE07",
    "WALL_PEACE08"};
constexpr const char *const kLyrIconMental[4] = { // -> +0x258 (+0x268 frame counts)
    "ICON_MENTAL00",
    "ICON_MENTAL01",
    "ICON_MENTAL02",
    "ICON_MENTAL03"};

// getFrameNo names (Ghidra: DAT_00132904 / DAT_0013296c / DAT_00132998 /
// DAT_001329c0 / DAT_001329d0 / PTR_s_TRIANGLE01_05).
constexpr const char *const kFrmBoard[26] = { // -> +0x2d0
    "CHARA_KOMA00",  "MUSIC_PEACE_BOARD_S", "JACKET_QUESTION",   "JACKET_DISCOVERY",
    "BT_ROULETTE",   "BT_ROULETTE_NO",      "BT_ROULETTE_EVENT", "BT_ROULETTE_EVENT_NO",
    "BT_GATYA",      "BT_GATYA01",          "PAGE_BEFORE",       "PAGE_NEXT",
    "WARNING",       "BT_WALL_SAVE",        "DEFENSE_01_00",     "DEFENSE_01_01",
    "DEFENSE_01_02", "DEFENSE_01_03",       "DEFENSE_01_04",     "DEFENSE_00",
    "DEFENSE_02",    "BT_SQUARE01_00",      "DEFENSE_03_00",     "DEFENSE_03_01",
    "DEFENSE_03_02", "DEFENSE_03_03"};
constexpr const char *const kFrmBase1[11] = { // -> +0x338
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
constexpr const char *const kFrmBase08[10] = { // -> +0x368
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
constexpr const char *const kFrmBase05[4] = { // -> +0x390
    "BASE_05_00",
    "BASE_05_01",
    "BASE_05_02",
    "BASE_05_03"};
constexpr const char *const kFrmTriangle0[6] = { // -> +0x3a0 (interleaved with the below)
    "TRIANGLE00_05",
    "TRIANGLE00_04",
    "TRIANGLE00_03",
    "TRIANGLE00_02",
    "TRIANGLE00_01",
    "TRIANGLE00_00"};
constexpr const char *const kFrmTriangle1[6] = { // -> +0x3b8
    "TRIANGLE01_05",
    "TRIANGLE01_04",
    "TRIANGLE01_03",
    "TRIANGLE01_02",
    "TRIANGLE01_01",
    "TRIANGLE01_00"};

// getUserNo names (Ghidra: DAT_00132a00) -> +0x3d0.
constexpr const char *const kUsrBoard[26] = {
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
constexpr const char *const kRouletteNames[29] = {"ROULETTE_START_OPEN",
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
constexpr int kRouletteOrder[29] = {20, 20, 20, 20, 19, 15, 15, 25, 11, 11, 23, 23, 23, 14, 7,
                                    31, 32, 31, 16, 23, 23, 23, 23, 23, 23, 23, 22, 6,  22};

// 4 sugoroku arrows (Ghidra: PTR_s_SUGOROKU_ARROW01_001328a4) -> +0xc0, order
// 0x1d.
constexpr const char *const kArrowNames[4] = {
    "SUGOROKU_ARROW01", "SUGOROKU_ARROW03", "SUGOROKU_ARROW02", "SUGOROKU_ARROW00"};

// The 8 select-panel layers -> +0xa0. Two device-branched name tables (Ghidra:
// DAT_001328d4 default / DAT_001328b4 tall-phone) share one order table
// (DAT_0012f914).
constexpr const char *const kPanelNamesDefault[8] = { // 640/960 assets
    "IMG960",
    "CHARACTER_SELECTION640_OPEN",
    "CHARACTER_SELECTION640_OUT",
    "CHARACTER_CHANGE640",
    "COLLECTION_SELECT_640_OPEN",
    "COLLECTION_SELECT_640_OUT",
    "MUSIC_PEACE_S_960_OPEN",
    "WALL_PEACE_S_960_OPEN"};
constexpr const char *const kPanelNamesTall[8] = { // 1136 assets (tall phone, dt==2)
    "IMG1136",
    "CHARACTER_SELECTION1136_OPEN",
    "CHARACTER_SELECTION1136_OUT",
    "CHARACTER_CHANGE1136",
    "COLLECTION_SELECT_1136_OPEN",
    "COLLECTION_SELECT_1136_OUT",
    "MUSIC_PEACE_S_1136_OPEN",
    "WALL_PEACE_S_1136_OPEN"};
constexpr int kPanelOrder[8] = {28, 17, 17, 17, 13, 13, 12, 12};

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
    m_padDisplay = neSceneManager::isPadDisplay();

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
    const int availableCount = static_cast<int>(available.count);
    m_charaRowCount = static_cast<int>(static_cast<float>(availableCount) / 6.0f + 0.5f);

    // Working copy of the owned-character set (+1 retained; released on the next
    // rebuild). Ghidra: release the old, then gotCharaArray mutableCopy.
    if (m_gotCharaArray) {
        static_cast<void>((__bridge_transfer id)m_gotCharaArray);
        m_gotCharaArray = nullptr;
    }
    m_gotCharaArray = (__bridge_retained void *)[[UserSettingData gotCharaArray] mutableCopy];

    // Resolve the active character's skill record (Ghidra:
    // availableInfoForCharaId, then GetSkillDataStruct on its skillId).
    short charaId = [UserSettingData charaId];
    if (charaId < 0) { // Ghidra: 0x9fe5a cmp r4,#0 / 0x9fe62 it lt / 0x9fe64 mov.lt r4,#0
        charaId = 0;
    }
    CharaInfo *info = gCharaManager.availableInfoForCharaId(charaId);
    m_skillInfo = (__bridge void *)info;
    m_skillData = GetSkillDataStruct(static_cast<int>(info.skillId));

    // Mark every roulette SE slot idle (Ghidra: memset +0x474).
    std::memset(m_rouletteSeInst, 0xff, sizeof(m_rouletteSeInst));

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
    m_rng.setSeed(static_cast<unsigned>(time(nullptr)));

    // Device-branched layout constants. this+0x5f7 == 0 is a phone; the extra
    // this+0x614/0x618 seed applies only to a tall (displayType 2) phone.
    const bool pad = (m_padDisplay);
    if (!pad) {
        if ([[AppDelegate appDelegate] displayType] == DisplayTypePhoneRetinaTall) {
            m_layoutAnchorZ = 0x6a;
            m_layoutOffsetY = 0x9e;
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
    setupLoadTextures(charaId);

    // Prime the mode-select BGM (Ghidra: appAppSupportDirectory +
    // bgm01_modesel.m4a).
#ifdef ENABLE_PATCHES
    NSString *bgmPath = [AppDelegate appAssetsPath:@"bgm01_modesel.m4a"];
#else
    NSString *bgmPath =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:@"bgm01_modesel.m4a"];
#endif
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
    aep.setGroupDrawCallback(5, &AcMainTask::AcMainSugorokuDraw, this);
}

// Resolve the ~50 layer / frame / user handle tables into the this+0x21c..
// arrays (Ghidra: the getLyrNo/layerFrameCount/getFrameNo/getUserNo loops of
// FUN_0009fc90). This hoists all of the binary's interleaved resolve loops ahead
// of the overlay construction; the handle resolves read only the loaded AEP and
// write task arrays, so the reorder is behaviour-preserving (loop counts,
// offsets, the pad-only BT_ROULETTE_MOVE gate, and the interleaved TRIANGLE00 /
// TRIANGLE01 pairing were all byte-verified).
void AcMainTask::setupResolveHandles() {
    AepManager &aep = *m_aep;

    for (int i = 0; i < 5; i++) {
        const int lyr = aep.getLyrNo(5, kLyrSkillBoards[i]);
        m_skillBoard[i].lyr = lyr;
        m_skillBoard[i].frameCount = aep.layerFrameCount(lyr);
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
        m_iconMental[i].lyr = lyr;
        m_iconMental[i].frameCount = aep.layerFrameCount(lyr);
    }

    for (int i = 0; i < 26; i++) {
        m_boardFrame[i] = aep.getFrameNo(5, kFrmBoard[i]);
    }
    for (int i = 0; i < 11; i++) {
        m_base1Frame[i] = aep.getFrameNo(5, kFrmBase1[i]);
    }
    if (m_padDisplay) { // pad only
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
void AcMainTask::setupBuildOverlays() {
    const bool pad = (m_padDisplay);

    // 29 roulette layers -> +0x2c: new(0x60)+ctor+init(5, name, owner=this,
    // order).
    for (int i = 0; i < 29; i++) {
        m_rouletteLayers[i] = std::make_unique<AepLyrCtrl>();
        m_rouletteLayers[i]->init(5, kRouletteNames[i], this, kRouletteOrder[i]);
    }
    // 4 arrows -> +0xc0, order 0x1d.
    for (int i = 0; i < 4; i++) {
        m_arrowLayers[i] = std::make_unique<AepLyrCtrl>();
        m_arrowLayers[i]->init(5, kArrowNames[i], this, 0x1d);
    }
    // 8 select panels -> +0xa0. The tall-phone name table is used only for a tall
    // (displayType 2) phone; on a pad the two COLLECTION_SELECT panels (i == 4/5)
    // are skipped entirely.
    const bool tall =
        ([[AppDelegate appDelegate] displayType] == DisplayTypePhoneRetinaTall) && !pad;
    const char *const *panelNames = tall ? kPanelNamesTall : kPanelNamesDefault;
    for (int i = 0; i < 8; i++) {
        if (!pad || (i != 4 && i != 5)) {
            m_panelLayers[i] = std::make_unique<AepLyrCtrl>();
            m_panelLayers[i]->init(5, panelNames[i], this, kPanelOrder[i]);
        }
    }

    // Hand-tune two roulette layers: shorten roulette[1] by one frame and set
    // roulette[3] to (roulette[1] original length - 2) at 0.8 alpha.
    AepLyrCtrl *roul1 = m_rouletteLayers[1].get(); // roulette index 1
    AepLyrCtrl *roul3 = m_rouletteLayers[3].get(); // roulette index 3
    const int roul1Frames = roul1->frameCount();
    roul1->frameCount() = roul1Frames - 1;
    roul3->frameCount() = roul1Frames - 2;
    roul3->playSpeed() = 0.8f; // 0x3f4ccccd

    // Anchor eight specific roulette layers to the layout base (origin x cleared
    // @ +0x18, origin y = raw m_layoutAnchorZ @ +0x1c); indices derived from the
    // +0x18/+0x1c store offsets.
    static constexpr int kAnchorIndex[8] = {8, 9, 5, 6, 10, 11, 12, 14};
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
void AcMainTask::setupLoadTextures(short charaId) {
    NSBundle *bundle = [NSBundle mainBundle];

    // circle / blind_circle -> +0xd4 / +0xe4.
    m_circleTex = std::make_unique<neTextureForiOS>();
    m_circleTex->load([[bundle pathForResource:@"circle" ofType:@"png"] UTF8String]);

    m_blindCircleTex = std::make_unique<neTextureForiOS>();
    m_blindCircleTex->load([[bundle pathForResource:@"blind_circle" ofType:@"png"] UTF8String]);

    // The active character's board sprite from the downloadable support dir ->
    // +0xdc.
    m_charaTex = std::make_unique<neTextureForiOS>();
    NSString *charaFile =
        [NSString stringWithFormat:@"sugo_chara%03d.png", static_cast<int>(charaId)];
#ifdef ENABLE_PATCHES
    NSString *charaPath = [AppDelegate appAssetsPath:charaFile];
#else
    NSString *charaPath =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:charaFile];
#endif
    m_charaTex->load([charaPath UTF8String]);

    // 10 digit glyphs each for points (+0xfc), roulette (+0x124) and ticket
    // (+0x14c).
    for (int i = 0; i < 10; i++) {
        m_pointsDigitTex[i] = std::make_unique<neTextureForiOS>();
        m_pointsDigitTex[i]->load(
            [[bundle pathForResource:[NSString stringWithFormat:@"num_points%d", i] ofType:@"png"]
                UTF8String]);

        m_roulDigitTex[i] = std::make_unique<neTextureForiOS>();
        m_roulDigitTex[i]->load(
            [[bundle pathForResource:[NSString stringWithFormat:@"num_roulette_%d", i]
                              ofType:@"png"] UTF8String]);

        m_ticketDigitTex[i] = std::make_unique<neTextureForiOS>();
        m_ticketDigitTex[i]->load(
            [[bundle pathForResource:[NSString stringWithFormat:@"ticket_num%d", i] ofType:@"png"]
                UTF8String]);
    }

    // 12 event icons ("event_0_%03d@2x") -> +0x1ec.
    for (int i = 0; i < 12; i++) {
        m_eventTex[i] = std::make_unique<neTextureForiOS>();
        m_eventTex[i]->load(
            [[bundle pathForResource:[NSString stringWithFormat:@"event_0_%03d@2x", i]
                              ofType:@"png"] UTF8String]);
    }
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
