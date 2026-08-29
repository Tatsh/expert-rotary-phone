/**
 * @file
 * The ARCADE-mode task: arcade song select, sugoroku treasure map, option select, and
 * note play.
 *
 * It drives the arcade note engine (AcNoteMng) and is launched by the mode menu (MenuMainTask).
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (ctor AcMainTask_ctor
 * FUN_00099ab0, update AcMainTask_update FUN_00099d18).
 *
 * AcMainTask_update is the app's largest function (~24 KB / ~4300 decompiled lines, heavily
 * inlined). It is reconstructed in pieces from the on-disk decompile
 * (.decompile/AcMainTask_update.c): update() is the touch/SE preamble plus a dispatch over the
 * play-data state (@ +0x9f8) into one handler method per state; each state's inlined body is
 * lifted into its own method. Progress tracked in STUBS.md.
 *
 * Work area (this class IS the ~0xa00-byte play-data struct): it is runtime-only, never
 * serialised to or from a file, so its exact byte layout is NOT preserved. The `// +0xNN`
 * comments cross-reference each field's binary offset, but unused gaps are dropped (noted
 * inline) rather than padded, and members are reached by name, not raw offset. A few
 * device-branched select and dialog layout regions (m_selSceneLayout, m_dlgLayoutA/B,
 * m_dlgLayout954) are pure coordinate constants the setup pass writes and only the
 * not-yet-reconstructed select and option draw states read; they are kept as documented
 * write-only arrays, and their interior roles are best-effort. The play state @ +0x9f8 is what
 * update() dispatches on; the embedded arcade RNG @ +0x4f4 is a real Random member,
 * auto-constructed and destroyed.
 */

#pragma once

#include <cstdint>
#include <memory>

#import <Foundation/Foundation.h>

#include "C_TASK.h"
#include "Random.h"      // embedded PRNG at this+0x4f4 (Ghidra: FUN_00062b20)
#include "TreasureMap.h" // TreasureMap + nested Node / ConnectStruct (sugoroku draw params)

class AepManager;
class AepLyrCtrl;
class neTextureForiOS;
struct SkillDataStruct; // System/../SkillData.h (pointer member only)
struct neTouchPoint;    // System/src/Render/neGraphics.h (touch pool record)
class neGraphics;       // System/src/Render/neGraphics.h (applyDragScroll parameter)

/**
 * Draw-dispatch keys into m_boardUserNo.
 *
 * Each entry is a getUserNo element id that the group-5 board draw callback (AcMainSugorokuDraw)
 * matches the drawn `child` against to render one sugoroku or chara-select board element. The
 * names come from the callback's per-element branches.
 */
enum BoardElem {
    kBoardTreasurePoint = 0,    /**< The treasure-point 4-digit counter. */
    kBoardCharaColRightA = 1,   /**< Chara-select right column, paired with RightB. */
    kBoardCharaColLeftA = 2,    /**< Chara-select left column, paired with LeftB. */
    kBoardCharaBacking = 3,     /**< The chara backing panel. */
    kBoardCharaColLeftB = 4,    /**< Chara-select left column, paired with LeftA. */
    kBoardCharaColRightB = 5,   /**< Chara-select right column, paired with RightA. */
    kBoardCharaName = 6,        /**< The selected chara's name. */
    kBoardSkillText = 7,        /**< The skill name, id, and description. */
    kBoardMusicPieceGrid = 8,   /**< The music-piece unlock grid. */
    kBoardMusicPanel = 9,       /**< The music-panel grid, holding the music anchors. */
    kBoardSmallPanel = 10,      /**< The small chara panel. */
    kBoardMusicReveal = 11,     /**< The music-piece reveal overlay. */
    kBoardWallPieceGrid = 12,   /**< The wallpaper-piece unlock grid. */
    kBoardWallPanel = 13,       /**< The wall-panel grid, holding the wall anchors. */
    kBoardWallReveal = 14,      /**< The wall-piece reveal overlay. */
    kBoardFullBg = 15,          /**< The full-board background panel. */
    kBoardStepValue = 16,       /**< The per-skill roulette step-value digits. */
    kBoardNewCharaButton = 17,  /**< The "new chara available" button. */
    kBoardListPanel = 18,       /**< The chara list panel. */
    kBoardListScrollBar = 19,   /**< The chara list scroll bar. */
    kBoardCompleteBadge = 20,   /**< The pulsing collection-complete badge. */
    kBoardCharaTickets = 21,    /**< The owned chara-ticket count, at most 99. */
    kBoardRouletteDigit = 22,   /**< A roulette-result digit. */
    kBoardBonusCount = 23,      /**< The bonus count, drawn as ticket glyphs. */
    kBoardRouletteIcon = 24,    /**< The roulette-result event icon. */
    kBoardRouletteCaption = 25, /**< The roulette-result caption text. */
};

/**
 * Frame handles into m_boardFrame, resolved in setup from getFrameNo(5, kFrmBoard[i]).
 *
 * Each entry is named after its board frame asset. The DEFENSE_* and SQUARE frames are the
 * roulette-result event frames the result switch selects by outcome mode.
 */
enum BoardFrame {
    kBoardFrameCharaKoma = 0,        /**< CHARA_KOMA00. */
    kBoardFrameMusicPeaceBoardS = 1, /**< MUSIC_PEACE_BOARD_S. */
    kBoardFrameJacketQuestion = 2,   /**< JACKET_QUESTION. */
    kBoardFrameJacketDiscovery = 3,  /**< JACKET_DISCOVERY. */
    kBoardFrameRoulette = 4,         /**< BT_ROULETTE. */
    kBoardFrameRouletteNo = 5,       /**< BT_ROULETTE_NO. */
    kBoardFrameRouletteEvent = 6,    /**< BT_ROULETTE_EVENT. */
    kBoardFrameRouletteEventNo = 7,  /**< BT_ROULETTE_EVENT_NO. */
    kBoardFrameGatya = 8,            /**< BT_GATYA. */
    kBoardFrameGatya01 = 9,          /**< BT_GATYA01. */
    kBoardFramePageBefore = 10,      /**< PAGE_BEFORE. */
    kBoardFramePageNext = 11,        /**< PAGE_NEXT. */
    kBoardFrameWarning = 12,         /**< WARNING. */
    kBoardFrameWallSave = 13,        /**< BT_WALL_SAVE. */
    kBoardFrameDefense0100 = 14,     /**< DEFENSE_01_00. */
    kBoardFrameDefense0101 = 15,     /**< DEFENSE_01_01. */
    kBoardFrameDefense0102 = 16,     /**< DEFENSE_01_02. */
    kBoardFrameDefense0103 = 17,     /**< DEFENSE_01_03. */
    kBoardFrameDefense0104 = 18,     /**< DEFENSE_01_04. */
    kBoardFrameDefense00 = 19,       /**< DEFENSE_00. */
    kBoardFrameDefense02 = 20,       /**< DEFENSE_02. */
    kBoardFrameSquare0100 = 21,      /**< BT_SQUARE01_00. */
    kBoardFrameDefense0300 = 22,     /**< DEFENSE_03_00. */
    kBoardFrameDefense0301 = 23,     /**< DEFENSE_03_01. */
    kBoardFrameDefense0302 = 24,     /**< DEFENSE_03_02. */
    kBoardFrameDefense0303 = 25,     /**< DEFENSE_03_03. */
};

