// The board entry states of AcMainTask's state machine: scene build, fade-in, the pending
// treasure check, the board reveal, the idle hub, and the square message and arrival handling.
//
// This is a body fragment, not a translation unit. See AcMainTaskWalk.mm.inc for why these are
// included into AcMainTask.mm rather than compiled separately, and why the suffix is .mm.inc.

// case 0 — build the select/map scene, then start the BGM if a treasure record
// is present (subMapId @ +0x620 >= 0); otherwise take the no-treasure path.
// Ghidra: the case 0 body at 0x99e92 (FUN_0009fc90 then playBgm:0.5 /
// LAB_0009aa74).
void AcMainTask::stateInit() {
    setupScene(); // FUN_0009fc90
    if (m_subMapId >= 0) {
        // Ghidra: 0x99f46 bgt 0x9a026 — the treasure path jumps into the case-2
        // tail (playBgm then b 0x9dda8), sharing its state-3 store but skipping
        // loadTreasureMap.
        AudioManager *audio = [AudioManager sharedManager];
        [audio playBgm:0.5f]; // Ghidra: playBgm:, arg 0x3fe00000 == 0.5
        m_state = kAcMainStateBoardReveal;
    } else {
        // Ghidra: 0x99f48 clears +0x5ee then b 0x9aa74 (movs r0,#1; b 0x9ddac).
        m_bgmActive = false;
        m_state = kAcMainStateFadeIn;
    }
}

// case 1 — set a 30-frame fade-out and jump it to fully-faded, restore the menu
// BGM stack, push the sugoroku map-select screen, then advance to the treasure
// check. Ghidra: case 1 (setAepTransitionMode(scene, 2) = FUN_00010698,
// setTransitionFrame(scene, 0) = FUN_00010758).
void AcMainTask::stateFadeIn() {
    AepManager &aep = AepManager::shared();
    aep.setAepTransitionMode(2); // FUN_00010698(scene, 2): fade-out, 30 frames
    aep.setTransitionFrame(0);   // FUN_00010758(scene, 0): jump to fully-faded

    AudioManager *audio = [AudioManager sharedManager];
    if ([audio isPushBgm]) {
        [audio popBgm];
    }
    [audio playBgm:0.5f];

    MainViewController *root =
        static_cast<MainViewController *>(neSceneManager::rootViewController());
    [root GotoMapSelect]; // -[MainViewController GotoMapSelect] @ 0xc7d8
    m_state = kAcMainStateTreasureCheck;
}

// case 2 — read the temp-treasure record; if a sub-map is pending (subMapId >=
// 0), cache it (@ +0x620), load the map, and start play, else keep waiting.
// Ghidra: case 2 (UserSettingData treasureTmp; FUN_000a0b58; playBgm at
// LAB_0009a026).
void AcMainTask::stateTreasureCheck() {
    TreasureTmpData tmp = [UserSettingData treasureTmp];
    m_subMapId = tmp.subMapId;
    if (tmp.subMapId >= 0) {
        // Ghidra: 0x9a022 loadTreasureMap, 0x9a026 playBgm, 0x9a042 b 0x9dda8.
        loadTreasureMap(); // FUN_000a0b58
        AudioManager *audio = [AudioManager sharedManager];
        [audio playBgm:0.5f];
        m_state = kAcMainStateBoardReveal;
    } else {
        // Ghidra: 0x9a01a blt 0x9fa72 (movs r0,#0x4b; b 0x9ddac): no pending
        // sub-map, so begin the exit fade-out.
        m_state = kAcMainStateExitBegin;
    }
}

