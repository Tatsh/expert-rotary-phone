//
//  MainTask.h
//  pop'n rhythmin
//

/// @file
/// @brief Standard-mode MUSIC-SELECT task (launched by MenuMainTask), reconstructed
/// from Ghidra project rb420, program PopnRhythmin. A ne::C_TASK subclass allocated at
/// 0xaa8 bytes (operator_new(0xaa8) in MenuMainTask::update and the post-play Finish).
/// ne::C_TASK's base is 0x28 bytes, so the members land at their true 32-bit binary
/// offsets (documented for reference; exact size/position is not preserved on the
/// 64-bit target). "MainTask" was a Ghidra type-conflict artifact of this same
/// class; see the alias below. The packed per-song select state is a documented seam.

#pragma once

#include <cstdint>
#include <dispatch/dispatch.h>
#include <memory>

#include "C_TASK.h"
#include "neTextureForiOS.h" // complete type: MusicSelCell holds a unique_ptr<neTextureForiOS>

class AepManager;
class AepLyrCtrl;

/// @brief Standard-mode music-select task: song list, score display, and option nav.
class MainTask : public ne::C_TASK {
public:
    /// @brief Construct with a zero-initialised work area. Ghidra: MainTask::MainTask @ 0x34d48.
    MainTask();
    /// @brief Detach as DownloadMain's recommend-list delegate, then ~ne::C_TASK. Ghidra: MainTask::~MainTask @ 0x34d90.
    ~MainTask() override;

    /**
     * @brief Per-frame update: detect a tap, then step the state machine.
     * @param deltaMs Frame delta in milliseconds (unused).
     * @note Ghidra: MainTask::update @ 0x35914.
     */
    void update(int deltaMs) override;

    /// @brief Build the state-0 scene (resolve Aep handles, load SE, seed flags). Ghidra: MainTask::Setup @ 0x370f0.
    void Setup();
    /// @brief Per-frame list-scroll physics. Ghidra: MainTask::Update @ 0x34f4c.
    void Update();
    /// @brief Re-sort / rebuild the music-select list. Ghidra: MainTask::rebuildList @ 0x3835c.
    void rebuildList();
    /// @brief True when every visible jacket cell is empty or fully loaded. Ghidra: MainTask::AllCellsReady @ 0x37f38.
    /// @returns true if all 27 cells are ready.
    bool AllCellsReady();
    /// @brief Per-frame highlight / badge pulse animation. Ghidra: MainTask::UpdateHighlight @ 0x355fc.
    void UpdateHighlight();
    /// @brief State-0x10 teardown: save the selection, release scene resources. Ghidra: MainTask::StopAndSave @ 0x38008.
    void StopAndSave();

    /**
     * @brief Build the cached recommend + info panel.
     * @param mode Panel mode selector.
     * @note Ghidra: MainTask::UpdateInfoPanel @ 0x37c88.
     */
    void UpdateInfoPanel(int mode);

    /**
     * @brief Stream the next list column's jacket cells into a widget row.
     * @param column Widget row to populate.
     * @note Ghidra: MainTask::MusicSelLoadColumnNext @ 0x35448.
     */
    void MusicSelLoadColumnNext(int column);
    /**
     * @brief Stream the previous list column's jacket cells into a widget row.
     * @param column Widget row to populate.
     * @note Ghidra: MainTask::MusicSelLoadColumnPrev @ 0x35520.
     */
    void MusicSelLoadColumnPrev(int column);

    /// @brief The music sort rebuildList last applied.
    /// @returns The applied sort id (m_appliedSort @ +0x8fc).
    int appliedSort() const {
        return m_appliedSort;
    }

public:
    /**
     * @brief Shared body of the two column loaders.
     * @param rowBase First cell row to stream into.
     * @param delta Direction: +1 next / -1 prev.
     * @param latch Per-direction load latch byte gating the stream.
     */
    inline void loadColumn(int rowBase, int delta, uint8_t &latch);

