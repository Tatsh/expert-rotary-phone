// The board-walk half of AcMainTask's state machine: the tapped square's label hold, the
// eleven-way square tap router, the walk itself, the roulette, and the exit to the mode menu.
//
// This is a body fragment, not a translation unit. AcMainTask.mm includes it so the whole state
// machine stays in one translation unit, which is what lets these bodies keep using the file-scope
// constants, the file-static helpers and the anonymous namespace declared ahead of the include.
// The .mm.inc suffix is deliberate. theos builds every file whose name ends in .mm under
// Project/, and compiling this one separately would duplicate every symbol in it; the suffix
// keeps it out of that glob while still telling the editor and the formatters what it holds. It
// is distinct from the plain .inc used for bf_init_bytes.inc, which is a bare byte list spliced
// into an array initialiser rather than formattable C++.

// case 0x0e — the arrived square's label is on screen. It is redrawn every frame; the moment it
// has nothing left to draw, or a finger is lifted, the square's own handler is chosen. The
// comment layer is loaded here (0x9a666) but reset inside the router, which both branches enter
// with it already in r0. Ghidra: 0x9a658.
void AcMainTask::stateSquareLabelWait() {
    const bool drew = sugorokuDrawSquareText(); // 0x9a660
    if (m_frameReleasedTouch || !drew) {        // 0x9a66a / 0x9a674
        sugorokuRouteSquareTap();
        return;
    }
    m_rouletteLayers[kRouletteLayerCommentBoard]->pause(); // 0x9a680
}

// Advance the board-story page counter for the tapped square and persist it. The board always
// returns to the reveal state; the page counter only moves when the square actually has story
// pages. Ghidra: 0x9f198.
void AcMainTask::sugorokuAdvanceSquareStory() {
    m_state = kAcMainStateBoardReveal;                               // 0x9f19c movs 3
    if (m_readCount > 0) {                                           // 0x9f198 / 0x9f1a2
        ++m_readNo;                                                  // 0x9f1b0 / 0x9f1be / 0x9f1c2
        [UserSettingData saveTreasureReadNo:m_subMapId no:m_readNo]; // 0x9f1ce / 0x9f1d4
    }
}

