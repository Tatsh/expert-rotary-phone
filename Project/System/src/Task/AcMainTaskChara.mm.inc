// The character-select screens of AcMainTask's state machine: the change panel, the select hub
// with its page flips, the lottery and its reveal, the confirmation, and the four close paths.
//
// This is a body fragment, not a translation unit. See AcMainTaskWalk.mm.inc for why these are
// included into AcMainTask.mm rather than compiled separately, and why the suffix is .mm.inc.

// Load sugo_chara%03d.png for a character into a texture slot. Every site builds the same name
// (0x9ba60..0x9bab4 and the case-0x2f copy).
void AcMainTask::loadCharaBoardTexture(std::unique_ptr<neTextureForiOS> &slot, int charaId) {
    slot = std::make_unique<neTextureForiOS>();
    NSString *file = [NSString stringWithFormat:@"sugo_chara%03d.png", charaId];
#ifdef ENABLE_PATCHES
    NSString *path = [AppDelegate appAssetsPath:file];
#else
    NSString *path = [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:file];
#endif
    slot->load([path UTF8String]);
}

// case 0x2f — the player picked a character: load its board portrait into the scratch slot and
// open the confirmation panel. Ghidra: 0x9b812.
void AcMainTask::stateCharaSelectApply() {
    m_reserveTex[2].reset();
    loadCharaBoardTexture(m_reserveTex[2], m_skillCharaId);
    m_rouletteLayers[kRouletteLayerCharaOpen]->playOnce();
    m_state = kAcMainStateCharaConfirm;
}

// case 0x30 — the character-change confirmation. A tap inside the confirm rect commits the pick;
// any other tap is a cancel. Ghidra: 0x9b8e4.
void AcMainTask::stateCharaConfirm() {
    if (!m_frameTapped) {
        return; // 0x9b8e4
    }
    if (m_rouletteLayers[kRouletteLayerCharaOpen]->isAnimating()) {
        return; // 0x9b8ec, still opening
    }

    // m_dlgLayoutB[12..15] are the confirm button's x, y, w and h. 0x9b900..0x9b972 reads
    // +0x9e8/+0x9ec/+0x9f0/+0x9f4 with vldr.32 then vcvt.f32.s32, so those slots hold ints.
    if (!acTapInScaledRect(m_frameTapTouch,
                           m_screenScale,
                           m_dlgLayoutB[12],
                           m_dlgLayoutB[13],
                           m_dlgLayoutB[14],
                           m_dlgLayoutB[15])) {
        neEngine::playSystemSe(2); // 0x9df6a / 0x9df7c
        m_state = kAcMainStateCharaConfirmCancel;
        return;
    }

    [[AudioManager sharedManager] playSe:nil resourceId:m_rouletteSe[kRouletteSeSkill]]; // 0x9b998
    [UserSettingData saveCharaId:m_skillCharaId];                                        // 0x9b9ba
    m_charaId = m_skillCharaId;                                                          // 0x9b9be

    // Re-resolve the active skill record for the new character. Ghidra: the gCharaManager guard
    // at 0x9b9c8, availableInfoForCharaId at 0x9b9dc and GetSkillDataStruct at 0x9b9f8.
    CharaInfo *info = gCharaManager.availableInfoForCharaId(m_skillCharaId);
    m_skillInfo = (__bridge void *)info;
    m_skillData = GetSkillDataStruct(static_cast<int>(info.skillId));

    m_charaTex.reset();                                // 0x9ba00
    loadCharaBoardTexture(m_charaTex, m_skillCharaId); // 0x9ba1a / 0x9ba60..0x9bab4
    m_state = kAcMainStateCharaChangeClose;            // 0x9bab8 movs 0x34
}

