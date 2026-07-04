//
//  AcMainTask.h
//  pop'n rhythmin
//
//  The ARCADE-mode task: arcade song select + sugoroku treasure map + option select +
//  note play, driving the arcade note engine (AcNoteMng, already reconstructed). Launched
//  by the mode menu (MenuMainTask). Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (ctor AcMainTask_ctor FUN_00099ab0, update AcMainTask_update FUN_00099d18).
//
//  AcMainTask_update is the app's largest function (~24 KB / ~4300 decompiled lines,
//  heavily inlined). It is reconstructed in pieces from the on-disk decompile
//  (.decompile/AcMainTask_update.c): update() is the touch/SE preamble + a dispatch
//  over the play-data state (@ +0x9f8) into one handler method per state; each state's
//  inlined body is lifted into its own method. Progress tracked in STUBS.md.
//
//  ---- work area (this class IS the ~0xa00-byte play-data struct) ----
//  C_TASK's base is exactly 0x28 bytes, so the members below land at their true binary
//  offsets. Every scalar/array the ctor / setup / map-load / sugoroku-draw passes reach
//  by flat `*(T*)(this+off)` in the binary is named at its exact offset (`// +0xNN`);
//  genuine gaps are `_rsvd_NN[]` fillers. A few device-branched select/dialog layout
//  regions (m_selSceneLayout, m_dlgLayoutA/B, m_dlgLayout954) are pure coordinate
//  constants the setup pass writes and only the not-yet-reconstructed select/option draw
//  states read; they are kept as documented write-only arrays (their interior roles are
//  best-effort). The play state @ +0x9f8 is what update() dispatches on; the embedded
//  arcade RNG @ +0x4f4 is placement-constructed by the ctor and destroyed by the dtor.
//

#pragma once

#include <cstdint>

#include "C_TASK.h"
#include "Random.h"        // embedded PRNG at this+0x4f4 (Ghidra: FUN_00062b20)
#include "TreasureMap.h"   // TreasureMap + nested Node / ConnectStruct (sugoroku draw params)

class AepManager;
class AepLyrCtrl;
class neTextureForiOS;
struct SkillDataStruct;    // System/../SkillData.h (pointer member only)
struct neTouchPoint;       // System/src/Render/neGraphics.h (touch pool record)

class AcMainTask : public C_TASK {
public:
    AcMainTask();                        // Ghidra: AcMainTask_ctor (FUN_00099ab0)
    ~AcMainTask() override;              // @ 0x99ba4 (acMainTaskDtor; destroys the RNG + base)
    void update(int deltaMs) override;   // Ghidra: AcMainTask_update (FUN_00099d18)

    // Chara-select page-texture helpers (CharaManager.mm). In the binary these are
    // AcMainTask methods (@ 0xa27f0 / 0xa2a40 / 0xa2b10); reconstructed as free
    // functions, they read this task's private chara arrays/textures by name.
    friend void charaSelectLoadPageTextures(AcMainTask *task, int page);
    friend int  charaSelectFindCharaIndex(AcMainTask *task, int charaId);
    friend void charaSelectReleaseTextures(AcMainTask *task);

private:
    // Per-state handlers, lifted from AcMainTask_update's inlined switch cases.
    void stateInit();          // case 0  (setup, then BGM or the no-treasure path)
    void stateFadeIn();        // case 1  (fade the select scene, open the sugoroku map)
    void stateTreasureCheck(); // case 2  (read the temp-treasure record, branch)

    // Scene build / map load (their own reconstruction pieces).
    void setupScene();         // Ghidra: FUN_0009fc90 (build the select/map scene)
    void loadTreasureMap();    // Ghidra: FUN_000a0b58 (load the sugoroku map data)

    // setupScene() reconstruction helpers (big resolve/build/load loops of FUN_0009fc90).
    void setupResolveHandles();       // the ~50 getLyrNo/getFrameNo/getUserNo tables
    void setupBuildOverlays();        // the ~35 AepLyrCtrl overlay objects
    void setupLoadTextures();         // circle/chara/number/event textures + BGM prep

