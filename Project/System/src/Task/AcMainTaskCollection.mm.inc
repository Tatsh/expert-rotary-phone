// The collection screens of AcMainTask's state machine: the music-piece and wallpaper-piece
// boards, their reveals, the camera-roll save, the collection menu, and the scene reload.
//
// This is a body fragment, not a translation unit. See AcMainTaskWalk.mm.inc for why these are
// included into AcMainTask.mm rather than compiled separately, and why the suffix is .mm.inc.

// Commit every piece the reveal just showed into its TreasureData record. In each three-slot
// table word bit b is "collected" and bit b + 8 is "already revealed", so only a collected piece
// whose revealed bit is still clear is written back. The board-encoded id is built as page * 10 +
// row and split again for the fetch, matching the m_subMapId convention. Both callers set the
// reload flag before the nil test, not after (0x9c056 and 0x9d446).
// Ghidra: 0x9bea0..0x9c186 (music) and 0x9d386..0x9d558 (wallpaper).
bool AcMainTask::commitRevealedPieces(const uint32_t *table, int page, bool wallpaper) {
    bool changed = false;
    for (int i = 0; i < 9; i++) {
        const int row = i / 3;
        const int col = i % 3;
        const uint32_t bits = table[page * 3 + row];
        if ((bits & (1u << col)) == 0 || (bits & (1u << (col + 8))) != 0) {
            continue;
        }
        NSManagedObjectContext *ctx = [AppDelegate appDelegate].managedObjectContext;
        [ctx reset];
        TreasureData *record = [TreasureData getTreasureData:static_cast<short>(page)
                                                    subMapId:static_cast<short>(row)
                                      inManagedObjectContext:ctx];
        changed = true;
        if (!record) {
            continue;
        }
        const int seen = 1 << (col + 8);
        if (wallpaper) {
            record.wallPaperPiece = @([record.wallPaperPiece intValue] | seen);
        } else {
            record.musicPiece = @([record.musicPiece intValue] | seen);
        }
        NSError *saveErr = nil;
        if (![ctx save:&saveErr]) {
            // The same walk sugorokuSaveTreasureProgress makes: the shipped build's enumeration
            // body is empty (0x9c116..0x9c14c and 0x9d4b4..0x9d53c).
            NSArray *detailedErrors = saveErr.userInfo[NSDetailedErrorsKey];
            if (detailedErrors.count != 0) {
                for (__unused NSError *detail in detailedErrors) {
                }
            }
        }
    }
    return changed;
}

// case 0x3b — the music-piece collection board is up and interactive: tap a panel to open its
// reveal, or tap the close button to leave. Ghidra: 0x9bcde.
void AcMainTask::stateMusicPieceView() {
    if (!m_frameTapped) {
        return; // 0x9bcde
    }
    const int tapX = m_frameTapTouch->x;
    const int tapY = m_frameTapTouch->y;
    const float scale = m_screenScale;
    // The hit box is a fixed square (0x9bcf0, pool 0x9be24 == 196.0f).
    const int panelSize = static_cast<int>(kPiecePanelHitSize * scale);

    for (int i = 0; i < 9; i++) { // 0x9bcf8..0x9bd48
        if (!neGraphics::pointInRect(tapX,
                                     tapY,
                                     static_cast<int>(m_musicAnchor[i].x * scale),
                                     static_cast<int>(m_musicAnchor[i].y * scale),
                                     panelSize,
                                     panelSize)) {
            continue;
        }
        neEngine::playSystemSe(1); // 0x9d0e6
        AepLyrCtrl *reveal = m_rouletteLayers[kRouletteLayerMusicPieceOpen].get();
        reveal->playSpeed() = 1.0f;                 // 0x9d0ee
        reveal->playOnce();                         // 0x9d0f6
        m_selMusicPanel = i;                        // 0x9d0fc
        m_pieceRevealFrame = 0;                     // 0x9d100
        m_state = kAcMainStateMusicPieceRevealWait; // 0x9d104
        return;
    }

    // The close button (0x9bd54): m_dlgLayoutB[4..7] are its x, y, w and h.
    if (!acTapInScaledRect(m_frameTapTouch,
                           scale,
                           m_dlgLayoutB[4],
                           m_dlgLayoutB[5],
                           m_dlgLayoutB[6],
                           m_dlgLayoutB[7])) {
        return; // 0x9bdcc
    }
    neEngine::playSystemSe(2);             // 0x9bde4
    if (m_padDisplay) {                    // 0x9bde8
        m_state = kAcMainStateBoardReveal; // 0x9bdf2
    } else {
        m_panelLayers[kPanelCollectionOpen]->pause(); // 0x9ed7c
        m_state = kAcMainStateCollectionMenu;         // 0x9ed80
    }
    AepLyrCtrl *board = m_panelLayers[kPanelMusicPieceBoard].get(); // 0x9ed86
    board->playSpeed() = -1.0f;                                     // 0x9eda4
    board->stop(1);                                                 // 0x9edb4
}