/**
 * A resolved Aep layer handle paired with its frame count; the setup pass always resolves
 * the two together (getLyrNo then layerFrameCount).
 */
struct AcLayerRef {
    int lyr = 0;        /**< The getLyrNo handle. */
    int frameCount = 0; /**< layerFrameCount(lyr). */
};

/**
 * An integer (x, y) board-panel anchor position (a grid cell's top-left after the per-cell
 * anchor offset).
 */
struct AcAnchor {
    int x = 0; /**< Anchor x in board space. */
    int y = 0; /**< Anchor y in board space. */
};

/**
 * The arcade-mode task: arcade song select, the sugoroku treasure map, option select and
 * note play.
 *
 * This class is also the ~0xa00-byte play-data work area the binary's one megafunction dispatches
 * over.
 */
class AcMainTask : public ne::C_TASK {
public:
    // The binary ctor/dtor (FUN_00099ab0 / 0x99ba4) are just the compiler-emitted
    // ne::C_TASK base + Random member construct/destruct plus the members' in-class
    // initialisers, so both are defaulted.
    // Both defined out-of-line so the unique_ptr scene members are constructed /
    // destroyed where AepLyrCtrl / neTextureForiOS are complete (the header only
    // forward-declares them).
    AcMainTask();
    ~AcMainTask() override;
    /**
     * Per-frame arcade-mode tick: the touch/SE preamble, then a dispatch over the play-data
     * state into one handler method per state.
     * @param deltaMs Milliseconds elapsed since the previous scheduler tick.
     * @ghidraAddress 0x99d18
     */
    void update(int deltaMs) override;

private:
    // Per-state handlers, lifted from AcMainTask_update's inlined switch cases.
    void stateInit();          // case 0  (setup, then BGM or the no-treasure path)
    void stateFadeIn();        // case 1  (fade the select scene, open the sugoroku map)
    void stateTreasureCheck(); // case 2  (read the temp-treasure record, branch)
    void stateBoardReveal();   // case 3  (fade the board in, save the tmp, arm the move count)
    void stateBoardIdle(neGraphics &gfx); // case 4 (roulette intro, drag; tap routing is TODO)
    void stateRouletteScrollArm();        // case 5 (arm the recentre ease, fill the step table)
    void stateRouletteScrollWait();       // case 6 (run the ease, then open the roulette)
    void stateRouletteSpin();             // case 7 (spin, and stop the wheel on a touch)
    void stateRouletteStop();             // case 8 (brake, commit the roll, release the board)
    void stateBoardStepAdvance();         // case 0x0a (one step of the board walk)
    void stateSquareMessageOpen();        // case 0x0b (open the square message board)
    void stateSquareMessageRead();        // case 0x0c (hold the message until a tap)
    void stateSquareArrive();             // case 0x0d (the token settles on a square)
    void stateShowArrows();               // case 0x0f (light the directions the square opens on)
    void stateSquareLabelWait();          // case 0x0e (hold the label, then route the tap)
    void stateWarpBegin();                // case 0x1d (resolve the warp partner square)
    void stateWarpEffect();               // case 0x1e (warp SE, park EFF_WARP_3, arm the squish)
    void stateWarpArrive();               // case 0x1f (commit the partner square)
    void stateWarpScroll();               // case 0x20 (ease to the destination, rewind the fx)
    void stateWarpInWait();               // case 0x21 (wait out the overlay, drop the gate)
    /**
     * Park an overlay over the player token in screen space.
     * @param layer The layer to position.
     */
    void parkLayerOverToken(AepLyrCtrl *layer);
    void stateWallPieceGet();    // case 0x17 (bank a wallpaper piece, arm GET_WALL)
    void stateMusicPieceGrant(); // case 0x19 (bank a music piece, arm GET_MUSIC)
    /**
     * Cases 0x18 and 0x1a: hold while a piece-reveal overlay plays out.
     * @param layerIndex The m_rouletteLayers slot to poll, GET_WALL or GET_MUSIC.
     */
    void statePieceRevealWait(int layerIndex);
    void stateGoalAward();         // case 0x11 (roll and hand out the goal reward)
    void stateGoalRewardShow();    // case 0x12 (play the matching goal board)
    void stateMusicCompleteShow(); // case 0x13 (the music-collection reveal)
    void stateWallCompleteShow();  // case 0x14 (the wallpaper-collection reveal)
    void stateNewMapShow();        // case 0x15 (the new-area reveal, else arm the fade)
    void stateGoalFinish();        // case 0x16 (reload the SE pool, back to map-select)
    /** Park the square message board over the token and publish its text anchor. */
    void sugorokuPositionSquareMessage();
    /** Advance and persist the tapped square's board-story page counter. */
    void sugorokuAdvanceSquareStory();
    /** Hand the board to the state that owns the tapped square's kind. */
    void sugorokuRouteSquareTap();
    /** The sub-map-flag arm of the arrival routing. */
    void sugorokuArriveSubMapFlag();
    /** Advance the roulette step cursor, wrapping the sub-tick on m_stepSubTickLen. */
    void advanceRouletteStepTick();
    /** Run the braking wheel, committing the roll once the play head reaches the stop frame. */
    void rouletteStopSpin();
    /**
     * Commit a landed roll: publish the step value, charge its cost and persist the record.
     * @param spin The loop layer the wheel landed on.
     * @param stopFrame The latched slot boundary the play head is frozen at.
     */
    void commitRouletteResult(AepLyrCtrl *spin, int stopFrame);
    /** Release the board once the wheel has parked, honouring the two parity-gate squares. */
    void rouletteStopResolve();
    /**
     * Put a parity-gate square's message up and discard the roll.
     * @param message The 40-byte message body.
     */
    void showBoardGateMessage(const char *message);
    void stateExitBegin();  // case 0x4b (start the exit fade-out)
    void stateExitWait();   // case 0x4c (wait for the exit fade-out to finish)
    void stateExitToMenu(); // case 0x4d (spawn MenuMainTask, dispose this task)

    // Scene build / map load (their own reconstruction pieces).
    void setupScene();      // Ghidra: FUN_0009fc90 (build the select/map scene)
    void loadTreasureMap(); // Ghidra: FUN_000a0b58 (DB synced; was mislabeled
                            // charaSelectReloadData — it loads map_%03d.map, see the .mm plate)