// case 0x2c — spend five tickets on the character lottery: arm the overlay, fire the play-log
// beacon, draw the awarded character, bank the spend and load the award portrait.
// Ghidra: 0x9b48e.
void AcMainTask::stateCharaGachaRoll() {
    if (countAvailableCharacters((__bridge NSArray *)m_gotCharaArray) != 0) {
        m_state = kAcMainStateCharaSelectIdle; // 0x9b49e bne 0x9bad8
        return;
    }

    AepLyrCtrl *gacha = m_rouletteLayers[kRouletteLayerGatsha].get();
    gacha->frameCount() = kGachaRollFrames; // 0x9b4aa str 0x98 -> +0x3c
    gacha->playOnce();

    // Fire-and-forget play-log beacon (0x9b4b2..0x9b5dc): a delegate-less connection the
    // original started and never read back.
    NSMutableURLRequest *request =
        [[NSMutableURLRequest alloc] initWithURL:[StoreUtil logCharaKujiURL]
                                     cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                 timeoutInterval:15.0];
    [request setValue:[AppDelegate appDelegate].userAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:[StoreUtil targetStore] forHTTPHeaderField:@"Accept-Language"];
    static_cast<void>([[NSURLConnection alloc] initWithRequest:request delegate:nil]);

    // Award pick (0x9b5e2..0x9b662), with the rarity-weighted fallback at 0x9cecc..0x9e0c2.
    NSArray *unlocked = gCharaManager.collectUnlockedCharaIds();
    __unsafe_unretained NSArray *infos = (__bridge NSArray *)m_availableInfos;
    __unsafe_unretained NSArray *owned = (__bridge NSArray *)m_gotCharaArray;
    if (unlocked && unlocked.count != 0) {
        const int pick = m_rng.getRandRangeInt(static_cast<int>(unlocked.count));
        m_wonCharaId = [unlocked[static_cast<NSUInteger>(pick)] shortValue];
    } else {
        int weightTotal = 0;
        for (CharaInfo *info in infos) {
            const auto bit = static_cast<unsigned>(static_cast<short>(info.charaId));
            if (!RhTestBitInNumberArray(owned, bit)) {
                weightTotal += info.rarity;
            }
        }
        int roll = m_rng.getRandRangeInt(weightTotal);
        for (CharaInfo *info in infos) {
            const auto bit = static_cast<unsigned>(static_cast<short>(info.charaId));
            if (RhTestBitInNumberArray(owned, bit)) {
                continue;
            }
            const int weight = info.rarity;
            if (roll < weight) { // 0x9e0a4 cmp / blt 0x9e452
                m_wonCharaId = static_cast<int16_t>(info.charaId);
                break;
            }
            roll -= weight;
        }
    }

    // Award tail (0x9e456): the tickets are spent but never taken below zero, the character is
    // banked and its board portrait loads for the reveal.
    m_charaTicket = static_cast<int16_t>(
        m_charaTicket - kCharaLotteryCost > 0 ? m_charaTicket - kCharaLotteryCost : 0);
    [UserSettingData saveCharaTicket:m_charaTicket];
    [UserSettingData saveGotCharaArray:m_wonCharaId];
    loadCharaBoardTexture(m_reserveTex[1], m_wonCharaId);
    static_cast<void>(
        [[AudioManager sharedManager] playSe:nil resourceId:m_rouletteSe[kRouletteSeGacha]]);
    m_revealTexLoaded = false;
    m_state = kAcMainStateCharaGachaReveal;
}

// case 0x2d — hold the gacha overlay. Once its play head passes the reveal frame the awarded
// character's grid portrait swaps in, but only while its page is the one on screen; the next tap
// extends the overlay into its closing run. Ghidra: 0x9b666.
void AcMainTask::stateCharaGachaReveal() {
    AepLyrCtrl *gacha = m_rouletteLayers[kRouletteLayerGatsha].get();
    if (!m_revealTexLoaded && static_cast<int>(gacha->curFrame()) >= kGachaRevealFrame) {
        const int index = charaSelectFindCharaIndex(m_wonCharaId);
        if (m_charaColRight == index / kCharaCellsPerPage) { // 0x9b6aa
            auto &slot = m_charaPagePrevTex[index % kCharaCellsPerPage];
            slot = std::make_unique<neTextureForiOS>();
            NSString *imageName =
                [NSString stringWithFormat:@"open_chara%03d.png", static_cast<int>(m_wonCharaId)];
            NSString *path;
            if (m_wonCharaId < kBundledCharaCount) { // 0x9b748
                path = [[NSBundle mainBundle] pathForResource:imageName ofType:nil];
            } else {
#ifdef ENABLE_PATCHES
                path = [AppDelegate appAssetsPath:imageName];
#else
                path =
                    [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:imageName];
#endif
            }
            slot->load([path UTF8String]);
        }
        m_revealTexLoaded = true; // 0x9e7fe, reached from both arms
    }

    // 0x9e80e isAnimating, 0x9e816 the tap flag, 0x9e824 the closing length, 0x9e830 stop(false),
    // which re-arms the layer as a once-play.
    if (!gacha->isAnimating() && m_frameTapped) {
        gacha->frameCount() = kGachaCloseFrames;
        gacha->stop(0);
        m_state = kAcMainStateCharaGachaClose;
    }
}

