//
//  AcMainTask.h
//  pop'n rhythmin
//
//  The ARCADE-mode task: arcade song select + sugoroku treasure map + option
//  select + note play, driving the arcade note engine (AcNoteMng, already
//  reconstructed). Launched by the mode menu (MenuMainTask). Reconstructed from
//  Ghidra project rb420, program PopnRhythmin (ctor AcMainTask_ctor
//  FUN_00099ab0, update AcMainTask_update FUN_00099d18).
//
//  AcMainTask_update is the app's largest function (~24 KB / ~4300 decompiled
//  lines, heavily inlined). It is reconstructed in pieces from the on-disk
//  decompile
//  (.decompile/AcMainTask_update.c): update() is the touch/SE preamble + a
//  dispatch over the play-data state (@ +0x9f8) into one handler method per
//  state; each state's inlined body is lifted into its own method. Progress
//  tracked in STUBS.md.
//
//  ---- work area (this class IS the ~0xa00-byte play-data struct) ----
//  This is a runtime-only struct (never serialised to/from a file), so its exact
//  byte layout is NOT preserved: the `// +0xNN` comments cross-reference each
//  field's binary offset, but unused gaps are dropped (noted inline) rather than
//  padded, and members are reached by name, not raw offset. A
//  few device-branched select/dialog layout regions (m_selSceneLayout,
//  m_dlgLayoutA/B, m_dlgLayout954) are pure coordinate constants the setup pass
//  writes and only the not-yet-reconstructed select/option draw states read;
//  they are kept as documented write-only arrays (their interior roles are
//  best-effort). The play state @ +0x9f8 is what update() dispatches on; the
//  embedded arcade RNG @ +0x4f4 is a real Random member (auto-constructed and
//  destroyed).
//

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

// Draw-dispatch keys into m_boardUserNo: each entry is a getUserNo element id
// that the group-5 board draw callback (AcMainSugorokuDraw) matches the drawn
// `child` against to render one sugoroku / chara-select board element. Names are
// from the callback's per-element branches.
enum BoardElem {
    kBoardTreasurePoint = 0,    // treasure-point 4-digit counter
    kBoardCharaColRightA = 1,   // chara-select right column (paired with RightB)
    kBoardCharaColLeftA = 2,    // chara-select left column (paired with LeftB)
    kBoardCharaBacking = 3,     // chara backing panel
    kBoardCharaColLeftB = 4,    // chara-select left column (paired with LeftA)
    kBoardCharaColRightB = 5,   // chara-select right column (paired with RightA)
    kBoardCharaName = 6,        // selected chara name
    kBoardSkillText = 7,        // skill name / id / description
    kBoardMusicPieceGrid = 8,   // music-piece unlock grid
    kBoardMusicPanel = 9,       // music-panel grid (music anchors)
    kBoardSmallPanel = 10,      // small chara panel
    kBoardMusicReveal = 11,     // music-piece reveal overlay
    kBoardWallPieceGrid = 12,   // wallpaper-piece unlock grid
    kBoardWallPanel = 13,       // wall-panel grid (wall anchors)
    kBoardWallReveal = 14,      // wall-piece reveal overlay
    kBoardFullBg = 15,          // full-board background panel
    kBoardStepValue = 16,       // per-skill roulette step-value digits
    kBoardNewCharaButton = 17,  // "new chara available" button
    kBoardListPanel = 18,       // chara list panel
    kBoardListScrollBar = 19,   // chara list scroll bar
    kBoardCompleteBadge = 20,   // collection-complete badge (pulsing)
    kBoardCharaTickets = 21,    // owned chara-ticket count (<= 99)
    kBoardRouletteDigit = 22,   // roulette-result digit
    kBoardBonusCount = 23,      // bonus count (ticket glyphs)
    kBoardRouletteIcon = 24,    // roulette-result event icon
    kBoardRouletteCaption = 25, // roulette-result caption text
};