// Hand the board to the state that owns the tapped square's kind. Entered from case 0x0e when a
// tap landed this frame (0x9a66a) or when the square-text pass drew no label (0x9a670). The
// eleven-way table at 0x9c94a is indexed by Node::type directly, and the unsigned range check at
// 0x9c940 sends anything past kind 10 to the same default the kind-0 entry uses.
// Ghidra: 0x9c932.
void AcMainTask::sugorokuRouteSquareTap() {
    m_rouletteLayers[kRouletteLayerCommentBoard]->reset(); // 0x9c934

    const TreasureMap::Node *node = m_curNode; // 0x9c938
    switch (node->type) {                      // 0x9c93c ldrsh, 0x9c946 tbh
    case TreasureMap::kSquarePlayerStart:
        m_state = kAcMainStateGoalAward; // 0x9c960 movs 0x11
        break;

    case TreasureMap::kSquareDeactivatedBonus:
        // 0x9edd0, a verbatim inline copy of the story tail at 0x9f198.
        sugorokuAdvanceSquareStory();
        break;

    case TreasureMap::kSquareBonus:
        // 0x9ede4
        if (m_rouletteMode == 0x12) {
            if (m_hudState != 2) {
                m_rouletteMode = -1; // 0x9ee0e strh 0xffff
            }
            sugorokuAdvanceSquareStory(); // 0x9edf4 / 0x9ee16
            break;
        }
        if (m_hudState == 2) { // 0x9f172
            sugorokuAdvanceSquareStory();
            break;
        }
        if (m_activeType3SquareId == node->id) { // 0x9f176
            m_activeType3SquareId = -1;          // 0x9f18a
            m_state = kAcMainStateBoardReveal;   // 0x9f18e
            break;
        }
        if (m_activeType3SquareId == -1) { // 0x9f750
            m_activeType3SquareId = node->id;
        }
        m_bonusCount = node->slotId; // 0x9f75a / 0x9f75e
        if (m_boardMoveState == 2) { // 0x9f762
            m_boardMoveState = 1;    // 0x9f76c
        }
        m_state = kAcMainStateBoardIdleBonus; // 0x9faa4 movs 9
        break;

    case TreasureMap::kSquareTreasure:
        // 0x9edfa
        if (m_rouletteMode == 0x12) {
            if (m_hudState != 3) {
                m_rouletteMode = -1; // 0x9ee0e
            }
            sugorokuAdvanceSquareStory(); // 0x9ee0a / 0x9ee16
            break;
        }
        if (m_hudState == 3) { // 0x9f192
            sugorokuAdvanceSquareStory();
            break;
        }
        if (m_activeType4SquareId == node->id) { // 0x9f770
            m_activeType4SquareId = -1;          // 0x9f784
            m_state = kAcMainStateBoardReveal;   // 0x9f788
            break;
        }
        if (m_activeType4SquareId == -1) { // 0x9f966
            m_activeType4SquareId = node->id;
        }
        m_bonusCount = node->slotId;        // 0x9f970 / 0x9f974
        if (m_boardMoveState == 1) {        // 0x9f97c
            m_boardMoveState = 2;           // 0x9f982
        } else if (m_boardMoveState == 0) { // 0x9fa9c cbnz
            m_boardMoveState = 3;           // 0x9fa9e
        }
        m_state = kAcMainStateBoardIdleBonus; // 0x9faa4 movs 9
        break;

    case TreasureMap::kSquareSubMapFlag: {
        // 0x9ee18: the flag must agree with the HUD state, the same test
        // sugorokuDrawSquareText makes before it shows the message.
        const int flag = getTreasureMapValue_fb54(0, node->slotId); // 0x9ee18 / 0x9ee26
        const int st = m_hudState;                                  // 0x9ee2a
        const bool matched = (st == 6 && flag == 0) || (st == 7 && flag == 1) ||
                             (st == 8 && flag == 2) || (st == 9 && flag == 3) || (st == 5);
        if (matched) {
            sugorokuAdvanceSquareStory();
        } else {
            m_state = kAcMainStateSquareApply; // 0x9ee6e movs 0x22
        }
        break;
    }

    case TreasureMap::kSquareWallpaperPiece:
        m_state = kAcMainStateWallPieceGet; // 0x9ee74 movs 0x17
        break;

    case TreasureMap::kSquareMusicPiece:
        m_state = kAcMainStateMusicPieceGrant; // 0x9ee7a movs 0x19
        break;

    case TreasureMap::kSquareWarp:
        m_state = kAcMainStateWarpBegin; // 0x9ee80 movs 0x1d
        break;

    case TreasureMap::kSquareGoalLock:
        // 0x9ee86
        if (m_hudState == 4) {
            sugorokuAdvanceSquareStory();
            break;
        }
        m_bonusCount = 0;                  // 0x9ee92
        m_state = kAcMainStateBoardReveal; // 0x9ee96
        break;

    case TreasureMap::kSquareBonusTreasure: {
        // 0x9ee9a: the friend-meet goal square only opens while the portrait is loaded and the
        // meet has not been consumed yet.
        TreasureTmpData tmp = [UserSettingData treasureTmp]; // 0x9eeba
        if (m_goalCharaTex && tmp.friendMeetFlag == 0) {     // 0x9eebe / 0x9eec4
            m_state = kAcMainStateGoalReward;                // 0x9f4bc movs 0x1b
        } else {
            m_state = kAcMainStateBoardReveal; // 0x9eed0 movs 3
        }
        break;
    }

    case TreasureMap::kSquareStart:
    default:
        m_state = kAcMainStateBoardReveal;
        break;
    }
}

