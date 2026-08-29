// The goal and warp half of AcMainTask's state machine: the skill effect and the roulette result
// it applies, the visitor request, the friend-meet reveal, the goal payout and award, the square
// gimmick apply, the warp sequence and the piece grants.
//
// This is a body fragment, not a translation unit. See AcMainTaskWalk.mm.inc for why these are
// included into AcMainTask.mm rather than compiled separately, and why the suffix is .mm.inc.

// case 0x25 — start the skill effect: arm the overlay's one-shot, anchor it over the player token
// and play the skill SE. Unlike the warp anchor this one truncates the scroll offset to an int
// before subtracting it (the 0x9b0c8 / 0x9b0de and 0x9b106 / 0x9b120 vcvt round-trips) and adds
// the half-tile bias after the conversion (0x9b12e adds r0,#0x34). Ghidra: 0x9b08c.
void AcMainTask::stateSkillEffect() {
    AepLyrCtrl *effect = m_rouletteLayers[kRouletteLayerSkillEffect].get();
    effect->stop(1); // 0x9b094 / 0x9b098

    const int scrollOffX = static_cast<int>(m_scrollX - m_scrollBaseX);
    const int scrollOffY = static_cast<int>(m_scrollY - m_scrollBaseY);
    const int screenX = static_cast<int>(m_playerX - static_cast<float>(scrollOffX) +
                                         static_cast<float>(m_overlayW / 2));
    const int screenY = static_cast<int>(m_playerY - static_cast<float>(scrollOffY) +
                                         static_cast<float>(m_overlayH / 2));
    effect->setPosition(screenX + static_cast<int>(kBoardHalfTileBias), screenY);

    [[AudioManager sharedManager] playSe:nil resourceId:m_rouletteSe[kRouletteSeSkill]]; // 0x9b13a
    m_state = kAcMainStateSkillEffectWait;
}

// case 0x26 — hold while the skill overlay plays, then apply the roulette result: warps,
// direction flips, trap-square clears, the treasure-progress bump, or the visitor request.
// Ghidra: 0x9b154.
void AcMainTask::stateSkillEffectWait() {
    if (m_rouletteLayers[kRouletteLayerSkillEffect]->isAnimating()) {
        return; // 0x9b15e
    }

    // 0x9b16c: the mode is sign-extended but compared unsigned, so -1 lands here.
    if (static_cast<unsigned>(m_rouletteMode) > 0x1d) {
        m_rouletteMode = -1; // 0x9b176
        m_state = kAcMainStateBoardReveal;
        return;
    }

    m_state = kAcMainStateBoardReveal; // 0x9dda8, unless an arm says otherwise
    switch (m_rouletteMode) {
    case 7: // 0x9d040: warp back to the board's start square
        m_rouletteMode = -1;
        m_targetNode = m_map->startNode(); // 0x9d04c ldr [map,#0x54]
        m_state = kAcMainStateWarpEffect;
        break;
    case 8: { // 0x9f214: warp back to the last junction, or stay put when there is none
        m_rouletteMode = -1;
        TreasureTmpData tmp = [UserSettingData treasureTmp];
        m_targetNode =
            (tmp.lastBranchNodeId == -1) ? m_curNode : m_map->findArea(tmp.lastBranchNodeId);
        m_state = kAcMainStateWarpEffect;
        break;
    }
    case 9: // 0x9f266: flip the board travel direction
        m_rouletteMode = -1;
        m_boardMoveState = (static_cast<unsigned>(m_boardMoveState) < 2u) ? 2 : 0;
        break;
    case 0x11: { // 0x9f282: ask the server for a visitor
        TreasureTmpData tmp = [UserSettingData treasureTmp];
        tmp.visitorFetchCount++; // 0x9f2b2
        [UserSettingData saveTreasureTmp:tmp];
        MainViewController *root =
            static_cast<MainViewController *>(neSceneManager::rootViewController());
        [root InsertCommunicating];
        [[DownloadMain getInstance] startGetVisitorHttp:m_subMapId type:1];
        m_rouletteMode = -1; // 0x9f32c, after the request goes out
        m_state = kAcMainStateVisitorWait;
        break;
    }
    case 0x18: // 0x9f336
        m_rouletteMode = -1;
        if (m_boardSquareState[8] >= 1) {
            m_rankBadgeType = 1;
        }
        m_boardSquareState[8] = kBoardSquareIdle;
        break;
    case 0x19: // 0x9f35a
        m_rouletteMode = -1;
        if (m_boardSquareState[14] >= 1) {
            m_rankBadgeType = 1;
        }
        m_boardSquareState[14] = kBoardSquareIdle;
        break;
    case 0x1a: // 0x9f37e
        m_rouletteMode = -1;
        if (m_boardSquareState[kWarpGateSquareSlot] >= 1) {
            m_rankBadgeType = 1;
        }
        m_boardSquareState[kWarpGateSquareSlot] = kBoardSquareIdle;
        break;
    case 0x1b: // 0x9f3a2: ldrsb, so a kBoardSquareEventPending marker does not count
        m_rouletteMode = -1;
        if (m_boardSquareState[0] >= 1 || m_boardSquareState[1] >= 1) {
            m_rankBadgeType = 1;
        }
        m_boardSquareState[0] = kBoardSquareIdle;
        m_boardSquareState[1] = kBoardSquareIdle;
        break;
    case 0x1c: // 0x9f3d2: ldrb, so a kBoardSquareEventPending marker does count
        m_rouletteMode = -1;
        if (m_boardSquareState[kBoardSquareGateEven] != 0 ||
            m_boardSquareState[kBoardSquareGateOdd] != 0) {
            m_rankBadgeType = 1;
        }
        m_boardSquareState[kBoardSquareGateEven] = kBoardSquareIdle;
        m_boardSquareState[kBoardSquareGateOdd] = kBoardSquareIdle;
        break;
    case 0x1d: // 0x9f3fe
        m_rouletteMode = -1;
        m_treasureProgress = static_cast<int8_t>(m_treasureProgress + 1);
        break;
    default: // 0..6, 0x0a..0x10 and 0x12..0x17 keep the mode standing
        break;
    }
}