    // setupScene() reconstruction helpers (big resolve/build/load loops of
    // FUN_0009fc90).
    void setupResolveHandles(); // the ~50 getLyrNo/getFrameNo/getUserNo tables
    void setupBuildOverlays();  // the ~35 AepLyrCtrl overlay objects
    // circle/chara/number/event textures + BGM prep; charaId is the clamped value
    // setupScene spills at 0x9fe6a and reloads at 0xa0776.
    void setupLoadTextures(short charaId);

    // Genuine sub-routines the arcade scene builders call.
    void computeStepValues();     // Ghidra: FUN_000a1950 (fills the m_stepValues table)
    void buildSelectListLayout(); // Ghidra: FUN_000a21a8
    void loadTreasureProgress();  // Ghidra: FUN_000a2264 (DB synced; was sugorokuLoadTreasureMap)
    void buildMapPanelLayers();   // Ghidra: FUN_000a2650
    void refreshMapScroll(int mode);       // Ghidra: FUN_000a3550
    void applyDragScroll(neGraphics &gfx); // drag/rubber-band scroll update
                                           // (disasm 0x9a6ba / 0x9cb56)
    void unloadMapBgGroup();               // Ghidra: FUN_000a4e84
    void sugorokuReleaseGoalLayer();       // Ghidra: sibling of FUN_000a4e84 (same
                                           // teardown effect)

    // Sugoroku board draw / logic sub-passes (Ghidra 0xa14a0..0xa5740). These
    // operate on this task's work area, so they are real members (the
    // "SugorokuMainTask" a prior agent invented was a mis-attribution). The
    // group-5 draw callback drives them.
    int sugorokuDrawSkillPanel();     // FUN_000a14a0
    int sugorokuDrawButtonHitTest();  // FUN_000a178c
    bool sugorokuEasePositionPairA(); // FUN_000a19dc
    bool sugorokuEasePositionPairB(); // FUN_000a1ac8
    /**
     * Draw the current square's label, if it has one to show.
     * @return Whether anything was drawn; state 0x0e routes the tap the frame this goes false.
     * @ghidraAddress 0xa1bb4
     */
    bool sugorokuDrawSquareText();
    void sugorokuSaveTreasureProgress();     // FUN_000a1ddc
    void sugorokuSetupScrollBounds();        // FUN_000a2544
    void sugorokuLoadWallTextures(int page); // FUN_000a2b64
    void sugorokuTaskDispose();              // FUN_000a2d00
    void drawFrame();                        // Ghidra: RealUpdate draw tail @ 0x9ddb0
    void sugorokuDrawBoard();                // FUN_000a303c
    void sugorokuDrawBackground();           // FUN_000a3308
    void sugorokuDrawSquare(const TreasureMap::Node *node);        // FUN_000a4eb4
    void sugorokuDrawPath(const TreasureMap::ConnectStruct *edge); // FUN_000a50dc
    void sugorokuDrawPlayerAndUi();                                // FUN_000a52f0
    void sugorokuDrawFriendMeet();                                 // FUN_000a5740

    // Chara-select page-texture helpers (defined in CharaManager.mm; the binary
    // has them as AcMainTask methods reading this task's chara arrays/textures).
    void charaSelectLoadPageTextures(int page); // Ghidra: FUN @ 0xa27f0
    int charaSelectFindCharaIndex(int charaId); // Ghidra: FUN @ 0xa2a40
    void charaSelectReleaseTextures();          // Ghidra: FUN @ 0xa2b10

    // The group-5 sugoroku render callback reaches this task's members through
    // `context`; a static member so it is a plain function pointer for
    // setGroupDrawCallback while still reaching the private members directly.
    static void AcMainSugorokuDraw(int child,
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
                                   void *context);