// case 0x0f — light the direction arrows the current square can leave by, then hand over to the
// map-drag state. Unlike the other layer kicks in this task the arrows are started
// unconditionally, without an isAnimating() guard. Ghidra: 0x9a688.
void AcMainTask::stateShowArrows() {
    for (int i = 0; i < 4; ++i) {
        const TreasureMapDirection dir = static_cast<TreasureMapDirection>(i);
        if (findAdjacentSquareIndex(m_curNode, dir) != -1) { // 0x9a69a
            m_arrowLayers[i]->play();                        // 0x9a6aa
        }
    }
    m_state = kAcMainStateMapDrag; // 0x9a6b4
}

// Choose the forward link the walk steps along. An unset index takes the only link there is; a
// junction hands over to the direction arrows instead and leaves the walk parked.
// Ghidra: 0x9d6a4.
const TreasureMap::Node *AcMainTask::pickForwardLink() {
    if (m_moveLinkIndex < 0) { // 0x9d6a8 cmp #0xff
        if (countSquareLinks(m_curNode, 0) != 1) {
            m_state = kAcMainStateShowArrows; // 0x9e23e movs 0xf
            return nullptr;
        }
        m_moveLinkIndex = 0; // 0x9d6b4
    }
    return m_curNode->links[m_moveLinkIndex]; // 0x9d6be / 0x9d6c2
}

// The recovery for backing up into a square with no back link: a junction still raises the arrows,
// but an already-chosen index is honoured and a single link is taken outright. Ghidra: 0x9e224.
const TreasureMap::Node *AcMainTask::pickBackupLink() {
    if (countSquareLinks(m_curNode, 0) > 1) { // 0x9e22e / 0x9e232
        m_state = kAcMainStateShowArrows;     // 0x9e78e
        if (m_moveLinkIndex < 0) {            // 0x9e796
            return nullptr;
        }
    } else {
        m_moveLinkIndex = 0; // 0x9e238
    }
    return m_curNode->links[m_moveLinkIndex]; // 0x9e79c -> 0x9d6be
}

// Arm the scroll and player eases toward the square the walk is stepping onto, then hand over to
// the step state. The scroll target carries the same +52 / +64 half-tile bias the rest of the
// board uses and is clamped into the map's scroll box; the player target is the raw tile position,
// unbiased and unclamped (0x9d7ce and 0x9d814 convert the products before the biases are added).
// Ghidra: the shared block at 0x9d76e, whose velocity tail only runs for this state.
void AcMainTask::armBoardStepEase(const TreasureMap::Node *dest) {
    const int tileX = dest->x * 0x1a; // 0x9d770..0x9d77c
    const int tileY = dest->y * 0x1a; // 0x9d778 / 0x9d7aa
    const float biasedX = static_cast<float>(tileX + 0x34);
    const float biasedY = static_cast<float>(tileY + 0x40);

    m_scrollTargetX = std::min(std::max(biasedX, m_clampCentreX), m_clampCentreX2); // 0x9d7e0
    m_scrollTargetY = std::min(std::max(biasedY, m_clampMinY), m_clampMaxY);        // 0x9d818
    m_playerTargetX = static_cast<float>(tileX);                                    // 0x9d81c
    m_playerTargetY = static_cast<float>(tileY);                                    // 0x9d820

    // 0x9d824: the block above is shared with other states, but only the walk arms the eases.
    if (m_state != kAcMainStateBoardIdleBonus) {
        return; // 0x9d82e
    }

    // 0x9d83a / 0x9d842: the two speeds are vmov.f32 immediates, -10.0f and +10.0f.
    m_scrollVelX = (m_scrollX < m_scrollTargetX) ? 10.0f : -10.0f; // 0x9d84e
    m_scrollVelY = (m_scrollY < m_scrollTargetY) ? 10.0f : -10.0f; // 0x9d878
    m_playerVelX = (m_playerX < m_playerTargetX) ? 10.0f : -10.0f; // 0x9d8a2
    m_playerVelY = (m_playerY < m_playerTargetY) ? 10.0f : -10.0f; // 0x9d8cc
    m_state = kAcMainStateBoardStepAdvance;                        // 0x9d8de movs 0x0a
}