// Frame handles into m_boardFrame, resolved in setup from getFrameNo(5,
// kFrmBoard[i]); each entry is named after its board frame asset. The DEFENSE_*
// / SQUARE frames are the roulette-result event frames the result switch selects
// by outcome mode.
enum BoardFrame {
    kBoardFrameCharaKoma = 0,        // CHARA_KOMA00
    kBoardFrameMusicPeaceBoardS = 1, // MUSIC_PEACE_BOARD_S
    kBoardFrameJacketQuestion = 2,   // JACKET_QUESTION
    kBoardFrameJacketDiscovery = 3,  // JACKET_DISCOVERY
    kBoardFrameRoulette = 4,         // BT_ROULETTE
    kBoardFrameRouletteNo = 5,       // BT_ROULETTE_NO
    kBoardFrameRouletteEvent = 6,    // BT_ROULETTE_EVENT
    kBoardFrameRouletteEventNo = 7,  // BT_ROULETTE_EVENT_NO
    kBoardFrameGatya = 8,            // BT_GATYA
    kBoardFrameGatya01 = 9,          // BT_GATYA01
    kBoardFramePageBefore = 10,      // PAGE_BEFORE
    kBoardFramePageNext = 11,        // PAGE_NEXT
    kBoardFrameWarning = 12,         // WARNING
    kBoardFrameWallSave = 13,        // BT_WALL_SAVE
    kBoardFrameDefense0100 = 14,     // DEFENSE_01_00
    kBoardFrameDefense0101 = 15,     // DEFENSE_01_01
    kBoardFrameDefense0102 = 16,     // DEFENSE_01_02
    kBoardFrameDefense0103 = 17,     // DEFENSE_01_03
    kBoardFrameDefense0104 = 18,     // DEFENSE_01_04
    kBoardFrameDefense00 = 19,       // DEFENSE_00
    kBoardFrameDefense02 = 20,       // DEFENSE_02
    kBoardFrameSquare0100 = 21,      // BT_SQUARE01_00
    kBoardFrameDefense0300 = 22,     // DEFENSE_03_00
    kBoardFrameDefense0301 = 23,     // DEFENSE_03_01
    kBoardFrameDefense0302 = 24,     // DEFENSE_03_02
    kBoardFrameDefense0303 = 25,     // DEFENSE_03_03
};

// A resolved Aep layer handle paired with its frame count; the setup pass always
// resolves the two together (getLyrNo then layerFrameCount).
struct AcLayerRef {
    int lyr = 0;        // getLyrNo handle
    int frameCount = 0; // layerFrameCount(lyr)
};

// An integer (x, y) board-panel anchor position (a grid cell's top-left after
// the per-cell anchor offset).
struct AcAnchor {
    int x = 0;
    int y = 0;
};

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
    void update(int deltaMs) override; // Ghidra: AcMainTask_update (FUN_00099d18)