// case 0x27 — wait out the visitor request. On success the communicating overlay comes down; on
// failure the skill's treasure-point cost is refunded and the failure reported. Ghidra: 0x9b17e.
void AcMainTask::stateVisitorWait() {
    DownloadMain *download = [DownloadMain getInstance];
    if ([download isGetVisitorDownLoading]) { // 0x9b1b2
        return;
    }

    MainViewController *root =
        static_cast<MainViewController *>(neSceneManager::rootViewController());
    if (!download.isGetVisitorSuccess) {                                       // 0x9b1ce
        const int cost = m_skillData->weight;                                  // 0x9dd38
        m_treasurePoint = std::min(m_treasurePoint + cost, kMaxTreasurePoint); // 0x9dd4c
        [UserSettingData saveTreasurePoint:static_cast<short>(m_treasurePoint)];
        [UserSettingData addConsumedTreasurePoint:static_cast<short>(-cost)];
        [root CommunicatingFailed];        // 0x9dda4
        m_state = kAcMainStateBoardReveal; // 0x9dda8
        return;
    }

    [root DeleteCommunicating];           // 0x9b202
    m_state = kAcMainStateFriendMeetAnim; // 0x9b206
}

// case 0x28 — tick the goal/friend reveal counter; on frame 15 swap in the goal portrait and the
// pending record's goal name, and past frame 29 hand back to the board. Ghidra: 0x9b20c.
void AcMainTask::stateFriendMeetAnim() {
    if (m_friendAnimFrame > 29) {
        // 0x9b212 bgt 0x9c98e, which clears +0x5e8 and falls into the shared state-3 store.
        m_friendAnimFrame = 0;
        m_state = kAcMainStateBoardReveal;
        return;
    }
    if (++m_friendAnimFrame != 15) { // 0x9b21c cmp #0xf / 0x9b21e bne tail
        return;
    }

    // 0x9b244 treasureTmp, 0x9b248 frees the goal portrait, 0x9b25c releases the cached name and
    // 0x9b29a takes the record's goalName.
    TreasureTmpData tmp = [UserSettingData treasureTmp];
    m_goalCharaTex.reset();
    if (m_mapName) {
        static_cast<void>((__bridge_transfer id)m_mapName);
        m_mapName = nullptr;
    }
    m_mapName = (__bridge_retained void *)[NSString stringWithUTF8String:tmp.goalName];
    buildMapPanelLayers(); // 0x9b2b8
}