// case 0x3d — the music-piece reveal is on screen: advance the two frame counters, and on a tap
// persist every newly revealed piece before returning to the board. Ghidra: 0x9be28.
void AcMainTask::stateMusicPieceReveal() {
    if (m_pieceRevealFrame < m_musicPeaceFrames - 1) { // 0x9be28
        ++m_pieceRevealFrame;
    }
    if (m_musicResultFrame < m_skillBoard[2].frameCount - 1) { // 0x9be3c
        ++m_musicResultFrame;
    }
    if (!m_frameTapped) {
        return; // 0x9be50
    }

    neEngine::playSystemSe(2); // 0x9be62 / 0x9be76

    if (AepLyrCtrl *select = m_panelLayers[kPanelCollectionOpen].get()) { // 0x9be7a
        select->pause();                                                  // 0x9be86
    }

    AepLyrCtrl *reveal = m_rouletteLayers[kRouletteLayerMusicPieceOpen].get(); // 0x9be8a
    reveal->playSpeed() = -1.0f;                                               // 0x9be94
    reveal->stop(1);                                                           // 0x9be9c

    if (commitRevealedPieces(
            m_musicPieceTableDup, findTreasureMapIndexById(m_selMusicPanel), false)) {
        loadTreasureProgress(); // 0x9c180
    }
    m_state = kAcMainStateMusicPieceView; // 0x9c184
}

// case 0x40 — the wallpaper-piece collection board is up and interactive: tap a panel to open its
// reveal, loading that page's board artwork and recomputing the page-complete flag, or tap the
// close button to leave. Ghidra: 0x9c1e6.
void AcMainTask::stateWallBoardIdle() {
    if (!m_frameTapped) {
        return; // 0x9c1e6
    }
    const int tapX = m_frameTapTouch->x;
    const int tapY = m_frameTapTouch->y;
    const float scale = m_screenScale;
    const int panelSize = static_cast<int>(scale * kPiecePanelHitSize);

    for (int i = 0; i < 9; i++) { // 0x9c1ee..0x9c250
        if (!neGraphics::pointInRect(
                tapX,
                tapY,
                static_cast<int>(static_cast<float>(m_wallAnchor[i].x) * scale),
                static_cast<int>(static_cast<float>(m_wallAnchor[i].y) * scale),
                panelSize,
                panelSize)) {
            continue;
        }
        neEngine::playSystemSe(1); // 0x9d10a
        AepLyrCtrl *reveal = m_rouletteLayers[kRouletteLayerWallPieceOpen].get();
        reveal->playSpeed() = 1.0f;
        reveal->playOnce();
        m_rouletteMapId = i;
        m_pieceRevealFrame = 0;

        // The reveal draws this page's whole board behind the nine piece layers (the
        // kBoardWallReveal draw branch reads the same slot). Ghidra: 0x9d144..0x9d200.
        const int mapIdx = findTreasureMapIndexById(i);
        m_reserveTex[0] = std::make_unique<neTextureForiOS>();
        NSString *file = [NSString stringWithFormat:@"sugo_wall%02d_960.png", mapIdx];
#ifdef ENABLE_PATCHES
        NSString *path = [AppDelegate appAssetsPath:file];
#else
        NSString *path = [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:file];
#endif
        m_reserveTex[0]->load([path UTF8String]);

        // The page counts as complete only while all nine of its piece bits are set: the flag
        // goes up first and the first clear bit drops it and stops the scan.
        // Ghidra: 0x9d204..0x9d242 with the 0x9e008 tail.
        m_wallpaperComplete = true;
        for (int j = 0; j < 9; j++) {
            if ((m_wallPieceTableDup[mapIdx * 3 + j / 3] & (1u << (j % 3))) == 0) {
                m_wallpaperComplete = false;
                break;
            }
        }
        m_state = kAcMainStateWallPieceOpen; // 0x9e00e movs 0x42
        return;
    }

    // The close button: m_dlgLayoutB[8..11] as x, y, w and h. Ghidra: 0x9c25c..0x9c2d4.
    if (!acTapInScaledRect(m_frameTapTouch,
                           scale,
                           m_dlgLayoutB[8],
                           m_dlgLayoutB[9],
                           m_dlgLayoutB[10],
                           m_dlgLayoutB[11])) {
        return;
    }
    neEngine::playSystemSe(2); // 0x9c2da / 0x9c2ec
    if (m_padDisplay) {
        m_fadeDir = 0;                        // 0x9c2fc
        m_state = kAcMainStateWallBoardClose; // 0x9c300
    } else {
        m_panelLayers[kPanelCollectionOpen]->pause(); // 0x9ed8c
        m_state = kAcMainStateCollectionMenu;         // 0x9ed9a
    }
    AepLyrCtrl *board = m_panelLayers[kPanelWallPieceBoard].get(); // 0x9eda4
    board->playSpeed() = -1.0f;
    board->stop(1);
}

