// AcMainTask's map and progress loading: the pending sugoroku map load with its scroll bounding
// box, the per-skill step table, the roulette SE table, the Core Data piece grids, the goal
// portrait, the bonus-treasure unlock and the board-background teardown.
//
// This is a body fragment, not a translation unit. See AcMainTaskWalk.mm.inc for why these are
// included into AcMainTask.mm rather than compiled separately, and why the suffix is .mm.inc.

// ===========================================================================
// loadTreasureMap — Ghidra FUN_000a0b58. Load the pending sugoroku map,
// snapshot the record + progress, rebuild the board scroll, and push the board
// BGM.
//
// Ghidra formerly labeled this charaSelectReloadData, which was the misnomer: the
// disassembly @0xa0b58 loads "map_%03d.map" into a new TreasureMap (nodes @+0x54,
// edges @+0x58, findArea @0xce934), sets the player position, board-square state
// and scroll bounds, then calls loadTreasureProgress + buildMapPanelLayers and
// pushes the board bg / BGM. The chara-progress reload it was named after is just
// the preamble; loadTreasureMap is the accurate name (verified against the
// disassembly 2026-07-17, and the rb420 DB is now synced to loadTreasureMap).
// ===========================================================================

// Ghidra: FUN_000ce1a8 — the "read count" (number of board-story pages) for a
// sugoroku sub-map. Only boards 6x and 8x (sub 0..2) have pages; everything
// else is 0. Tables byte-verified at DAT_0012fb90 / DAT_0012fb9c.
static int TreasureReadCount(short subMapId) {
    static constexpr int kBoard6[3] = {41, 35, 47}; // DAT_0012fb90
    static constexpr int kBoard8[3] = {64, 72, 71}; // DAT_0012fb9c
    const int board = subMapId / 10;
    const int sub = subMapId - board * 10;
    if (board == 8) {
        if (static_cast<unsigned>(sub) < 3) {
            return kBoard8[sub];
        }
    } else if (board == 6 && static_cast<unsigned>(sub) < 3) {
        return kBoard6[sub];
    }
    return 0;
}

// Sub-map board number (subMapId/10) -> board-background / board-BGM asset
// numbers. Only indices 0..4 and 7 are reachable (the 0x9f bitmask gate); both
// tables are the identity there. Byte-verified at DAT_0012f934 / DAT_0012f946.
constexpr short kMapBgNumber[9] = {0, 1, 2, 3, 4, -1, -1, 7, -1};
constexpr short kMapBgmNumber[9] = {0, 1, 2, 3, 4, 0, 6, 7, 8};