// case 0x09 — the board hub variant that starts one step of the walk. It settles which direction
// the token travels, resolves the square it steps onto, and arms the eases. Ghidra: 0x9a444.
void AcMainTask::stateBoardIdleBonus() {
    m_rankBadgeType = 0xff; // 0x9a446

    int moveState = m_boardMoveState; // 0x9a44a
    const TreasureMap::Node *dest = nullptr;

    // 0x9a44e: `bic r1,#1` folds move states 2 and 3 together, so this is the backing-up test.
    // Losing the back link drops the walk into the forward direction.
    bool forward = false;
    if ((moveState & ~1) == 2) {                   // 0x9a452
        if (countSquareLinks(m_curNode, 1) == 0) { // 0x9a462
            m_boardMoveState = 0;                  // 0x9d68e
            forward = true;
        } else {
            moveState = m_boardMoveState; // 0x9a46c
        }
    }
    if (!forward && moveState == 0) { // 0x9a470 -> 0x9cec4
        forward = true;
    }

    if (forward) {
        // 0x9d692: with no forward link the token backs up instead, and a player-start square
        // backs up as state 3 rather than 2.
        if (countSquareLinks(m_curNode, 0) == 0) {
            m_boardMoveState =
                (m_curNode->type == TreasureMap::kSquarePlayerStart) ? 3 : 2; // 0x9d75c
            dest = m_curNode->backLink;                                       // 0x9d76e
        } else {
            dest = pickForwardLink();
        }
    } else if (moveState == 1) {                   // 0x9a47a
        if (countSquareLinks(m_curNode, 0) != 0) { // 0x9a488
            dest = pickForwardLink();
        } else {
            m_boardMoveState = 2;       // 0x9a494
            dest = m_curNode->backLink; // 0x9a49c -> 0x9d76e
        }
    } else {
        dest = m_curNode->backLink; // 0x9cfbc
        if (!dest) {
            dest = pickBackupLink(); // 0x9cfc0 -> 0x9e224
        }
    }

    if (dest) {
        armBoardStepEase(dest);
    }
}

// case 0x0a — one step of the board walk. Hold the frame until both position eases have settled,
// remember the square if it is a junction, then step the token onto the next square and
// decrement +0x628. The walk stops (state 0x0d) when that counter runs out or the square reached
// is a player start, a goal lock, or a warp whose slot-10 board state is not armed; otherwise
// the walk SE replays and state 9 starts the next step. Ghidra: 0x9a4a0, whose tail is the
// shared block at 0x9cda0..0x9cf9c.
void AcMainTask::stateBoardStepAdvance() {
    // 0x9a4a2 and 0x9a4ac: both eases are stepped every frame, so neither call may be skipped;
    // 0x9a4b0-0x9a4b4 then holds while either reports movement.
    const bool scrollMoving = sugorokuEasePositionPairA();
    const bool playerMoving = sugorokuEasePositionPairB();
    if (scrollMoving || playerMoving) {
        return; // 0x9a4b4
    }

    if (countSquareLinks(m_curNode, 0) >= 2) { // 0x9a4c4
        m_lastBranchNodeId = m_curNode->id;    // 0x9a4d2
    }

    // 0x9a4de: past move state 1 the walk retreats along the back link. Otherwise
    // m_moveLinkIndex picks the forward link; its -1 idle value also means the back link,
    // because the binary indexes links[-1] and Node::links (+0x10) minus one entry is
    // Node::backLink (+0x0c).
    const TreasureMap::Node *next = (m_boardMoveState > 1 || m_moveLinkIndex < 0) ?
                                        m_curNode->backLink :
                                        m_curNode->links[m_moveLinkIndex];
    m_curNode = next; // 0x9cda8

    const bool stop = (--m_bonusCount < 1) ||                          // 0x9cdb6
                      next->type == TreasureMap::kSquarePlayerStart || // 0x9cdbc
                      next->type == TreasureMap::kSquareGoalLock ||    // 0x9cdc0
                      (next->type == TreasureMap::kSquareWarp &&       // 0x9cdc4
                       m_boardSquareState[kWarpGateSquareSlot] <= 1);  // 0x9cdd0
    if (stop) {
        m_state = kAcMainStateSquareArrive; // 0x9cdd4
    } else {
        [[AudioManager sharedManager] playSe:nil resourceId:m_rouletteSe[kRouletteSeMove]];
        m_state = kAcMainStateBoardIdleBonus; // 0x9cf90
    }
    m_moveLinkIndex = -1; // 0x9cf98
}