// case 0x42 — WALL_PEACE_OPEN plays the wallpaper open animation, fading the save button in on
// the layer's own progress; the full-size view takes over when the layer settles.
// Ghidra: 0x9c342.
void AcMainTask::stateWallPieceOpen() {
    AepLyrCtrl *lyr = m_rouletteLayers[kRouletteLayerWallPieceOpen].get();
    if (!lyr->isAnimating()) {
        m_rouletteSeInst[kRouletteSePiece] = -1; // 0x9c354 str -1 -> +0x498
        m_state = kAcMainStateWallPieceView;
    }
    if (!m_wallpaperComplete) {
        return;
    }
    // 0x9c37c truncates the play head before 0x9c38a multiplies by 100, so the division at
    // 0x9c392 sees int(curFrame) * 100, not int(curFrame * 100).
    const int progress = (static_cast<int>(lyr->curFrame()) * 100) / (lyr->frameCount() - 1);
    AepDrawSpriteHandle(m_aep,
                        m_boardFrame[kBoardFrameWallSave],
                        kWallSaveButtonX,
                        m_overlayH - kWallSaveButtonBottomOffset,
                        100,
                        100,
                        0,
                        0,
                        0,
                        progress,
                        100 - progress,
                        8,
                        0xffffff,
                        nullptr,
                        0xa,
                        1);
}

// case 0x43 — the full-size wallpaper view: step the two reveal counters, and on a tap either arm
// the camera-roll save (inside the save button, once the map's nine pieces are owned) or close
// back to the piece board, persisting any newly-revealed pieces. Ghidra: 0x9c3d6.
void AcMainTask::stateWallPieceView() {
    if (m_pieceRevealFrame < m_wallPeaceFrames - 1) {
        ++m_pieceRevealFrame;
    }
    if (m_wallResultFrame < m_skillBoard[3].frameCount - 1) { // WALL_PEACE_LOCK1
        ++m_wallResultFrame;
    }

    if (m_frameTapped) {
        const float scale = m_screenScale;
        const int buttonY = m_overlayH - kWallSaveButtonBottomOffset;
        if (acTapInScaledRect(m_frameTapTouch,
                              scale,
                              kWallSaveButtonX,
                              buttonY,
                              kWallSaveButtonW,
                              kWallSaveButtonH)) {
            // 0x9c46c: an incomplete map ignores the button, since it is not drawn.
            if (m_wallpaperComplete) {
                neEngine::playSystemSe(1);
                m_state = kAcMainStateWallSaveBegin;
            }
        } else {
            neEngine::playSystemSe(2); // 0x9d246
            // 0x9d262: a pad never builds panels 4 and 5, so this is a null guard.
            if (!m_padDisplay) {
                m_panelLayers[kPanelCollectionOpen]->pause();
            }
            AepLyrCtrl *open = m_rouletteLayers[kRouletteLayerWallPieceOpen].get();
            open->playSpeed() = -1.0f; // 0x9d276
            open->stop(1);             // 0x9d288

            if (commitRevealedPieces(
                    m_wallPieceTableDup, findTreasureMapIndexById(m_rouletteMapId), true)) {
                loadTreasureProgress(); // 0x9d560
            }
            m_state = kAcMainStateWallBoardIdle;
        }
    }

    // 0x9d57a: the BT_WALL_SAVE button, drawn only once the map is complete.
    if (m_wallpaperComplete) {
        drawAepFrame(m_aep,
                     m_boardFrame[kBoardFrameWallSave],
                     kWallSaveButtonX,
                     m_overlayH - kWallSaveButtonBottomOffset,
                     0x20,
                     10);
    }
}