// case 0x1b — the goal payout. Mark the friend meet consumed, then reveal one randomly-chosen
// awarded piece the collection lacks; with nothing left to reveal the goal's friendship is paid
// out as treasure points instead. Ghidra: 0x9ac28, the payout arm at 0x9ca4a.
void AcMainTask::stateGoalReward() {
    [[AudioManager sharedManager] playSe:nil resourceId:m_rouletteSe[kRouletteSeItemGet]];

    TreasureTmpData tmp = [UserSettingData treasureTmp]; // 0x9ac68
    tmp.friendMeetFlag = 1;                              // 0x9ac74

    // Count the awarded bits the collection has not banked yet, music first. Ghidra: the two
    // three-iteration loops at 0x9ac80 and 0x9acc6.
    int musicCandidates = 0;
    for (int i = 0; i < 3; i++) {
        if ((tmp.musicPieceMask & (1 << i)) != 0 &&
            !sugorokuPieceUnlocked(m_musicPieceTable, m_subMapId, i)) {
            musicCandidates++;
        }
    }
    int wallCandidates = 0;
    for (int i = 0; i < 3; i++) {
        if ((tmp.wallPieceMask & (1 << i)) != 0 &&
            !sugorokuPieceUnlocked(m_wallPieceTable, m_subMapId, i)) {
            wallCandidates++;
        }
    }

    const int candidates = musicCandidates + wallCandidates; // 0x9ad00
    if (candidates < 1) {                                    // 0x9ad06
        // Friendship converts to a treasure-point payout the goal board counts up. The 250.0 and
        // 50.0 come from the pools at 0x9d8e8 and 0x9d8f0; the 10.0 is the vmov.f64 immediate at
        // 0x9d6f2, and vcvt.s32.f64 truncates towards zero.
        int friendship = tmp.friendship; // 0x9ca4a
        if (friendship < 0) {
            friendship = 0; // 0x9ca50
        }
        int points = 300;       // 0x9ca58
        if (friendship <= 99) { // 0x9ca52
            points = static_cast<int>((std::sqrt(static_cast<double>(friendship)) * 250.0 / 10.0) +
                                      50.0); // 0x9d6de..0x9d702
        }
        m_rouletteDigit = static_cast<int16_t>(points); // 0x9d716

        AepLyrCtrl *goalBoard = m_rouletteLayers[kRouletteGoalBoard[0]].get(); // 0x9d71a
        goalBoard->playSpeed() = 1.0f;                                         // 0x9d724
        goalBoard->playOnce();                                                 // 0x9d728

        int balance = m_treasurePoint + points; // 0x9d73e
        if (balance > kMaxTreasurePoint) {      // 0x9d740 cmp against 0x270f
            balance = kMaxTreasurePoint;
        }
        m_treasurePoint = balance;                                         // 0x9d748
        [UserSettingData saveTreasurePoint:static_cast<int16_t>(balance)]; // 0x9d754
    } else {
        int pick = m_rng.getRandRangeInt(candidates); // 0x9ad14
        if (pick < musicCandidates) {                 // 0x9ad18
            for (int i = 0; i < 3; i++) {             // 0x9ad30
                if ((tmp.musicPieceMask & (1 << i)) == 0 ||
                    sugorokuPieceUnlocked(m_musicPieceTable, m_subMapId, i)) {
                    continue;
                }
                if (pick > 0) {
                    pick--; // 0x9ad68
                    continue;
                }
                // The scan already required this bit, so the OR is a no-op; the binary emits it
                // all the same.
                tmp.musicPieceMask |= 1 << i;                      // 0x9e242
                m_rouletteLayers[kRouletteLayerGetMusic]->stop(1); // 0x9e33c
                break;
            }
        } else {
            pick -= musicCandidates;      // 0x9ce6c
            for (int i = 0; i < 3; i++) { // 0x9ce80
                if ((tmp.wallPieceMask & (1 << i)) == 0 ||
                    sugorokuPieceUnlocked(m_wallPieceTable, m_subMapId, i)) {
                    continue;
                }
                if (pick > 0) {
                    pick--; // 0x9ceb8
                    continue;
                }
                tmp.wallPieceMask |= 1 << i;                      // 0x9e32a
                m_rouletteLayers[kRouletteLayerGetWall]->stop(1); // 0x9e33c
                break;
            }
        }
    }

    [UserSettingData saveTreasureTmp:tmp]; // 0x9e358
    loadTreasureProgress();                // 0x9e362
    m_state = kAcMainStateGoalRewardWait;  // 0x9e366
}

// case 0x1c — hold while the goal payout plays. A tap cuts the goal board short, and the state
// only advances once both piece-reveal overlays and the goal board are idle. Ghidra: 0x9ad74.
void AcMainTask::stateGoalRewardWait() {
    AepLyrCtrl *goalBoard = m_rouletteLayers[kRouletteGoalBoard[0]].get();
    if (m_frameTapped && !goalBoard->isAnimating() && // 0x9ad76 / 0x9ad84
        goalBoard->playSpeed() > 0.0f) {              // 0x9ad8e vcmpe s0,#0 / ble
        neEngine::playSystemSe(2);                    // 0x9adb4
        goalBoard->reset();                           // 0x9adbe
    }

    if (m_rouletteLayers[kRouletteLayerGetMusic]->isAnimating() || // 0x9adcc
        m_rouletteLayers[kRouletteLayerGetWall]->isAnimating() ||  // 0x9addc
        goalBoard->isActive()) {                                   // 0x9adf0
        return;
    }

    m_rouletteDigit = 0;               // 0x9adfc
    m_state = kAcMainStateBoardReveal; // 0x9ae00
}