// case 3 — reveal the sugoroku board. Flip the scene from fade-out to fade-in,
// persist the just-entered board snapshot back to the pending record, start the
// board background layers, drop the drag / type-4 latches, then arm the
// player-token move-frame countdown and advance to the board-idle state. Ghidra:
// RealUpdate case 3, whose body the compiler scattered across 0x9a046 (fade / save
// / layers), 0x9a12c (base count) and 0x9cc2c (scale, halve, store, next state).
void AcMainTask::stateBoardReveal() {
    AepManager &aep = AepManager::shared();
    if (aep.transitionMode() == 2) { // was fading out: switch to fade-in
        aep.setAepTransitionMode(1); // Ghidra: 0x9a04e getMode == 2 -> 0x9a060 setMode(1)
    }

    // Persist the live board state into the pending TreasureTmpData: read it,
    // patch the eight fields the board owns, write it back. Ghidra:
    // 0x9a086..0x9a0f2.
    TreasureTmpData tmp = [UserSettingData treasureTmp];
    tmp.mainMapId = static_cast<int16_t>(m_bonusCount);              // +0x00 <- +0x628
    tmp.curSubMapId = m_curNode->id;                                 // +0x04 <- curNode->id
    tmp.lastBranchNodeId = m_lastBranchNodeId;                       // +0x06 <- +0x4f0
    tmp.boardMoveState = static_cast<int16_t>(m_boardMoveState);     // +0x10 <- +0x5d4
    tmp.rouletteMode = m_rouletteMode;                               // +0x44 <- +0x8ac
    tmp.treasureProgress = static_cast<uint8_t>(m_treasureProgress); // +0x51 <- +0x8b9
    tmp.listHalveCount = static_cast<uint8_t>(m_listHalveCount);     // +0x52 <- +0x8b8
    std::memcpy(tmp.boardSquareState,
                m_boardSquareState,
                sizeof(tmp.boardSquareState)); // +0x35 <- +0x894 (15 bytes)
    [UserSettingData saveTreasureTmp:tmp];

    // Start the board background layers if idle. Ghidra: 0x9a0f6 (panel[0]) and
    // 0x9a110 (board background, null-guarded).
    acPlayIfIdle(m_panelLayers[0].get());
    acPlayIfIdle(m_boardBgLayer.get());

    // Drop the drag anchor and the latched type-4 event square. Ghidra: 0x9a130
    // str -1,[+0x508]; 0x9a134 str -1,[+0x8b4].
    m_dragAnchorId = -1;
    m_activeType4SquareId = -1;

    // Arm the player-token move-frame countdown (kept in the +0x63c slot). Base is
    // 20, or 50 when the sub-map id sits in [30, 50). Ghidra: 0x9a138..0x9a148
    // (ldrh so the id is read unsigned).
    int moveFrames = 20;
    if (static_cast<uint16_t>(static_cast<uint16_t>(m_subMapId) - 30) < 20) {
        moveFrames = 50;
    }
    // Scale by the two board-square flags: square 4 set stretches it x1.5, else
    // square 5 set doubles it. Ghidra: 0x9a156..0x9a166 (vmul by 0x3fc00000 == 1.5,
    // truncated) / 0x9cc34 (lsl #1).
    if (m_boardSquareState[4] >= 1) {
        moveFrames = static_cast<int>(static_cast<float>(moveFrames) * 1.5f);
    } else if (m_boardSquareState[5] >= 1) {
        moveFrames <<= 1;
    }
    // Halve for treasure-event 11 and again when the list-halve flag is set.
    // Ghidra: 0x9cc3c (m_hudState == 0xb) / 0x9cc50 (m_listHalveCount >= 1).
    if (m_hudState == 11) {
        moveFrames /= 2;
    }
    if (m_listHalveCount >= 1) {
        moveFrames /= 2;
    }
    if (moveFrames < 1) {
        moveFrames = 1;
    }
    m_listBottom = static_cast<int16_t>(moveFrames);

    // Advance to the board-idle state (4), or the bonus-overlay variant (9) when a
    // bonus/main-map is active. Ghidra: 0x9cc72 (m_bonusCount > 0 -> 9), 0x9cc7c.
    m_state = m_bonusCount > 0 ? kAcMainStateBoardIdleBonus : kAcMainStateBoardIdle;
}

// case 4 — the interactive board-idle hub: the result-roulette auto-stop, the one-shot
// event-intro kick, and the drag-scroll normalisation. A tap that lands on the board itself is
// routed by the square-kind dispatch in sugorokuRouteSquareTap, which state 0x0e enters. Ghidra:
// case 4 body scattered across 0x9a172 (roulette), 0x9c748 (event-intro) and 0x9cb50 (drag,
// byte-identical to the state-0x10 block).
void AcMainTask::stateBoardIdle(neGraphics &gfx) {
    AepLyrCtrl *roul = m_rouletteLayers[0x1b].get();

    // The result roulette is spinning: once it has run past its last frame and the
    // player taps, brake it (-2.0) and stop it. Ghidra: 0x9a172..0x9a1ce.
    if (roul->isActive()) {
        if (roul->playSpeed() > 0.0f &&
            roul->frameCount() - 1 <= static_cast<int>(roul->curFrame()) && m_frameTapped) {
            roul->playSpeed() = -2.0f;
            roul->stop(true);
            m_fadeDir = 0;
        }
        return;
    }

    // First idle frame with a pending treasure-event tab (m_hudState >= 0): kick the
    // event-intro roulette once. The binary's 0x101 half-word store sets both the
    // one-shot flag and the fade direction. Ghidra: 0x9c748..0x9c774 (playOnce @
    // 0x2cac0).
    if (!m_eventIntroStarted && m_hudState >= 0) {
        roul->playSpeed() = 1.0f;
        roul->playOnce();
        m_eventIntroStarted = true;
        m_fadeDir = 1;
        return;
    }

    // Otherwise clear the fade direction and run the per-frame drag / rubber-band
    // scroll normalisation. Ghidra: 0x9cb50 movs r0,#0 / 0x9cb52 strb.w
    // r0,[r10,#0x5fa], so the transition dim ramps back out on every idle frame
    // that is not the intro one-shot; the drag block that follows is
    // byte-identical to the state-0x10 block at 0x9a6ba, which has no such store.
    m_fadeDir = 0;
    applyDragScroll(gfx);
}