// case 0x38 — the collection menu's tap routing: three hit rects sending the player to the
// music-piece board, the wallpaper board, or back out. Ghidra: 0x9bbec.
void AcMainTask::stateCollectionMenu() {
    if (!m_frameTapped) {
        return; // 0x9bbee / 0x9bbf0
    }
    const int tapX = m_frameTapTouch->x;
    const int tapY = m_frameTapTouch->y;
    const float scale = m_screenScale;
    const int layout = (m_overlayH == kTallPhoneOverlayHeight) ? 1 : 0; // 0x9bc08 cmp #0x470
    const int buttonX = static_cast<int>(kCollectionButtonX * scale);
    const int buttonW = static_cast<int>(kCollectionButtonW * scale);
    const int buttonH = static_cast<int>(kCollectionButtonH * scale);

    if (neGraphics::pointInRect(tapX,
                                tapY,
                                buttonX,
                                static_cast<int>(kCollectionMusicY[layout] * scale),
                                buttonW,
                                buttonH)) {
        neEngine::playSystemSe(1);            // 0x9bc82
        m_state = kAcMainStateMusicPieceOpen; // 0x9bc86 movs 0x39
        return;
    }

    if (neGraphics::pointInRect(tapX,
                                tapY,
                                buttonX,
                                static_cast<int>(kCollectionWallY[layout] * scale),
                                buttonW,
                                buttonH)) {
        neEngine::playSystemSe(1);           // 0x9d0c4
        m_state = kAcMainStateWallBoardOpen; // 0x9d0c8 movs 0x3e
        return;
    }

    if (neGraphics::pointInRect(tapX,
                                tapY,
                                0,
                                0,
                                static_cast<int>(kCollectionBackW * scale),
                                static_cast<int>(kCollectionBackH * scale))) {
        neEngine::playSystemSe(2);             // 0x9e000
        m_state = kAcMainStateCollectionClose; // 0x9e004 movs 0x47
    }
}

// case 0x3e — open the wallpaper-piece collection board: play the WALL_PEACE_S panel in and load
// page 0's nine nail textures. On a pad the transition dim is armed as well. Ghidra: 0x9c18a.
void AcMainTask::stateWallBoardOpen() {
    if (m_padDisplay) {
        m_fadeDir = 1; // 0x9c19a / 0x9c19c
    }
    AepLyrCtrl *panel = m_panelLayers[kPanelWallPieceBoard].get(); // 0x9c1a0
    panel->playSpeed() = 1.0f;                                     // 0x9c1a4
    panel->playOnce();                                             // 0x9c1a8
    sugorokuLoadWallTextures(0);                                   // 0x9c1b2
    m_state = kAcMainStateWallBoardOpenWait;                       // 0x9c1b6 movs 0x3f
}

// case 0x3c — hold until MUSIC_PEACE_OPEN has finished playing in, then free the reveal SE slot
// and show the piece list. Ghidra: 0x9bdf8.
void AcMainTask::stateMusicPieceRevealWait() {
    if (m_rouletteLayers[kRouletteLayerMusicPieceOpen]->isAnimating()) {
        return; // 0x9be02
    }
    m_rouletteSeInst[kRouletteSePiece] = -1; // 0x9be0c str -1 -> +0x498
    m_state = kAcMainStateMusicPieceReveal;
}

// case 0x3f — hold until the WALL_PEACE_S panel has slid in, then park the collection-select
// panel and hand over to the interactive board. Ghidra: 0x9c1bc.
void AcMainTask::stateWallBoardOpenWait() {
    if (m_panelLayers[kPanelWallPieceBoard]->isAnimating()) {
        return;
    }
    if (AepLyrCtrl *select = m_panelLayers[kPanelCollectionOpen].get()) {
        select->stopPlay();
    }
    m_state = kAcMainStateWallBoardIdle;
}

// case 0x41 — the pad-only close of the wall-piece board: wait for the panel to finish rewinding,
// then drop the nine wall-nail textures. Ghidra: 0x9c306.
void AcMainTask::stateWallBoardClose() {
    if (m_panelLayers[kPanelWallPieceBoard]->isAnimating()) {
        return;
    }
    for (auto &slot : m_wallNailTex) {
        slot.reset();
    }
    m_state = kAcMainStateBoardReveal;
}