// case 0x22 — apply the landed square's gimmick: dispatch on the square's slotId and arm, clear
// or step the matching m_boardSquareState entry. Ghidra: 0x9b042, table at 0x9ca64.
void AcMainTask::stateSquareApply() {
    if (m_squareAnimActive) { // 0x9b042
        m_state = kAcMainStateSquareAnimWait;
        return;
    }

    m_state = kAcMainStateBoardReveal; // 0x9ca6a: every arm except slot 11
    switch (m_curNode->slotId) {       // 0x9ca64 ldrsh node+0x8
    case 0:                            // 0x9ca90
        m_boardSquareState[0] = 1;
        break;
    case 1: // 0x9eed6
        m_boardSquareState[1] = 1;
        break;
    case 2: // 0x9eeda
        m_boardSquareState[2] = kBoardSquareEventPending;
        break;
    case 3: // 0x9eede
        m_boardSquareState[3] = kBoardSquareEventPending;
        break;
    case 4: // 0x9eee8
        m_boardSquareState[4] = 1;
        break;
    case 5: // 0x9eef2
        m_boardSquareState[5] = 1;
        break;
    case 6: // 0x9eefc
        m_boardSquareState[6] = 1;
        break;
    case 7: // 0x9ef06
        m_boardSquareState[7] = 1;
        break;
    case 8: // 0x9ef10
        m_boardSquareState[8] = 1;
        break;
    case 9: { // 0x9ef14: the friend-meet square is consumed
        TreasureTmpData tmp = [UserSettingData treasureTmp]; // 0x9ef38
        // 0x9ef50 zeroes sixteen bytes from +0x20 and 0x9ef5a / 0x9ef5e zero the words at +0x2d
        // and +0x31, so the cleared span is [+0x20, +0x35): the friend id and the goal name
        // together, and nothing past them.
        std::memset(tmp.friendPlayerId, 0, sizeof(tmp.friendPlayerId));
        std::memset(tmp.goalName, 0, sizeof(tmp.goalName));
        [UserSettingData saveTreasureTmp:tmp];                            // 0x9ef66
        m_goalCharaTex.reset();                                           // 0x9ef6a
        m_boardSquareState[m_curNode->slotId] = kBoardSquareEventPending; // 0x9ef8a
        break;
    }
    case 10: // 0x9ef92
        m_boardSquareState[10] = 2;
        break;
    case 11: // 0x9ef96
        m_boardSquareState[11] = kBoardSquareIdle;
        m_state = kAcMainStateButtobiPick; // 0x9ef9c
        break;
    case 12: { // 0x9efa2: reverse the board travel direction
        const int moveState = m_boardMoveState;
        int next;
        if (moveState == 2) {
            next = 1; // 0x9f4c0
        } else if (moveState == 1) {
            next = 2; // 0x9efb2
        } else {
            next = (moveState != 0) ? 0 : 3; // 0x9f4c4..0x9f4ca
        }
        m_boardMoveState = next;                   // 0x9f4cc
        m_boardSquareState[12] = kBoardSquareIdle; // 0x9f4d2
        break;
    }
    case 13: // 0x9efb6
        m_boardSquareState[13] = static_cast<int8_t>(m_boardSquareState[13] - 1);
        break;
    case 14: // 0x9efc4
        m_boardSquareState[14] = 1;
        break;
    default: // 0x9ca6a: nothing to apply
        break;
    }
}

// case 0x23 — hold while the square-select effect overlay plays, then drop the gate.
// Ghidra: 0x9b052.
void AcMainTask::stateSquareAnimWait() {
    if (m_rouletteLayers[kRouletteLayerSkillKouka]->isAnimating()) {
        return;
    }
    m_squareAnimActive = false;
    m_state = kAcMainStateBoardReveal;
}

// case 0x24 — pick the random buttobi (fly-to) destination and hand over to the warp-out
// animation. Ghidra: 0x9b070.
void AcMainTask::stateButtobiPick() {
    m_targetNode = m_map->getButtobiSquare(m_curNode);
    m_state = kAcMainStateWarpEffect;
}

// Park an overlay over the player token in screen space. The binary inlines this at each site
// (0x9ecd6, 0x9aeac..0x9aef0 and 0x9af92..0x9b012), and all three compute the same thing.
void AcMainTask::parkLayerOverToken(AepLyrCtrl *layer) {
    layer->setPosition(
        static_cast<int>((m_playerX - m_scrollX) + static_cast<float>(m_overlayW / 2) +
                         kBoardHalfTileBias),
        static_cast<int>((m_playerY - m_scrollY) + static_cast<float>(m_overlayH / 2)));
}

// case 0x1d — a warp square was landed on. The warp is suppressed while the slot-10 gimmick is
// still counting down; otherwise the partner square is resolved. Ghidra: 0x9ae04.
void AcMainTask::stateWarpBegin() {
    if (m_boardSquareState[kWarpGateSquareSlot] >= 1) { // 0x9ae04 ldrsb +0x89e, 0x9ae0a bge
        m_state = kAcMainStateBoardReveal;              // 0x9dda8
        return;
    }

    // 0x9ae0e / 0x9ae16 / 0x9ae1c: getWarpSquare(m_map, m_curNode) -> +0x4c0.
    m_targetNode = m_map->getWarpSquare(const_cast<TreasureMap::Node *>(m_curNode));
    if (!m_targetNode) {
        // The original aborts here; 0x9ae2e passes line 0x8f5 to __assert_rtn at 0x9ae4e.
        assert(0 && "getWarpSquare");
        return;
    }

    m_state = kAcMainStateWarpEffect; // 0x9ae26 bne 0x9b086
}

// case 0x1e — play the warp SE, park EFF_WARP_3 over the token, arm it and raise the squish flag.
// Ghidra: 0x9ae52.
void AcMainTask::stateWarpEffect() {
    [[AudioManager sharedManager] playSe:nil resourceId:m_rouletteSe[kRouletteSeWarp]]; // 0x9ae6c

    AepLyrCtrl *warp = m_rouletteLayers[kRouletteLayerWarp].get();
    warp->playSpeed() = 1.0f; // 0x9aea0
    warp->stop(true);         // 0x9aea8
    parkLayerOverToken(warp); // 0x9aeac..0x9aef0

    m_warpAnim = true;                // 0x9aef6
    m_state = kAcMainStateWarpArrive; // 0x9aef4
}