    /// @brief List-scroll settle states (m_scrollState @ +0x984).
    enum ScrollState {
        kScrollIdle = 0,      ///< no drag / settled
        kScrollFlingPrev = 1, ///< fling toward the previous column
        kScrollFlingNext = 2, ///< fling toward the next column
        kScrollSnapRight = 3, ///< rubber-band back after a rightward drag
        kScrollSnapLeft = 4,  ///< rubber-band back after a leftward drag
    };
    // Scroll-physics tuning constants (Ghidra 0x354xx floats; 16.16 pixel
    // conversions modelled as identity — a Q-format seam).
    static constexpr float kSpringAccel = 0.2f;    ///< 0x35440/44: fling-complete accel
    static constexpr float kFrictionAccel = 0.1f;  ///< 0x35434/38: snap-back accel
    static constexpr float kFrameStepMs = 16.6f;   ///< 0x3543c: per-frame time step
    static constexpr float kMaxVelocity = 8.0f;    ///< fling velocity clamp
    static constexpr float kMinVelocity = 1.0f;    ///< minimum completing velocity
    static constexpr float kFlingThreshold = 0.1f; ///< |velocity| gate for fling vs snap-back

    /// @brief Pick the free jacket row not held by one of the three column-row latches.
    /// @returns The free row base index.
    inline int findFreeColumnRow() const;

    /// @brief Music-select buttons hit-tested each frame.
    enum Button {
        kBtnSettings,
        kBtnSort,
        kBtnRecommend,
        kBtnOverScoreLog, ///< state 2 top row
        kBtnBackToMenu,
        kBtnTutorial,
        kBtnDiffToggle, ///< state 2 overlay
        kBtnSongCell,
        kBtnFavToggle, ///< state 2 song grid
        kBtnPlay,
        kBtnFriendScore,
        kBtnDifficulty, ///< state 4 preview
    };

    /// @brief Indices into m_layers[4] (the +0x34 scene-layer bank; kLayerNames).
    enum MainSceneLayer {
        kLayerBg = 0,        ///< BG_640X1136 background
        kLayerDiffOpen = 1,  ///< DIFFICULTY_OPEN sweep
        kLayerDiffClose = 2, ///< DIFFICULTY_CLOSE sweep
        kLayerDiffLoop = 3,  ///< DIFFICULTY_ROOP loop
    };

    /// @brief Indices into m_introLayers[2] (the +0x44 intro bank; kIntroNames).
    enum IntroLayer {
        kIntroImage = 0,   ///< 640IMG / 1024IMG foreground image
        kIntroBgImage = 1, ///< BG_IMG_640 / BG_IMG_1136 background
    };

    /// @brief Indices into m_bgLyrNo[3] / m_bgLyrFrames[3] (+0x14c; kBgLyrNames).
    enum BgLayer {
        kBgNeko = 0,     ///< BG_NEKO
        kBgStarOpen = 1, ///< DIFFICULTY_STAR_OPEN
        kBgStarOut = 2,  ///< DIFFICULTY_STAR_OUT
    };

    /// @brief Indices into m_elemUsrNo[22] (+0x22c; kElemUsrNames) — the
    /// AepDrawCallback per-element user-number dispatch keys.
    enum ElemUsr {
        kElemJacket00 = 0,
        kElemJacket09 = 1,
        kElemStarGreen = 2,
        kElemStarYellow = 3,
        kElemStarRed = 4,
        kElemRankNumGreen = 5,
        kElemRankNumYellow = 6,
        kElemRankNumRed = 7,
        kElemDiffRankE = 8,
        kElemBt00 = 9,
        kElemMusicTitle = 10,
        kElemDiffTitle = 11,
        kElemDiffName = 12,
        kElemNewBoard = 13,
        kElemFullCombo = 14,
        kElemBgNeko = 15,
        kElemPointNum = 16,
        kElemFriendScoreFont = 17,
        kElemFriendScoreIcon = 18,
        kElemFriendUpdefFontbar = 19,
        kElemFriendUpIcon = 20,
        kElemFriendUpFirstIcon = 21,
    };

    /// @brief Indices into m_arrowTex[2] (+0x4c; kArrowNames).
    enum ArrowTex {
        kArrowRecommend = 0, ///< "circle" recommend arrow
        kArrowWarning = 1,   ///< "vie_cmn_warning@2x" friend-request / over-score badge
    };

