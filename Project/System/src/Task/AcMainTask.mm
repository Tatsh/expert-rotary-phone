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
#include <array>
#include <cassert>
#include <cstring>
#include <ctime>
#include <memory>

#import "AepFrameDraw.h"
#import "AepLyrCtrl.h"
#import "AepManager.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "CharaInfo.h"
#import "CharaManager.h"
#import "CommonAlertView.h"
#import "DownloadMain.h"
#import "MainViewController.h"
#import "MenuMainTask.h"
#import "MusicData.h"
#import "MusicManager.h"
#import "RhUtil.h"
#import "SkillData.h"
#import "StoreUtil.h"
#import "TreasureData+Store.h"
#import "TreasureData.h"
#import "TreasureMap.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neTextureForiOS.h"

// Defaulted out-of-line so the unique_ptr scene members are constructed /
// destroyed where AepLyrCtrl / neTextureForiOS are complete (the header only
// forward-declares them). dispose() already releases the scene resources; the
// destructor frees anything still held if the task is destroyed without it.
AcMainTask::AcMainTask() = default;
AcMainTask::~AcMainTask() = default;

// Indices into m_rouletteLayers, naming the kRouletteNames slots the roulette sequence drives.
// These sit above update() because its dispatch passes two of them to a shared handler.
constexpr int kRouletteLayerOpen = 0;           // ROULETTE_START_OPEN
constexpr int kRouletteLayerLoop = 1;           // ROULETTE_START_ROOP
constexpr int kRouletteLayerOpenEvent = 2;      // ROULETTE_START_OPEN_EVENT
constexpr int kRouletteLayerLoopEvent = 3;      // ROULETTE_START_ROOP_EVENT
constexpr int kRouletteLayerEff = 4;            // ROULETTE_EFF
constexpr int kRouletteLayerCharaOpen = 5;      // SELECTION_CHARA_OPEN
constexpr int kRouletteLayerCharaClose = 6;     // SELECTION_CHARA_CLOSE
constexpr int kRouletteLayerCommentBoard = 7;   // SUGO_COMMENT_BOARD
constexpr int kRouletteLayerMusicPieceOpen = 8; // MUSIC_PEACE_OPEN
constexpr int kRouletteLayerWallPieceOpen = 9;  // WALL_PEACE_OPEN
constexpr int kRouletteGoalOpen = 10;           // GOAL_OPEN
constexpr int kRouletteLayerGetMusic = 11;      // GET_MUSIC
constexpr int kRouletteLayerGetWall = 12;       // GET_WALL
constexpr int kRouletteLayerGatsha = 13;        // GATSHA_OPEN
constexpr int kRouletteLayerWallSaveCom = 14;   // WALL_SAVE_COM
constexpr int kRouletteLayerSkillEffect = 15;   // EFF_SKILL2
constexpr int kRouletteLayerSkillKouka = 16;    // EFF_SKILL_KOUKA2
constexpr int kRouletteLayerWarp = 17;          // EFF_WARP_3
constexpr int kRouletteLayerSelectArrow = 18;   // SELECT_ARROW