// case 0x1f — the warp lands. Once EFF_WARP_3 is done the partner square becomes the current one,
// the scroll bounds are refitted and the flash is raised. Ghidra: 0x9af02.
void AcMainTask::stateWarpArrive() {
    if (m_rouletteLayers[kRouletteLayerWarp]->isAnimating()) {
        return; // 0x9af0c / 0x9af12
    }

    // 0xa2544 reads m_curNode, so the commit must come first.
    m_curNode = m_targetNode;    // 0x9af16 / 0x9af1a
    sugorokuSetupScrollBounds(); // 0x9af20
    m_warpFlash = true;          // 0x9af26

    m_state = kAcMainStateWarpScroll; // 0x9af2a movs 0x20
}

// case 0x20 — ease the map scroll to the warp destination; when it settles, play the arrival
// sting, rewind the overlay over the token and wait for it. Ghidra: 0x9af30.
void AcMainTask::stateWarpScroll() {
    m_scrollVelX += m_scrollAccumX; // 0x9af30..0x9af5c
    m_scrollVelY += m_scrollAccumY;
    if (sugorokuEasePositionPairA()) { // 0x9af66 / 0x9af6c
        return;
    }

    [[AudioManager sharedManager] playSe:nil resourceId:m_rouletteSe[kRouletteSeWarpIn]];

    // 0x9afc4 / 0x9afca: rewind EFF_WARP_3 and re-arm its one-shot, then re-anchor it.
    AepLyrCtrl *warp = m_rouletteLayers[kRouletteLayerWarp].get();
    warp->playSpeed() = -1.0f;
    warp->stop(true);
    parkLayerOverToken(warp); // 0x9af92..0x9b012

    m_warpFlash = false; // 0x9b018
    m_state = kAcMainStateWarpInWait;
}

// case 0x21 — hold until the warp overlay has played back, then drop the animation gate.
// Ghidra: 0x9b024.
void AcMainTask::stateWarpInWait() {
    if (m_rouletteLayers[kRouletteLayerWarp]->isAnimating()) {
        return;
    }
    m_warpAnim = false;
    m_state = kAcMainStateBoardReveal;
}

// case 0x17 — a wallpaper-piece square was tapped. An already-owned piece drops straight back to
// the board; otherwise the piece bit is OR'd into the pending record, the grids are reloaded and
// GET_WALL is armed. Ghidra: 0x9aa7a.
void AcMainTask::stateWallPieceGet() {
    // The +0x748 grid is indexed the same way loadTreasureProgress builds it. Ghidra:
    // 0x9aa7e..0x9aab2.
    if (sugorokuPieceUnlocked(m_wallPieceTable, m_subMapId, m_curNode->slotId)) {
        m_state = kAcMainStateBoardReveal; // 0x9aab8
        return;
    }

    [[AudioManager sharedManager] playSe:nil resourceId:m_rouletteSe[kRouletteSeItemGet]];

    TreasureTmpData tmp = [UserSettingData treasureTmp];
    tmp.wallPieceMask |= static_cast<int32_t>(1u << m_curNode->slotId); // 0x9ab12
    [UserSettingData saveTreasureTmp:tmp];
    loadTreasureProgress(); // 0x9ab2c

    // stop(1) rewinds GET_WALL to frame 0 and leaves it drawn, so the next state can poll
    // isAnimating() for the one-shot to finish. Ghidra: 0x9ab38.
    m_rouletteLayers[kRouletteLayerGetWall]->stop(1);
    m_state = kAcMainStateWallPieceWait;
}

// case 0x19 — the same shape as case 0x17 for a music-piece square. Ghidra: 0x9ab4a.
void AcMainTask::stateMusicPieceGrant() {
    if (sugorokuPieceUnlocked(m_musicPieceTable, m_subMapId, m_curNode->slotId)) {
        m_state = kAcMainStateBoardReveal; // 0x9ab4a..0x9ab88
        return;
    }

    [[AudioManager sharedManager] playSe:nil resourceId:m_rouletteSe[kRouletteSeItemGet]];

    TreasureTmpData tmp = [UserSettingData treasureTmp]; // 0x9abca
    tmp.musicPieceMask |= 1 << m_curNode->slotId;        // 0x9abce..0x9abe8
    [UserSettingData saveTreasureTmp:tmp];               // 0x9abf4
    loadTreasureProgress();                              // 0x9abfc
    m_rouletteLayers[kRouletteLayerGetMusic]->stop(1);   // 0x9ac08
    m_state = kAcMainStateMusicPieceWait;
}

// cases 0x18 and 0x1a — hold while a piece-reveal overlay plays out, then drop back into the
// board loop. Both states load their layer and branch to the same tail, so they are one body:
// case 0x18 passes GET_WALL from +0x5c (0x9ab42) and case 0x1a GET_MUSIC from +0x58 (0x9ac12).
// Ghidra: the shared tail at 0x9c62c.
void AcMainTask::statePieceRevealWait(int layerIndex) {
    if (!m_rouletteLayers[layerIndex]->isAnimating()) { // 0x9c632
        m_state = kAcMainStateBoardReveal;              // 0x9c638
    }
}