    /// @brief Group base offsets into m_digitTex[60] (+0x5c; kDigitAtlasNames):
    /// each group is 10 consecutive glyphs (0..9), so the digit is `base + n`.
    enum DigitGroup {
        kDigitScore = 0,   ///< num_score_0..9
        kDigitPoints = 10, ///< num_points0..9
        kDigitJkDif = 20,  ///< num_jk_dif_0..9
        kDigitRank = 30,   ///< rank block: green/yellow/pink 10s at 30/40/50
    };

    /**
     * @brief Hit-test a UI-scaled button rect against a tap.
     * @param tapX Tap x in screen pixels.
     * @param tapY Tap y in screen pixels.
     * @param button Button whose rect to test.
     * @param cellIndex Selects the rect for per-cell buttons; -1 otherwise.
     * @returns true if the tap falls inside the button.
     * @note Ghidra: pointInRect @ 0x2d974, inlined in MainTask::update @ 0x35914.
     */
    inline bool hitButton(int tapX, int tapY, Button button, int cellIndex = -1) const;

    /**
     * @brief Map a Button to its widget cell (index into m_cells).
     * @param button Button to map.
     * @returns The widget-cell index, or -1 for kBtnBackToMenu.
     */
    inline int widgetIndexForButton(Button button) const;

    /// @brief Seed the three difficulty-star bg-layer frame counters (@ +0x170). State 3/4 seam.
    inline void seedDiffStarLayerFrames();
    /// @brief Re-read the three difficulty score rows for the current song.
    inline void refreshScoreRows();

    /// @brief Release the old list and clear the 27 jacket cells. Ghidra: MainTask::Cleanup @ 0x3cfb0.
    void Cleanup();

    struct MusicSelCell; // forward-declared for the reference param below
    /**
     * @brief Fetch a song's three difficulty score rows into a cell's detail block.
     * @param cell Destination jacket cell.
     * @param musicId Song id to fetch.
     * @note De-inlined from MainTask::rebuildList @ 0x3835c.
     */
    inline void loadCellScoreRows(MusicSelCell &cell, unsigned musicId);

    /// @brief Background jacket loader (the dispatch_async body rebuildList starts).
    /// Ghidra: resultTaskSetup @ 0x3d048 (mislabeled by binary proximity).
    void backgroundCellLoader();

    /// @brief One widget cell of the select scene (the cell array @ +0x2d8, stride 0x38).
    struct MusicSelCell { // 0x38 bytes
        union {
            float scale;   // +0x00 per-widget UI scale (button widgets)
            int songIndex; // +0x00 jacket cells: list index of the song
        };
        int loadState;                            // +0x04 jacket state: 0 empty / 3 ready
        __unsafe_unretained id imageData;         // +0x08 bundled PNG data (released after upload)
        std::unique_ptr<neTextureForiOS> texture; // +0x0c uploaded jacket texture
        __unsafe_unretained id name;              // +0x10 truncated song-name string
        struct ScoreRows {                        // +0x14 jacket-cell score rows (0x24 bytes)
            int score[3];                         // +0x00 per-difficulty best score
            int playCnt[3];                       // +0x0c per-difficulty play count
            short rank[3];                        // +0x18 per-difficulty rank
            uint8_t fullCombo[3];                 // +0x1e FC medal
            uint8_t perfect[3];                   // +0x21 PERFECT medal
        };
        struct WidgetRect {
            int x, y, w, h;
        }; // 0x10 bytes: {x, y, w, h} view of a packed hit-rect (seam)
        union {
            uint8_t detail[0x24]; // widget state (button/UI widgets)
            ScoreRows scores;     // jacket-cell score rows
            WidgetRect widget;    // UI cells: representative packed hit-rect
        };
    };