// Ghidra: AcMainTask_update (FUN_00099d18). Snapshot the touches (recording a
// drag anchor and classifying a tap), refresh the "scrolled past the end" flag,
// then dispatch on the play-data state (@ +0x9f8).
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
                // of the touch coord, vstr.32). The consuming per-frame
                // scroll-normalization lives in the not-yet-reconstructed
                // arcade states 0x10 / 0x4d: delta = ((float)touch - anchor) /
                // m_screenScale (NEON_ACCURACY.md #13).
                m_dragAnchorX = static_cast<float>(t->x);
                m_dragAnchorY = static_cast<float>(t->y);
            }
            m_frameDragging = true;
            break;
        }
        if (t->released != 0) {
            int dx = t->x - t->startX;
            if (dx < 0) {
                dx = -dx;
            }
            if (dx > 10) { // the binary's raw pixel slop; not a tap if moved too far
                break;     // moved too far horizontally: not a tap
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

    // "Scrolled past the last row" flag (@ +0x5f2): list offset >= content
    // bottom.
    m_scrolledPastEnd = static_cast<int>(m_listBottom) <= m_treasurePoint;

    switch (m_state) {
    case kAcMainStateInit:
        stateInit();
        break;
    case kAcMainStateFadeIn:
        stateFadeIn();
        break;
    case kAcMainStateTreasureCheck:
        stateTreasureCheck();
        break;
    case kAcMainStateBoardReveal:
        stateBoardReveal();
        break;
    case kAcMainStateBoardIdle:
        stateBoardIdle(gfx);
        break;
    case kAcMainStateRouletteScrollArm:
        stateRouletteScrollArm();
        break;
    case kAcMainStateRouletteScrollWait:
        stateRouletteScrollWait();
        break;
    case kAcMainStateRouletteSpin:
        stateRouletteSpin();
        break;
    case kAcMainStateRouletteStop:
        stateRouletteStop();
        break;
    case kAcMainStateBoardIdleBonus:
        stateBoardIdleBonus();
        break;
    case kAcMainStateBoardStepAdvance:
        stateBoardStepAdvance();
        break;
    case kAcMainStateSquareMessageOpen:
        stateSquareMessageOpen();
        break;
    case kAcMainStateSquareMessageRead:
        stateSquareMessageRead();
        break;
    case kAcMainStateSquareArrive:
        stateSquareArrive();
        break;
    case kAcMainStateSquareMessage:
        stateSquareLabelWait();
        break;
    case kAcMainStateCollectionMenu:
        stateCollectionMenu();
        break;
    case kAcMainStateMusicPieceView:
        stateMusicPieceView();
        break;
    case kAcMainStateMusicPieceReveal:
        stateMusicPieceReveal();
        break;
    case kAcMainStateWallBoardIdle:
        stateWallBoardIdle();
        break;
    case kAcMainStateWallPieceOpen:
        stateWallPieceOpen();
        break;
    case kAcMainStateWallPieceView:
        stateWallPieceView();
        break;
    case kAcMainStateWallBoardOpen:
        stateWallBoardOpen();
        break;
    case kAcMainStateMusicPieceRevealWait:
        stateMusicPieceRevealWait();
        break;
    case kAcMainStateWallBoardOpenWait:
        stateWallBoardOpenWait();
        break;
    case kAcMainStateWallBoardClose:
        stateWallBoardClose();
        break;
    case kAcMainStateWallSaveBegin:
        stateWallSaveBegin();
        break;
    case kAcMainStateWallSaveWait:
        stateWallSaveWait();
        break;
    case kAcMainStateWallSaveDone:
        stateWallSaveDone();
        break;
    case kAcMainStateCollectionClose:
        stateCollectionClose();
        break;
    case kAcMainStateCollectionCloseWait:
        stateCollectionCloseWait();
        break;
    case kAcMainStateMapReloadBegin:
        stateMapReloadBegin();
        break;
    case kAcMainStateMapReloadWait:
        stateMapReloadWait();
        break;
    case kAcMainStateCharaSelectApply:
        stateCharaSelectApply();
        break;
    case kAcMainStateCharaConfirm:
        stateCharaConfirm();
        break;
    case kAcMainStateCollectionOpen:
        stateCollectionOpen();
        break;
    case kAcMainStateCollectionOpenWait:
        stateCollectionOpenWait();
        break;
    case kAcMainStateMusicPieceOpen:
        stateMusicPieceOpen();
        break;
    case kAcMainStateMusicPieceOpenWait:
        stateMusicPieceOpenWait();
        break;
    case kAcMainStateCharaChangeOpen:
        stateCharaChangeOpen();
        break;
    case kAcMainStateCharaSelectIdle:
        stateCharaSelectIdle();
        break;
    case kAcMainStateCharaGachaRoll:
        stateCharaGachaRoll();
        break;
    case kAcMainStateCharaGachaReveal:
        stateCharaGachaReveal();
        break;
    case kAcMainStateCharaChangeOpenWait:
        stateCharaChangeOpenWait();
        break;
    case kAcMainStateCharaGachaClose:
        stateCharaGachaClose();
        break;
    case kAcMainStateCharaConfirmCancel:
        stateCharaConfirmCancel();
        break;
    case kAcMainStateCharaSelectClose:
        stateCharaSelectClose();
        break;
    case kAcMainStateCharaSelectCloseWait:
        stateCharaSelectCloseWait();
        break;
    case kAcMainStateCharaChangeClose:
        stateCharaChangeClose();
        break;
    case kAcMainStateCharaChangeCloseWait:
        stateCharaChangeCloseWait();
        break;
    case kAcMainStateSkillEffect:
        stateSkillEffect();
        break;
    case kAcMainStateSkillEffectWait:
        stateSkillEffectWait();
        break;
    case kAcMainStateVisitorWait:
        stateVisitorWait();
        break;
    case kAcMainStateFriendMeetAnim:
        stateFriendMeetAnim();
        break;
    case kAcMainStateGoalReward:
        stateGoalReward();
        break;
    case kAcMainStateGoalRewardWait:
        stateGoalRewardWait();
        break;
    case kAcMainStateSquareApply:
        stateSquareApply();
        break;
    case kAcMainStateSquareAnimWait:
        stateSquareAnimWait();
        break;
    case kAcMainStateButtobiPick:
        stateButtobiPick();
        break;
    case kAcMainStateWarpBegin:
        stateWarpBegin();
        break;
    case kAcMainStateWarpEffect:
        stateWarpEffect();
        break;
    case kAcMainStateWarpArrive:
        stateWarpArrive();
        break;
    case kAcMainStateWarpScroll:
        stateWarpScroll();
        break;
    case kAcMainStateWarpInWait:
        stateWarpInWait();
        break;
    case kAcMainStateWallPieceGet:
        stateWallPieceGet();
        break;
    case kAcMainStateWallPieceWait:
        statePieceRevealWait(kRouletteLayerGetWall);
        break;
    case kAcMainStateMusicPieceGrant:
        stateMusicPieceGrant();
        break;
    case kAcMainStateMusicPieceWait:
        statePieceRevealWait(kRouletteLayerGetMusic);
        break;
    case kAcMainStateGoalAward:
        stateGoalAward();
        break;
    case kAcMainStateGoalRewardShow:
        stateGoalRewardShow();
        break;
    case kAcMainStateMusicCompleteShow:
        stateMusicCompleteShow();
        break;
    case kAcMainStateWallCompleteShow:
        stateWallCompleteShow();
        break;
    case kAcMainStateNewMapShow:
        stateNewMapShow();
        break;
    case kAcMainStateGoalFinish:
        stateGoalFinish();
        break;
    case kAcMainStateShowArrows:
        stateShowArrows();
        break;
    case kAcMainStateMapDrag:
        // Sugoroku map-drag state: the reconstructed sub-pass here is the per-frame
        // drag-scroll normalization (NEON_ACCURACY.md #13, disasm prologue at
        // 0x9a6ba). The remainder of this state's body (board redraw / input
        // arbitration) is not yet reconstructed. The same drag-scroll block also
        // appears in state 4 (0x9cb56); it belongs there, not to state 0x4d.
        applyDragScroll(gfx);
        break;
    case kAcMainStateExitBegin:
        stateExitBegin();
        break;
    case kAcMainStateExitWait:
        stateExitWait();
        break;
    case kAcMainStateExitToMenu:
        stateExitToMenu();
        break;
    default:
        break;
    }

    // Common draw tail. In the binary every state falls through to this shared
    // block (Ghidra: RealUpdate @ 0x9ddb0): when the board is up it renders the
    // sugoroku board and background and drives the treasure-event tab layer, and
    // it always advances/draws the Aep layer scene. The reconstruction previously
    // returned after the state switch without ever drawing, which is why Treasure
    // Mode showed a black screen.
    drawFrame();
}

static bool acIsIndexInRange12(int index);

// Common per-frame draw tail (Ghidra: the switch's fall-through at 0x9ddb0). The
// board draw is gated on the board-visible flag (+0x5ee); the Aep layer scene is
// always advanced and drawn.
void AcMainTask::drawFrame() {
    if (m_bgmActive) {
        sugorokuDrawBoard();      // Ghidra: sugorokuDrawBoard @ 0xa303c
        sugorokuDrawBackground(); // Ghidra: sugorokuDrawBackground @ 0xa3308

        // Resolve the active treasure-event tab whenever the download layer flags
        // new info (or on the first frame, when m_hudState still holds its -99
        // sentinel): pick the first event id that falls in the 0..11 tab range.
        DownloadMain *download = [DownloadMain getInstance];
        if (download.isTreasureEventInfoUpdated || m_hudState == kHudStateUninitialized) {
            m_hudState = -1;
            for (NSNumber *eventId in download.treasureEventIdArray) {
                if (acIsIndexInRange12(eventId.intValue)) {
                    m_hudState = eventId.intValue;
                    break;
                }
            }
            download.isTreasureEventInfoUpdated = NO;
        }

        // The event-tab overlay (roulette layer 0x1a) loops while a tab is active
        // and resets to hidden when none is.
        AepLyrCtrl *eventTab = m_rouletteLayers[0x1a].get();
        if (m_hudState < 0) {
            eventTab->reset();
        } else if (!eventTab->isAnimating()) {
            eventTab->play();
        }
    }

    AepLyrCtrl::updateAndDrawAepLayers(0); // Ghidra: FUN_0002c924
}

// Ghidra: isIndexInRange12 @ 0xe2c3c — true when the unsigned index is below 12.
static bool acIsIndexInRange12(int index) {
    return static_cast<unsigned>(index) < 12u;
}

// The "start the layer if it is idle" idiom (Ghidra: IsPlaying @ 0x2cb64 then
// play @ 0x2caf8) that RealUpdate inlines at roughly forty sites. isAnimating()
// is the reconstruction's name for IsPlaying; the null guard mirrors the
// call sites that check the layer pointer first and is a no-op for the ones that
// do not (those layers are always built by setupScene).
static void acPlayIfIdle(AepLyrCtrl *layer) {
    if (layer && !layer->isAnimating()) {
        layer->play();
    }
}

// Per-frame drag / rubber-band scroll normalization. Ground truth is the
// disassembly (0x9a6ba, byte-identical at 0x9cb56) — the decompiler garbles the
// vcvt/vsub NEON here. The live drag delta (in screen units) is subtracted from
// the accumulated scroll, the result is clamped to the map's scroll box, and
// any overshoot past the clamp is banked into a rubber-band accumulator
// (m_scrollRubberX/Y) so the view springs back.
void AcMainTask::applyDragScroll(neGraphics &gfx) {
    if (m_dragAnchorId < 0) {
        return;
    }
    const neTouchPoint *t = gfx.findTouchById(m_dragAnchorId);
    if (!t) {
        // The anchor's finger is gone, so fold the committed base back into the
        // scroll, clear the rubber-band bank, and drop the anchor so the next drag
        // can latch. Ghidra: 0x9e1e6 (state-0x10 copy 0x9d648), where 0x9e21a
        // zeroes +0x514..+0x520 with one NEON store and 0x9e21e writes -1.
        m_scrollX -= m_scrollBaseX;
        m_scrollY -= m_scrollBaseY;
        m_scrollBaseX = 0.0f;
        m_scrollBaseY = 0.0f;
        m_scrollRubberX = 0.0f;
        m_scrollRubberY = 0.0f;
        m_dragAnchorId = -1;
        return;
    }

    // Drag delta from the latched anchor, converted to logical screen units. The
    // binary does vcvt.f32.s32 on the raw touch coords, subtracts the float
    // anchor, then divides by m_screenScale (vdiv).
    const float dX = (static_cast<float>(t->x) - m_dragAnchorX) / m_screenScale;
    const float dY = (static_cast<float>(t->y) - m_dragAnchorY) / m_screenScale;

    // Proposed scroll positions, minus whatever is already banked in the
    // rubber-band. The clamp comparisons in the binary use the truncated
    // (int)->(float) round-trip of these values, so mirror the int cast before
    // comparing.
    const int nx = static_cast<int>((m_scrollX - dX) - m_scrollRubberX);
    const int ny = static_cast<int>((m_scrollY - dY) - m_scrollRubberY);

    int fx;
    if (static_cast<float>(nx) > m_clampCentreX2) {
        m_scrollRubberX += static_cast<float>(nx) - m_clampCentreX2;
        fx = static_cast<int>(m_clampCentreX2);
    } else if (static_cast<float>(nx) < m_clampCentreX) {
        m_scrollRubberX += static_cast<float>(nx) - m_clampCentreX;
        fx = static_cast<int>(m_clampCentreX);
    } else {
        fx = nx;
    }

    int fy;
    if (static_cast<float>(ny) > m_clampMaxY) {
        m_scrollRubberY += static_cast<float>(ny) - m_clampMaxY;
        fy = static_cast<int>(m_clampMaxY);
    } else if (static_cast<float>(ny) < m_clampMinY) {
        m_scrollRubberY += static_cast<float>(ny) - m_clampMinY;
        fy = static_cast<int>(m_clampMinY);
    } else {
        fy = ny;
    }

    // Publish the clamped screen-space base the board draw subtracts from every
    // layer.
    m_scrollBaseX = m_scrollX - static_cast<float>(fx);
    m_scrollBaseY = m_scrollY - static_cast<float>(fy);
}

constexpr int kRouletteLayerLiftMusic = 19; // LIFTING_MUSIC
constexpr int kRouletteLayerLiftWall = 20;  // LIFTING_WALL
constexpr int kRouletteLayerLiftMap = 21;   // LIFTING_MAP
// LIFTING_GAOL_BOARD_01_02 through _03_02. The goal payout kicks whichever matches its reward,
// and each of the three collection reveals clears all of them before playing its own.
constexpr int kRouletteGoalBoard[3] = {23, 24, 25};

// Indices into m_panelLayers; the names are kPanelNamesDefault' entries.
constexpr int kPanelCharaSelectOpen = 1; // CHARACTER_SELECTION*_OPEN
constexpr int kPanelCharaSelectOut = 2;  // CHARACTER_SELECTION*_OUT
constexpr int kPanelCharaChange = 3;     // CHARACTER_CHANGE*
constexpr int kPanelCollectionOpen = 4;  // COLLECTION_SELECT_*_OPEN
constexpr int kPanelCollectionOut = 5;   // COLLECTION_SELECT_*_OUT
constexpr int kPanelMusicPieceBoard = 6; // MUSIC_PEACE_S_*_OPEN
constexpr int kPanelWallPieceBoard = 7;  // WALL_PEACE_S_*_OPEN

// The character grid shows six characters to a page, two rows of three, each cell a square.
constexpr int kCharaCellsPerPage = 6;
constexpr int kCharaCellsPerRow = 3;
constexpr int kCharaCellSize = 196;
// The lottery costs five tickets.
constexpr int kCharaLotteryCost = 5;
// GATSHA_OPEN's frame count is retargeted for the roll and again for the close, and the awarded
// portrait swaps in once the play head passes the reveal frame.
constexpr int kGachaRollFrames = 152;
constexpr int kGachaRevealFrame = 146;
constexpr int kGachaCloseFrames = 197;
// Characters below this id ship inside the bundle; the rest come from the downloaded assets.
constexpr int kBundledCharaCount = 30;

// Indices into kRouletteSeNames, and so into m_rouletteSe / m_rouletteSeInst.
constexpr int kRouletteSeOpen = 0;     // se11_roulapp
constexpr int kRouletteSeStop = 2;     // se13_roulstop
constexpr int kRouletteSeMove = 3;     // se14_move
constexpr int kRouletteSeGoal = 12;    // se22_goal
constexpr int kRouletteSeGacha = 13;   // se23_gacha
constexpr int kRouletteSeItemGet = 11; // se21_itemget
constexpr int kRouletteSeSkill = 4;    // se15_skill
constexpr int kRouletteSeTrap = 5;     // se16_wana
constexpr int kRouletteSeWarp = 6;     // se17_warp
constexpr int kRouletteSeWarpIn = 7;   // se17b_warp
constexpr int kRouletteSeShield = 8;   // se18_shield
constexpr int kRouletteSePiece = 9;    // se19_peace
constexpr int kRouletteSeQuiz = 14;    // se25_quiz_x

// The m_boardSquareState slot a warp square checks before it will fire.
constexpr int kWarpGateSquareSlot = 10;
// The m_boardSquareState slot whose gimmick scales the goal's treasure-point award.
constexpr int kTreasurePointBoostSquareSlot = 13;
// The treasure-point balance saturates here.
constexpr int kMaxTreasurePoint = 9999;
// Half a board tile. Anything parked over the player token carries this on x only; the same bias
// refreshMapScroll applies (pool 0x9ac24).
constexpr float kBoardHalfTileBias = 52.0f;

// Layout slots are stored unscaled and converted to pixels at the point of use.
static int acScaleToPixels(int v, float scale) {
    return static_cast<int>(static_cast<float>(v) * scale);
}

// Every chara-select and collection hit rect is four stored ints scaled by m_screenScale and
// handed to pointInRect (0x9b3ec, 0x9e24e, 0x9eb0a, 0x9f0c2 and 0x9f6c4 all reach 0x2d974 that
// way).
static bool acTapInScaledRect(const neTouchPoint *touch, float scale, int x, int y, int w, int h) {
    return neGraphics::pointInRect(touch->x,
                                   touch->y,
                                   acScaleToPixels(x, scale),
                                   acScaleToPixels(y, scale),
                                   acScaleToPixels(w, scale),
                                   acScaleToPixels(h, scale));
}

// Defined below with the other sugoroku helpers; the states run before it.
static bool sugorokuPieceUnlocked(const uint32_t *grid, int charId, int bitIndex);

namespace {
// Defined further down inside this same anonymous namespace, with the other cross-file helpers.
// The declaration has to sit in the namespace too: at file scope it would be a second, externally
// linked entity and every call would then be ambiguous between the two.
short findTreasureMapIndexById(int id);
} // namespace

// The collection menu's three hit rects, in unscaled units. The two board buttons share an x,
// width and height and differ only in y, which the tall-phone layout shifts down; the back rect
// is anchored at the screen origin (0x9df9e supplies both its x and y from an all-zero NEON
// pair). Ghidra: 0x9bc08 picks the layout by comparing the overlay height against 0x470.
constexpr int kTallPhoneOverlayHeight = 1136;
constexpr float kCollectionButtonX = 149.0f;
constexpr float kCollectionButtonW = 360.0f;
constexpr float kCollectionButtonH = 100.0f;
constexpr float kCollectionMusicY[2] = {360.0f, 451.0f};
constexpr float kCollectionWallY[2] = {524.0f, 613.0f};
constexpr float kCollectionBackW = 140.0f;
constexpr float kCollectionBackH = 80.0f;

// A collection-board piece panel's hit box is a fixed square (pool 0x9be24).
constexpr float kPiecePanelHitSize = 196.0f;
// The BT_WALL_SAVE button, whose y is measured up from the bottom of the overlay.
constexpr int kWallSaveButtonX = 147;
constexpr int kWallSaveButtonW = 360;
constexpr int kWallSaveButtonH = 112;
constexpr int kWallSaveButtonBottomOffset = 175;

// The wallpaper asset height each display uses.
constexpr int kWallpaperHeightPad = 2048;
constexpr int kWallpaperHeightPhone = 960;
constexpr int kWallpaperHeightPhoneTall = 1136;

// Maps a sugoroku main-map id (0..8) to its touch-sound bit index. Ghidra: FUN_000a218c. The tree
// already carries this as a file-local static in UserSettingData.mm and
// InputConversionPassViewController.mm; the goal payout needs a third.
static int neSugorokuTouchSoundBit(int mainMapId) {
    static constexpr int kBits[9] = {1, 2, 3, 4, 5, 6, 7, 8, 9};
    const unsigned id = static_cast<unsigned>(mainMapId) & 0xffff;
    return id < 9 ? kBits[id] : 0;
}

// The square message board parks a fixed distance from the token, picking the nearer offset once
// the token is far enough down the transition overlay (0x9c898 vcmpe against 420.0f, then the
// it-lt pair at 0x9c8a2 / 0x9c8a6).
constexpr float kSquareMessageFlipThreshold = 420.0f;
constexpr float kSquareMessageOffsetNear = 250.0f;
constexpr float kSquareMessageOffsetFar = 524.0f;
// The square message text sits one line above the parked board anchor (0x9a610).
constexpr float kSquareMessageTextRise = 31.0f;

// One wheel slot is six animation frames, so a stop always lands on a multiple of six: 0x9a390
// to 0x9a3b4 is the divide-by-six magic multiply followed by the multiply back and the +6.
constexpr int kRouletteSlotFrames = 6;
// The brake drops both loop layers on frame 60 and releases the board from frame 61 (0x9a422
// cmp #0x3c, 0x9c7c0 cmp #0x3d).
constexpr int kRouletteStopFrames = 60;
// The step cursor cycles the seven m_stepValues slots (0x9d5e8 to 0x9d606).
constexpr int kStepValueCount = 7;
// A roll uses up roulette modes 0..6 and 14..15 (0x9e382 cmp #0xf, 0x9e38c the 0xc07f mask).
constexpr int kRouletteModeMax = 15;
constexpr unsigned kRouletteModeOneShotMask = 0xc07f;
// The two m_boardSquareState slots the parity-gate squares latch.
constexpr int kBoardSquareGateOdd = 2;
constexpr int kBoardSquareGateEven = 3;
// The two messages a parity-gate square puts up (0x9f46c and 0x9c810, copied by the fixed
// 40-byte block at 0x9f476). As with the board-dialogue tables, the text is copyrighted game
// content and is not carried here, so the buffer is blank and the board draws no message.
constexpr int kBoardGateMessageBytes = 40;
constexpr char kBoardGateMessageNeedOdd[kBoardGateMessageBytes] = {};
constexpr char kBoardGateMessageNeedEven[kBoardGateMessageBytes] = {};

// The board entry, reveal, idle and square-arrival states live in their own fragment.
#include "AcMainTaskBoard.mm.inc"

// The collection boards, their reveals, the camera-roll save and the scene reload live in their
// own fragment.
#include "AcMainTaskCollection.mm.inc"

// The character-select panel, its lottery and the four close paths live in their own fragment.
#include "AcMainTaskChara.mm.inc"

// The skill effect, the roulette result it applies, the visitor request, the goal payout and
// award, the square gimmick apply and the warp sequence live in their own fragment.
#include "AcMainTaskGoal.mm.inc"

// The board walk, the square tap router, the roulette and the exit states live in their own
// fragment; see the file comment there for why it is #included rather than compiled separately.
#include "AcMainTaskWalk.mm.inc"

// The scene builder, its asset-name tables and its three delegated passes live in their own
// fragment.
#include "AcMainTaskSetup.mm.inc"

// The map load, the step and SE tables, the Core Data piece grids and the board-background
// teardown live in their own fragment.
#include "AcMainTaskMap.mm.inc"

// The board, background, square, path, player and friend-meet draws, the panel and button hit
// tests, the easing pairs, the scroll bounds and the task teardown live in their own fragment.
#include "AcMainTaskDraw.mm.inc"