// case 5 — recentre the board on the current square, then refill the step table. The ease
// target is the square's pixel position (tile 0x1a, +52 x / +64 y, the same bias
// sugorokuSetupScrollBounds and loadTreasureMap use) clamped into the map's scroll box, and the
// ease is armed at 15 px/frame with a 2 px/frame increment: case 6 adds +0x5b4 / +0x5b8 into
// +0x5ac / +0x5b0 every frame before running sugorokuEasePositionPairA. Ghidra: the case-5 body
// at 0x9a1d6, whose sign arms the compiler split across 0x9c77c (x negative), 0x9c788 (shared x
// increment store), 0x9c998 (y negative) and 0x9c9a4 (shared y increment store). The current
// node is dereferenced unguarded, as in the binary.
void AcMainTask::stateRouletteScrollArm() {
    const TreasureMap::Node *cur = m_curNode; // 0x9a1d6 ldr [r10,#0x4bc]
    // 0x9a1e0 / 0x9a1e8 ldrsh x, y; 0x9a1ec / 0x9a1ee mul 0x1a; 0x9a1f4 +0x34; 0x9a202 +0x40.
    const float targetX = static_cast<float>(cur->x * 0x1a + 0x34);
    const float targetY = static_cast<float>(cur->y * 0x1a + 0x40);
    // 0x9a20c / 0x9a222 clamp x into [+0x4e0, +0x4e8]; 0x9a23c / 0x9a252 clamp y into
    // [+0x4e4, +0x4ec]; each bound is a vcmpe with an it-mi vmov.
    m_scrollTargetX = std::min(std::max(targetX, m_clampCentreX), m_clampCentreX2); // 0x9a234
    m_scrollTargetY = std::min(std::max(targetY, m_clampMinY), m_clampMaxY);        // 0x9a264

    // Arm the ease: 15 px/frame with a 2 px/frame increment, signed toward the target. 0x9a274
    // vcmpe s8,s4 / 0x9a27c bpl and 0x9c798 vcmpe s4,s0 / 0x9c7a0 bpl both fall through when
    // the scroll is below the target.
    m_scrollVelX = (m_scrollX < m_scrollTargetX) ? 15.0f : -15.0f;
    m_scrollAccumX = (m_scrollX < m_scrollTargetX) ? 2.0f : -2.0f;
    m_scrollVelY = (m_scrollY < m_scrollTargetY) ? 15.0f : -15.0f;
    m_scrollAccumY = (m_scrollY < m_scrollTargetY) ? 2.0f : -2.0f;

    computeStepValues();                      // FUN_000a1950 @ 0x9c9aa
    m_state = kAcMainStateRouletteScrollWait; // 0x9c9ae movs r0,#6
}