// The shared chara-select page-flip commit (0x9e2f8 for the next-page arrow, 0x9ebb2 for the
// previous one; both join the layer kick at 0x9ce60). The new page loads into the incoming
// texture slots and the change layer runs in the flip's direction; the handover to the drawn
// slots happens once that layer reports finished, back in stateCharaSelectIdle.
void AcMainTask::charaSelectFlipToPage(int page, float playSpeed) {
    m_charaColLeft = page;
    charaSelectLoadPageTextures(page);
    m_rouletteLayers[kRouletteLayerSelectArrow]->reset();
    m_panelLayers[kPanelCharaSelectOpen]->reset();
    AepLyrCtrl *change = m_panelLayers[kPanelCharaChange].get();
    change->playSpeed() = playSpeed;
    change->playOnce();
}

// case 0x2b — the character-select hub: settle a committed page flip, then route the frame's tap
// to the close button, the two page arrows, the lottery button or the 2x3 owned-character grid.
// Ghidra: 0x9b364, whose tap router the compiler scattered across the function.
void AcMainTask::stateCharaSelectIdle() {
    AepLyrCtrl *change = m_panelLayers[kPanelCharaChange].get();
    if (change->isAnimating()) { // 0x9b36e
        return;
    }
    if (m_rouletteLayers[kRouletteLayerCharaClose]->isAnimating()) { // 0x9b37e
        return;
    }

    // A page flip that reached its end commits: the target page becomes the current one and its
    // textures move into the drawn slots. Ghidra: 0x9b38e reads and clears the +0x5c latch.
    if (change->takeFinished()) {
        m_charaColRight = m_charaColLeft;
        for (int i = 0; i < kCharaCellsPerPage; i++) { // 0x9b3a6..0x9b3ca
            m_charaPagePrevTex[i] = std::move(m_charaPageCurrTex[i]);
        }
        change->reset();                               // 0x9b3d6
        m_panelLayers[kPanelCharaSelectOpen]->pause(); // 0x9b3e0
    }

    if (!m_frameTapped) {
        return; // 0x9b3e4
    }
    const neTouchPoint *touch = m_frameTapTouch;
    const float scale = m_screenScale;

    // Close button (0x9b3ec..0x9b48a).
    if (acTapInScaledRect(
            touch, scale, m_dlgLayoutB[0], m_dlgLayoutB[1], m_dlgLayoutB[2], m_dlgLayoutB[3])) {
        neEngine::playSystemSe(2); // 0x9b484
        m_state = kAcMainStateCharaSelectClose;
        return;
    }

    // Next-page arrow (0x9e24e), live only while another page follows.
    if (acTapInScaledRect(touch,
                          scale,
                          m_dlgLayoutA[4],
                          m_dlgLayoutA[5] + m_layoutOffsetY,
                          m_dlgLayoutA[6],
                          m_dlgLayoutA[7])) {
        if (m_charaColRight < m_charaRowCount - 1) { // 0x9e2cc..0x9e2d8
            neEngine::playSystemSe(4);               // 0x9e2f4
            charaSelectFlipToPage(m_charaColRight + 1, 1.0f);
        }
        return;
    }

    // Previous-page arrow (0x9eb0a).
    if (acTapInScaledRect(touch,
                          scale,
                          m_dlgLayoutA[8],
                          m_dlgLayoutA[9] + m_layoutOffsetY,
                          m_dlgLayoutA[10],
                          m_dlgLayoutA[11])) {
        if (m_charaColRight >= 1) { // 0x9eb8c..0x9eb92
            neEngine::playSystemSe(4);
            charaSelectFlipToPage(m_charaColRight - 1, -1.0f);
        }
        return;
    }

    // Character-lottery button (0x9f0c2). It wants five tickets and at least one character still
    // left to collect; countAvailableCharacters reports 1 once the collection is complete, and
    // 0x9f158 takes the accept path only on 0, so anything else just rejects the tap.
    if (acTapInScaledRect(touch,
                          scale,
                          m_dlgLayoutA[0],
                          m_dlgLayoutA[1] + m_layoutOffsetY,
                          m_dlgLayoutA[2],
                          m_dlgLayoutA[3])) {
        if (m_charaTicket >= kCharaLotteryCost &&
            countAvailableCharacters((__bridge NSArray *)m_gotCharaArray) == 0) {
            neEngine::playSystemSe(1); // 0x9f742
            m_state = kAcMainStateCharaGachaRoll;
        } else {
            neEngine::playSystemSe(2); // 0x9f170 -> 0x9eafe
        }
        return;
    }

    // The 2x3 grid of owned characters (0x9f5ec). The pick is cleared first, so a tap that lands
    // on no cell leaves the panel idle; the binary does it with one 32-bit store spanning +0x5fe
    // and +0x600 (0x9f61c).
    m_skillCharaId = -1;
    m_skillCharaSlot = -1;
    __unsafe_unretained NSArray *infos = (__bridge NSArray *)m_availableInfos;
    __unsafe_unretained NSArray *owned = (__bridge NSArray *)m_gotCharaArray;
    for (int slot = 0; slot < kCharaCellsPerPage; slot++) {
        const auto index = static_cast<unsigned>(m_charaColRight * kCharaCellsPerPage + slot);
        if (index >= static_cast<unsigned>([infos count])) { // 0x9f658
            continue;
        }
        CharaInfo *info = infos[index];
        const int charaId = info.charaId; // 0x9f67c, ahead of the nil guard
        if (!info) {                      // 0x9f682
            continue;
        }
        if (!RhTestBitInNumberArray(owned, static_cast<unsigned>(static_cast<short>(charaId)))) {
            continue; // 0x9f698: an unowned cell is dead
        }
        // 0x9f6a4 (top row, +0x60c / +0x610) and 0x9f6b2 (bottom row, +0x604 / +0x608 with the
        // three-cell bias removed).
        const bool topRow = slot < kCharaCellsPerRow;
        const int cellBaseX =
            topRow ? m_charaPanelX : m_skillPanelX - kCharaCellSize * kCharaCellsPerRow;
        const int cellX = cellBaseX + slot * kCharaCellSize;
        const int cellY = topRow ? m_charaPanelY : m_skillPanelY;
        if (acTapInScaledRect(touch, scale, cellX, cellY, kCharaCellSize, kCharaCellSize)) {
            neEngine::playSystemSe(1);                      // 0x9f93c
            m_skillCharaSlot = static_cast<int16_t>(slot);  // 0x9f944
            m_skillCharaId = static_cast<int16_t>(charaId); // 0x9f948
            break;
        }
    }
    if (m_skillCharaSlot != -1) { // 0x9f950
        m_state = kAcMainStateCharaSelectApply;
    }
}