    // ================= work-area layout (// +0xNN = binary offset, for
    // cross-reference; the C++ layout is not byte-exact) =================
    AepManager *m_aep = {}; // +0x28 cached AepManager (every resolve/draw reads it)
    std::unique_ptr<AepLyrCtrl>
        m_rouletteLayers[29]; // +0x2c 29 roulette/effect overlay layers (built by setupScene)
    std::unique_ptr<AepLyrCtrl> m_panelLayers[8];  // +0xa0 8 character/collection select panels
    std::unique_ptr<AepLyrCtrl> m_arrowLayers[4];  // +0xc0 4 sugoroku hit-flash / direction arrows
    std::unique_ptr<AepLyrCtrl> m_boardBgLayer;    // +0xd0 current board background layer (group 6)
    std::unique_ptr<neTextureForiOS> m_circleTex;  // +0xd4 bundled circle.png
    std::unique_ptr<neTextureForiOS> m_boardBgTex; // +0xd8 board background texture
    std::unique_ptr<neTextureForiOS> m_charaTex;   // +0xdc active player-character board sprite
    std::unique_ptr<neTextureForiOS> m_goalCharaTex; // +0xe0 goal / friend-meet character portrait
    std::unique_ptr<neTextureForiOS> m_blindCircleTex; // +0xe4 bundled blind_circle.png
    std::unique_ptr<neTextureForiOS>
        m_reserveTex[5]; // +0xe8 scene textures freed by dispose (unreconstructed states)
    std::unique_ptr<neTextureForiOS> m_pointsDigitTex[10];  // +0xfc num_points0..9 glyphs
    std::unique_ptr<neTextureForiOS> m_roulDigitTex[10];    // +0x124 num_roulette_0..9 glyphs
    std::unique_ptr<neTextureForiOS> m_ticketDigitTex[10];  // +0x14c ticket_num0..9 glyphs
    std::unique_ptr<neTextureForiOS> m_charaPagePrevTex[6]; // +0x174 prev-page chara textures
    std::unique_ptr<neTextureForiOS> m_charaPageCurrTex[6]; // +0x18c current-page chara textures
    std::unique_ptr<neTextureForiOS> m_jacketTex[9];        // +0x1a4 9 music-panel jacket textures
    std::unique_ptr<neTextureForiOS> m_wallNailTex[9];      // +0x1c8 9 wall-nail textures
    std::unique_ptr<neTextureForiOS> m_eventTex[12];        // +0x1ec 12 event_0_%03d icons
    AcLayerRef m_skillBoard[5] = {}; // SKILL_COM_BOARD/... layers + frame counts
    // (binary: lyr @+0x21c, frameCount @+0x230; paired here)
    // +0x244: 8 bytes unused padding (dropped; runtime struct, layout not preserved)
    int m_musicResultFrame = {}; // +0x24c music collection-result overlay frame
    int m_wallResultFrame = {};  // +0x250 wall collection-result overlay frame
    // +0x254: 4 bytes unused padding (dropped; runtime struct, layout not preserved)
    AcLayerRef m_iconMental[4] = {}; // ICON_MENTAL00..03 rank-badge layers + frame
                                     // counts (binary: lyr @+0x258, frameCount @+0x268)
    int m_animFrameCtr = {};         // +0x278 shared per-frame animation counter
    int m_musicPeaceLyr[9] = {};     // +0x27c MUSIC_PEACE00..08 layers
    int m_wallPeaceLyr[9] = {};      // +0x2a0 WALL_PEACE00..08 layers
    int m_musicPeaceFrames = {};     // +0x2c4 MUSIC_PEACE frame count
    int m_wallPeaceFrames = {};      // +0x2c8 WALL_PEACE frame count
    int m_pieceRevealFrame = {};     // +0x2cc frame for a newly-collected piece reveal
    int m_boardFrame[26] = {};       // +0x2d0 board frame numbers, indexed by BoardFrame
    int m_base1Frame[11] = {};       // +0x338 11 BASE_* square frame numbers
    int m_rouletteMoveFrame = {};    // +0x364 BT_ROULETTE_MOVE frame (pad only)
    int m_base08Frame[10] = {};      // +0x368 10 BASE_08_* warp frames
    int m_base05Frame[4] = {};       // +0x390 4 BASE_05_* sub-map-flag frames
    int m_triangle0Frame[6] = {};    // +0x3a0 TRIANGLE00_* forward-arrow frames
    int m_triangle1Frame[6] = {};    // +0x3b8 TRIANGLE01_* back-arrow frames
    int m_boardUserNo[26] = {};      // +0x3d0 getUserNo handles, indexed by BoardElem
    int m_rouletteSe[15] = {};       // +0x438 15 roulette SE source ids
    // +0x474 the playing-instance id for each m_rouletteSe entry, -1 while idle. This runs
    // parallel to m_rouletteSe and is reset by a single 0x3c-byte memset to 0xff, which is what
    // gives it away: 0x3c is 15 ints, so the region is one array rather than the three separate
    // members it was split into. 0x9a2ea plays m_rouletteSe[0] and 0x9a2ee stores the instance
    // straight to +0x474, pairing the two arrays index for index.
    int m_rouletteSeInst[15] = {};
    std::unique_ptr<TreasureMap> m_map;             // +0x4b0 loaded TreasureMap
    const TreasureMap::Node *m_nodes = {};          // +0x4b4 map node array
    const TreasureMap::ConnectStruct *m_edges = {}; // +0x4b8 edge (ConnectStruct) array (a real
    // pointer; the 32-bit binary held it in an int slot)
    const TreasureMap::Node *m_curNode = {}; // +0x4bc current board node
    // +0x4c0 the pending/target board node: update swaps it with m_curNode
    // (@ 0x9d... copies +0x4c0 <-> +0x4bc) as the player moves. A Node* in the
    // 32-bit binary's 4-byte slot; a real pointer here.
    const TreasureMap::Node *m_targetNode = {}; // +0x4c0
    uint16_t m_nodeCount = {};                  // +0x4c4 map node count
    int16_t m_edgeCount = {};                   // +0x4c6 map edge count
    float m_scrollBoxOriginX = {};              // +0x4c8 scroll bounding box origin x
    float m_scrollBoxOriginY = {};              // +0x4cc scroll bounding box origin y
    float m_scrollBoxW = {};                    // +0x4d0 scroll bounding box width
    float m_scrollBoxH = {};                    // +0x4d4 scroll bounding box height
    float m_scrollX = {};                       // +0x4d8 scroll position x (clamped)
    float m_scrollY = {};                       // +0x4dc scroll position y (clamped)
    float m_clampCentreX = {};                  // +0x4e0 scroll clamp min centre x
    float m_clampMinY = {};                     // +0x4e4 scroll clamp min y
    float m_clampCentreX2 = {};                 // +0x4e8 scroll clamp max centre x
    float m_clampMaxY = {};                     // +0x4ec scroll clamp max y
    int16_t m_lastBranchNodeId =
        {}; // +0x4f0 last junction board node id (persisted as record +0x06)
    // +0x4f2: 2 bytes unused padding (dropped; runtime struct, layout not preserved)
    Random m_rng;               // +0x4f4 embedded arcade RNG (auto-constructed/destructed)
    int m_dragAnchorId = -1;    // +0x508 touch drag anchor id (-1 == none)
    float m_dragAnchorX = {};   // +0x50c drag anchor x (float; disasm 0x99e3e)
    float m_dragAnchorY = {};   // +0x510 drag anchor y (float)
    float m_scrollBaseX = {};   // +0x514 scroll base x (subtracted for screen space)
    float m_scrollBaseY = {};   // +0x518 scroll base y
    float m_scrollRubberX = {}; // +0x51c rubber-band overscroll accumulator x (disasm 0x9a6ba)
    float m_scrollRubberY = {}; // +0x520 rubber-band overscroll accumulator y
    int m_overlayW = {};        // +0x524 transition-overlay width
    int m_overlayH = {};        // +0x528 transition-overlay height
    float m_screenScale = {};   // +0x52c screen scale
    int m_bgTileW = {};         // +0x530 background tile width
    int m_bgTileH = {};         // +0x534 background tile height
    int m_selSceneLayout[16] =
        {};                    // +0x538 device-branched select-scene layout constants (write-only;
                               // consumed by unreconstructed draw)
    int m_stepValues[7] = {};  // +0x578 7 per-skill roulette step values
    int m_stepValueIndex = {}; // +0x594 roulette step-value index (cycles 0..6 mod 7 each frame)
    int m_stepSubTick =
        {}; // +0x598 sub-tick; wraps mod m_stepSubTickLen, advancing m_stepValueIndex
    int m_charaLayerTargetFrame =
        {};                     // +0x59c +0x30 chara-layer target frame (next multiple of 6, wraps)
    int m_stepSubTickLen = 3;   // +0x5a0 sub-tick period / modulus for m_stepSubTick (ctor 3)
    float m_scrollTargetX = {}; // +0x5a4 scroll ease target x
    float m_scrollTargetY = {}; // +0x5a8 scroll ease target y
    float m_scrollVelX = {};    // +0x5ac scroll ease velocity x
    float m_scrollVelY = {};    // +0x5b0 scroll ease velocity y
    float m_scrollAccumX = {};  // +0x5b4 scroll ease accumulator x
    float m_scrollAccumY = {};  // +0x5b8 scroll ease accumulator y
    float m_playerTargetX = {}; // +0x5bc player ease target x
    float m_playerTargetY = {}; // +0x5c0 player ease target y
    float m_playerVelX = {};    // +0x5c4 player ease velocity x
    float m_playerVelY = {};    // +0x5c8 player ease velocity y
    float m_playerX = {};       // +0x5cc player board draw x
    float m_playerY = {};       // +0x5d0 player board draw y
    int m_boardMoveState = {};  // +0x5d4 board move / warp state
    // +0x5d8 index of the link the token walks out along, -1 while idle. The binary stores -1
    // here (0x9d6a8, and 0xa141c in loadTreasureMap), and state 0x0a steps m_curNode along
    // m_curNode->links[m_moveLinkIndex], so this is a signed index and not a flag.
    int8_t m_moveLinkIndex = -1;
    // +0x5d9: 3 bytes unused padding (dropped; runtime struct, layout not preserved)
    int m_rouletteStopTimer = {};  // +0x5dc roulette brake frame counter
    int m_charaColRight = {};      // +0x5e0 chara-grid right column base index
    int m_charaColLeft = {};       // +0x5e4 chara-grid left column base index
    int m_friendAnimFrame = {};    // +0x5e8 friend-meet animation frame
    bool m_skillPanelActive = {};  // +0x5ec skill-use panel modal (drives sugorokuDrawSkillPanel)
    bool m_buttonPanelActive = {}; // +0x5ed board-button panel modal (sugorokuDrawButtonHitTest)
    bool m_bgmActive = {};         // +0x5ee select-BGM active flag
    bool m_warpFlash = {};         // +0x5ef warp flash gate
    bool m_warpAnim = {};          // +0x5f0 warp squish animation active
    bool m_wallpaperComplete = {}; // +0x5f1 all 9 wall pieces owned -> reveal draw enabled
    bool m_scrolledPastEnd = {};   // +0x5f2 list scrolled-past-end flag (recomputed each frame)
    // +0x5f3 board-square select animation running; while set, sugorokuDrawSquareText
    // hides the square label and case 0x23 clears it when the +0x6c layer finishes.
    // Accessed as a byte in the binary (strb/ldrb), not an int.
    bool m_squareAnimActive = {}; // +0x5f3
    // The goal payout raises these three when it completes a collection, and states 0x13, 0x14
    // and 0x15 each consume one to decide whether to play its LIFTING_* reveal or fall through.
    bool m_musicCompleteReveal = {}; // +0x5f4 the map's 9 music pieces just completed
    bool m_wallCompleteReveal = {};  // +0x5f5 the map's 9 wallpaper pieces just completed
    bool m_newMapReveal = {};        // +0x5f6 the next area's record was just created
    bool m_padDisplay = {};          // +0x5f7 iPad display flag
    bool m_revealTexLoaded =
        {}; // +0x5f8 reveal texture loaded (gates the +0x60-layer reveal, case 0x2c/0x2d)
    bool m_eventIntroStarted =
        {};                 // +0x5f9 one-shot: kicked the +0x98 event-intro layer (play once)
    uint8_t m_fadeDir = {}; // +0x5fa transition fade direction
    // +0x5fb: 1 bytes unused padding (dropped; runtime struct, layout not preserved)
    int16_t m_charaId = {};      // +0x5fc active character id
    int16_t m_skillCharaId = {}; // +0x5fe skill-panel active character id
    int16_t m_skillCharaSlot =
        {}; // +0x600 selected chara grid slot (0..5; 0xffff none) for m_skillCharaId
    // +0x602: 2 bytes unused padding (dropped; runtime struct, layout not preserved)
    int m_skillPanelX = {};   // +0x604 skill-panel origin x cache
    int m_skillPanelY = {};   // +0x608 skill-panel origin y cache
    int m_charaPanelX = {};   // +0x60c chara-panel origin x cache
    int m_charaPanelY = {};   // +0x610 chara-panel origin y cache
    int m_layoutAnchorZ = {}; // +0x614 roulette layer anchor z (tall-phone seed)
    int m_layoutOffsetY =
        {}; // +0x618 board-draw Y offset (added to +0x95c/0x96c/0x97c; 0x9e on tall phones)
    int m_friendOpacity = {};   // +0x61c friend-meet fade opacity
    int16_t m_subMapId = {};    // +0x620 pending sub-map id (board*10+sub; -1 none)
    int16_t m_charaTicket = {}; // +0x622 owned chara tickets
    int m_treasurePoint = {};   // +0x624 treasure point balance
    int m_bonusCount = {};      // +0x628 bonus/main-map id (roulette overlay gate)
    // +0x62c is seeded to this out-of-range negative sentinel so the first update
    // frame forces the initial treasure-event scan (update @ 0x9d... checks
    // == this value); it reads as "no event" (< 0) and is distinct from the -1
    // "scanned, none found" value.
    static constexpr int kHudStateUninitialized = -99;
    int m_hudState = kHudStateUninitialized; // +0x62c HUD state / active treasure-event id
    void *m_gotCharaArray = {};              // +0x630 owned-chara working copy (retained)
    void *m_availableInfos = {};             // +0x634 available chara infos (unretained)
    int m_charaRowCount = {};                // +0x638 chara list row count
    int16_t m_listBottom = {};               // +0x63c list content bottom
    // +0x63e: 2 bytes unused padding (dropped; runtime struct, layout not preserved)
    void *m_treasureMusicArray = {};        // +0x640 treasure music data array (retained)
    int m_selMusicPanel = {};               // +0x644 selected music panel index (result popup)
    AcAnchor m_musicAnchor[9] = {};         // +0x648 9 music-panel (x,y) anchor positions
    int m_rouletteMapId = {};               // +0x690 current roulette map id
    AcAnchor m_wallAnchor[9] = {};          // +0x694 9 wall-panel (x,y) anchor positions
    uint32_t m_musicPieceTable[27] = {};    // +0x6dc 9x3 music-piece unlock bitmask grid
    uint32_t m_wallPieceTable[27] = {};     // +0x748 9x3 wallpaper-piece unlock bitmask grid
    uint32_t m_musicPieceTableDup[27] = {}; // +0x7b4 music grid duplicate
    uint32_t m_wallPieceTableDup[27] = {};  // +0x820 wallpaper grid duplicate
    float m_squareFrameIdx = {};            // +0x88c square text-x / slot index (stored as float)
    float m_squareTextY = {};               // +0x890 current square text y
    // Named values held per entry of m_boardSquareState (and the record's
    // boardSquareState). Positive values 1..0x7e are a countdown of highlight
    // animation frames remaining, decremented toward idle each tick; these two are
    // the named non-countdown states.
    enum BoardSquareState : int8_t {
        kBoardSquareIdle = 0,          // no animation, no pending event
        kBoardSquareEventPending = -1, // 0xff in the byte: permanent marker; the
                                       // per-frame tick skips it (it is negative)
                                       // until the square's event fires and clears
                                       // it back to idle
    };
    // Per-square board-cell animation/event state, one signed byte per square,
    // indexed by TreasureMap::Node::slotId (the square's slot id, 0..14). Copied
    // to/from the pending record's boardSquareState (+0x35). Ghidra: a per-frame
    // tick (loop at 0x9c... in AcMainTask_update) decrements every positive entry
    // toward idle; the -1 sentinel is negative, so the tick skips it and it
    // persists until the square's event fires (mark-square state 0x22) and resets
    // it to idle. Every binary read site casts to signed char, so the element type
    // is int8_t (which drops those casts here).
    int8_t m_boardSquareState[15] = {}; // +0x894
    // +0x8a3: 1 bytes unused padding (dropped; runtime struct, layout not preserved)
    void *m_skillInfo = {};                  // +0x8a4 active CharaInfo (unretained)
    const SkillDataStruct *m_skillData = {}; // +0x8a8 active SkillDataStruct
    int16_t m_rouletteMode = {};             // +0x8ac roulette mode / result value
    int16_t m_wonCharaId =
        {}; // +0x8ae rarity-weighted RNG chara award; saved + loads sugo_chara_%03d
    uint8_t m_rankBadgeType = {};       // +0x8b0 rank badge type (>=4 hidden)
    uint8_t m_goalType = {};            // +0x8b1 goal reward type (1 chara / 2 sound)
    int16_t m_rouletteDigit = {};       // +0x8b2 roulette-result digit value
    int16_t m_activeType4SquareId = {}; // +0x8b4 latched type-4 event-square id (-1 none)
    int16_t m_activeType3SquareId = {}; // +0x8b6 latched type-3 event-square id (-1 none)
    int8_t m_listHalveCount =
        {}; // +0x8b8 >0 halves the list bottom; +on roulette 0x14-0x17; saved listHalveCount
    int8_t m_treasureProgress =
        {}; // +0x8b9 *5+25 (cap 100) for treasure-event 10; +in state 0x1d; saved treasureProgress
    // +0x8ba: 2 bytes unused padding (dropped; runtime struct, layout not preserved)
    int m_readNo = {};    // +0x8bc board-story read progress
    int m_readCount = {}; // +0x8c0 board-story page count
    // +0x8c4 skill-panel info block: update copies the selected skill's name/text
    // records here (the s__* string-table entries) when the skill panel opens.
    uint8_t m_skillInfoBuffer[128] = {}; // +0x8c4
    void *m_mapName = {};                // +0x944 map display name (retained)
    void *m_nextTask = {};               // +0x948 follow-on task activated on dispose
    int m_badgePulse = {};               // +0x94c collection-complete badge pulse phase
    int m_transitionAlpha = {};          // +0x950 background transition overlay alpha
    int m_dlgLayout954 = {};             // +0x954 dialog layout constant (write-only)
    int m_dlgLayoutA[12] = {}; // +0x958 device-branched dialog layout constants (write-only)
    // +0x988: 8 bytes unused padding (dropped; runtime struct, layout not preserved)
    int m_dlgPanelW = {};      // +0x990 two-button dialog panel width
    int m_dlgPanelH = {};      // +0x994 panel height
    int m_dlgBtn1X = {};       // +0x998 button1 x
    int m_dlgBtn1Y = {};       // +0x99c button1 y
    int m_dlgBtn1W = {};       // +0x9a0 button1 w
    int m_dlgBtn1H = {};       // +0x9a4 button1 h
    int m_dlgBtn2X = {};       // +0x9a8 button2 x
    int m_dlgBtn2Y = {};       // +0x9ac button2 y
    int m_dlgBtn2W = {};       // +0x9b0 button2 w
    int m_dlgBtn2H = {};       // +0x9b4 button2 h
    int m_dlgLayoutB[16] = {}; // +0x9b8 device-branched dialog/friend layout constants (write-only)
    // update()'s switch dispatches on this. The values are the full set of the
    // binary's dispatch table at 0x99e96, which has 78 entries covering 0x00 to
    // 0x4d contiguously; each entry has its own handler.
    enum AcMainState {
        // Build the select / map scene and start the BGM.
        kAcMainStateInit = 0,
        // Fade out, restore the BGM stack, and push map-select.
        kAcMainStateFadeIn = 1,
        // Wait for, then load, the pending treasure sub-map.
        kAcMainStateTreasureCheck = 2,
        // Switch the scene to fade-in, save the tmp record, play the board layers, and arm the
        // reveal countdown.
        kAcMainStateBoardReveal = 3,
        // Interactive board hub: roulette intro, drag, and tap routing.
        kAcMainStateBoardIdle = 4,
        // Arm the accelerating scroll ease that recentres the board on the current square, then
        // fill the roulette step-value table.
        kAcMainStateRouletteScrollArm = 5,
        // Advance the recentring ease each frame; on the frame it lands, open the roulette and
        // pick the spin speed from the active treasure event.
        kAcMainStateRouletteScrollWait = 6,
        // Hand the opening animation over to the spinning loop, tick the step cursor, and stop
        // the wheel on the next slot boundary when the player touches the screen.
        kAcMainStateRouletteSpin = 7,
        // Decelerate and park the wheel, commit and persist the rolled step value, then release
        // the board — or hold it on an odd/even gate square whose message goes up instead.
        kAcMainStateRouletteStop = 8,
        // Board hub variant entered when a bonus map is active.
        kAcMainStateBoardIdleBonus = 9,
        // Finish one step of the board walk: wait for both eases, latch the junction id, step
        // m_curNode along the chosen link, burn one move, and decide whether to walk again
        // (state 9) or stop (state 0x0d).
        kAcMainStateBoardStepAdvance = 0x0a,
        // Open the board-square message: play the square SE, park the message board over or
        // under the player token, freeze it, and set the rank badge to the message-open type.
        kAcMainStateSquareMessageOpen = 0x0b,
        // Hold the square message on screen, redrawing its body every frame; a tap plays the
        // cancel SE, clears the message board, and returns to the board-reveal state.
        kAcMainStateSquareMessageRead = 0x0c,
        // The walk has stopped: settle the move state, re-park the message board, age every
        // square's highlight countdown, then route on the square kind to pick the arrival SE
        // and the rank-badge type before handing over to the label state.
        kAcMainStateSquareArrive = 0x0d,
        // Hold on the tapped square's comment board and route as soon as a finger lifts or the
        // board draws nothing.
        kAcMainStateSquareMessage = 0x0e,
        // Light the direction arrow for every cardinal neighbour the current square has, then
        // hand over to the map-drag state so the player can pick one.
        kAcMainStateShowArrows = 0x0f,
        // Sugoroku map drag-scroll.
        kAcMainStateMapDrag = 0x10,
        // The goal square was tapped: play the goal SE, arm the friend-meet fade, roll and hand
        // out the goal reward, flush the record, detect a just-completed music/wallpaper
        // collection, upload the goal, create the next area's record and arm GOAL_OPEN.
        kAcMainStateGoalAward = 0x11,
        // Wait for GOAL_OPEN to finish, kick the LIFTING_GAOL_BOARD layer matching the reward
        // that was just handed out, then hold until it has played out and the player taps.
        kAcMainStateGoalRewardShow = 0x12,
        // If this goal completed the map's nine music pieces, play LIFTING_MUSIC once and hold
        // until it finishes and the player taps; otherwise fall straight through.
        kAcMainStateMusicCompleteShow = 0x13,
        // If this goal completed the map's nine wallpaper pieces, play LIFTING_WALL once and
        // hold until it finishes and the player taps; otherwise fall straight through.
        kAcMainStateWallCompleteShow = 0x14,
        // If the goal opened a new area record, play LIFTING_MAP once and hold for a tap; when
        // there is nothing to reveal it instead arms the 30-frame fade-out the next state waits
        // on.
        kAcMainStateNewMapShow = 0x15,
        // Once the fade-out has finished, reset the board-story read progress if the player
        // reached the last page, swap the shared system-SE pool, reload the roulette SEs, and
        // go back to the map-select fade (state 1).
        kAcMainStateGoalFinish = 0x16,
        // A wallpaper-piece square was tapped: if the piece is already owned drop back to the
        // board reveal, otherwise play the item-get SE, OR the piece into the pending record,
        // reload the collection grids and arm GET_WALL.
        kAcMainStateWallPieceGet = 0x17,
        // Hold while the GET_WALL piece-reveal overlay finishes, then drop back into the board
        // loop.
        kAcMainStateWallPieceWait = 0x18,
        // The player landed on a music-piece square: bank that square's piece bit into the
        // pending record and arm the GET_MUSIC reveal.
        kAcMainStateMusicPieceGrant = 0x19,
        // Hold while the GET_MUSIC piece-reveal overlay finishes, then drop back into the board
        // loop.
        kAcMainStateMusicPieceWait = 0x1a,
        // The goal payout: mark the friend meet consumed, then reveal one randomly-chosen
        // awarded piece the collection lacks, or pay the goal's friendship out as treasure
        // points when there is nothing left to reveal.
        kAcMainStateGoalReward = 0x1b,
        // Hold while the goal payout plays; a tap cuts the goal board short, and the state only
        // advances once both piece-reveal overlays and the goal board are idle.
        kAcMainStateGoalRewardWait = 0x1c,
        // The player landed on a warp square: resolve the partner square, unless the board-
        // effect slot that suppresses warps is still counting down.
        kAcMainStateWarpBegin = 0x1d,
        // Play the warp SE, park the EFF_WARP_3 overlay over the player token in screen space,
        // arm it, and raise the warp squish flag.
        kAcMainStateWarpEffect = 0x1e,
        // The warp lands: once EFF_WARP_3 is done, commit the partner square as the current
        // one, refit the scroll bounds and raise the warp flash.
        kAcMainStateWarpArrive = 0x1f,
        // Accelerate and ease the map scroll to the warp destination; when it settles, play the
        // arrival SE, rewind the warp overlay over the player token, and wait for it.
        kAcMainStateWarpScroll = 0x20,
        // Hold until the warp overlay finishes playing back, then clear the warp animation gate
        // and return to the board.
        kAcMainStateWarpInWait = 0x21,
        // Apply the landed board square's gimmick: dispatch on the square's slotId (0..14) and
        // arm, clear or step the matching m_boardSquareState entry.
        kAcMainStateSquareApply = 0x22,
        // Hold while the square-select effect overlay plays, then drop the square-animation
        // gate.
        kAcMainStateSquareAnimWait = 0x23,
        // Pick the random buttobi (fly-to) destination square and hand over to the warp-out
        // animation.
        kAcMainStateButtobiPick = 0x24,
        // Start the skill effect: arm the effect overlay's one-shot, anchor it over the player
        // token, and play the skill SE.
        kAcMainStateSkillEffect = 0x25,
        // Hold while the skill-effect overlay plays, then apply the roulette result: warps,
        // direction flips, trap-square clears (which set the rank badge), the treasure-progress
        // bump, or the visitor request.
        kAcMainStateSkillEffectWait = 0x26,
        // Wait out the visitor HTTP request kicked by roulette mode 0x11: on success dismiss
        // the communicating overlay, on failure refund the skill's treasure-point cost and
        // report the failure.
        kAcMainStateVisitorWait = 0x27,
        // Tick the goal/friend reveal counter; on frame 15 swap in the goal portrait and the
        // pending record's goal name, and past frame 29 hand back to the board-reveal state.
        kAcMainStateFriendMeetAnim = 0x28,
        // Open the character-change panel: seed both page indices from the active character's
        // grid page, load that page's textures, hand them to the drawn slots and start the open
        // sweep.
        kAcMainStateCharaChangeOpen = 0x29,
        // Hold until the character-select open sweep settles, then hide the sugoroku board
        // behind the panel on a phone layout.
        kAcMainStateCharaChangeOpenWait = 0x2a,
        // The character-select hub: settle a committed page flip, then route the frame's tap to
        // the close button, the two page arrows, the character-lottery button or the 2x3 owned-
        // character grid.
        kAcMainStateCharaSelectIdle = 0x2b,
        // Spend five tickets on the character lottery: arm the gacha overlay, fire the play-log
        // beacon, draw the awarded character (server list, else a rarity-weighted pick over the
        // missing ones), bank the spend and load the award portrait.
        kAcMainStateCharaGachaRoll = 0x2c,
        // Hold the gacha overlay; once its play head passes frame 146 swap the awarded
        // character's grid portrait in (only while its page is the one on screen), and on the
        // next tap extend the overlay into its closing run.
        kAcMainStateCharaGachaReveal = 0x2d,
        // The gacha overlay has closed: drop the award portrait and refresh the owned-character
        // working copy so the grid redraws with the new character.
        kAcMainStateCharaGachaClose = 0x2e,
        // The player picked a character: load its board portrait into the scratch texture slot
        // and open the confirmation panel.
        kAcMainStateCharaSelectApply = 0x2f,
        // Character-change confirmation: wait for the SELECTION_CHARA_OPEN overlay to settle,
        // then commit the picked character on a tap inside the confirm rect, or treat any other
        // tap as a cancel.
        kAcMainStateCharaConfirm = 0x30,
        // Drop the character-confirm overlay and run its close animation, returning to the
        // character list.
        kAcMainStateCharaConfirmCancel = 0x31,
        // Start the character-select screen's close: park the arrow and open overlays, run
        // CHARACTER_SELECTION_OUT, clear the dim and re-enable the board draw.
        kAcMainStateCharaSelectClose = 0x32,
        // Wait for CHARACTER_SELECTION_OUT to finish, free the chara page textures, and return
        // to the board-reveal state.
        kAcMainStateCharaSelectCloseWait = 0x33,
        // After a committed character change, park both open overlays and start
        // SELECTION_CHARA_CLOSE and CHARACTER_SELECTION_OUT, re-enabling the board draw.
        kAcMainStateCharaChangeClose = 0x34,
        // Wait for the close overlays, free the chara page textures, park SELECT_ARROW, and
        // return to the board-reveal state.
        kAcMainStateCharaChangeCloseWait = 0x35,
        // Play the collection-select menu's opening overlay once.
        kAcMainStateCollectionOpen = 0x36,
        // Wait for the collection-menu opening overlay, then hide the sugoroku board behind it
        // on phones.
        kAcMainStateCollectionOpenWait = 0x37,
        // Collection-menu tap routing: three hit rects sending the player to the music-piece
        // board, the wallpaper board, or back out.
        kAcMainStateCollectionMenu = 0x38,
        // Open the music-piece collection board, arming the transition dim on the pad layout.
        kAcMainStateMusicPieceOpen = 0x39,
        // Wait for the music-piece board to finish opening, then park the collection-menu layer
        // and hand over to the board's own state.
        kAcMainStateMusicPieceOpenWait = 0x3a,
        // The music-piece collection board is up and interactive: tap a panel to open its
        // reveal overlay, or tap the close button to leave.
        kAcMainStateMusicPieceView = 0x3b,
        // Hold until the MUSIC_PEACE_OPEN reveal overlay has finished playing in, then free the
        // reveal SE slot and show the piece list.
        kAcMainStateMusicPieceRevealWait = 0x3c,
        // The music-piece reveal is on screen: advance the reveal and result-overlay frames,
        // and on a tap persist every newly revealed piece to Core Data (the inlined
        // SaveCoreDataMusicPieceView) before returning to the board.
        kAcMainStateMusicPieceReveal = 0x3d,
        // Open the wallpaper-piece collection board: play the WALL_PEACE_S panel in and load
        // page 0's nine nail textures.
        kAcMainStateWallBoardOpen = 0x3e,
        // Hold until the WALL_PEACE_S panel has slid in, then park the collection-select panel
        // and hand over to the interactive board.
        kAcMainStateWallBoardOpenWait = 0x3f,
        // The wallpaper-piece collection board is up and interactive: tap a panel to open its
        // reveal (loading that page's board artwork and recomputing the page-complete flag), or
        // tap the close button to leave.
        kAcMainStateWallBoardIdle = 0x40,
        // iPad-only close of the wall-piece board: wait for the WALL_PEACE_S panel to finish
        // rewinding, drop the nine wall-nail textures, hand back to the board reveal.
        kAcMainStateWallBoardClose = 0x41,
        // Runs while WALL_PEACE_OPEN (roulette layer 9) plays the wallpaper open animation,
        // fading the save button in on the layer's own progress; advances to the full-size view
        // when the layer settles.
        kAcMainStateWallPieceOpen = 0x42,
        // The full-size wallpaper view: steps the two reveal frame counters, and on a tap
        // either arms the camera-roll save (inside the save button, once the map's nine pieces
        // are owned) or closes back to the piece board, persisting any newly-revealed pieces.
        kAcMainStateWallPieceView = 0x43,
        // Builds the wallpaper file name from the map's nail index and the device's wallpaper
        // height and hands it to MainViewController's asynchronous camera-roll save.
        kAcMainStateWallSaveBegin = 0x44,
        // Polls the asynchronous camera-roll save; on failure raises the permission alert and
        // returns to the wallpaper view, on success plays the WALL_SAVE_COM confirmation once.
        kAcMainStateWallSaveWait = 0x45,
        // The "saved" confirmation panel: a tap once WALL_SAVE_COM has settled plays the decide
        // SE, runs the layer backwards and returns to the wallpaper view.
        kAcMainStateWallSaveDone = 0x46,
        // Leaves the wallpaper collection screen: rewinds the collection-open panel, arms the
        // collection-out panel, makes the board visible again and drops the nail textures.
        kAcMainStateCollectionClose = 0x47,
        // Holds until the collection-out panel finishes, then hands back to the board reveal.
        kAcMainStateCollectionCloseWait = 0x48,
        // Starts the standard 30-frame fade-out that precedes a full scene rebuild.
        kAcMainStateMapReloadBegin = 0x49,
        // Once the fade-out has finished and the decide SE has gone quiet, tears the sugoroku
        // scene down, rebuilds it and restarts at the fade-in state.
        kAcMainStateMapReloadWait = 0x4a,
        // Begin the exit fade-out (no pending sub-map).
        kAcMainStateExitBegin = 0x4b,
        // Wait for the exit fade-out to finish.
        kAcMainStateExitWait = 0x4c,
        // Fade done: spawn MenuMainTask and dispose this task.
        kAcMainStateExitToMenu = 0x4d,
    };
    AcMainState m_state = {}; // +0x9f8 play-data state machine field (update switch
                              // dispatches on it)
    // +0x9fc: 4 bytes unused padding (dropped; runtime struct, layout not preserved)
    // Per-frame touch classification produced by update()'s preamble
    // (reconstruction-only: in the binary these are shared stack locals of the
    // one megafunction, hoisted here as the function is de-inlined into per-state
    // methods). They are NOT part of the binary object's flat layout, so they
    // trail it.
    bool m_frameDragging = false;                  // a finger is currently held down
    bool m_frameTapped = false;                    // a tap landed this frame
    const neTouchPoint *m_frameTapTouch = nullptr; // the tapped touch (when m_frameTapped)
    // The touch the preamble last saw released, held in r6 across both release arms (0x99dc0).
    // This is not m_frameTapTouch: the preamble stops classifying a tap once the finger has
    // travelled more than 10 units, so a released drag leaves m_frameTapTouch null while this
    // one stays set. State 0x0e reads it at 0x9a66a to decide whether to route the square tap.
    const neTouchPoint *m_frameReleasedTouch = nullptr;
};