// case 6 — run the ease that recentres the board. While it is still moving nothing else happens;
// the frame it lands, the roulette opens: play se11_roulapp, arm the open one-shot (the _EVENT
// layer while treasure event 0 or 1 is active) and set the sub-tick period, which is longer -- a
// slower spin -- for those two events. Ghidra: 0x9a290 (velocity += acceleration, then
// sugorokuEasePositionPairA), 0x9a2d0 (SE), 0x9a2f2 / 0x9cfa0 / 0x9df84 (the event branch),
// shared exit at 0x9df96.
void AcMainTask::stateRouletteScrollWait() {
    m_scrollVelX += m_scrollAccumX;    // 0x9a298..0x9a2a8
    m_scrollVelY += m_scrollAccumY;    // 0x9a2b0..0x9a2bc
    if (sugorokuEasePositionPairA()) { // 0x9a2c6: still moving
        return;
    }

    // 0x9a2dc reads m_rouletteSe[0] and 0x9a2ee stores the instance to m_rouletteSeInst[0].
    m_rouletteSeInst[kRouletteSeOpen] = static_cast<int>(
        [[AudioManager sharedManager] playSe:nil resourceId:m_rouletteSe[kRouletteSeOpen]]);

    // stop(true) arms play-state 3 (play once from frame 0, then idle) instead of stopping:
    // 0x2cb24 writes 3 to the play-state and seeks the play head.
    if (m_hudState == 0) {
        m_rouletteLayers[kRouletteLayerOpenEvent]->stop(true);
        m_stepSubTickLen = 16;
    } else if (m_hudState == 1) {
        m_rouletteLayers[kRouletteLayerOpenEvent]->stop(true);
        m_stepSubTickLen = 9;
    } else {
        m_rouletteLayers[kRouletteLayerOpen]->stop(true);
        m_stepSubTickLen = 3;
    }
    m_state = kAcMainStateRouletteSpin;
}

// case 7 — the roulette is opening, then spinning. While either opening one-shot is still
// running only the step tick happens; the frame an opening completes, its matching
// ROULETTE_START_ROOP loop starts. A finger down then stops the wheel: play se13_roulstop, latch
// the next six-frame slot boundary as the stop frame (0 when that would run past the loop's
// end), fire ROULETTE_EFF and zero the stop timer. Ghidra: 0x9a30e (opening polls), 0x9a32e /
// 0x9a34c (the +0x5c completion latches), 0x9a368 (the held-touch gate), 0x9a38c (slot
// arithmetic) and 0x9a3d8 (the step tick).
void AcMainTask::stateRouletteSpin() {
    AepLyrCtrl *open = m_rouletteLayers[kRouletteLayerOpen].get();
    AepLyrCtrl *openEvent = m_rouletteLayers[kRouletteLayerOpenEvent].get();
    if (!open->isAnimating() && !openEvent->isAnimating()) {
        if (open->takeFinished()) { // 0x9a334 ldrb/strb +0x5c
            m_rouletteLayers[kRouletteLayerLoop]->play();
        }
        if (openEvent->takeFinished()) { // 0x9a350 ldrb/strb +0x5c
            m_rouletteLayers[kRouletteLayerLoopEvent]->play();
        }
        if (m_frameDragging) { // 0x9a368 cmp r4,#1
            [[AudioManager sharedManager] playSe:nil resourceId:m_rouletteSe[kRouletteSeStop]];
            AepLyrCtrl *loop = m_rouletteLayers[kRouletteLayerLoop].get();
            const int head = static_cast<int>(loop->curFrame());
            const int stopFrame =
                (head / kRouletteSlotFrames) * kRouletteSlotFrames + kRouletteSlotFrames;
            // Past the loop's last frame the wheel wraps back to slot zero.
            m_charaLayerTargetFrame = loop->frameCount() > stopFrame ? stopFrame : 0;
            m_rouletteLayers[kRouletteLayerEff]->stop(1);
            m_rouletteStopTimer = 0;
            m_state = kAcMainStateRouletteStop;
        }
    }
    advanceRouletteStepTick();
}

// case 8 — the wheel is braking. Below frame 60 it keeps spinning until the play head reaches
// the latched stop frame, on frame 60 both loop layers are dropped, and past that the board gets
// its move back. Every arm funnels through the shared counter bump. Ghidra: 0x9a41e, 0x9c7c0,
// 0x9f4ac.
void AcMainTask::stateRouletteStop() {
    if (m_rouletteStopTimer == kRouletteStopFrames) {       // 0x9a422
        m_rouletteLayers[kRouletteLayerLoop]->reset();      // 0x9a432
        m_rouletteLayers[kRouletteLayerLoopEvent]->reset(); // 0x9a43c
    } else if (m_rouletteStopTimer <= kRouletteStopFrames) {
        rouletteStopSpin(); // 0x9c7c2
    } else {
        rouletteStopResolve(); // 0x9c7c6
    }
    m_rouletteStopTimer++; // 0x9f4ac
}