void AcMainTask::loadTreasureMap() {
    const short subMapId = m_subMapId;
    if (subMapId < 0) {
        return; // nothing pending (subMapId == -1)
    }

    // Drop the previous owned-character working copy (+0x630, +1 retained).
    if (m_gotCharaArray) {
        static_cast<void>((__bridge_transfer id)m_gotCharaArray);
        m_gotCharaArray = nullptr;
    }

    const int bgIndex = subMapId / 10; // board number (Ghidra: local_110)

    // Reset the per-map play flags + counters.
    std::memset(m_rouletteSeInst, 0xff, sizeof(m_rouletteSeInst));
    m_skillPanelActive = false;
    m_buttonPanelActive = false;
    m_bgmActive = true;
    m_squareAnimActive = false;
    // The binary zeroes +0x5ef with one 32-bit store (Ghidra loadTreasureMap
    // @ 0xa0c34: str.w r1(=0), [r4,#0x5ef]); it spans these four named bytes.
    m_warpFlash = false;
    m_warpAnim = false;
    m_wallpaperComplete = false;
    m_scrolledPastEnd = false;

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
    for (auto &l : m_rouletteLayers) {
        if (l) {
            l->stopPlay(); // 29 roulette
        }
    }
    for (auto &l : m_panelLayers) {
        if (l) {
            l->stopPlay(); // 8 panels
        }
    }
    for (auto &l : m_arrowLayers) {
        if (l) {
            l->stopPlay(); // 4 arrows
        }
    }
    if (m_boardBgLayer) {
        m_boardBgLayer->stopPlay();
    }

    // Re-read the pending record (its non-position fields are copied in below).
    TreasureTmpData tmp = [UserSettingData treasureTmp];

    // Load "map_%03d.map" for this sub-map. make_unique frees the previous map
    // object first (Ghidra: FUN_000ce2e4 pre-step + dtor FUN_000ce330).
    NSString *mapName = [NSString stringWithFormat:@"map_%03d", static_cast<int>(subMapId)];
    NSString *mapPath = [[NSBundle mainBundle] pathForResource:mapName ofType:@"map"];
    m_map = std::make_unique<TreasureMap>(); // FUN_000ce2b0
    TreasureMap *map = m_map.get();
    map->load([mapPath UTF8String]); // FUN_000ce340

    // Copy the map header into play data.
    const int nodeCount = map->nodeCount();
    m_nodeCount = static_cast<uint16_t>(nodeCount);
    m_nodes = map->nodes();
    m_edgeCount = map->edgeCount();
    m_edges = map->edges();

    // Choose the current board position: the pending record's node id, or the
    // map's start node when it is out of range (id < 0 or >= node count). Ghidra:
    // 0xa0e70 cmp #0 gates a four-instruction GE block at 0xa0e72, so id 0 is kept.
    if (tmp.curSubMapId < 0 || tmp.curSubMapId >= nodeCount) {
        tmp.curSubMapId = map->startSubId();
    }

    // Current node screen origin (tile size 0x1a == 26 px) + the "reached" flag.
    const TreasureMap::Node *cur = map->findArea(tmp.curSubMapId); // FUN_000ce934
    m_curNode = cur;
    m_playerX = static_cast<float>((cur ? cur->x : 0) * 0x1a);
    m_playerY = static_cast<float>((cur ? cur->y : 0) * 0x1a);
    m_boardMoveState = (tmp.boardMoveState == 2) ? static_cast<unsigned>(tmp.boardMoveState) : 0u;
    m_bonusCount = tmp.mainMapId;
    m_lastBranchNodeId = tmp.lastBranchNodeId;
    std::memcpy(&m_boardSquareState[0],
                tmp.boardSquareState,
                15); // per-square board state (0x894..0x8a2)

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
    const float originX = static_cast<float>(minX * 0x1a);
    const float originY = static_cast<float>(minY * 0x1a);
    const float contentW = static_cast<float>((maxX - minX) * 0x1a + 0x68); // +104
    const float contentH = static_cast<float>((maxY - minY) * 0x1a + 0x80); // +128
    m_scrollBoxOriginX = originX;
    m_scrollBoxOriginY = originY;
    m_scrollBoxW = contentW;
    m_scrollBoxH = contentH;

    const float halfW = static_cast<float>(m_overlayW / 2);
    const float halfH = static_cast<float>(m_overlayH / 2);
    const bool pad = (m_padDisplay);
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
    const float scrollXRaw = static_cast<float>((cur ? cur->x : 0) * 0x1a + 0x34); // +52
    const float scrollYRaw = static_cast<float>((cur ? cur->y : 0) * 0x1a + 0x40); // +64
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
            bgGroupName = [NSString
                stringWithFormat:@"sugoroku_bg%02d", static_cast<int>(kMapBgNumber[bgIndex])];
            bgLoopName = ([[AppDelegate appDelegate] displayType] == DisplayTypePhoneRetinaTall) ?
                             @"BG_LOOP1136" :
                             @"BG_LOOP960";
        } else {
            bgGroupName = [NSString
                stringWithFormat:@"sugoroku_bg%02d_ipad", static_cast<int>(kMapBgNumber[bgIndex])];
            bgLoopName = @"BG_LOOP";
        }
        AepManager &aep = *m_aep;
        aep.loadAepDataDefaultPath(6, [bgGroupName UTF8String]); // FUN_0000f758 slot 6
        m_boardBgLayer = std::make_unique<AepLyrCtrl>();
        m_boardBgLayer->init(6, [bgLoopName UTF8String], this, 0x24);
    }

    // Board-bg texture (+0xd8): "sugoroku_bg%02d(~iPad)" for this board index.
    m_boardBgTex = std::make_unique<neTextureForiOS>(); // frees the previous board bg
    NSString *bgTexName = pad ? [NSString stringWithFormat:@"sugoroku_bg%02d~iPad", bgIndex] :
                                [NSString stringWithFormat:@"sugoroku_bg%02d", bgIndex];
    m_boardBgTex->load(
        [[[NSBundle mainBundle] pathForResource:bgTexName ofType:@"png"] UTF8String]);

    // Remaining record fields + the board character/panel builders.
    m_rouletteMode = tmp.rouletteMode;
    m_listHalveCount = static_cast<int8_t>(tmp.listHalveCount);
    m_treasureProgress = static_cast<int8_t>(tmp.treasureProgress);
    loadTreasureProgress(); // FUN_000a2264
    buildMapPanelLayers();  // FUN_000a2650

    // Cache the map's display name (+0x944, +1 retained), replacing any previous.
    if (m_mapName) {
        static_cast<void>((__bridge_transfer id)m_mapName);
        m_mapName = nullptr;
    }
    m_mapName = (__bridge_retained void *)[NSString stringWithUTF8String:tmp.goalName];

    // Push + load the board treasure BGM ("bgm04_tre_%02d.m4a").
    AudioManager *audio = [AudioManager sharedManager];
    NSString *bgmName =
        [NSString stringWithFormat:@"bgm04_tre_%02d.m4a", static_cast<int>(kMapBgmNumber[bgIndex])];