// case 0x44 — build the wallpaper file name from the map's nail index and the device's wallpaper
// height, and hand it to the asynchronous camera-roll save. Ghidra: 0x9c498.
void AcMainTask::stateWallSaveBegin() {
    const short mapIndex = findTreasureMapIndexById(m_rouletteMapId);

    int height = kWallpaperHeightPad;
    if (!m_padDisplay) {
        height = ([[AppDelegate appDelegate] displayType] == DisplayTypePhoneRetinaTall) ?
                     kWallpaperHeightPhoneTall :
                     kWallpaperHeightPhone;
    }

    NSString *name =
        [NSString stringWithFormat:@"sugo_wall%02d_%d.png", static_cast<int>(mapIndex), height];
    MainViewController *root =
        static_cast<MainViewController *>(neSceneManager::rootViewController());
    [root SaveToCameraRoll:name];
    m_state = kAcMainStateWallSaveWait;
}

// case 0x45 — poll the asynchronous save. A failure raises the permission alert and returns to
// the wallpaper view; a success plays the confirmation once. Ghidra: 0x9c4b8.
void AcMainTask::stateWallSaveWait() {
    MainViewController *root =
        static_cast<MainViewController *>(neSceneManager::rootViewController());
    if (root.cameraRollSaving) {
        return;
    }

    if (root.cameraRollError) {
        CommonAlertView *alert = [[CommonAlertView alloc]
                initWithTitle:@"CameraRoll"
                      message:@"保存に失敗しました。\n写真へのアクセス許可を確認して下さい。"
                     delegate:nil
            cancelButtonTitle:nil
            otherButtonTitles:@"OK"];
        [alert show];
        m_state = kAcMainStateWallPieceView;
        return;
    }

    AepLyrCtrl *done = m_rouletteLayers[kRouletteLayerWallSaveCom].get();
    done->playSpeed() = 1.0f;
    done->playOnce();
    m_state = kAcMainStateWallSaveDone;
}

// case 0x46 — the "saved" confirmation panel. A tap once it has settled plays the decide SE, runs
// the layer backwards and returns to the wallpaper view. Ghidra: 0x9c58e.
void AcMainTask::stateWallSaveDone() {
    if (!m_frameTapped) {
        return;
    }
    AepLyrCtrl *done = m_rouletteLayers[kRouletteLayerWallSaveCom].get();
    if (done->isAnimating()) {
        return;
    }
    neEngine::playSystemSe(1);
    done->playSpeed() = -1.0f;
    done->stop(1);
    m_state = kAcMainStateWallPieceView;
}

// case 0x47 — leave the wallpaper collection screen: rewind the open panel, arm the out panel,
// make the board visible again and drop the nail textures. Ghidra: 0x9c5dc.
void AcMainTask::stateCollectionClose() {
    m_panelLayers[kPanelCollectionOpen]->stopPlay(); // 0x9c5e8
    m_panelLayers[kPanelCollectionOut]->stop(1);     // 0x9c5f8
    m_bgmActive = true;                              // 0x9c600
    for (auto &slot : m_wallNailTex) {               // 0x9c608, the nine-slot loop over +0x1c8
        slot.reset();
    }
    m_state = kAcMainStateCollectionCloseWait; // 0x9c622
}

// case 0x48 — hold until the out panel finishes, then hand back to the board. Ghidra: 0x9c628.
void AcMainTask::stateCollectionCloseWait() {
    if (!m_panelLayers[kPanelCollectionOut]->isAnimating()) {
        m_state = kAcMainStateBoardReveal;
    }
}

// case 0x49 — start the standard 30-frame fade-out that precedes a full scene rebuild.
// Ghidra: 0x9c640.
void AcMainTask::stateMapReloadBegin() {
    AepManager::shared().setAepTransitionMode(2);
    m_state = kAcMainStateMapReloadWait;
}

// case 0x4a — once the fade has finished and the decide SE has gone quiet, tear the sugoroku
// scene down, rebuild it and restart at the fade-in state. Ghidra: 0x9c656.
void AcMainTask::stateMapReloadWait() {
    if (!AepManager::shared().isTransitionDone()) {
        return;
    }
    if (neEngine::isSePlaying(1)) {
        return; // the decide SE is still sounding
    }
    sugorokuTaskDispose();
    setupScene();
    m_bgmActive = false;
    m_state = kAcMainStateFadeIn;
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