// Move the roulette step cursor on: the sub-tick wraps on m_stepSubTickLen and every wrap
// advances the seven-slot step-value cursor. Ghidra: 0x9d5cc (the same block runs in the state-7
// tail at 0x9a3d8).
void AcMainTask::advanceRouletteStepTick() {
    m_stepSubTick = (m_stepSubTick + 1) % m_stepSubTickLen;
    if (m_stepSubTick == 0) {
        m_stepValueIndex = (m_stepValueIndex + 1) % kStepValueCount;
    }
}

// The braking wheel (Ghidra: 0x9d5ac). The step cursor keeps ticking while a loop layer runs;
// the roll is committed the frame the play head reaches the latched stop frame, which for a
// wrapped (zero) stop frame means the head is back inside slot zero.
void AcMainTask::rouletteStopSpin() {
    AepLyrCtrl *loop = m_rouletteLayers[kRouletteLayerLoop].get();
    AepLyrCtrl *loopEvent = m_rouletteLayers[kRouletteLayerLoopEvent].get();
    if (!loop->isAnimating() && !loopEvent->isAnimating()) {
        return; // 0x9d5ba / 0x9d5c8
    }
    advanceRouletteStepTick(); // 0x9d5cc

    AepLyrCtrl *spin = loop->isAnimating() ? loop : loopEvent; // 0x9d60a..0x9d624
    const int head = static_cast<int>(spin->curFrame());       // 0x9d628
    const int stopFrame = m_charaLayerTargetFrame;             // 0x9d62c
    if (stopFrame < 1) {                                       // 0x9d634 / 0x9d63a
        // 0x9e378 is an unsigned compare against 5, so only frames 0..5 land.
        if (static_cast<unsigned>(head) >= static_cast<unsigned>(kRouletteSlotFrames)) {
            return;
        }
    } else if (stopFrame > head) {
        return; // 0x9d63e / 0x9d640
    }
    commitRouletteResult(spin, stopFrame);
}

// The wheel has landed (Ghidra: 0x9e37e). Use up a one-shot roulette mode, publish the rolled
// step value, charge the roll's treasure points, freeze the wheel on the landed frame and
// persist all of it. The rolled value goes to the pending record's +0x00 (0x9e404), which the
// record otherwise carries a main map id in.
void AcMainTask::commitRouletteResult(AepLyrCtrl *spin, int stopFrame) {
    const int mode = m_rouletteMode; // 0x9e37e
    if ((static_cast<unsigned>(mode) <= kRouletteModeMax) &&
        (((1u << mode) & kRouletteModeOneShotMask) != 0u)) { // 0x9e382..0x9e390
        m_rouletteMode = -1;                                 // 0x9e394 / 0x9e398
    }

    m_bonusCount = m_stepValues[m_stepValueIndex]; // 0x9e39c..0x9e3b4
    m_treasurePoint -= m_listBottom;               // 0x9e3b8..0x9e3c2

    spin->curFrame() = static_cast<float>(stopFrame); // 0x9e3a0 / 0x9e3c8
    spin->pause();                                    // 0x9e3d2

    TreasureTmpData tmp = [UserSettingData treasureTmp];                         // 0x9e3f4
    tmp.mainMapId = static_cast<int16_t>(m_bonusCount);                          // 0x9e404
    tmp.rouletteMode = static_cast<int16_t>(m_rouletteMode);                     // 0x9e40e
    [UserSettingData saveTreasureTmp:tmp];                                       // 0x9e41a
    [UserSettingData saveTreasurePoint:static_cast<short>(m_treasurePoint)];     // 0x9e432
    [UserSettingData addConsumedTreasurePoint:static_cast<short>(m_listBottom)]; // 0x9e44a
}

