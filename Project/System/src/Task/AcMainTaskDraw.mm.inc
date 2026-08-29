//
//  AcMainTaskDraw.mm.inc
//  pop'n rhythmin
//
//  Body fragment of AcMainTask.mm, spliced in where this code used to sit
//  rather than compiled on its own, so it keeps the file-scope constants, the
//  file-static helpers and the anonymous namespace of the one translation unit
//  the reconstruction models.
//

// ═══════════════════════════════════════════════════════════════════════════════
// Sugoroku board draw / logic helpers  (Ghidra 0xa14a0 – 0xa5740).
// All are file-static (anonymous namespace = internal linkage).  They were
// erroneously placed in a fabricated SugorokuMainTask class by a prior agent;
// they belong here, operating on AcMainTask *.
// ═══════════════════════════════════════════════════════════════════════════════

#include <cmath>  // cosf, sinf, M_PI, M_PI_2
#include <cstdio> // snprintf

#import "TreasureTmpData.h"

namespace {

// ── cross-file helpers (TODO: promote to their own .h/.mm when decompiled) ───

// Ghidra: isWithinRange2D @ 0x2d9dc — 2-D AABB overlap cull used by
// sugorokuDrawBoard. Tests whether node box [x0..extX] × [y0..y1] overlaps
// camera rect [camL..camR] × [camT..camH]. The binary's four bounds arrive in
// r0-r3 as distinct floats; the duplicated second argument is this
// reconstruction's own padding, so only x0, extX, y0 and y1 are read. Every
// comparison is inclusive (0x2d9e6 / 0x2d9f8 / 0x2da0a / 0x2da20), which decides
// the exactly-aligned camera edge that the tight connector band produces.
bool isWithinRange2D(float x0,
                     float /*x1*/,
                     float extX,
                     float y0,
                     float y1,
                     float camL,
                     float camT,
                     float camR,
                     float camH) {
    return x0 <= camR && extX >= camL && y0 <= camH && y1 >= camT;
}

// Ghidra: FUN_000a2... — maps a sugoroku square id to its wall-nail texture
// index via a fixed 9-entry lookup table (DAT_0012faa0 = {0,3,4,5,6,1,2,7,8});
// returns the matching index, or -1 when the id is not present. (Not identity —
// ids 1/2 and 3..6 are permuted, so the wall-nail sprite order differs from the
// raw id order.)
short findTreasureMapIndexById(int id) {
    static constexpr int kWallNailIdTable[9] = {0, 3, 4, 5, 6, 1, 2, 7, 8};
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
// (reset(): it frees m_nodes/m_edges), which `delete m_map` in
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
// touch handling deviates from the disassembly. Ghidra
// FUN_000a14a0 takes the touch point as its second parameter (r1, stored @
// sp+0x44) and performs a single tap-distance test on raw coordinates (0xa1674:
// x@+0xc, startX@+0x4; `subs; abs; cmp #0xa; bgt` reject when > 10 px), not the
// internal `activeTouchCount()`/`touchAt(i)` loop below. The DrawText labels,
// button geometry (iVar7-0xbb/iVar10-0xbc and iVar7+0x3f) and the 0/1/-1
// returns were all verified faithful; the touch coords are plain pixels
// (0xa16c0 feeds x@+0xc / y@+0x10 straight to pointInRect, no shift).
int AcMainTask::sugorokuDrawSkillPanel() {
    AepManager *mgr = m_aep;
    const neGraphics &gfx = neGraphics::shared();
    float scale = gfx.contentScale();

    // Player board → screen position.
    float scrollOffX = m_scrollX - m_scrollBaseX;
    float scrollOffY = m_scrollY - m_scrollBaseY;
    int halfW = m_overlayW / 2;
    int halfH = m_overlayH / 2;
    int iVar7 = static_cast<int>(m_playerX - scrollOffX + static_cast<float>(halfW));
    int iVar10 = static_cast<int>(m_playerY - scrollOffY + static_cast<float>(halfH));

    // Draw the skill panel as a layer tree, not a flat sprite: 0xa15a6 calls
    // AepManager::drawLayer (0xfd64), not the 6-argument drawAepFrame (0xfc58).
    mgr->drawLayer(m_skillBoard[0].lyr,
                   0,
                   iVar7 + 52,
                   iVar10 - 300,
                   100,
                   100,
                   0,
                   254, // anchorX  (0xa1554 movs r3,#0xfe)
                   0,
                   100,
                   0,
                   1, // loopFlags (0xa156c)
                   0x20,
                   0x00ffffff, // colorRGB (0xa1542)
                   nullptr,
                   nullptr,
                   0x14, // priority (0xa153e)
                   1);

    // Skill name label (from the active character's skill record).
    __unsafe_unretained id skillObj = (__bridge id)m_skillInfo;
    if (skillObj) {
        NSString *nameStr = [skillObj skillName];
        if (nameStr) {
            mgr->DrawText(
                [nameStr UTF8String], 0x1e, iVar7 + 52, iVar10 - 0x11a, 1, 100, 0x59514f, 0x13);
        }
    }

    // Skill description string + weight (shown as "N pt"), read from the active
    // SkillDataStruct by name (m_skillData is already a typed pointer).
    if (m_skillData) {
        __unsafe_unretained NSString *skillText = m_skillData->description;
        if (skillText) {
            mgr->DrawText(
                [skillText UTF8String], 0x14, iVar7 + 52, iVar10 - 0xed, 1, 100, 0x59514f, 0x13);
        }

        // The format string is the 39-byte constant at 0x10a7f4 and the binary's
        // destination is the 64-byte frame slot at sp+0x4c (0xa1634).
        const int pts = m_skillData->weight;
        char ptsBuf[64];
        snprintf(ptsBuf, sizeof(ptsBuf), u8"トレジャーポイント %d pt消費", pts);
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
        int tx = tp->x; // plain device pixels (0xa16c0 uses x/y unshifted)
        int ty = tp->y;
        // Tap test: finger displacement < 11 px on the raw coordinates.
        int adx = tp->x - tp->startX;
        if (adx < 0) {
            adx = -adx;
        }
        int ady = tp->y - tp->startY;
        if (ady < 0) {
            ady = -ady;
        }
        // The binary's raw pixel slop (0xb); moved too far means not a tap.
        if (adx >= 11 || ady >= 11) {
            continue;
        }
        // Button 1 (left).
        if (neGraphics::pointInRect(tx,
                                    ty,
                                    static_cast<int>((iVar7 - 0xbb) * scale),
                                    static_cast<int>((iVar10 - 0xbc) * scale),
                                    static_cast<int>(hw),
                                    static_cast<int>(hh))) {
            return 0;
        }
        // Button 2 (right).
        if (neGraphics::pointInRect(tx,
                                    ty,
                                    static_cast<int>((iVar7 + 0x3f) * scale),
                                    static_cast<int>((iVar10 - 0xbc) * scale),
                                    static_cast<int>(hw),
                                    static_cast<int>(hh))) {
            return 1;
        }
    }
    return -1;
}

// ════════════════════════════════════════════════════════════════════════════
// 2.  sugorokuDrawButtonHitTest — Ghidra: FUN_000a178c
// ════════════════════════════════════════════════════════════════════════════
// Draw a generic two-button dialog panel (layerId @ +0x220, layout data @
// +0x990..+0x9b4) and return: 1 = button 1 hit, 0 = button 2 hit, -1 = miss or
// no valid touch.
//
// touch handling deviates from the disassembly, as with
// sugorokuDrawSkillPanel. Ghidra FUN_000a178c takes the touch point as its
// second parameter (r1, tested @ 0xa1810 on raw coords: `subs; abs; cmp #0xa;
// bgt` reject when > 10 px, returning -1) rather than looping over
// `activeTouchCount()`/`touchAt(i)`. Both button hit-rects (m_dlgBtn1*/
// m_dlgBtn2* @ +0x998..+0x9b4) were verified faithful; the touch coords are
// plain pixels (0xa1830 uses x@+0xc / y@+0x10 unshifted).
int AcMainTask::sugorokuDrawButtonHitTest() {
    AepManager *mgr = m_aep;
    const neGraphics &gfx = neGraphics::shared();
    float scale = gfx.contentScale();

    int panelW = m_dlgPanelW;
    int panelH = m_dlgPanelH;
    int iVar5 = m_overlayW / 2;              // half-screen width
    int iVar6 = m_overlayH / 2 - panelH / 2; // panel top Y

    // Draw panel: AEP layer handle @ +0x220, anchored on panelW/2.
    mgr->drawLayer(m_skillBoard[1].lyr,
                   0,     // frame     (0xa1804 movs r2,#0x0)
                   iVar5, // x         (0xa1806 mov r3,r5)
                   iVar6, // y         (0xa17f8 [sp,#0x00])
                   100,
                   100,
                   0,
                   panelW / 2, // anchorX   (0xa17fc [sp,#0x10])
                   0,
                   100,
                   0,
                   1, // loopFlags (0xa17c6 [sp,#0x20])
                   0x20,
                   0x00ffffff, // colorRGB  (0xa17da [sp,#0x28])
                   nullptr,
                   nullptr,
                   0x14, // priority  (0xa17e4 [sp,#0x34])
                   1);

    // Touch hit-test.
    int n = gfx.activeTouchCount();
    for (int i = 0; i < n; i++) {
        const neTouchPoint *tp = gfx.touchAt(i);
        if (!tp || !tp->released) {
            continue;
        }
        int tx = tp->x; // plain device pixels (0xa1830 uses x/y unshifted)
        int ty = tp->y;
        // Button 1.
        if (neGraphics::pointInRect(tx,
                                    ty,
                                    static_cast<int>((iVar5 - panelW / 2 + m_dlgBtn1X) * scale),
                                    static_cast<int>((m_dlgBtn1Y + iVar6) * scale),
                                    static_cast<int>(m_dlgBtn1W * scale),
                                    static_cast<int>(m_dlgBtn1H * scale))) {
            return 1;
        }
        // Button 2.
        if (neGraphics::pointInRect(tx,
                                    ty,
                                    static_cast<int>((iVar5 - panelW / 2 + m_dlgBtn2X) * scale),
                                    static_cast<int>((m_dlgBtn2Y + iVar6) * scale),
                                    static_cast<int>(m_dlgBtn2W * scale),
                                    static_cast<int>(m_dlgBtn2H * scale))) {
            return 0; // 0xa1946-0xa1948 sign-extend bit 0 of the inverted flag to 0
        }
    }
    return -1; // 0xa18ba mov.w r0,#0xffffffff
}

// ════════════════════════════════════════════════════════════════════════════
// 3.  sugorokuEasePositionPairA — Ghidra: FUN_000a19dc
// ════════════════════════════════════════════════════════════════════════════
// Ease the scroll position (+0x4d8/+0x4dc) toward the target (+0x5a4/+0x5a8)
// using stored velocities (+0x5ac/+0x5b0).  Returns true while still moving.
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
// has the node's slotId bit set. Ghidra address form: task + (charId/10)*-0x1c
// + charId*4 + gridBase, i.e. grid[(charId/10)*3 + charId%10] tested against (1
// << slotId).
static bool sugorokuPieceUnlocked(const uint32_t *grid, int charId, int bitIndex) {
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
// The text x at +0x88c is a FLOAT (writer @ 0x9a528 does
// vcvt.f32.s32 + vstr.32; this reader does vldr.32 then vcvt.s32.f32 to truncate
// @ 0xa1be2), so m_squareFrameIdx is a float truncated to int here. All nine
// node-type branches, the tbb table (wallpaper/music-piece squares map to the
// wall/music tables @
// +0x748/+0x6dc), the story-ready gate (readCount @ +0x8c0 / readNo @ +0x8bc),
// and the text draw (m_squareTextY - 31.0f, constants 0x1b / 0x2e / 0x615245 /
// 0x18 / 100) were verified faithful. The getTreasureMapValue_fb54(0, ...) call
// is fine: the binary passes m_map (@ +0x4b0) but FUN_000cea50 ignores it.
bool AcMainTask::sugorokuDrawSquareText() {
    if (m_squareAnimActive) {
        return false; // hide the square label while the select animation runs (+0x5f3)
    }
    const TreasureMap::Node *node = m_curNode;
    if (!node) {
        return false;
    }

    // +0x88c is a float slot; the binary truncates it to int (vcvt.s32.f32 @
    // 0xa1be2) for the text x.
    int iVar8 = static_cast<int>(m_squareFrameIdx); // task+0x88c
    enum { kNone, kCharAsset, kNodeText } pick = kNone;

    // A character message shows only once the board-story page counter
    // (readCount) has advanced past the last-read page (readNo).
    const bool storyReady = (m_readCount > 0) && (m_readCount > m_readNo);

    switch (node->type) {
    case TreasureMap::kSquareDeactivatedBonus: // board-story message (deactivated bonus)
        pick = (m_readCount >= 1) ? (storyReady ? kCharAsset : kNone) : kNodeText;
        break;
    case TreasureMap::kSquareBonus: // message live when roulette == 0x12 or HUD state 2
        pick = (m_rouletteMode == 0x12 || m_hudState == 2) ? (storyReady ? kCharAsset : kNone) :
                                                             kNodeText;
        break;
    case TreasureMap::kSquareTreasure: // message live when roulette == 0x12 or HUD state 3
        pick = (m_rouletteMode == 0x12 || m_hudState == 3) ? (storyReady ? kCharAsset : kNone) :
                                                             kNodeText;
        break;
    case TreasureMap::kSquareSubMapFlag: { // message when the flag value matches the current
                                           // state
        int v = getTreasureMapValue_fb54(0, node->slotId);
        int st = m_hudState;
        bool matched = (st == 6 && v == 0) || (st == 7 && v == 1) || (st == 8 && v == 2) ||
                       (st == 9 && v == 3) || (st == 5);
        pick = matched ? (storyReady ? kCharAsset : kNone) : kNodeText;
        break;
    }
    case TreasureMap::kSquareWallpaperPiece: // grid @ 0x748: label shown only while
        // locked
        pick =
            sugorokuPieceUnlocked(m_wallPieceTable, m_subMapId, node->slotId) ? kNone : kNodeText;
        break;
    case TreasureMap::kSquareMusicPiece: // grid @ 0x6dc: label shown only while locked
        pick =
            sugorokuPieceUnlocked(m_musicPieceTable, m_subMapId, node->slotId) ? kNone : kNodeText;
        break;
    case TreasureMap::kSquareGoalLock: // character-message live once the goal is cleared
        // (HUD state 4)
        pick = (m_hudState == 4) ? (storyReady ? kCharAsset : kNone) : kNodeText;
        break;
    case TreasureMap::kSquareBonusTreasure: { // friend-meet: node label while the meet is
                                              // pending and not yet consumed
        TreasureTmpData tmp = [UserSettingData treasureTmp];
        bool consumed = tmp.friendMeetFlag != 0;
        pick = (m_goalCharaTex && !consumed) ? kNodeText : kNone;
        break;
    }
    default: // start / player-start / warp / ...: the node's own label if present
        pick = kNodeText;
        break;
    }

    const char *text = nullptr;
    unsigned style = 1; // uVar7: 1 for node text, 0 for character asset
    if (pick == kCharAsset) {
        // Ghidra: 0xa1d0a ldr.w r1,[r5,#0x8bc] — the page index is the read
        // progress counter, not the text x that r8 carries.
        text = getCharacterAssetName(static_cast<int>(m_subMapId), m_readNo);
        if (!text) {
            return false; // content asset absent in this build
        }
        iVar8 -= 0xe6;
        style = 0;
    } else if (pick == kNodeText) {
        if (node->text[0] == '\0') {
            return false; // empty label -> nothing to draw
        }
        text = node->text;
        style = 1;
    } else {
        return false;
    }

    drawAepTextMultiline(text,
                         iVar8,
                         static_cast<int>(m_squareTextY - kSquareMessageTextRise),
                         style,
                         0x1b,
                         0x2e,
                         0x615245,
                         0x18,
                         100);
    return true;
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
void AcMainTask::sugorokuSaveTreasureProgress() {
    TreasureTmpData tmp = [UserSettingData treasureTmp];
    short subId = static_cast<short>(tmp.subMapId);
    if (subId < 0) {
        return;
    }

    NSManagedObjectContext *ctx = [AppDelegate appDelegate].managedObjectContext;
    [ctx reset];

    TreasureData *td =
        [TreasureData getTreasureData:subId / 10 subMapId:subId % 10 inManagedObjectContext:ctx];
    if (!td) {
        return;
    }

    td.musicPiece = @([td.musicPiece intValue] | static_cast<int>(tmp.musicPieceMask));
    td.wallPaperPiece = @([td.wallPaperPiece intValue] | static_cast<int>(tmp.wallPieceMask));

    // Goal type: task[0x8b1] == 2 → sound ticket; 1 → chara ticket.
    uint8_t goalType = m_goalType;
    if (goalType == 2) {
        td.goalTouchSound = @([td.goalTouchSound intValue] + 1);
    } else if (goalType == 1) {
        td.goalCharaTicket = @([td.goalCharaTicket intValue] + 1);
    }

    td.clearCnt = @([td.clearCnt intValue] + 1);

    // Keep the best (minimum) fast-record score (the misaligned int at +0x4c;
    // binary @ 0xa2044 ldr [sp,#0xc0]).
    const int32_t newFast = tmp.fastRecord;
    int existFast = [td.fastRecord intValue];
    td.fastRecord = @(existFast < newFast ? existFast : static_cast<int>(newFast));

    // Friend-meet flag (+0x50).
    if (tmp.friendMeetFlag) {
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
void AcMainTask::sugorokuLoadWallTextures(int page) {
    // Delete existing wall textures.
    for (auto &slot : m_wallNailTex) {
        slot.reset();
    }
    int base = page * 9;
    for (int i = 0; i < 9; i++) {
        short idx = findTreasureMapIndexById(base + i);
        m_wallNailTex[i] = std::make_unique<neTextureForiOS>();
        NSString *name = [NSString stringWithFormat:@"sugo_wall_nail%02d", static_cast<int>(idx)];
        NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"png"];
        if (path) {
            m_wallNailTex[i]->load([path UTF8String]);
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
void AcMainTask::sugorokuTaskDispose() {
    AudioManager *audioMgr = [AudioManager sharedManager];

    // 1. Delete the scene sprite textures (offsets 0xd4..0xf8): the named
    //    circle/board-bg/chara/goal/blind textures plus the five reserve slots.
    auto dropTex = [](std::unique_ptr<neTextureForiOS> &s) { s.reset(); };
    dropTex(m_circleTex);
    dropTex(m_boardBgTex);
    dropTex(m_charaTex);
    dropTex(m_goalCharaTex);
    dropTex(m_blindCircleTex);
    for (auto &s : m_reserveTex) {
        dropTex(s);
    }

    // 2. Delete the three 10-glyph digit texture sets (points / roulette /
    // ticket).
    for (auto &s : m_pointsDigitTex) {
        dropTex(s);
    }
    for (auto &s : m_roulDigitTex) {
        dropTex(s);
    }
    for (auto &s : m_ticketDigitTex) {
        dropTex(s);
    }

    // 3. Delete the music-jacket (9), wall-nail (9) and event (12) textures
    //    (Ghidra slot range 0x69..0x86 == byte offsets 0x1a4..0x218).
    for (auto &s : m_jacketTex) {
        dropTex(s);
    }
    for (auto &s : m_wallNailTex) {
        dropTex(s);
    }
    for (auto &s : m_eventTex) {
        dropTex(s);
    }

    // 4. Release character-select textures.
    charaSelectReleaseTextures();

    // 5. Unlink + delete AEP layer slots (Ghidra loop order preserved:
    //    roulette, then arrows, then panels).
    auto dropLayer = [](std::unique_ptr<AepLyrCtrl> &lyr) {
        if (lyr) {
            lyr->unlink();
            lyr.reset();
        }
    };
    for (auto &lyr : m_rouletteLayers) {
        dropLayer(lyr); // offsets 0x2c..0x9c
    }
    for (auto &lyr : m_arrowLayers) {
        dropLayer(lyr); // offsets 0xc0..0xcc
    }
    for (auto &lyr : m_panelLayers) {
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
    m_map.reset();

    // 9. Release the Objective-C objects the blob owns (+0x944, +0x630, +0x640),
    //    each a +1 reference the binary drops here before nulling the slot
    //    (0xa2f10, 0xa2f32, 0xa2f54).
    if (m_mapName) {
        static_cast<void>((__bridge_transfer id)m_mapName);
        m_mapName = nullptr;
    }
    if (m_gotCharaArray) {
        static_cast<void>((__bridge_transfer id)m_gotCharaArray);
        m_gotCharaArray = nullptr;
    }
    if (m_treasureMusicArray) {
        static_cast<void>((__bridge_transfer id)m_treasureMusicArray);
        m_treasureMusicArray = nullptr;
    }

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
    if (ne::C_TASK *next = static_cast<ne::C_TASK *>(m_nextTask)) {
        kill();
        next->setPriority(3);
    }
}

// ════════════════════════════════════════════════════════════════════════════
// 10.  sugorokuDrawBoard — Ghidra: FUN_000a303c
// ════════════════════════════════════════════════════════════════════════════
// Cull and draw all board squares, edges, the player sprite and the HUD for
// the current frame.
void AcMainTask::sugorokuDrawBoard() {
    AepManager *mgr = m_aep;

    float scrollOffX = m_scrollX - m_scrollBaseX;
    float scrollOffY = m_scrollY - m_scrollBaseY;
    int screenW = m_overlayW; // full screen width
    int screenH = m_overlayH;
    int halfW = screenW / 2;
    int halfH = screenH / 2;

    // Camera AABB (in board-pixel space).
    float camL = scrollOffX - static_cast<float>(halfW);
    float camR = scrollOffX + static_cast<float>(halfW);
    float camT = scrollOffY - static_cast<float>(halfH);
    float camH = scrollOffY + static_cast<float>(halfH);

    // Draw squares.
    const TreasureMap::Node *nodes = m_nodes;
    int nodeCount = m_nodeCount;
    for (int i = 0; i < nodeCount; i++) {
        const TreasureMap::Node *n = nodes + i; // stride 0x120
        float nx = static_cast<float>(n->x * 26);
        float ny = static_cast<float>(n->y * 26);
        if (isWithinRange2D(nx, nx, nx + 104.0f, ny, ny + 128.0f, camL, camT, camR, camH)) {
            sugorokuDrawSquare(n);
        }
    }

    // Draw edges.
    const TreasureMap::ConnectStruct *edges = m_edges;
    int edgeCount = static_cast<int>(m_edgeCount);
    for (int i = 0; i < edgeCount; i++) {
        const TreasureMap::ConnectStruct *e = edges + i;
        float ax = static_cast<float>(e->a->x * 26), ay = static_cast<float>(e->a->y * 26);
        float bx = static_cast<float>(e->b->x * 26), by = static_cast<float>(e->b->y * 26);
        float minX = ax < bx ? ax : bx, maxX = ax > bx ? ax : bx;
        float minY = ay < by ? ay : by, maxY = ay > by ? ay : by;
        // The cull rect is the connector band, whose orientation the binary
        // branches on at 0xa3178 / 0xa3180. A horizontal band takes its top and
        // bottom from a->y and a vertical one its left and right from a->x, so
        // neither may be widened to the union of both squares.
        float x0, x1, y0, y1;
        if (e->sameRow) {
            x0 = minX + 104.0f; // 0xa31ae
            x1 = maxX;          // 0xa31a6
            y0 = ay + 52.0f;    // 0xa31b2
            y1 = ay + 76.0f;    // 0xa31aa
        } else {
            x0 = ax + 40.0f;    // 0xa31dc
            x1 = ax + 64.0f;    // 0xa31d8
            y0 = minY + 128.0f; // 0xa31e4
            y1 = maxY;          // 0xa31e0
        }
        if (isWithinRange2D(x0, x0, x1, y0, y1, camL, camT, camR, camH)) {
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
        if (static_cast<uint32_t>(m_hudState) < 2) {
            frame = m_scrolledPastEnd ? m_boardFrame[kBoardFrameRouletteEvent] :
                                        m_boardFrame[kBoardFrameRouletteEventNo];
        } else {
            frame = m_scrolledPastEnd ? m_boardFrame[kBoardFrameRoulette] :
                                        m_boardFrame[kBoardFrameRouletteNo];
        }
        drawAepFrame(mgr, frame, m_selSceneLayout[0], m_selSceneLayout[1] + screenH, 0x20, 0x1a);
    }

    // Notice layer: drawn at m_selSceneLayout[9], [13] + overlayH, size 0x20 x
    // 0x1b.
    if (m_boardSquareState[6]) {
        drawAepFrame(mgr,
                     m_boardFrame[kBoardFrameSquare0100],
                     m_selSceneLayout[9],
                     m_selSceneLayout[13] + screenH,
                     0x20,
                     0x1b);
    }
}

// ════════════════════════════════════════════════════════════════════════════
// 11.  sugorokuDrawBackground — Ghidra: FUN_000a3308
// ════════════════════════════════════════════════════════════════════════════
// Draw the scrolling background tile for the current scroll position, apply
// the transition fade overlay, and drive the background animation layer.
void AcMainTask::sugorokuDrawBackground() {
    AepManager *mgr = m_aep;
    neTextureForiOS *bgTex = m_boardBgTex.get();
    if (!bgTex) {
        return;
    }

    int scrollX = static_cast<int>(m_scrollX - m_scrollBaseX);
    int screenW = m_overlayW;
    bool fadeFl = m_padDisplay;
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
        neTextureForiOS_draw(mgr,
                             bgTex,
                             0,
                             0,
                             bgW,
                             bgH,
                             x,
                             0,
                             sx,
                             sy,
                             0,        // rotation
                             0,        // ex
                             0,        // ey
                             100,      // color
                             0,        // alpha
                             0x20,     // blend0
                             0xffffff, // colorMul
                             nullptr,  // clip
                             0x25,     // priority (0xa33aa)
                             1);       // layer   (0xa33ae str r4,[sp,#0x3c])
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
        mgr->drawTransitionOverlay(alpha);
    }

    // Background animation layer (+0x9c): play/reset driven by board state.
    AepLyrCtrl *bgLyr = m_rouletteLayers[28].get();
    if (bgLyr) {
        int bgState = m_boardMoveState;
        if (static_cast<uint32_t>(bgState - 1) <
            2) { // unsigned: idle state 0 falls to the reset branch
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
void AcMainTask::sugorokuDrawSquare(const TreasureMap::Node *node) {
    AepManager *mgr = m_aep;
    int scrollOffX = static_cast<int>(m_scrollX - m_scrollBaseX);
    int scrollOffY = static_cast<int>(m_scrollY - m_scrollBaseY);
    int screenW = m_overlayW;
    int screenH = m_overlayH;
    int type = node->type;

    // "Active move" override: while a move is in progress (flag byte @ task+0x8a2
    // > 0), every walkable square (not player-start, not warp) shows the
    // move-hint frame.
    if (m_boardSquareState[14] > 0 && type != TreasureMap::kSquarePlayerStart &&
        type != TreasureMap::kSquareWarp) {
        drawAepFrame(mgr,
                     m_base1Frame[2],
                     node->x * 26 - scrollOffX + screenW / 2,
                     node->y * 26 - 32 - scrollOffY + screenH / 2,
                     0x20,
                     0x22);
        return;
    }

    int frameHandle =
        m_base1Frame[2]; // default (kSquareDeactivatedBonus and any unmet condition -> 0x340)
    switch (type) {
    case TreasureMap::kSquareStart:
        frameHandle = m_base1Frame[0];
        break;
    case TreasureMap::kSquarePlayerStart:
        frameHandle = m_base1Frame[1];
        break;
    case TreasureMap::kSquareBonus: // locked frame unless the bonus is live (roulette 0x12 or
                                    // HUD state 2)
        if (m_rouletteMode != 0x12 && m_hudState != 2) {
            frameHandle = m_base1Frame[3];
        }
        break;
    case TreasureMap::kSquareTreasure: // locked frame unless the treasure is live (roulette
        // 0x12 or state 3)
        if (m_rouletteMode != 0x12 && m_hudState != 3) {
            frameHandle = m_base1Frame[4];
        }
        break;
    case TreasureMap::kSquareSubMapFlag: { // flag sprite unless the flag value matches the
                                           // current state
        int v = getTreasureMapValue_fb54(0, node->slotId);
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
    case TreasureMap::kSquareWallpaperPiece: // grid @ 0x748: filled vs empty frame by
        // unlock bit
        frameHandle = sugorokuPieceUnlocked(m_wallPieceTable, m_subMapId, node->slotId) ?
                          m_base1Frame[6] :
                          m_base1Frame[5];
        break;
    case TreasureMap::kSquareMusicPiece: // grid @ 0x6dc: filled vs empty frame by unlock
        // bit
        frameHandle = sugorokuPieceUnlocked(m_musicPieceTable, m_subMapId, node->slotId) ?
                          m_base1Frame[8] :
                          m_base1Frame[7];
        break;
    case TreasureMap::kSquareWarp: // warp-index sprite, but only until the warp animation
        // settles (<2)
        if (m_boardSquareState[10] < 2) {
            int warpIdx = node->slotId;
            if (warpIdx < 0) {
                warpIdx = 0;
            }
            if (warpIdx > 9) {
                warpIdx = 9;
            }
            frameHandle = m_base08Frame[warpIdx];
        }
        break;
    case TreasureMap::kSquareGoalLock: // locked frame unless already cleared (HUD state 4)
        if (m_hudState != 4) {
            frameHandle = m_base1Frame[9];
        }
        break;
    case TreasureMap::kSquareBonusTreasure: // friend-meet: draw the overlay, then the base frame
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
void AcMainTask::sugorokuDrawPath(const TreasureMap::ConnectStruct *edge) {
    AepManager *mgr = m_aep;
    int scrollOffX = static_cast<int>(m_scrollX - m_scrollBaseX);
    int scrollOffY = static_cast<int>(m_scrollY - m_scrollBaseY);
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
void AcMainTask::sugorokuDrawPlayerAndUi() {
    AepManager *mgr = m_aep;

    float scrollOffX = m_scrollX - m_scrollBaseX;
    float scrollOffY = m_scrollY - m_scrollBaseY;
    int halfW = m_overlayW / 2;
    int halfH = m_overlayH / 2;
    int screenX = static_cast<int>(m_playerX - scrollOffX + static_cast<float>(halfW));
    int screenY = static_cast<int>(m_playerY - scrollOffY + static_cast<float>(halfH));
    int iVar6 = screenX + 0x34; // player draw X (offset from board node centre)

    // Warp / board-entry horizontal scale (squish animation).
    int warpSX = 30;
    if (m_warpAnim) {
        // Bounce using the active roulette layer's frame counter. Ghidra
        // sugorokuDrawPlayerAndUi @ 0xa53a4: ldr r0,[this,#0x70] (m_rouletteLayers[17]),
        // then ldr [r0,#0x3c] (frame count) and vldr.32 [r0,#0x40] (current frame).
        AepLyrCtrl *lyr = m_rouletteLayers[17].get();
        int frameTotal = lyr->frameCount() - 1; // +0x3c nFrameCount
        // The binary truncates the float play head to an int before the multiply
        // (Ghidra @ 0xa53b0: vcvt.s32.f32, then vcvt.f64.s32 into the *6pi term).
        int frame = static_cast<int>(lyr->curFrame()); // +0x40 flCurFrame
        double angle = (frameTotal > 0) ?
                           static_cast<double>(frame) * (6.0 * M_PI) /
                               static_cast<double>(frameTotal) // DAT_000a5710 == 6*pi
                           :
                           0.0;
        warpSX = static_cast<int>(cosf(static_cast<float>(angle)) * 30.0f);
    }
    // Reverse horizontal scale when moving right (board-state bit).
    if ((m_boardMoveState & ~1) == 2) {
        warpSX = -warpSX;
    }

    // Player sprite (hidden during warp flash).
    if (!m_warpFlash) {
        neTextureForiOS_draw(mgr,
                             m_charaTex.get(),
                             0,
                             0,
                             0x228,
                             0x228,
                             iVar6,
                             screenY,
                             warpSX,
                             0x1e,
                             0,        // rotation (0xa5458 sp+0x18)
                             0x114,    // pivot x  (0xa5408 r5, sp+0x1c)
                             0x114,    // pivot y  (sp+0x20)
                             100,      // color
                             0,        // alpha
                             0x20,     // blend0
                             0xffffff, // colorMul
                             nullptr,  // clip
                             0x21,     // priority
                             1);       // layer
    }

    // Rank badge (types 0..3, stored at +0x8b0; hidden if type >= 4 or during
    // warp flash).
    uint8_t badgeType = m_rankBadgeType;
    if (badgeType < 4 && !m_warpFlash) {
        int badgeLyrHandle = m_iconMental[static_cast<int>(badgeType)].lyr;
        int badgeFrameCnt = m_iconMental[static_cast<int>(badgeType)].frameCount;
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
                       1, // loopFlags (0xa549a -> [sp,#0x20], r12 = 1)
                       0x20,
                       0x00ffffff, // colorRGB (0xa54a0 -> [sp,#0x28], mvn #0xff000000)
                       nullptr,
                       nullptr,
                       0x20,
                       1);
        frameCtr++;
    }

    // Event badge (+0x89b), which the -1 sentinel hides: 0xa54d6 is a signed load
    // and 0xa54da/0xa54dc a `cmp #1` / `blt`.
    if (m_boardSquareState[7] >= 1) {
        int evHandle = m_boardFrame[kBoardFrameDefense02];
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
    if (!m_warpFlash) {
        // +0x8ac is a signed 16-bit field (Ghidra @ 0xa552a/0xa553c: ldrsh.w);
        // assigning the int16_t to int sign-extends exactly like the binary's load.
        int roulVal = m_rouletteMode;
        if (roulVal >= -1) {
            AepLyrCtrl *resultLyr = m_rouletteLayers[15].get();
            if (!resultLyr || !resultLyr->isAnimating()) {
                int rHandle = -1; // no match / not-found frame -> skip (binary: -1 < handle)
                switch (roulVal) {
                case 10:
                    rHandle = m_boardFrame[kBoardFrameDefense0100];
                    break;
                case 11:
                    rHandle = m_boardFrame[kBoardFrameDefense0101];
                    break;
                case 12:
                    rHandle = m_boardFrame[kBoardFrameDefense0102];
                    break;
                case 13:
                    rHandle = m_boardFrame[kBoardFrameDefense0103];
                    break;
                case 16:
                    rHandle = m_boardFrame[kBoardFrameDefense00];
                    break;
                case 19:
                    rHandle = m_boardFrame[kBoardFrameDefense0104];
                    break;
                case 20:
                    rHandle = m_boardFrame[kBoardFrameDefense0300];
                    break;
                case 21:
                    rHandle = m_boardFrame[kBoardFrameDefense0301];
                    break;
                case 22:
                    rHandle = m_boardFrame[kBoardFrameDefense0302];
                    break;
                case 23:
                    rHandle = m_boardFrame[kBoardFrameDefense0303];
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
        AepLyrCtrl *lyr = m_arrowLayers[i].get();
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
// node source deviates. Ghidra FUN_000a5740 takes the node as
// its second parameter (r1); its only caller, sugorokuDrawSquare's type-10 case
// (0xa50bc, `mov r0,r8; bl 0xa5740`), leaves r1 holding the friend-meet square
// being drawn. The code below instead reads m_curNode (the player's node) and
// adds a null-node fallback the binary lacks (0xa579c dereferences r1
// unconditionally). For a friend square != the player node these differ. The
// cos/sin bounce shape (frame @ +0x5e8, cos<15 / sin>=15, x30.0) and the name
// truncation (4 chars + "..") were verified faithful.
void AcMainTask::sugorokuDrawFriendMeet() {
    neTextureForiOS *friendTex = m_goalCharaTex.get();
    if (!friendTex) {
        return;
    }
    int opacity = m_friendOpacity;
    if (!opacity) {
        return;
    }

    int scrollOffX = static_cast<int>(m_scrollX - m_scrollBaseX);
    int scrollOffY = static_cast<int>(m_scrollY - m_scrollBaseY);
    int screenW = m_overlayW;
    int screenH = m_overlayH;

    const TreasureMap::Node *node = m_curNode;
    int iVar7 = node ? node->x * 26 + 0x34 - scrollOffX + screenW / 2 : screenW / 2;
    int iVar6 = node ? node->y * 26 - scrollOffY + screenH / 2 : screenH / 2;

    // Cos/sin bounce animation (30 frames: first 15 = cos, next 15 = sin).
    int frame = m_friendAnimFrame;
    float animVal;
    // The angular constant is the pi/2 pool word at 0xa59b0, loaded by both
    // 0xa57ee and 0xa5812.
    if (frame < 15) {
        animVal = cosf(static_cast<float>(static_cast<double>(frame) * M_PI_2 / 15.0));
    } else {
        animVal = sinf(static_cast<float>(static_cast<double>(frame - 15) * M_PI_2 / 15.0));
    }
    int animScale = static_cast<int>(animVal * 30.0f);

    AepManager *mgr = m_aep;
    neTextureForiOS_draw(mgr,
                         friendTex,
                         0,
                         0,
                         0x228,
                         0x228,
                         iVar7,
                         iVar6,
                         animScale,
                         0x1e,
                         0,             // rotation (0xa589c sp+0x18)
                         0x114,         // pivot x  (sp+0x1c)
                         0x114,         // pivot y  (sp+0x20)
                         opacity,       // color
                         100 - opacity, // alpha
                         0x20,          // blend0
                         0xffffff,      // colorMul
                         nullptr,       // clip
                         0x21,          // priority
                         1);            // layer

    // Name label.
    __unsafe_unretained NSString *nameStr = (__bridge NSString *)m_mapName;
    if (nameStr) {
        mgr->drawLayer(m_skillBoard[4].lyr,
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
                       1,          // loopFlags  (0xa58a8 -> [sp,#0x20])
                       0x20,       // blendFlags (0xa58aa -> [sp,#0x24])
                       0x00ffffff, // colorRGB   (0xa58ac -> [sp,#0x28])
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

    // Fade out (0xa5986-0xa5998), re-reading the member as the binary does rather
    // than reusing the value cached on entry. 100 is the load-time hold, which the
    // update state machine breaks by storing 95. RealUpdate state 0x11 does it at
    // 0x9a868/0x9a86e as `m_friendOpacity = tmp.friendMeetFlag ? 0 : 95`, reading
    // the +0x50 byte of the [UserSettingData treasureTmp] record returned into
    // sp+0x18c: a goal whose friend meet is already recorded shows nothing, a fresh
    // one shows the portrait and fades it. The shared tail at 0x9efce/0x9efd0
    // stores 95 unconditionally and also sets m_rankBadgeType, which is likewise
    // read but never written, so lifting that path arms both.
    if (m_friendOpacity <= 99) {
        int v = m_friendOpacity - 5;
        m_friendOpacity = (v <= 0) ? 0 : v;
    }
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
// divide-by-100 (magic reciprocal 0x51eb851f @ 0xa3aca / 0xa3c88 / 0xa469c). The
// index-9/13 grid round-trip @ 0xa3f66 is an int<->float identity for the draw
// ABI. The chara-select highlight
// keys on object identity (info.charaId == m_charaId @ 0xa3a84), not on any
// incoming coordinate. All 26 branches, offsets, digit-run bounds, and constants
// were verified faithful against disassembly.
void AcMainTask::AcMainSugorokuDraw(int child,
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
                                    uint32_t priority,
                                    void *context) {
    static_cast<void>(frame);
    static_cast<void>(clipRect);
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
    // The digit / panel draw helpers below only READ their atlas, so borrow the
    // owning unique_ptr slots as a raw view rather than handing a routine a
    // pointer-to-smart-pointer. The returned array outlives the draw call it is
    // passed to (it lives to the end of the enclosing full-expression).
    auto atlasView = []<std::size_t N>(const std::unique_ptr<neTextureForiOS>(&owned)[N]) {
        std::array<neTextureForiOS *, N> view{};
        for (std::size_t i = 0; i < N; i++) {
            view[i] = owned[i].get();
        }
        return view;
    };

    // A right-to-left digit run from a texture atlas (glyph w x h), stepping x by
    // -step.
    auto drawDigits =
        [&](neTextureForiOS *const *atlas, int value, int count, int px, int step, int gw, int gh) {
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
                                     priority,
                                     1);
                px -= step;
                value /= 10;
            }
        };

    // ---- treasure-point / ticket / bonus digit readouts
    // -----------------------------------
    if (self->m_boardUserNo[kBoardTreasurePoint] == child) { // treasure point (4 digits)
        int v = self->m_treasurePoint;
        if (v > 9999) {
            v = 9999;
        }
        drawDigits(
            atlasView(self->m_pointsDigitTex).data(), v, 4, x, self->m_dlgLayout954, 0x22, 0x26);
        return;
    }
    if (self->m_boardUserNo[kBoardBonusCount] == child) { // bonus count (ticket glyphs)
        // Disasm +0x42c (0xa3806): 2 digits from x-7, step 0x20 (loop init -7, exit
        // at -0x47).
        drawDigits(atlasView(self->m_ticketDigitTex).data(),
                   self->m_bonusCount,
                   2,
                   x - 7,
                   0x20,
                   0x20,
                   0x24);
        return;
    }
    if (self->m_boardUserNo[kBoardCharaTickets] == child) { // owned chara tickets (<=99)
        int v = self->m_charaTicket;
        if (v > 99) {
            v = 99;
        }
        // Disasm +0x424 (0xa38a6): 2 digits (loop init 0, exit at -0x40), step
        // 0x20.
        drawDigits(atlasView(self->m_ticketDigitTex).data(), v, 2, x, 0x20, 0x20, 0x24);
        return;
    }
    if (self->m_boardUserNo[kBoardRouletteDigit] == child) { // roulette-result digit
        const int val = self->m_rouletteDigit;
        const int n = numDigits(val);
        drawDigits(atlasView(self->m_pointsDigitTex).data(),
                   val,
                   n,
                   x + n * 0x20 - 0x30,
                   0x20,
                   0x22,
                   0x26);
        return;
    }
    if (self->m_boardUserNo[kBoardStepValue] == child) { // per-skill step value (roulette digits)
        // Ghidra 0xa48e4: the slot is m_stepValues[m_stepValueIndex], where the
        // index (+0x594) cycles 0..6 each frame — the spinning roulette readout.
        int val = self->m_stepValues[self->m_stepValueIndex];
        const int n = numDigits(val);
        if (n >= 1) {
            drawDigits(atlasView(self->m_roulDigitTex).data(),
                       val,
                       n,
                       x + (n == 2 ? 0x1c : -2),
                       0x3c,
                       0x3c,
                       0x48);
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
                tex = (base == self->m_boardUserNo[kBoardCharaColLeftA] ||
                       base == self->m_boardUserNo[kBoardCharaColLeftB]) ?
                          self->m_charaPageCurrTex[idxBase].get() :
                          self->m_charaPagePrevTex[idxBase].get();
            } else {
                tex = self->m_charaPagePrevTex[idxBase].get();
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
                                 priority,
                                 1);
            // Highlight the currently-selected chara with the hit-flash layer.
            const int listIdx = idxBase + self->m_charaColLeft * 6;
            NSArray *avail = (__bridge NSArray *)self->m_availableInfos;
            if (static_cast<unsigned>(listIdx) < [avail count]) {
                CharaInfo *info = avail[listIdx];
                if (info && static_cast<int>(info.charaId) == self->m_charaId) {
                    AepLyrCtrl *hl = self->m_rouletteLayers[18].get();
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
    if (self->m_boardUserNo[kBoardCharaColLeftA] == child ||
        self->m_boardUserNo[kBoardCharaColLeftB] == child) {
        drawCharaColumn(child, true);
        return;
    }
    if (self->m_boardUserNo[kBoardCharaColRightA] == child ||
        self->m_boardUserNo[kBoardCharaColRightB] == child) {
        drawCharaColumn(child, false);
        return;
    }

    // ---- chara name / skill text
    // ----------------------------------------------------------
    if (self->m_boardUserNo[kBoardCharaName] == child) { // selected chara name
        if (self->m_skillCharaId < 0) {
            return;
        }
        CharaInfo *info = gCharaManager.availableInfoForCharaId(self->m_skillCharaId);
        aep->DrawText(info.charaName.UTF8String, 0x23, x, y - 0xf, 1, color, 0, priority);
        return;
    }
    if (self->m_boardUserNo[kBoardSkillText] == child) { // skill name / id / description
        if (self->m_skillCharaId < 0) {
            return;
        }
        CharaInfo *info = gCharaManager.availableInfoForCharaId(self->m_skillCharaId);
        const SkillDataStruct *sd = GetSkillDataStruct(static_cast<int>(info.skillId));
        // Ghidra: the raw C string at 0x10a82b, referenced from 0xa3e12.
        aep->DrawText(u8"スキル名", 0xe, x, y - 0x5f, 1, color, 0x59514f, priority);
        aep->DrawText(info.skillName.UTF8String, 0x20, x, y - 0x4e, 1, color, 0x59514f, priority);
        aep->DrawText(sd->description.UTF8String, 0x19, x, y - 0x22, 1, color, 0x7fb4, priority);
        drawAepTextMultiline(
            info.info.UTF8String, x, y + 0x1f, 1, 0x16, 0x1c, 0x59514f, priority, color);
        return;
    }

    // ---- music / wall collection grids (treasure-map piece unlock state)
    // -------------------
    auto pieceCount = [](const uint32_t *table, int mapIdx, int col) {
        int n = 0;
        for (int b = 0; b < 3; b++) {
            if (table[mapIdx * 3 + col] & (1 << b)) {
                n++;
            }
        }
        return n;
    };
    auto drawPieceGrid = [&](const uint32_t *pieceTable,
                             neTextureForiOS *const *panelTex,
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
            const int frameNo = (lit == 0) ? self->m_boardFrame[kBoardFrameCharaKoma] :
                                (lit < 9)  ? self->m_boardFrame[kBoardFrameMusicPeaceBoardS] :
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
                               priority,
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
                                 priority,
                                 1);
            if (anchorOut) {
                anchorOut[i * 2] = cx;
                anchorOut[i * 2 + 1] = cy;
            }
        }
    };
    if (self->m_boardUserNo[kBoardMusicPieceGrid] == child) { // music-piece grid
        drawPieceGrid(
            self->m_musicPieceTableDup, atlasView(self->m_jacketTex).data(), 0x168, 0x26, nullptr);
        return;
    }
    if (self->m_boardUserNo[kBoardWallPieceGrid] == child) { // wall-piece grid
        // Disasm +0x400 (0xa45c4): the wall-piece panel scale is 0x64 (100), not
        // 0x26 like music.
        drawPieceGrid(
            self->m_wallPieceTableDup, atlasView(self->m_wallNailTex).data(), 0x88, 0x64, nullptr);
        return;
    }

    // ---- collection frame grids + anchor cache (index 9 music, 13 wall)
    // ------------------- Ghidra +0x3f4 / +0x404: a 3x3 grid of the collection
    // frame m_boardFrame[kBoardFrameMusicPeaceBoardS]; each cell's anchored position (cx-anchorX,
    // cy-anchorY) is cached for the result-popup overlays. The int<->float
    // conversions here are identity round-trips (no scaling).
    if (self->m_boardUserNo[kBoardMusicPanel] == child ||
        self->m_boardUserNo[kBoardWallPanel] == child) {
        AcAnchor *anchorCache = (self->m_boardUserNo[kBoardMusicPanel] == child) ?
                                    self->m_musicAnchor :
                                    self->m_wallAnchor;
        for (int i = 0; i < 9; i++) {
            const int cx = (i % 3) * 200 + x;
            const int cy = (i / 3) * 0xcc + y;
            drawAepFrameEx(aep,
                           self->m_boardFrame[kBoardFrameMusicPeaceBoardS],
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
                           priority,
                           1);
            anchorCache[i].x = cx - anchorX;
            anchorCache[i].y = cy - anchorY;
        }
        return;
    }

    // ---- "new chara available" button (index 17): two-frame icon
    // -------------------------- Ghidra +0x414: m_boardFrame[kBoardFrameGatya] when >=5 tickets
    // AND all charas collected, else [9].
    if (self->m_boardUserNo[kBoardNewCharaButton] == child) {
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
                       priority,
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
    if (self->m_boardUserNo[kBoardMusicReveal] == child) {
        int px = x, py = y;
        if (self->m_padDisplay) {
            px = x + 1;
            py = y - 5;
        }
        neTextureForiOS_draw(aep,
                             self->m_jacketTex[self->m_selMusicPanel].get(),
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
                             priority,
                             1);
        const int yAdj = (scaleY * 0xe) / 100;
        const int mapIdx = findTreasureMapIndexById(self->m_selMusicPanel);
        const int rowY = y - 0x10;
        bool anyMissing = false, anyNew = false;
        for (int i = 0; i < 9; i++) {
            const uint32_t bits = self->m_musicPieceTableDup[mapIdx * 3 + i / 3];
            int frameNo = 0;
            bool draw = false;
            if ((bits & (1u << (i % 3))) == 0) { // not collected
                anyMissing = true;
                draw = true;
            } else if ((bits & (1u << (i % 3 + 8))) == 0) { // collected, not yet revealed
                frameNo = self->m_pieceRevealFrame;
                if (self->m_rouletteSeInst[kRouletteSePiece] < 0) {
                    self->m_rouletteSeInst[kRouletteSePiece] = static_cast<int>(
                        [[AudioManager sharedManager] playSe:0
                                                  resourceId:self->m_rouletteSe[kRouletteSePiece]]);
                }
                anyNew = true;
                draw = (frameNo >= 0);
            }
            if (draw) {
                int lx, ly;
                if (!self->m_padDisplay) { // phone
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
        self->m_aep->drawLayer(self->m_skillBoard[2].lyr,
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
    if (self->m_boardUserNo[kBoardWallReveal] == child) {
        neTextureForiOS_draw(aep,
                             self->m_reserveTex[0].get(),
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
                             priority,
                             1);
        const int zoomX = static_cast<int>(static_cast<float>(scaleX) * 1.6949f) + 1;
        const int zoomY = static_cast<int>(static_cast<float>(scaleY) * 1.6949f) + 1;
        const int baseX = x - (anchorX * scaleX) / 100;
        const int baseY = y - (anchorY * scaleY) / 100;
        const int mapIdx = findTreasureMapIndexById(self->m_rouletteMapId);
        bool anyMissing = false, anyNew = false;
        for (int i = 0; i < 9; i++) {
            const uint32_t bits = self->m_wallPieceTableDup[mapIdx * 3 + i / 3];
            int frameNo = 0;
            bool draw = false;
            if ((bits & (1u << (i % 3))) == 0) {
                anyMissing = true;
                draw = true;
            } else if ((bits & (1u << (i % 3 + 8))) == 0) {
                frameNo = self->m_pieceRevealFrame;
                if (self->m_rouletteSeInst[kRouletteSePiece] < 0) {
                    self->m_rouletteSeInst[kRouletteSePiece] = static_cast<int>(
                        [[AudioManager sharedManager] playSe:0
                                                  resourceId:self->m_rouletteSe[kRouletteSePiece]]);
                }
                anyNew = true;
                draw = (frameNo >= 0);
            }
            if (draw) {
                int lx, ly, sx, sy, ax, ay;
                if (!self->m_padDisplay) { // phone
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
        self->m_aep->drawLayer(self->m_skillBoard[3].lyr,
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
        {self->m_boardUserNo[kBoardCharaBacking],
         0x2,
         0x228,
         0x228}, // m_reserveTex[2]-ish chara backing
        {self->m_boardUserNo[kBoardSmallPanel], 0x3, 0x168, 0x168}, // small panel
        {self->m_boardUserNo[kBoardFullBg], 0x4, 0x280, 0x3c0},     // full-board bg
        {self->m_boardUserNo[kBoardListPanel], 0x1, 0x228, 0x228},  // list panel
    };
    for (auto &pnl : kPanels) {
        if (pnl.usr == child) {
            neTextureForiOS_draw(aep,
                                 self->m_reserveTex[pnl.slot].get(),
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
                                 priority,
                                 1);
            return;
        }
    }

    // ---- scroll bar / collection-complete pulse badge
    // -------------------------------------
    if (self->m_boardUserNo[kBoardListScrollBar] == child) { // list scroll bar
        if (self->m_charaColLeft > 0) {
            drawAepFrameEx(aep,
                           self->m_boardFrame[kBoardFramePageBefore],
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
                           priority,
                           1);
        }
        drawAepFrameEx(aep,
                       self->m_boardFrame[kBoardFramePageNext],
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
                       priority,
                       1);
        return;
    }
    if (self->m_boardUserNo[kBoardCompleteBadge] == child) { // collection-complete badge (pulsing)
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
                       self->m_boardFrame[kBoardFrameWarning],
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
                       priority,
                       1);
        return;
    }

    // ---- roulette result panel / caption
    // --------------------------------------------------
    auto inRange12 = [](int i) { return i >= 0 && i < 12; };
    if (self->m_boardUserNo[kBoardRouletteIcon] == child) { // roulette-result event icon
        if (!inRange12(self->m_hudState)) {
            return;
        }
        neTextureForiOS_draw(aep,
                             self->m_eventTex[self->m_hudState].get(),
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
                             priority,
                             1);
        return;
    }
    if (self->m_boardUserNo[kBoardRouletteCaption] == child) { // roulette-result caption text
        if (!inRange12(self->m_hudState)) {
            return;
        }
        const char *desc = getStringByIndex12(static_cast<unsigned>(self->m_hudState));
        aep->DrawText(desc, 0x16, x, y - 10, 1, color, 0xffffff, priority);
        return;
    }
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