// Park the square message board over the player token and publish the anchor the message text is
// drawn from. Shared by case 0x0b (0x9a512) and case 0x0d (0x9c828). The board's x is simply half
// the transition overlay; its y follows the token in scrolled board space, then takes whichever
// of the two fixed offsets the token's distance down the overlay selects.
void AcMainTask::sugorokuPositionSquareMessage() {
    const int halfW = m_overlayW / 2;             // 0x9c828..0x9c83e
    const int halfH = m_overlayH / 2;             // 0x9c854..0x9c870
    m_squareFrameIdx = static_cast<float>(halfW); // 0x9c84c

    // 0x9c868 / 0x9c884 / 0x9c888: the token's board y, less the scroll the board draw already
    // applies, biased by half the overlay.
    float y = (m_playerY - (m_scrollY - m_scrollBaseY)) + static_cast<float>(halfH);
    m_squareTextY = y; // 0x9c894
    y += ((static_cast<float>(m_overlayH) - y) < kSquareMessageFlipThreshold) ?
             kSquareMessageOffsetNear :
             kSquareMessageOffsetFar; // 0x9c898..0x9c8aa
    m_squareTextY = y;                // 0x9c8ae

    AepLyrCtrl *board = m_rouletteLayers[kRouletteLayerCommentBoard].get();      // 0x9c8b6
    board->setPosition(static_cast<int>(m_squareFrameIdx), static_cast<int>(y)); // 0x9c8ba
}

// case 0x0b — open the board-square message board. Ghidra: 0x9a4f4.
void AcMainTask::stateSquareMessageOpen() {
    [[AudioManager sharedManager] playSe:nil resourceId:m_rouletteSe[kRouletteSeQuiz]]; // 0x9a50e
    sugorokuPositionSquareMessage();                                                    // 0x9a512
    m_rouletteLayers[kRouletteLayerCommentBoard]->pause();                              // 0x9a5b2
    m_rankBadgeType = 2;                                                                // 0x9a5b8
    m_state = kAcMainStateSquareMessageRead;                                            // 0x9a5bc
}

// case 0x0c — the square message is up. The body is redrawn every frame from the staged text
// block at +0x8c4, one line-height above the parked board anchor; a tap dismisses it.
// Ghidra: 0x9a5c2.
void AcMainTask::stateSquareMessageRead() {
    drawAepTextMultiline(reinterpret_cast<const char *>(m_skillInfoBuffer),
                         static_cast<int>(m_squareFrameIdx),
                         static_cast<int>(m_squareTextY - kSquareMessageTextRise),
                         1,
                         0x1b,
                         0x2e,
                         0x615245,
                         0x18,
                         100); // 0x9a610
    if (!m_frameTapped) {
        return; // 0x9a618
    }
    neEngine::playSystemSe(2);                             // 0x9a634
    m_rouletteLayers[kRouletteLayerCommentBoard]->reset(); // 0x9a640
    m_state = kAcMainStateBoardReveal;
}