/**
 * The group-5 sugoroku per-frame render pass the scene installs as its draw callback.
 *
 * AepDrawLayer's type-3 dispatch invokes it with the full per-frame draw arguments, matching
 * AepGroupDrawFn. It is a ~5.8 KB draw routine, reconstructed separately.
 *
 * @param child The board element id to render; see BoardElem.
 * @param frame The remapped child frame.
 * @param x Composed translation x.
 * @param y Composed translation y.
 * @param scaleX Composed scale x as a percentage.
 * @param scaleY Composed scale y as a percentage.
 * @param anchorX Pivot x.
 * @param anchorY Pivot y.
 * @param color Colour (brightness) channel value.
 * @param alpha Alpha channel value.
 * @param rotation Composed rotation.
 * @param blend Composed blend word.
 * @param clipRect The four-int clip rect.
 * @param priority Ordering-table priority.
 * @param context The owning AcMainTask.
 * @ghidraAddress 0xa3724
 */
void AcMainSugorokuDraw(int child,
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
                        void *context);

/**
 * Unlock the board-8 bonus treasure record when its prerequisite purchased songs are
 * present on disk.
 *
 * It goes through TreasureData and MusicManager.
 *
 * @ghidraAddress 0xa345c
 */
void AcMainUnlockBonusTreasure();