// case 0x11 — the goal square was tapped. Play the goal SE, arm the friend-meet fade, roll and
// hand out the goal reward, flush the record, detect a just-completed collection, upload the goal
// and create the next area's record. Ghidra: 0x9a790 with its arms at 0x9c966, 0x9ca06, 0x9cc84,
// 0x9ccc6 and the collection recount at 0x9d926.
void AcMainTask::stateGoalAward() {
    AudioManager *audio = [AudioManager sharedManager];
    [audio playSe:nil resourceId:m_rouletteSe[kRouletteSeGoal]]; // 0x9a7a4 / 0x9a7b2

    const short subMapId = static_cast<short>(m_subMapId);
    const short mainMapId = static_cast<short>(subMapId / 10);
    const short areaId = static_cast<short>(subMapId % 10);

    NSManagedObjectContext *ctx = [[AppDelegate appDelegate] managedObjectContext];
    TreasureData *record =
        [TreasureData getTreasureData:mainMapId subMapId:areaId inManagedObjectContext:ctx];

    // A goal whose friend meet is already recorded shows nothing; a fresh one shows the portrait
    // at 95 and lets sugorokuDrawFriendMeet fade it out. Ghidra: 0x9a85e..0x9a86e.
    TreasureTmpData tmp = [UserSettingData treasureTmp];
    m_friendOpacity = tmp.friendMeetFlag ? 0 : 95;

    const int touchSoundOwned = [[record goalTouchSound] intValue]; // 0x9a874 / 0x9a888

    // Reward roll. The chara-ticket window is the treasure progress scaled to a percentage; the
    // touch-sound window sits below it and doubles while treasure event 10 is running and the
    // sound is still unowned. The two together are capped at 100, with the ticket window taking
    // priority. Ghidra: 0x9a89a..0x9a8c6 and 0x9c966..0x9c976.
    int ticketWindow = (m_treasureProgress * 5) + 25;
    if (ticketWindow > 100) {
        ticketWindow = 100;
    }
    int soundWindow = 15;
    if (m_hudState == 10) {
        soundWindow = (touchSoundOwned > 0) ? 15 : 30;
    }
    if ((soundWindow + ticketWindow) > 100) {
        soundWindow = 100 - ticketWindow;
        if (soundWindow < 0) {
            soundWindow = 0;
        }
    }

    const int roll = static_cast<int8_t>(tmp.bonusRoll);
    uint8_t goalType = 0;
    if (roll < soundWindow) {
        // The touch sound is only ever awarded on a map's third area, and only while it is still
        // unowned. Ghidra: 0x9c980..0x9c98c.
        if ((areaId == 2) && (touchSoundOwned <= 0)) {
            goalType = 2;
        }
    } else if (roll < (soundWindow + ticketWindow)) {
        if ([[record goalCharaTicket] intValue] <= 2) { // 0x9c9b4..0x9c9e0
            goalType = 1;
        }
    }
    m_goalType = goalType;
    sugorokuSaveTreasureProgress(); // 0x9c9f2, which copies the goal type into the record

    switch (m_goalType) {
    case 2: {
        // Ghidra: 0x9cc84..0x9ccbc, then the shared save at 0x9d8fa.
        const int owned = [UserSettingData haveTouchSoundFlg];
        const int bit = neSugorokuTouchSoundBit(mainMapId);
        [UserSettingData saveHaveTouchSoundFlg:(owned | (1 << bit))];
        break;
    }
    case 1:
        m_charaTicket = static_cast<int16_t>(m_charaTicket + 1); // 0x9ca06..0x9ca30
        [UserSettingData saveCharaTicket:m_charaTicket];
        break;
    default: {
        // Treasure points: a flat per-area award, scaled by the square-13 gimmick and then capped
        // by what the player has already spent, which the award refunds. Ghidra: 0x9ccc6..0x9cd9c.
        int points = (((mainMapId * 3) + areaId) * 25) + 100;
        if (points >= 200) {
            points = 200;
        }
        m_rouletteDigit = static_cast<int16_t>(points);
        if (m_boardSquareState[kTreasurePointBoostSquareSlot] <= kBoardSquareEventPending) {
            // ldexp(1.0, state) @ 0x9ccfa: the gimmick byte is the power-of-two exponent, so the
            // -1 sentinel halves the award.
            int scaled = static_cast<int>(
                static_cast<double>(m_rouletteDigit) *
                std::ldexp(1.0, m_boardSquareState[kTreasurePointBoostSquareSlot]));
            if (scaled < 50) {
                scaled = 50;
            }
            if (static_cast<int16_t>(scaled) >= 300) {
                scaled = 300;
            }
            m_rouletteDigit = static_cast<int16_t>(scaled);
        }
        const int spent = [UserSettingData consumedTreasurePoint];
        if (spent < m_rouletteDigit) {
            m_rouletteDigit = static_cast<int16_t>(spent);
        }
        int balance = m_treasurePoint + m_rouletteDigit;
        if (balance >= kMaxTreasurePoint) {
            balance = kMaxTreasurePoint;
        }
        m_treasurePoint = balance;
        [UserSettingData saveTreasurePoint:static_cast<short>(balance)];
        [UserSettingData saveConsumedTreasurePoint:0];
        break;
    }
    }

    // Recount this map's nine music and nine wallpaper pieces, the live grids against the pre-goal
    // duplicates: a grid that has just reached all nine arms its reveal state.
    // Ghidra: 0x9d926..0x9d9b4 and 0x9dab8..0x9dac0.
    int musicNow = 0;
    int musicBefore = 0;
    int wallNow = 0;
    int wallBefore = 0;
    for (int area = 0; area < 3; area++) {
        const int cell = (mainMapId * 3) + area;
        for (int bit = 0; bit < 3; bit++) {
            const uint32_t mask = 1u << bit;
            if (m_musicPieceTableDup[cell] & mask) {
                musicBefore++;
            }
            if (m_musicPieceTable[cell] & mask) {
                musicNow++;
            }
            if (m_wallPieceTableDup[cell] & mask) {
                wallBefore++;
            }
            if (m_wallPieceTable[cell] & mask) {
                wallNow++;
            }
        }
    }

    if ((musicNow == 9) && (musicBefore <= 8)) {
        // Ghidra: 0x9d9b8..0x9dab4. 0x9da0c builds a texture into +0xf4 that nothing reads before
        // 0x9da82 overwrites it with a second one, so only the second is ever loaded; the binary
        // leaks the first, the unique_ptr here frees it.
        [[MusicManager getInstance] openTreasureMusic];
        NSArray<MusicData *> *treasureMusic =
            [[MusicManager getInstance] getTreasureMusicDataArray];
        NSData *artwork = [treasureMusic[mainMapId] artwork2xData];
        m_reserveTex[3] = std::make_unique<neTextureForiOS>();
        m_reserveTex[3]->loadFromImageData((__bridge const void *)artwork);
        m_musicCompleteReveal = true;
    }

    if ((wallNow == 9) && (wallBefore <= 8)) {
        // Ghidra: 0x9dac2..0x9db8a.
        m_reserveTex[4] = std::make_unique<neTextureForiOS>();
        NSString *wallFile =
            [NSString stringWithFormat:@"sugo_wall%02d_960.png", static_cast<int>(mainMapId)];
#ifdef ENABLE_PATCHES
        NSString *wallPath = [AppDelegate appAssetsPath:wallFile];
#else
        NSString *wallPath =
            [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:wallFile];
#endif
        m_reserveTex[4]->load([wallPath UTF8String]);
        m_wallCompleteReveal = true;
    }

    // Upload the goal, then make sure the next area already has a record so the board can open it.
    // Ghidra: 0x9db8e..0x9dcea.
    TreasureTmpData saved = [UserSettingData treasureTmp];
    NSString *visitor =
        [NSString stringWithCString:saved.friendPlayerId encoding:NSUTF8StringEncoding];
    const int friendship = (m_rouletteMode == 16) ? 2 : 1; // 0x9dbc0 / 0x9dc0c
    [[DownloadMain getInstance] startSaveTreasureHttp:subMapId
                                              visitor:visitor
                                           friendship:friendship];

    const short nextArea = static_cast<short>((areaId + 1) % 3);
    short nextMap = mainMapId;
    if (nextArea == 0) {
        nextMap = static_cast<short>(getTreasureMapValue_fb30(mainMapId)); // 0xce198
    }
    if (static_cast<uint16_t>(nextMap) <= 8) {
        NSManagedObjectContext *nextCtx = [[AppDelegate appDelegate] managedObjectContext];
        if (![TreasureData getTreasureData:nextMap
                                  subMapId:nextArea
                    inManagedObjectContext:nextCtx]) {
            [TreasureData addRecordWithMainMapId:nextMap
                                        subMapId:nextArea
                          inManagedObjectContext:nextCtx];
            m_newMapReveal = true;
        }
    }

    [UserSettingData initTreasureTmp];
    m_rouletteLayers[kRouletteGoalOpen]->stop(1); // 0x9dd14 / 0x9dd1a
    m_state = kAcMainStateGoalRewardShow;
}