    // Genuine sub-routines the arcade scene builders call.
    void computeStepValues();         // Ghidra: FUN_000a1950 (fills the m_stepValues table)
    void buildSelectListLayout();     // Ghidra: FUN_000a21a8
    void buildMapCharaLayers();       // Ghidra: FUN_000a2264
    void buildMapPanelLayers();       // Ghidra: FUN_000a2650
    void refreshMapScroll(int mode);  // Ghidra: FUN_000a3550
    void unloadMapBgGroup();          // Ghidra: FUN_000a4e84
    void sugorokuReleaseGoalLayer();  // Ghidra: sibling of FUN_000a4e84 (same teardown effect)

    // Sugoroku board draw / logic sub-passes (Ghidra 0xa14a0..0xa5740). These operate on
    // this task's work area, so they are real members (the "SugorokuMainTask" a prior
    // agent invented was a mis-attribution). The group-5 draw callback drives them.
    int  sugorokuDrawSkillPanel();                                 // FUN_000a14a0
    int  sugorokuDrawButtonHitTest();                              // FUN_000a178c
    bool sugorokuEasePositionPairA();                              // FUN_000a19dc
    bool sugorokuEasePositionPairB();                              // FUN_000a1ac8
    void sugorokuDrawSquareText();                                 // FUN_000a1bb4
    void sugorokuSaveTreasureProgress();                           // FUN_000a1ddc
    void sugorokuSetupScrollBounds();                              // FUN_000a2544
    void sugorokuLoadWallTextures(int page);                       // FUN_000a2b64
    void sugorokuTaskDispose();                                    // FUN_000a2d00
    void sugorokuDrawBoard();                                      // FUN_000a303c
    void sugorokuDrawBackground();                                 // FUN_000a3308
    void sugorokuDrawSquare(const TreasureMap::Node *node);        // FUN_000a4eb4
    void sugorokuDrawPath(const TreasureMap::ConnectStruct *edge); // FUN_000a50dc
    void sugorokuDrawPlayerAndUi();                                // FUN_000a52f0
    void sugorokuDrawFriendMeet();                                 // FUN_000a5740

    // The group-5 sugoroku render callback reaches this task's members through `context`
    // (it will drive the sugoroku* passes above); befriended like AcViewerTask's HUD hook.
    friend void AcMainSugorokuDraw(int child, int frame, int x, int y, int scaleX, int scaleY,
                                   int anchorX, int anchorY, int color, int alpha, int rotation,
                                   uint32_t blend, int *clipRect, uint32_t p17, void *context);