// case 0x0d — the token has stopped on a square. Ghidra: 0x9a648, the shared board block at
// 0x9c828, and the ten-way arrival table at 0x9c8f2.
void AcMainTask::stateSquareArrive() {
    if (m_boardMoveState == 1) { // 0x9a64c
        m_boardMoveState = 2;
    } else if (m_boardMoveState == 3) { // 0x9c81e
        m_boardMoveState = 0;
    }

    sugorokuPositionSquareMessage(); // 0x9c828

    // 0x9c8ca: every armed square counts one frame closer to idle. The kBoardSquareEventPending
    // marker is negative, so the tick leaves it alone.
    for (int8_t &square : m_boardSquareState) {
        if (square >= 1) {
            square = static_cast<int8_t>(square - 1);
        }
    }
    m_animFrameCtr = 0; // 0x9c8de

    AudioManager *audio = [AudioManager sharedManager];
    const TreasureMap::Node *node = m_curNode;
    switch (node->type) {                 // 0x9c8f2
    case TreasureMap::kSquarePlayerStart: // 0x9e5b0
    case TreasureMap::kSquareWallpaperPiece:
    case TreasureMap::kSquareMusicPiece:
        m_rankBadgeType = 1;
        break;

    case TreasureMap::kSquareBonus: // 0x9e580
        [audio playSe:nil resourceId:m_rouletteSe[kRouletteSeMove]];
        m_rankBadgeType = (m_rouletteMode == 0x12 || m_hudState == 2) ? 0xff : 1;
        break;

    case TreasureMap::kSquareTreasure: // 0x9e5b4
        if (m_rouletteMode == 0x12 || m_hudState == 3) {
            [audio playSe:nil resourceId:m_rouletteSe[kRouletteSeMove]]; // 0x9ecec
            m_rankBadgeType = 0xff;
        } else {
            [audio playSe:nil resourceId:m_rouletteSe[kRouletteSeTrap]]; // 0x9e5c6
            m_rankBadgeType = 2;
        }
        break;

    case TreasureMap::kSquareSubMapFlag: // 0x9e5e6
        sugorokuArriveSubMapFlag();
        break;

    case TreasureMap::kSquareWarp: // 0x9c90a
    case TreasureMap::kSquareGoalLock:
        [audio playSe:nil resourceId:m_rouletteSe[kRouletteSeMove]];
        m_rankBadgeType = 0;
        break;

    case TreasureMap::kSquareBonusTreasure: { // 0x9e744
        TreasureTmpData tmp = [UserSettingData treasureTmp];
        if (m_goalCharaTex && tmp.friendMeetFlag == 0) {
            m_rankBadgeType = 1;  // 0x9efca
            m_friendOpacity = 95; // 0x9efd0
        } else {
            [audio playSe:nil resourceId:m_rouletteSe[kRouletteSeMove]];
            m_rankBadgeType = 0xff;
        }
        break;
    }

    default: // 0x9ecec: the start square, a deactivated bonus, or any other kind
        [audio playSe:nil resourceId:m_rouletteSe[kRouletteSeMove]];
        m_rankBadgeType = 0xff;
        break;
    }

    m_state = kAcMainStateSquareMessage; // 0x9ed10
}

// The sub-map-flag arrival arm (Ghidra: 0x9e5e6 with its follow-ons at 0x9ebe8 and 0x9ec22). A
// flag square is live while either the roulette result or the treasure-event tab names it. The
// event tab only chimes; a roulette hit consumes the result, banks a list halve for results
// 0x14..0x17, and starts the flag layer's reveal over the token.
void AcMainTask::sugorokuArriveSubMapFlag() {
    AudioManager *audio = [AudioManager sharedManager];
    const int flag =
        static_cast<uint16_t>(getTreasureMapValue_fb54(0, m_curNode->slotId)); // 0x9e5f4
    const int roulette = static_cast<uint16_t>(m_rouletteMode);
    const int hud = m_hudState;

    // 0x9e5fe..0x9e688 (roulette side) and 0x9e68c..0x9e718 / 0x9ebe8 (tab side).
    const bool rouletteLive = (roulette == 0x0a && flag == 0) || (roulette == 0x0b && flag == 1) ||
                              (roulette == 0x0c && flag == 2) || (roulette == 0x0d && flag == 3) ||
                              (roulette == 0x13) || (roulette == 0x14 && flag == 0) ||
                              (roulette == 0x15 && flag == 1) || (roulette == 0x16 && flag == 2) ||
                              (roulette == 0x17 && flag == 3);
    const bool eventLive = (hud == 6 && flag == 0) || (hud == 7 && flag == 1) ||
                           (hud == 8 && flag == 2) || (hud == 9 && flag == 3) || (hud == 5);

    if (!rouletteLive && !eventLive) {
        [audio playSe:nil resourceId:m_rouletteSe[kRouletteSeTrap]]; // 0x9e71c
        m_squareAnimActive = false;                                  // 0x9e73c
        m_rankBadgeType = 2;                                         // 0x9e740
        return;
    }
    if (eventLive) {
        [audio playSe:nil resourceId:m_rouletteSe[kRouletteSeMove]]; // 0x9ecec
        m_rankBadgeType = 0xff;
        return;
    }

    [audio playSe:nil resourceId:m_rouletteSe[kRouletteSeShield]]; // 0x9ec3e
    if ((roulette & ~3) == 0x14) {                                 // 0x9ec4e
        ++m_listHalveCount;
    }
    m_rouletteMode = -1; // 0x9ec64

    AepLyrCtrl *flagLayer = m_rouletteLayers[kRouletteLayerSkillKouka].get();
    flagLayer->stop(1);            // 0x9ec92
    parkLayerOverToken(flagLayer); // 0x9ec70..0x9ecd6
    m_squareAnimActive = true;     // 0x9ecde
    m_rankBadgeType = 1;           // 0x9ece2
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