    // ---- packed per-song select state (documented tail seam), 0x40 bytes ----
    struct MusicSelState {
        uint8_t inviteOpen;        // EX unlocked for this invite song
        uint8_t previewBgmLoading; // +0x91a preview BGM (re)load in progress; the
                                   // async loadMusicPreviewBgm block clears it
        uint8_t diffDirty;         // difficulty changed -> refresh score rows
        uint8_t favorite;          // favourite toggle
        uint8_t tutorialOffered;   // first-play tutorial offered for the tapped cell
        uint8_t scrollLatchA;      // list-scroll latch pair (diff-toggle / friend-score)
        uint8_t scrollLatchB;
        // Always exactly the three difficulties (accessed individually, never by a
        // runtime index or loop), so these are named triples rather than [3] arrays.
        struct {
            uint8_t normal, hyper, ex;
        } fullCombo; // FC medals per difficulty
        struct {
            uint8_t normal, hyper, ex;
        } perfect; // PERFECT medals per difficulty
        uint8_t _pad0[3];
        unsigned musicId; // current song id
        // The selected difficulty lives in the real field m_resultSheet (+0x904),
        // the three levels in m_diffLevel (+0x908), and the fade-out handoff waits
        // on m_loaderCursor (+0xa8c) -- all outside this seam.
        int selectSeId;    // select-SE source id
        int selectSeInst;  // select-SE playing instance (for stop)
        int scrollConfig;  // per-column scroll config
        int overRowLen[3]; // over-score display row lengths (unused seam field)
    };