private:
    // Per-state handlers, lifted from AcMainTask_update's inlined switch cases.
    void stateInit();          // case 0  (setup, then BGM or the no-treasure path)
    void stateFadeIn();        // case 1  (fade the select scene, open the sugoroku map)
    void stateTreasureCheck(); // case 2  (read the temp-treasure record, branch)
    void stateBoardReveal();   // case 3  (fade the board in, save the tmp, arm the move count)
    void stateBoardIdle(neGraphics &gfx); // case 4 (roulette intro, drag; tap routing is TODO)
    void stateExitBegin();                // case 0x4b (start the exit fade-out)
    void stateExitWait();                 // case 0x4c (wait for the exit fade-out to finish)
    void stateExitToMenu();               // case 0x4d (spawn MenuMainTask, dispose this task)

    // Scene build / map load (their own reconstruction pieces).
    void setupScene();      // Ghidra: FUN_0009fc90 (build the select/map scene)
    void loadTreasureMap(); // Ghidra: FUN_000a0b58 (DB synced; was mislabeled
                            // charaSelectReloadData — it loads map_%03d.map, see the .mm plate)

    // setupScene() reconstruction helpers (big resolve/build/load loops of
    // FUN_0009fc90).
    void setupResolveHandles(); // the ~50 getLyrNo/getFrameNo/getUserNo tables
    void setupBuildOverlays();  // the ~35 AepLyrCtrl overlay objects
    void setupLoadTextures();   // circle/chara/number/event textures + BGM prep

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
    int sugorokuDrawSkillPanel();            // FUN_000a14a0
    int sugorokuDrawButtonHitTest();         // FUN_000a178c
    bool sugorokuEasePositionPairA();        // FUN_000a19dc
    bool sugorokuEasePositionPairB();        // FUN_000a1ac8
    void sugorokuDrawSquareText();           // FUN_000a1bb4
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
    AcLayerRef m_iconMental[4] = {};       // ICON_MENTAL00..03 rank-badge layers + frame
                                           // counts (binary: lyr @+0x258, frameCount @+0x268)
    int m_animFrameCtr = {};               // +0x278 shared per-frame animation counter
    int m_musicPeaceLyr[9] = {};           // +0x27c MUSIC_PEACE00..08 layers
    int m_wallPeaceLyr[9] = {};            // +0x2a0 WALL_PEACE00..08 layers
    int m_musicPeaceFrames = {};           // +0x2c4 MUSIC_PEACE frame count
    int m_wallPeaceFrames = {};            // +0x2c8 WALL_PEACE frame count
    int m_pieceRevealFrame = {};           // +0x2cc frame for a newly-collected piece reveal
    int m_boardFrame[26] = {};             // +0x2d0 board frame numbers, indexed by BoardFrame
    int m_base1Frame[11] = {};             // +0x338 11 BASE_* square frame numbers
    int m_rouletteMoveFrame = {};          // +0x364 BT_ROULETTE_MOVE frame (pad only)
    int m_base08Frame[10] = {};            // +0x368 10 BASE_08_* warp frames
    int m_base05Frame[4] = {};             // +0x390 4 BASE_05_* sub-map-flag frames
    int m_triangle0Frame[6] = {};          // +0x3a0 TRIANGLE00_* forward-arrow frames
    int m_triangle1Frame[6] = {};          // +0x3b8 TRIANGLE01_* back-arrow frames
    int m_boardUserNo[26] = {};            // +0x3d0 getUserNo handles, indexed by BoardElem
    int m_rouletteSe[15] = {};             // +0x438 15 roulette SE source ids
    uint8_t m_selScratch[36] = {};         // +0x474 selection-index scratch (memset 0xff)
    int m_rouletteSeInst = {};             // +0x498 roulette-hit SE playing instance (-1 idle)
    uint8_t m_selScratch2[20] = {};        // +0x49c remainder of the selection scratch
    std::unique_ptr<TreasureMap> m_map;    // +0x4b0 loaded TreasureMap
    const TreasureMap::Node *m_nodes = {}; // +0x4b4 map node array
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
    bool m_boardBgmLoaded = {}; // +0x5d8 board BGM loaded flag
    // +0x5d9: 7 bytes unused padding (dropped; runtime struct, layout not preserved)
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
    // +0x5f4: 3 bytes unused padding (dropped; runtime struct, layout not preserved)
    bool m_padDisplay = {}; // +0x5f7 iPad display flag
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
    // update()'s switch dispatches on this. The values are sparse (from the
    // binary); states 4 and 0x10 share the map drag-scroll body.
    enum AcMainState {
        kAcMainStateInit = 0,           // build the select / map scene, start the BGM
        kAcMainStateFadeIn = 1,         // fade out, restore the BGM stack, push map-select
        kAcMainStateTreasureCheck = 2,  // wait for / load the pending treasure sub-map
        kAcMainStateBoardReveal = 3,    // switch the scene to fade-in, save the tmp record,
                                        // play the board layers, arm the reveal countdown
        kAcMainStateBoardIdle = 4,      // interactive board hub: roulette intro, drag, tap routing
        kAcMainStateBoardIdleBonus = 9, // board hub variant entered when a bonus map is active
        kAcMainStateMapDrag = 0x10,     // sugoroku map drag-scroll
        kAcMainStateExitBegin = 0x4b,   // begin the exit fade-out (no pending sub-map)
        kAcMainStateExitWait = 0x4c,    // wait for the exit fade-out to finish
        kAcMainStateExitToMenu = 0x4d,  // fade done: spawn MenuMainTask, dispose this task
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
};

// The group-5 sugoroku per-frame render pass the scene installs as its draw
// callback, invoked by AepDrawLayer's type-3 dispatch with the full per-frame
// draw args (AepGroupDrawFn); the trailing `context` is the owning AcMainTask.
// (Ghidra: FUN_000a3724 @ 0xa3724 — a ~5.8 KB draw routine, reconstructed
// separately.)
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

// Unlock the board-8 bonus treasure record when its prerequisite purchased
// songs are present on disk (Ghidra: FUN_000a345c; uses TreasureData +
// MusicManager). No args.
void AcMainUnlockBonusTreasure();

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