    // ================= work-area layout (offsets are binary-exact) =================
    AepManager *    m_aep = {};                     // +0x28 cached AepManager (every resolve/draw reads it)
    AepLyrCtrl *    m_rouletteLayers[29] = {};      // +0x2c 29 roulette/effect overlay layers (built by setupScene)
    AepLyrCtrl *    m_panelLayers[8] = {};          // +0xa0 8 character/collection select panels
    AepLyrCtrl *    m_arrowLayers[4] = {};          // +0xc0 4 sugoroku hit-flash / direction arrows
    AepLyrCtrl *    m_boardBgLayer = {};            // +0xd0 current board background layer (group 6)
    neTextureForiOS *m_circleTex = {};              // +0xd4 bundled circle.png
    neTextureForiOS *m_boardBgTex = {};             // +0xd8 board background texture
    neTextureForiOS *m_charaTex = {};               // +0xdc active player-character board sprite
    neTextureForiOS *m_goalCharaTex = {};           // +0xe0 goal / friend-meet character portrait
    neTextureForiOS *m_blindCircleTex = {};         // +0xe4 bundled blind_circle.png
    neTextureForiOS *m_reserveTex[5] = {};          // +0xe8 scene textures freed by dispose; populated by unreconstructed states
    neTextureForiOS *m_pointsDigitTex[10] = {};     // +0xfc num_points0..9 glyphs
    neTextureForiOS *m_roulDigitTex[10] = {};       // +0x124 num_roulette_0..9 glyphs
    neTextureForiOS *m_ticketDigitTex[10] = {};     // +0x14c ticket_num0..9 glyphs
    neTextureForiOS *m_charaPagePrevTex[6] = {};    // +0x174 prev-page chara textures
    neTextureForiOS *m_charaPageCurrTex[6] = {};    // +0x18c current-page chara textures
    neTextureForiOS *m_jacketTex[9] = {};           // +0x1a4 9 music-panel jacket textures
    neTextureForiOS *m_wallNailTex[9] = {};         // +0x1c8 9 wall-nail textures
    neTextureForiOS *m_eventTex[12] = {};           // +0x1ec 12 event_0_%03d icons
    int             m_skillBoardLyr[5] = {};        // +0x21c SKILL_COM_BOARD/... layer numbers
    int             m_skillBoardFrames[5] = {};     // +0x230 their frame counts
    uint8_t          _rsvd_244[0x24c - 0x244] = {};   // +0x244
    int             m_musicResultFrame = {};        // +0x24c music collection-result overlay frame
    int             m_wallResultFrame = {};         // +0x250 wall collection-result overlay frame
    uint8_t          _rsvd_254[0x258 - 0x254] = {};   // +0x254
    int             m_iconMentalLyr[4] = {};        // +0x258 ICON_MENTAL00..03 layer numbers
    int             m_iconMentalFrames[4] = {};     // +0x268 their frame counts (rank badge)
    int             m_animFrameCtr = {};            // +0x278 shared per-frame animation counter
    int             m_musicPeaceLyr[9] = {};        // +0x27c MUSIC_PEACE00..08 layers
    int             m_wallPeaceLyr[9] = {};         // +0x2a0 WALL_PEACE00..08 layers
    int             m_musicPeaceFrames = {};        // +0x2c4 MUSIC_PEACE frame count
    int             m_wallPeaceFrames = {};         // +0x2c8 WALL_PEACE frame count
    int             m_pieceRevealFrame = {};        // +0x2cc frame for a newly-collected piece reveal
    int             m_boardFrame[26] = {};          // +0x2d0 26 board/roulette-result frame numbers
    int             m_base1Frame[11] = {};          // +0x338 11 BASE_* square frame numbers
    int             m_rouletteMoveFrame = {};       // +0x364 BT_ROULETTE_MOVE frame (pad only)
    int             m_base08Frame[10] = {};         // +0x368 10 BASE_08_* warp frames
    int             m_base05Frame[4] = {};          // +0x390 4 BASE_05_* sub-map-flag frames
    int             m_triangle0Frame[6] = {};       // +0x3a0 TRIANGLE00_* forward-arrow frames
    int             m_triangle1Frame[6] = {};       // +0x3b8 TRIANGLE01_* back-arrow frames
    int             m_boardUserNo[26] = {};         // +0x3d0 26 getUserNo handles
    int             m_rouletteSe[15] = {};          // +0x438 15 roulette SE source ids
    uint8_t         m_selScratch[0x498 - 0x474] = {}; // +0x474 selection-index scratch (memset 0xff)
    int             m_rouletteSeInst = {};          // +0x498 roulette-hit SE playing instance (-1 idle)
    uint8_t         m_selScratch2[0x4b0 - 0x49c] = {}; // +0x49c remainder of the selection scratch
    TreasureMap *   m_map = {};                     // +0x4b0 loaded TreasureMap
    const TreasureMap::Node *m_nodes = {};          // +0x4b4 map node array
    int             m_edgesPtr = {};                // +0x4b8 edge (ConnectStruct) array pointer, held in an int slot (type-pun)
    const TreasureMap::Node *m_curNode = {};        // +0x4bc current board node
    uint8_t          _rsvd_4c0[0x4c4 - 0x4c0] = {};   // +0x4c0
    uint16_t        m_nodeCount = {};               // +0x4c4 map node count
    int16_t         m_edgeCount = {};               // +0x4c6 map edge count
    float           m_scrollBoxOriginX = {};        // +0x4c8 scroll bounding box origin x
    float           m_scrollBoxOriginY = {};        // +0x4cc scroll bounding box origin y
    float           m_scrollBoxW = {};              // +0x4d0 scroll bounding box width
    uint8_t          _rsvd_4d4[0x4d8 - 0x4d4] = {};   // +0x4d4
    float           m_scrollX = {};                 // +0x4d8 scroll position x
    float           m_scrollY = {};                 // +0x4dc scroll position y
    float           m_clampCentreX = {};            // +0x4e0 scroll clamp centre x
    float           m_clampMinY = {};               // +0x4e4 scroll clamp min y
    float           m_clampCentreX2 = {};           // +0x4e8 scroll clamp centre x (dup)
    float           m_clampMaxY = {};               // +0x4ec scroll clamp max y
    int16_t         m_treasureRaw06 = {};           // +0x4f0 pending record raw0x06
    uint8_t          _rsvd_4f2[0x4f4 - 0x4f2] = {};   // +0x4f2
    Random           m_rng;                         // +0x4f4 embedded arcade RNG (ctor placement-constructs; dtor destroys)
    int             m_dragAnchorId = {};            // +0x508 touch drag anchor id (-1 == none)
    int             m_dragAnchorX = {};             // +0x50c drag anchor x
    int             m_dragAnchorY = {};             // +0x510 drag anchor y
    float           m_scrollBaseX = {};             // +0x514 scroll base x (subtracted for screen space)
    float           m_scrollBaseY = {};             // +0x518 scroll base y
    uint8_t          _rsvd_51c[0x524 - 0x51c] = {};   // +0x51c
    int             m_overlayW = {};                // +0x524 transition-overlay width
    int             m_overlayH = {};                // +0x528 transition-overlay height
    float           m_screenScale = {};             // +0x52c screen scale
    int             m_bgTileW = {};                 // +0x530 background tile width
    int             m_bgTileH = {};                 // +0x534 background tile height
    int             m_selSceneLayout[16] = {};      // +0x538 device-branched select-scene layout constants (write-only; consumed by unreconstructed draw)
    int             m_stepValues[7] = {};           // +0x578 7 per-skill roulette step values
    uint8_t          _rsvd_594[0x5a0 - 0x594] = {};   // +0x594
    int             m_initFlag5a0 = {};             // +0x5a0 ctor writes 3; role opaque (write-only)
    float           m_scrollTargetX = {};           // +0x5a4 scroll ease target x
    float           m_scrollTargetY = {};           // +0x5a8 scroll ease target y
    float           m_scrollVelX = {};              // +0x5ac scroll ease velocity x
    float           m_scrollVelY = {};              // +0x5b0 scroll ease velocity y
    float           m_scrollAccumX = {};            // +0x5b4 scroll ease accumulator x
    float           m_scrollAccumY = {};            // +0x5b8 scroll ease accumulator y
    float           m_playerTargetX = {};           // +0x5bc player ease target x
    float           m_playerTargetY = {};           // +0x5c0 player ease target y
    float           m_playerVelX = {};              // +0x5c4 player ease velocity x
    float           m_playerVelY = {};              // +0x5c8 player ease velocity y
    float           m_playerX = {};                 // +0x5cc player board draw x
    float           m_playerY = {};                 // +0x5d0 player board draw y
    int             m_boardMoveState = {};          // +0x5d4 board move / warp state
    uint8_t         m_boardBgmLoaded = {};          // +0x5d8 board BGM loaded flag
    uint8_t          _rsvd_5d9[0x5e0 - 0x5d9] = {};   // +0x5d9
    int             m_charaColRight = {};           // +0x5e0 chara-grid right column base index
    int             m_charaColLeft = {};            // +0x5e4 chara-grid left column base index
    int             m_friendAnimFrame = {};         // +0x5e8 friend-meet animation frame
    uint8_t         m_flag5ec = {};                 // +0x5ec per-map flag
    uint8_t         m_flag5ed = {};                 // +0x5ed per-map flag
    uint8_t         m_bgmActive = {};               // +0x5ee select-BGM active flag
    uint8_t         m_warpFlash = {};               // +0x5ef warp flash gate
    uint8_t         m_warpAnim = {};                // +0x5f0 warp squish animation active
    uint8_t          _rsvd_5f1[0x5f2 - 0x5f1] = {};   // +0x5f1
    uint8_t         m_scrolledPastEnd = {};         // +0x5f2 list scrolled-past-end flag (recomputed each frame)
    int             m_field5f3 = {};                // +0x5f3 cleared each map load; role opaque
    uint8_t         m_padDisplay = {};              // +0x5f7 iPad display flag
    uint8_t          _rsvd_5f8[0x5fa - 0x5f8] = {};   // +0x5f8
    uint8_t         m_fadeDir = {};                 // +0x5fa transition fade direction
    uint8_t          _rsvd_5fb[0x5fc - 0x5fb] = {};   // +0x5fb
    int16_t         m_charaId = {};                 // +0x5fc active character id
    int16_t         m_skillCharaId = {};            // +0x5fe skill-panel active character id
    uint8_t          _rsvd_600[0x604 - 0x600] = {};   // +0x600
    int             m_skillPanelX = {};             // +0x604 skill-panel origin x cache
    int             m_skillPanelY = {};             // +0x608 skill-panel origin y cache
    int             m_charaPanelX = {};             // +0x60c chara-panel origin x cache
    int             m_charaPanelY = {};             // +0x610 chara-panel origin y cache
    int             m_layoutAnchorZ = {};           // +0x614 roulette layer anchor z (tall-phone seed)
    int             m_field618 = {};                // +0x618 tall-phone layout seed
    int             m_friendOpacity = {};           // +0x61c friend-meet fade opacity
    int16_t         m_subMapId = {};                // +0x620 pending sub-map id (board*10+sub; -1 none)
    int16_t         m_charaTicket = {};             // +0x622 owned chara tickets
    int             m_treasurePoint = {};           // +0x624 treasure point balance
    int             m_bonusCount = {};              // +0x628 bonus/main-map id (roulette overlay gate)
    int             m_hudState = {};                // +0x62c HUD state (ctor -0x63)
    void *          m_gotCharaArray = {};           // +0x630 owned-chara working copy (retained)
    void *          m_availableInfos = {};          // +0x634 available chara infos (unretained)
    int             m_charaRowCount = {};           // +0x638 chara list row count
    int16_t         m_listBottom = {};              // +0x63c list content bottom
    uint8_t          _rsvd_63e[0x640 - 0x63e] = {};   // +0x63e
    void *          m_treasureMusicArray = {};      // +0x640 treasure music data array (retained)
    int             m_selMusicPanel = {};           // +0x644 selected music panel index (result popup)
    int             m_musicAnchor[18] = {};         // +0x648 9 music-panel (x,y) anchor positions
    int             m_rouletteMapId = {};           // +0x690 current roulette map id
    int             m_wallAnchor[18] = {};          // +0x694 9 wall-panel (x,y) anchor positions
    int             m_musicPieceTable[27] = {};     // +0x6dc 9x3 music-piece unlock grid
    int             m_wallPieceTable[27] = {};      // +0x748 9x3 wallpaper-piece unlock grid
    int             m_musicPieceTableDup[27] = {};  // +0x7b4 music grid duplicate
    int             m_wallPieceTableDup[27] = {};   // +0x820 wallpaper grid duplicate
    int             m_squareFrameIdx = {};          // +0x88c current square frame/slot index
    float           m_squareTextY = {};             // +0x890 current square text y
    uint8_t         m_boardVisited[15] = {};        // +0x894 15-byte board-visited bitmap (from pending record)
    uint8_t          _rsvd_8a3[0x8a4 - 0x8a3] = {};   // +0x8a3
    void *          m_skillInfo = {};               // +0x8a4 active CharaInfo (unretained)
    const SkillDataStruct *m_skillData = {};        // +0x8a8 active SkillDataStruct
    int16_t         m_rouletteMode = {};            // +0x8ac roulette mode / result value
    uint8_t          _rsvd_8ae[0x8b0 - 0x8ae] = {};   // +0x8ae
    uint8_t         m_rankBadgeType = {};           // +0x8b0 rank badge type (>=4 hidden)
    uint8_t         m_goalType = {};                // +0x8b1 goal reward type (1 chara / 2 sound)
    int16_t         m_rouletteDigit = {};           // +0x8b2 roulette-result digit value
    uint8_t          _rsvd_8b4[0x8b8 - 0x8b4] = {};   // +0x8b4
    char            m_field8b8 = {};                // +0x8b8 pending record raw0x52
    char            m_field8b9 = {};                // +0x8b9 pending record raw0x51
    uint8_t          _rsvd_8ba[0x8bc - 0x8ba] = {};   // +0x8ba
    int             m_readNo = {};                  // +0x8bc board-story read progress
    int             m_readCount = {};               // +0x8c0 board-story page count
    uint8_t          _rsvd_8c4[0x944 - 0x8c4] = {};   // +0x8c4
    void *          m_mapName = {};                 // +0x944 map display name (retained)
    void *          m_nextTask = {};                // +0x948 follow-on task activated on dispose
    int             m_badgePulse = {};              // +0x94c collection-complete badge pulse phase
    int             m_transitionAlpha = {};         // +0x950 background transition overlay alpha
    int             m_dlgLayout954 = {};            // +0x954 dialog layout constant (write-only)
    int             m_dlgLayoutA[12] = {};          // +0x958 device-branched dialog layout constants (write-only)
    uint8_t          _rsvd_988[0x990 - 0x988] = {};   // +0x988
    int             m_dlgPanelW = {};               // +0x990 two-button dialog panel width
    int             m_dlgPanelH = {};               // +0x994 panel height
    int             m_dlgBtn1X = {};                // +0x998 button1 x
    int             m_dlgBtn1Y = {};                // +0x99c button1 y
    int             m_dlgBtn1W = {};                // +0x9a0 button1 w
    int             m_dlgBtn1H = {};                // +0x9a4 button1 h
    int             m_dlgBtn2X = {};                // +0x9a8 button2 x
    int             m_dlgBtn2Y = {};                // +0x9ac button2 y
    int             m_dlgBtn2W = {};                // +0x9b0 button2 w
    int             m_dlgBtn2H = {};                // +0x9b4 button2 h
    int             m_dlgLayoutB[16] = {};          // +0x9b8 device-branched dialog/friend layout constants (write-only)
    int             m_state = {};                   // +0x9f8 play-data state machine field (update switch dispatches on it)
    uint8_t          _reservedTail[0xa00 - 0x9fc] = {};   // +0x9fc object tail
    // Per-frame touch classification produced by update()'s preamble (reconstruction-only:
    // in the binary these are shared stack locals of the one megafunction, hoisted here as
    // the function is de-inlined into per-state methods). They are NOT part of the binary
    // object's flat layout, so they trail it.
    bool m_frameDragging = false;                  // a finger is currently held down
    bool m_frameTapped = false;                    // a tap landed this frame
    const neTouchPoint *m_frameTapTouch = nullptr; // the tapped touch (when m_frameTapped)
};

// The group-5 sugoroku per-frame render pass the scene installs as its draw callback,
// invoked by AepDrawLayer's type-3 dispatch with the full per-frame draw args
// (AepGroupDrawFn); the trailing `context` is the owning AcMainTask. (Ghidra:
// FUN_000a3724 @ 0xa3724 — a ~5.8 KB draw routine, reconstructed separately.)
void AcMainSugorokuDraw(int child, int frame, int x, int y, int scaleX, int scaleY,
                        int anchorX, int anchorY, int color, int alpha, int rotation,
                        uint32_t blend, int *clipRect, uint32_t p17, void *context);

// Unlock the board-8 bonus treasure record when its prerequisite purchased songs are
// present on disk (Ghidra: FUN_000a345c; uses TreasureData + MusicManager). No args.
void AcMainUnlockBonusTreasure();

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