// case 0x12 — wait for GOAL_OPEN to finish, kick the goal board matching the reward that was just
// handed out, then hold until it has played out and the player taps. Ghidra: 0x9a8ca.
void AcMainTask::stateGoalRewardShow() {
    if (m_rouletteLayers[kRouletteGoalOpen]->isAnimating()) { // 0x9a8d4
        return;
    }

    // 0x9a8de / 0x9a8ee / 0x9a902: a board already running suppresses the kick.
    if (!m_rouletteLayers[kRouletteGoalBoard[0]]->isActive() &&
        !m_rouletteLayers[kRouletteGoalBoard[1]]->isActive() &&
        !m_rouletteLayers[kRouletteGoalBoard[2]]->isActive()) {
        int board = 0; // 0x9ed1e
        if (m_goalType == 2) {
            board = 2; // 0x9ed16
        } else if (m_goalType == 1) {
            board = 1; // 0x9a922
        }
        m_rouletteLayers[kRouletteGoalBoard[board]]->playOnce(); // 0x9ed28
    }

    // 0x9ed2c / 0x9ed40 / 0x9ed50, then the tap flag at 0x9ed62.
    if (m_rouletteLayers[kRouletteGoalBoard[0]]->isAnimating() ||
        m_rouletteLayers[kRouletteGoalBoard[1]]->isAnimating() ||
        m_rouletteLayers[kRouletteGoalBoard[2]]->isAnimating() || !m_frameTapped) {
        return;
    }
    m_state = kAcMainStateMusicCompleteShow; // 0x9ed6c
}