    // ---- work-area layout (offsets are binary-exact) ----
    AepManager *m_aep = nullptr; // +0x28 Aep context (AepManager::shared)
#ifndef ENABLE_PATCHES
    uint8_t unused_2c[0x30 - 0x2c] = {}; // +0x2c unused 4-byte slot (Ghidra: no field access)
#endif
    __unsafe_unretained id m_musicList = nullptr;    // +0x30 NSArray<MusicInfo*>*
    std::unique_ptr<AepLyrCtrl> m_layers[4];         // +0x34 BG / preview / loop transports
    std::unique_ptr<AepLyrCtrl> m_introLayers[2];    // +0x44 intro transports
    std::unique_ptr<neTextureForiOS> m_arrowTex[2];  // +0x4c recommend / over-score arrows
    std::unique_ptr<neTextureForiOS> m_nameTex;      // +0x54 song-name banner
    std::unique_ptr<neTextureForiOS> m_artistTex;    // +0x58 artist-name banner
    std::unique_ptr<neTextureForiOS> m_digitTex[60]; // +0x5c score/points/rank digit atlases
    // Resolved Aep handle tables (+0x14c..+0x2d8), filled by Setup() via getLyrNo /
    // layerFrameCount / getFrameNo / getUserNo over the const name lists in MainTask.mm.
    int m_bgLyrNo[3] = {};     // +0x14c getLyrNo(BG_NEKO / DIFFICULTY_STAR_OPEN / _OUT)
    int m_bgLyrFrames[3] = {}; // +0x158 layerFrameCount of each m_bgLyrNo
    int m_diffIntroFrame = 0;  // +0x164 difficulty-intro sweep frame counter
#ifndef ENABLE_PATCHES
    uint8_t unused_168[0x170 - 0x168] = {}; // +0x168 unused (2 ints; Ghidra: no MainTask access)
#endif
    int m_diffStarLayerFrame[3] = {}; // +0x170 difficulty-star bg-layer frame counters
    int m_frmNo[24] = {};             // +0x17c getFrameNo(kFrmNames[24]) button/icon frames
    int m_starFrmNo[3] = {};          // +0x1dc getFrameNo(DIFFICULTY_STAR_GREEN/YELLOW/RED)
    int m_musicRankFrmNo[7] = {};     // +0x1e8 getFrameNo(MUSIC_RUNK_NUMBER_S/AAA/AA/A/B/C/D)
    int m_diffRankFrmNo[7] = {};      // +0x204 getFrameNo(DIFFICULTY_RUNK_NUMBER_S/AAA/AA/A/B/C/D)
    int m_jacketTipFrmNo[3] = {};     // +0x220 getFrameNo(JACKET_TIP00/01/02)
    int m_elemUsrNo[22] = {};         // +0x22c getUserNo(kElemUsrNames[22]) — draw dispatch
    int m_scoreDigitUsrNo[6] = {};    // +0x284 getUserNo(SCORE0 .. SCORE000000)
    int m_diffBlackUsrNo[3] = {};     // +0x29c getUserNo(DIFFICULTY_BLACK/BLACK2/BLACK3)
    int m_placeDigitUsrNo[9] = {};    // +0x2a8 getUserNo(GREEN/YELLOW/PINK _0/_0_0/_0_0_0)
    int m_jacketTipUsrNo[3] = {};     // +0x2cc getUserNo(JACKET_TIP00/01/02)
    MusicSelCell m_cells[27] = {};    // +0x2d8 jacket + widget array (stride 0x38)
    // Three per-column row-load latches (0xff == idle); a latch holds the row index
    // whose jacket column is currently streaming.
    uint8_t m_prevColLatch = 0xff; // +0x8c0 prev-column row-load latch
    uint8_t m_curColLatch = 0xff;  // +0x8c1 current-column widget-row latch
    uint8_t m_nextColLatch = 0xff; // +0x8c2 next-column row-load latch
#ifndef ENABLE_PATCHES
    uint8_t _pad_8c3[0x8c4 - 0x8c3] = {}; // +0x8c3 alignment pad before m_seId (no access)
#endif
    int m_seId[5] = {};               // +0x8c4 loaded touch-SE source ids
    int m_seInst[5] = {};             // +0x8d8 touch-SE instance handles (-1 idle)
    int m_songCount = 0;              // +0x8ec total songs in m_musicList (rebuildList)
    int m_columnIndex = 0;            // +0x8f0 current list column
    int m_columnCount = 0;            // +0x8f4 total columns
    int m_chosenIndex = 0;            // +0x8f8 chosen song list index (save)
    int m_appliedSort = 0;            // +0x8fc music-sort rebuildList last applied
    int m_chosenMusicId = 0;          // +0x900 chosen music id (launch save)
    int m_resultSheet = 0;            // +0x904 saved result sheet (difficulty)
    int m_diffLevel[3] = {};          // +0x908 per-difficulty level (lvNormal/Hyper/Ex)
    uint8_t m_fullComboMedal[3] = {}; // +0x914 per-sheet full-combo medal (fullComboN/H/Ex)
    uint8_t m_perfectMedal[3] = {};   // +0x917 per-sheet perfect medal (perfectN/H/Ex)
    uint8_t m_bgmLoading = 0;       // +0x91a preview-BGM async load in flight (cleared by loadBgm)
    uint8_t m_suppressDraw = 0;     // +0x91b hide the scene during teardown
    uint8_t m_showLevelNumbers = 0; // +0x91c show numeric level instead of rank frame
    uint8_t m_diffIntroActive = 0;  // +0x91d difficulty-intro sweep playing
    uint8_t m_tutorialBadge = 0;    // +0x91e first-play tutorial badge visible
    uint8_t m_recommendBadge = 0;   // +0x91f new-recommend badge visible
    uint8_t m_scoreRefreshPending = 0; // +0x920 re-fetch the 3 cells' scores after friend-score
    uint8_t m_inviteMusicOpen = 0;     // +0x921 chosen invite music is open (gates EX cell select)
    uint8_t m_cellLoaderStarted = 0;   // +0x922 background jacket loader launched
    uint8_t m_noSaveMode = 0;          // +0x923 guest / no-save teardown flag
    uint8_t m_overScoreBadge = 0;      // +0x924 over-score badge visible
    uint8_t m_isPadDisplay = 0;        // +0x925 pad-class display
#ifndef ENABLE_PATCHES
    uint8_t _pad_926[0x928 - 0x926] = {}; // +0x926 alignment pad before m_selectedCell (no access)
#endif
    int m_selectedCell = -1; // +0x928 drag touch id / chosen cell (ctor -1)
    // List-scroll fling ring (Update @ 0x34f4c): the drag finger is sampled into
    // a 10-deep ring each frame ([0] newest); the two arrays are contiguous.
    int m_dragSampleTime[10] = {};               // +0x92c sample timestamps (ms), [0] newest
    int m_dragSampleX[10] = {};                  // +0x954 sample touch-x (px), [0] newest
    float m_scrollVelocity = 0.0f;               // +0x97c fling velocity (px/ms)
    int m_scrollOffset = 0;                      // +0x980 scroll offset within the column (px)
    int m_scrollState = 0;                       // +0x984 settle state (see ScrollState)
    int m_layoutRects[(0xa64 - 0x988) / 4] = {}; // +0x988 Setup()-filled button rects
    int m_screenWidth = 0;                       // +0xa64 aep screen width
    int m_screenHeight = 0;                      // +0xa68 aep screen height
    float m_uiScale = 0.0f;      // +0xa6c UI scale factor (g_uiScale = screenScale * 0.5)
    int m_treasurePoint = 0;     // +0xa70 treasure-point count
    int m_columnStride = 0;      // +0xa74 cells per column (6 phone / 9 pad)
    int m_touchX = -1;           // +0xa78 current-frame drag touch x (-1 none)
    int m_touchY = -1;           // +0xa7c current-frame drag touch y (-1 none)
    uint8_t m_touchReleased = 0; // +0xa80 finger lifted this frame (settle trigger)
#ifndef ENABLE_PATCHES
    uint8_t _pad_a81[0xa84 - 0xa81] = {}; // +0xa81 alignment pad before m_layoutBaseX (no access)
#endif
    int m_layoutBaseX = 0;                            // +0xa84 layout base x (phone)
    int m_layoutBaseY = 0;                            // +0xa88 layout base y
    int m_loaderCursor = 0;                           // +0xa8c async jacket-loader progress cursor
    dispatch_semaphore_t m_cellSem = nullptr;         // +0xa90 guards the jacket cell array
    int m_highlightAnim = 0;                          // +0xa94 highlight pulse phase (0..0x96)
    __unsafe_unretained id m_overScoreDict = nullptr; // +0xa98 over-score "touched" set
    int m_overScorePulse = 0;            // +0xa9c over-score badge pulse phase (0..0x96)
    ne::C_TASK *m_spawnedTask = nullptr; // +0xaa0 launched play / tutorial / menu sub-task
    /// @brief MainTask::m_state music-select flow states, in the order update()
    /// walks them (Ghidra: MainTask_update). Values 0xb is unused.
    enum SelectState {
        kSelSetup = 0,            ///< build the scene, start BGM, fetch the recommend list
        kSelFadeIn = 1,           ///< fade the select scene in, start the intro layers
        kSelSelect = 2,           ///< interactive song / menu select
        kSelSongChosen = 3,       ///< a song was chosen: preview BGM + load textures
        kSelDifficulty = 4,       ///< difficulty / option select + BGM preview loop
        kSelGotoSettings = 5,     ///< open the settings screen
        kSelWaitSettings = 6,     ///< wait for settings to close (or relaunch the title)
        kSelGotoSort = 7,         ///< open the sort-select modal
        kSelSortModal = 8,        ///< sort modal shown -> resume select
        kSelGotoScoreLog = 9,     ///< open the over-score (friend score) log
        kSelScoreLogModal = 10,   ///< score-log modal shown -> resume select
        kSelPlayLaunch = 0xc,     ///< play-launch handoff
        kSelPlayLaunchWait = 0xd, ///< play-launch intermediate wait
        kSelFadeOut = 0xe,        ///< fade out, signal the async loader to stop
        kSelWaitFadeOut = 0xf,    ///< wait for the fade-out and the loader to stop
        kSelTeardown = 0x10,      ///< tear down once the select SEs finish
    };
    int m_state = 0;                           // +0xaa4 state-machine field (SelectState)
    MusicSelState m_sel = {};                  // +0xaa8 packed per-song select state (seam)
    uint8_t _reservedTail[0xcc1 - 0xae8] = {}; // +0xae8..0xcc1 remaining Setup/layout tail

    // Music-select scene per-layer Aep draw callback (group draw callback). A
    // static member so it stays a plain function pointer for setGroupDrawCallback
    // while reaching this task's members and index enums through `context`. Ghidra:
    // MainTask::AepDrawCallback @ 0x389fc. The param types MUST match AepGroupDrawFn
    // exactly (rotation int, clipRect int*): on arm64 a mistyped stack arg shifts every
    // following slot and corrupts `context`, faulting on a garbage `self`.
    static void AepDrawCallback(int child,
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
};

/// @brief `MainTask` was a Ghidra type-conflict artifact of MainTask (the same
/// 0xaa8 object, never separately constructed); kept as an alias so existing
/// MainTask-typed seams resolve to MainTask with no cast.

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