// The wheel is parked and both opening layers have gone idle (Ghidra: 0x9c7c6), so the board
// gets its move back. The two parity-gate squares hold the player until the roll matches their
// parity; when it does not, the square's message goes up and the roll is discarded.
void AcMainTask::rouletteStopResolve() {
    if (m_rouletteLayers[kRouletteLayerOpen]->isAnimating() ||
        m_rouletteLayers[kRouletteLayerOpenEvent]->isAnimating()) {
        return; // 0x9c7d6 / 0x9c7e6
    }
    m_moveLinkIndex = -1; // 0x9c7ec strb 0xff

    const bool odd = (m_bonusCount & 1) != 0;                                  // 0x9c808 / 0x9edc0
    if (m_boardSquareState[kBoardSquareGateOdd] == kBoardSquareEventPending) { // 0x9c7f0
        if (odd) {
            m_boardSquareState[kBoardSquareGateOdd] = kBoardSquareIdle; // 0x9edca
            m_state = kAcMainStateBoardIdleBonus;                       // 0x9f20c
        } else {
            showBoardGateMessage(kBoardGateMessageNeedOdd); // 0x9f46c
        }
    } else if (m_boardSquareState[kBoardSquareGateEven] == kBoardSquareEventPending) { // 0x9c7fa
        if (odd) {
            showBoardGateMessage(kBoardGateMessageNeedEven); // 0x9c810
        } else {
            m_boardSquareState[kBoardSquareGateEven] = kBoardSquareIdle; // 0x9f208
            m_state = kAcMainStateBoardIdleBonus;                        // 0x9f20c
        }
    } else {
        m_state = kAcMainStateBoardIdleBonus; // 0x9c800 -> 0x9f20c
    }
}

// Put a parity-gate square's message into the board message buffer and discard the roll
// (Ghidra: 0x9f476, a fixed 40-byte copy).
void AcMainTask::showBoardGateMessage(const char *message) {
    std::memcpy(m_skillInfoBuffer, message, kBoardGateMessageBytes);
    m_state = kAcMainStateSquareMessageOpen; // 0x9f4a0 / 0x9f4a2
    m_bonusCount = 0;                        // 0x9f4a6 / 0x9f4a8
}

// case 0x4b — begin the exit fade-out. Reached from stateTreasureCheck when no
// sub-map is pending. Ghidra: 0x9c6ac (getAepTransitionMode != 2 ->
// setAepTransitionMode(2)) then 0x9c6ca (unconditional -> 0x4c).
void AcMainTask::stateExitBegin() {
    AepManager &aep = AepManager::shared();
    if (aep.transitionMode() != 2) {
        aep.setAepTransitionMode(2); // fade out, 30 frames
    }
    m_state = kAcMainStateExitWait;
}

// case 0x4c — hold until the fade-out finishes, then advance to the hand-off.
// Ghidra: 0x9c6d0 (isTransitionDone == 1 -> 0x4d, else draw and stay).
void AcMainTask::stateExitWait() {
    if (AepManager::shared().isTransitionDone()) {
        m_state = kAcMainStateExitToMenu;
    }
}

// case 0x4d — the exit-to-menu final. Once the cancel/back SE (slot 2) has
// stopped, hand off to a fresh MenuMainTask (activated by the task framework on
// dispose) and tear this task down. Ghidra: 0x9c6ea (isSePlaying(2) == 0 -> clear
// board flag, operator new(0x1b0) MenuMainTask, store m_nextTask +0x948,
// sugorokuTaskDispose).
void AcMainTask::stateExitToMenu() {
    if (neEngine::isSePlaying(2)) {
        return; // the cancel/back SE is still sounding
    }
    m_bgmActive = false;
    m_nextTask = new MenuMainTask();
    sugorokuTaskDispose();
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