// case 0x29 — open the character-change panel: seed both page indices from the active character's
// grid page, load that page's textures, hand them to the drawn slots and start the open sweep.
// Ghidra: 0x9b2c0.
void AcMainTask::stateCharaChangeOpen() {
    // 0x9b2ce charaSelectFindCharaIndex, then the 0x2aaaaaab smmul / add lsr #31 pair at
    // 0x9b2da..0x9b2de, a signed divide by six.
    const int page = charaSelectFindCharaIndex(m_charaId) / kCharaCellsPerPage;
    m_charaColRight = page; // 0x9b2e2
    m_charaColLeft = page;  // 0x9b2e6
    if (m_padDisplay) {     // 0x9b2ea
        m_fadeDir = 1;
    }
    charaSelectLoadPageTextures(page); // 0x9b2fe

    // The load fills the current-page slots, but the column draw only reads those while the two
    // column bases differ, and they were just made equal, so the freshly loaded page has to be
    // promoted into the previous-page slots. Ghidra: 0x9b302..0x9b32a.
    for (int i = 0; i < kCharaCellsPerPage; i++) {
        m_charaPagePrevTex[i] = std::move(m_charaPageCurrTex[i]);
    }

    m_panelLayers[kPanelCharaSelectOpen]->playOnce(); // 0x9b32c / 0x9b336
    m_state = kAcMainStateCharaChangeOpenWait;
}