#ifdef ENABLE_PATCHES
    NSString *bgmPath = [AppDelegate appAssetsPath:bgmName];
#else
    NSString *bgmPath =
        [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:bgmName];
#endif
    [audio pushBgm];
    [audio loadBgm:bgmPath isLoop:YES];
    m_moveLinkIndex = -1;
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
constexpr int kStepBoardA[7] = {1, 2, 1, 3, 1, 2, 3};
constexpr int kStepBoardB[7] = {4, 5, 4, 6, 4, 5, 6};

void AcMainTask::computeStepValues() {
    for (int i = 0; i < 7; i++) {
        // Board-derived base (computed for every index, though modes 0..6 discard
        // it below — matching the binary, which evaluates the base before the tbb).
        int value;
        if (m_boardSquareState[0] >= 1) {
            value = kStepBoardA[i];
        } else if (m_boardSquareState[1] >= 1) {
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
// ===========================================================================

// Byte-verified SE resource names (Ghidra: PTR_cf_se11_roulapp_00132ae0, an
// array of 15 ASCII CFStrings, dataPtrs verified contiguous @ 0x10a6a4). Note
// the two warp variants (se17_warp AND se17b_warp) and the gap from se23
// straight to se25.
constexpr const char *const kRouletteSeNames[15] = {"se11_roulapp",
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
        NSString *path =
            [[NSBundle mainBundle] pathForResource:@(kRouletteSeNames[i]) ofType:@"m4a"];
        m_rouletteSe[i] =
            static_cast<int>([audio loadSe:path isLoop:(i == 1) callName:nil group:1]);
    }
}

// ===========================================================================
// loadTreasureProgress — Ghidra FUN_000a2264 (renamed from the reconstruction's
// earlier misnomer buildMapCharaLayers and Ghidra's sugorokuLoadTreasureMap; the
// rb420 DB is now synced to loadTreasureProgress. The disassembly @0xa2264 is a
// Core Data TreasureData load, not a layer builder).
// Rebuild the per-board music / wallpaper "piece" unlock tables from the
// persisted Core Data TreasureData records, then OR in the pending record's own
// masks for the current board.
//
// The tables live at this+0x28 + {0x6b4, 0x720, 0x78c, 0x7f8}, i.e.
// this-relative +0x6dc (music), +0x748 (wallpaper), +0x7b4 (music dup) and
// +0x820 (wallpaper dup). Each is a 9x3 uint32_t bitmask grid indexed by
// mainMapId*0xc + subMapId*4 (mainMapId is the board 0..8, subMapId the 0..2
// sub-index). The binary writes the music and wallpaper values into BOTH their
// primary and duplicate tables each iteration.
// ===========================================================================
void AcMainTask::loadTreasureProgress() {
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
    m_musicPieceTable[curIdx / 4] |= static_cast<uint32_t>(tmp.musicPieceMask); // music mask
    m_wallPieceTable[curIdx / 4] |= static_cast<uint32_t>(tmp.wallPieceMask);   // wallpaper mask
}

// ===========================================================================
// buildMapPanelLayers — Ghidra FUN_000a2650 (called by loadTreasureMap).
// Despite the declared name this (re)loads the goal-character portrait texture
// into +0xe0. The whole rebuild is gated by the pending record's friendMeetFlag
// (+0x50): when it is non-zero the routine is a no-op. Otherwise it frees any
// previous texture and, if a goal character is
// present (friendPlayerId[0] != 0), loads "sugo_chara%03d.png" for chara id goalCharaId
// from the app-support directory.
// ===========================================================================
void AcMainTask::buildMapPanelLayers() {
    TreasureTmpData tmp = [UserSettingData treasureTmp];

    // The friend-meet flag (+0x50) is the enable gate: non-zero -> leave the
    // current texture untouched.
    if (tmp.friendMeetFlag != 0) {
        return;
    }

    // Free the previously loaded portrait (Ghidra: the vtable[1] deleting dtor).
    m_goalCharaTex.reset();

    // No goal character on this record -> nothing more to load.
    if (tmp.friendPlayerId[0] == 0) {
        return;
    }

    m_goalCharaTex = std::make_unique<neTextureForiOS>();
    NSString *file =
        [NSString stringWithFormat:@"sugo_chara%03d.png",
                                   static_cast<int>(static_cast<short>(tmp.goalCharaId))];
#ifdef ENABLE_PATCHES
    NSString *path = [AppDelegate appAssetsPath:file];
#else
    NSString *path = [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:file];
#endif
    m_goalCharaTex->load([path UTF8String]);
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
constexpr int kBonusPrereqSongsA[4] = {
    // DAT_0012f9e0
    200000204,
    200000205,
    200000206,
    200000207 // 0x0bebc2cc..0x0bebc2cf
};
constexpr int kBonusPrereqSongsB[4] = {
    // DAT_0012f9f0
    200000208,
    200000209,
    200000210,
    200000211 // 0x0bebc2d0..0x0bebc2d3
};

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
static int MapPanelOrder(int displaySlot) {
    static constexpr int kOrder[9] = {0, 3, 4, 5, 6, 1, 2, 7, 8};
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
void AcMainTask::refreshMapScroll(int mode) {
    for (auto &tex : m_jacketTex) {
        tex.reset();
    }
    if (m_treasureMusicArray) {
        static_cast<void>((__bridge_transfer id)m_treasureMusicArray);
        m_treasureMusicArray = nullptr;
    }

    NSArray<MusicData *> *songs = [[MusicManager getInstance] getTreasureMusicDataArray];
    m_treasureMusicArray = (__bridge_retained void *)songs;
    const int count = static_cast<int>(songs.count);

    for (int slot = mode * 9; slot < count && slot < 9; slot++) {
        MusicData *md = songs[MapPanelOrder(slot)];
        m_jacketTex[slot] = std::make_unique<neTextureForiOS>();
        m_jacketTex[slot]->loadFromImageData(
            (__bridge const void *)[md artwork2xData]); // FUN_00011cbc
    }
}

// Ghidra: FUN_000a4e84 — unlink + delete the board background layer (+0xd0) and
// unload its asset group (6). loadTreasureMap calls this before loading the
// next board's bg.
void AcMainTask::unloadMapBgGroup() {
    if (m_boardBgLayer) {
        m_boardBgLayer->unlink(); // FUN_0002ca9c
        m_boardBgLayer.reset();
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
void AcMainTask::sugorokuReleaseGoalLayer() {
    unloadMapBgGroup();
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