// case 0x13 — if this goal completed the map's nine music pieces, play LIFTING_MUSIC once and
// hold until it has finished and the player taps; otherwise fall straight through. The kick block
// at 0x9cdd8 clears the three goal boards first, and every clear is a reset (bl 0x2cb5c), not a
// stopPlay. Ghidra: 0x9a938.
void AcMainTask::stateMusicCompleteShow() {
    if (m_musicCompleteReveal) { // 0x9a938 ldrb +0x5f4
        AepLyrCtrl *lifting = m_rouletteLayers[kRouletteLayerLiftMusic].get();
        if (!lifting->isActive()) { // 0x9a948 / 0x9a94e
            for (const int board : kRouletteGoalBoard) {
                m_rouletteLayers[board]->reset(); // 0x9cdde / 0x9cde8 / 0x9cdf2
            }
            lifting->playOnce(); // 0x9ce62
            return;
        }
        if (lifting->isAnimating() || !m_frameTapped) {
            return; // 0x9a966
        }
    }
    m_state = kAcMainStateWallCompleteShow; // 0x9a96a movs 0x14
}

// case 0x14 — the same shape as case 0x13 for the wallpaper collection, clearing the music lift
// as well before it plays. Ghidra: 0x9a970, kick block at 0x9cdfc.
void AcMainTask::stateWallCompleteShow() {
    if (m_wallCompleteReveal) { // 0x9a970 ldrb +0x5f5
        AepLyrCtrl *liftWall = m_rouletteLayers[kRouletteLayerLiftWall].get();
        if (!liftWall->isActive()) { // 0x9a980 / 0x9a986
            for (const int board : kRouletteGoalBoard) {
                m_rouletteLayers[board]->reset();
            }
            m_rouletteLayers[kRouletteLayerLiftMusic]->reset(); // 0x9ce20
            liftWall->playOnce();                               // 0x9ce62
            return;
        }
        if (liftWall->isAnimating() || !m_frameTapped) {
            return; // 0x9a99e
        }
    }
    m_state = kAcMainStateNewMapShow; // 0x9a9a2 movs 0x15
}

// case 0x15 — if the goal opened a new area record, play LIFTING_MAP once and hold for a tap.
// With nothing to reveal it instead arms the 30-frame fade-out the next state waits on, which is
// why the two exits differ. Ghidra: 0x9a9a8, kick block at 0x9ce2a.
void AcMainTask::stateNewMapShow() {
    if (!m_newMapReveal) {                            // 0x9a9a8 ldrb +0x5f6
        AepManager::shared().setAepTransitionMode(2); // 0x9ca40: fade out, 30 frames
        m_state = kAcMainStateGoalFinish;
        return;
    }

    AepLyrCtrl *liftMap = m_rouletteLayers[kRouletteLayerLiftMap].get();
    if (!liftMap->isActive()) { // 0x9a9c2
        for (const int board : kRouletteGoalBoard) {
            m_rouletteLayers[board]->reset();
        }
        m_rouletteLayers[kRouletteLayerLiftMusic]->reset(); // 0x9ce4e
        m_rouletteLayers[kRouletteLayerLiftWall]->reset();  // 0x9ce58
        liftMap->playOnce();                                // 0x9ce62
        return;
    }

    if (!liftMap->isAnimating() && m_frameTapped) {
        m_state = kAcMainStateGoalFinish; // 0x9a9da -> 0x9ca44, no fade armed
    }
}

// case 0x16 — once the fade-out has finished, reset the board-story read progress if the player
// reached the last page, swap the shared system-SE pool, reload the roulette SEs and go back to
// the map-select fade. Ghidra: 0x9a9e2.
void AcMainTask::stateGoalFinish() {
    if (!AepManager::shared().isTransitionDone()) { // 0x9a9ec
        return;
    }

    if (m_readCount >= 1 && m_readCount <= m_readNo) {
        [UserSettingData saveTreasureReadNo:m_subMapId no:0]; // 0x9aa2a
    }

    neSceneManager::shared().releaseSystemSe(); // 0x9aa46
    [[AudioManager sharedManager] cleanupSe];   // 0x9aa5a
    neSceneManager::shared().loadSystemSe();    // 0x9aa68
    buildSelectListLayout();                    // 0x9aa70

    m_state = kAcMainStateFadeIn;
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