// case 0x2a — hold until the open sweep settles, then hide the board behind the panel on a phone
// layout. Ghidra: 0x9b340.
void AcMainTask::stateCharaChangeOpenWait() {
    if (m_panelLayers[kPanelCharaSelectOpen]->isAnimating()) { // 0x9b34a
        return;
    }
    if (!m_padDisplay) { // 0x9b354
        m_bgmActive = false;
    }
    m_state = kAcMainStateCharaSelectIdle; // 0x9b362
}

// case 0x2e — the gacha overlay has closed: drop the award portrait and refresh the owned-
// character working copy so the grid redraws with the new character. Ghidra: 0x9b78a.
void AcMainTask::stateCharaGachaClose() {
    if (m_rouletteLayers[kRouletteLayerGatsha]->isAnimating()) { // 0x9b794
        return;
    }
    m_reserveTex[1].reset(); // 0x9b79e
    if (m_gotCharaArray) {   // 0x9b7b6
        static_cast<void>((__bridge_transfer id)m_gotCharaArray);
        m_gotCharaArray = nullptr;
    }
    m_gotCharaArray = (__bridge_retained void *)[[UserSettingData gotCharaArray] mutableCopy];
    m_state = kAcMainStateCharaSelectIdle; // 0x9b810
}

// case 0x31 — drop the character-confirm overlay and run its close animation, returning to the
// character list. Ghidra: 0x9babe.
void AcMainTask::stateCharaConfirmCancel() {
    m_rouletteLayers[kRouletteLayerCharaOpen]->reset();  // 0x9bac8
    m_rouletteLayers[kRouletteLayerCharaClose]->stop(1); // 0x9bad4
    m_state = kAcMainStateCharaSelectIdle;               // 0x9bad8
}

// case 0x32 — start the character-select screen's close: park the arrow and open overlays, run
// the out sweep, clear the dim and re-enable the board draw. Ghidra: 0x9bade.
void AcMainTask::stateCharaSelectClose() {
    m_rouletteLayers[kRouletteLayerSelectArrow]->reset(); // 0x9bae8
    m_panelLayers[kPanelCharaSelectOpen]->reset();        // 0x9baf2
    m_panelLayers[kPanelCharaSelectOut]->stop(1);         // 0x9bb00
    m_fadeDir = 0;                                        // 0x9bb06
    m_bgmActive = true;                                   // 0x9bb0c
    m_state = kAcMainStateCharaSelectCloseWait;
}

// case 0x33 — wait for the out sweep, free the page textures and return to the board.
// Ghidra: 0x9bb14.
void AcMainTask::stateCharaSelectCloseWait() {
    if (m_panelLayers[kPanelCharaSelectOut]->isAnimating()) {
        return; // 0x9bb1e
    }
    charaSelectReleaseTextures();      // 0x9bb2c
    m_state = kAcMainStateBoardReveal; // 0x9bb30
}

// case 0x34 — after a committed character change, park both open overlays and start the two close
// sweeps, re-enabling the board draw. Ghidra: 0x9bb34.
void AcMainTask::stateCharaChangeClose() {
    m_rouletteLayers[kRouletteLayerCharaOpen]->reset();  // 0x9bb3e
    m_panelLayers[kPanelCharaSelectOpen]->reset();       // 0x9bb48
    m_rouletteLayers[kRouletteLayerCharaClose]->stop(1); // 0x9bb56
    m_panelLayers[kPanelCharaSelectOut]->stop(1);        // 0x9bb62
    m_bgmActive = true;                                  // 0x9bb66
    m_state = kAcMainStateCharaChangeCloseWait;
}

// case 0x35 — wait for the close overlays, free the page textures, park the arrow and return to
// the board. Ghidra: 0x9bb70.
void AcMainTask::stateCharaChangeCloseWait() {
    if (m_panelLayers[kPanelMusicPieceBoard]->isAnimating()) {
        return; // 0x9bb7a
    }
    if (m_panelLayers[kPanelCharaSelectOut]->isAnimating()) {
        return; // 0x9bb8a
    }
    charaSelectReleaseTextures();                         // 0x9bb9c
    m_rouletteLayers[kRouletteLayerSelectArrow]->reset(); // 0x9bba6
    m_state = kAcMainStateBoardReveal;                    // 0x9bbaa
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
