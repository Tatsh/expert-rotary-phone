/**
 * @file
 * @brief The standard-mode music-select task, launched by MenuMainTask.
 *
 * Reconstructed from Ghidra project
 * rb420, program PopnRhythmin. A ne::C_TASK subclass allocated at 0xaa8 bytes
 * (operator_new(0xaa8) in MenuMainTask::update and the post-play Finish). ne::C_TASK's base is
 * 0x28 bytes, so the members land at their true 32-bit binary offsets (documented for reference;
 * exact size and position are not preserved on the 64-bit target). "MainTask" was a Ghidra
 * type-conflict artifact of this same class; see the alias below. The packed per-song select
 * state is a documented seam.
 */

#pragma once

#include <cstdint>
#include <dispatch/dispatch.h>
#include <memory>

#import <Foundation/Foundation.h>

#include "C_TASK.h"
#include "neTextureForiOS.h" // complete type: MusicSelCell holds a unique_ptr<neTextureForiOS>

class AepManager;
class AepLyrCtrl;

/**
 * @brief Standard-mode music-select task: song list, score display, and option navigation.
 */
class MainTask : public ne::C_TASK {
public:
    /**
     * @brief Construct with a zero-initialised work area.
     * @ghidraAddress 0x34d48
     */
    MainTask();
    /**
     * @brief Detach as DownloadMain's recommend-list delegate, then run the base task teardown.
     * @ghidraAddress 0x34d90
     */
    ~MainTask() override;

    /**
     * @brief Per-frame update: detect a tap, then step the state machine.
     * @param deltaMs Frame delta in milliseconds; unused.
     * @ghidraAddress 0x35914
     */
    void update(int deltaMs) override;

    /**
     * @brief Build the state-0 scene: resolve Aep handles, load the SEs and seed the flags.
     * @ghidraAddress 0x370f0
     */
    void Setup();
    /**
     * @brief Per-frame list-scroll physics.
     * @ghidraAddress 0x34f4c
     */
    void Update();
    /**
     * @brief Re-sort and rebuild the music-select list.
     * @ghidraAddress 0x3835c
     */
    void rebuildList();
    /**
     * @brief Whether every visible jacket cell is empty or fully loaded.
     * @return true if all 27 cells are ready.
     * @ghidraAddress 0x37f38
     */
    bool AllCellsReady();
    /**
     * @brief Per-frame highlight and badge pulse animation.
     * @ghidraAddress 0x355fc
     */
    void UpdateHighlight();
    /**
     * @brief State-0x10 teardown: save the selection and release the scene resources.
     * @ghidraAddress 0x38008
     */
    void StopAndSave();

    /**
     * @brief Build the cached recommend and info panel.
     * @param mode Panel mode selector.
     * @ghidraAddress 0x37c88
     */
    void UpdateInfoPanel(int mode);

    /**
     * @brief Stream the next list column's jacket cells into a widget row.
     * @param column Widget row to populate.
     * @ghidraAddress 0x35448
     */
    void MusicSelLoadColumnNext(int column);
    /**
     * @brief Stream the previous list column's jacket cells into a widget row.
     * @param column Widget row to populate.
     * @ghidraAddress 0x35520
     */
    void MusicSelLoadColumnPrev(int column);

    /**
     * @brief The music sort order rebuildList last applied.
     * @return The applied sort id (m_appliedSort @ +0x8fc).
     */
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

    /**
     * @brief List-scroll settle states (m_scrollState @ +0x984).
     */
    enum ScrollState {
        kScrollIdle = 0,      /**< No drag; settled. */
        kScrollFlingPrev = 1, /**< Fling toward the previous column. */
        kScrollFlingNext = 2, /**< Fling toward the next column. */
        kScrollSnapRight = 3, /**< Rubber-band back after a rightward drag. */
        kScrollSnapLeft = 4,  /**< Rubber-band back after a leftward drag. */
    };
    // Scroll-physics tuning constants (Ghidra 0x354xx floats). The pixel
    // conversions around them are plain int<->float (vcvt).
    static constexpr float kSpringAccel = 0.2f;    /**< 0x35440/44: fling-complete acceleration. */
    static constexpr float kFrictionAccel = 0.1f;  /**< 0x35434/38: snap-back acceleration. */
    static constexpr float kFrameStepMs = 16.6f;   /**< 0x3543c: per-frame time step. */
    static constexpr float kMaxVelocity = 8.0f;    /**< Fling velocity clamp. */
    static constexpr float kMinVelocity = 1.0f;    /**< Minimum completing velocity. */
    static constexpr float kFlingThreshold = 0.1f; /**< Velocity gate for fling vs snap-back. */

    /**
     * @brief Pick the free jacket row not held by one of the three column-row latches.
     * @return The free row base index.
     */
    inline int findFreeColumnRow() const;

    /**
     * @brief Music-select buttons hit-tested each frame.
     */
    enum Button {
        kBtnSettings,     /**< State 2 top row: open the settings screen. */
        kBtnSort,         /**< State 2 top row: open the sort-order sheet. */
        kBtnRecommend,    /**< State 2 top row: open the recommendations screen. */
        kBtnOverScoreLog, /**< State 2 top row: open the over-score log. */
        kBtnBackToMenu,   /**< State 2 top row: return to the mode menu. */
        kBtnTutorial,     /**< State 2 top row: start the tutorial. */
        kBtnDiffToggle,   /**< State 2 overlay: toggle the difficulty panel. */
        kBtnSongCell,     /**< State 2 song grid: select the tapped song cell. */
        kBtnFavToggle,    /**< State 2 song grid: toggle the song's favourite flag. */
        kBtnPlay,         /**< State 4 preview: start play at the previewed difficulty. */
        kBtnFriendScore,  /**< State 4 preview: open the friend-score panel. */
        kBtnDifficulty,   /**< State 4 preview: cycle the previewed difficulty. */
    };

    /**
     * @brief Indices into m_layers[4] (the +0x34 scene-layer bank; kLayerNames).
     */
    enum MainSceneLayer {
        kLayerBg = 0,        /**< BG_640X1136 background. */
        kLayerDiffOpen = 1,  /**< DIFFICULTY_OPEN sweep. */
        kLayerDiffClose = 2, /**< DIFFICULTY_CLOSE sweep. */
        kLayerDiffLoop = 3,  /**< DIFFICULTY_ROOP loop. */
    };

    /**
     * @brief Indices into m_introLayers[2] (the +0x44 intro bank; kIntroNames).
     */
    enum IntroLayer {
        kIntroImage = 0,   /**< 640IMG / 1024IMG foreground image. */
        kIntroBgImage = 1, /**< BG_IMG_640 / BG_IMG_1136 background. */
    };

    /**
     * @brief Indices into m_bgLyrNo[3] and m_bgLyrFrames[3] (+0x14c; kBgLyrNames).
     */
    enum BgLayer {
        kBgNeko = 0,     /**< BG_NEKO. */
        kBgStarOpen = 1, /**< DIFFICULTY_STAR_OPEN. */
        kBgStarOut = 2,  /**< DIFFICULTY_STAR_OUT. */
    };

    /**
     * @brief Indices into m_elemUsrNo[22] (+0x22c; kElemUsrNames) — the AepDrawCallback
     * per-element user-number dispatch keys.
     */
    enum ElemUsr {
        kElemJacket00 = 0,            /**< JACKET00: the song-jacket grid head. */
        kElemJacket09 = 1,            /**< JACKET09: the song-jacket grid tail. */
        kElemStarGreen = 2,           /**< Green (easy) difficulty star row. */
        kElemStarYellow = 3,          /**< Yellow (normal) difficulty star row. */
        kElemStarRed = 4,             /**< Red (hyper) difficulty star row. */
        kElemRankNumGreen = 5,        /**< Green-difficulty rank digits. */
        kElemRankNumYellow = 6,       /**< Yellow-difficulty rank digits. */
        kElemRankNumRed = 7,          /**< Red-difficulty rank digits. */
        kElemDiffRankE = 8,           /**< Difficulty rank letter badge. */
        kElemBt00 = 9,                /**< BT00: the button strip. */
        kElemMusicTitle = 10,         /**< Selected song title text. */
        kElemDiffTitle = 11,          /**< Difficulty panel heading. */
        kElemDiffName = 12,           /**< Difficulty name text. */
        kElemNewBoard = 13,           /**< "New song" board badge. */
        kElemFullCombo = 14,          /**< Full-combo badge. */
        kElemBgNeko = 15,             /**< BG_NEKO background element. */
        kElemPointNum = 16,           /**< Point-balance digits. */
        kElemFriendScoreFont = 17,    /**< Friend-score text. */
        kElemFriendScoreIcon = 18,    /**< Friend-score icon. */
        kElemFriendUpdefFontbar = 19, /**< Friend-update text bar. */
        kElemFriendUpIcon = 20,       /**< Friend-update icon. */
        kElemFriendUpFirstIcon = 21,  /**< First-time friend-update icon. */
    };

    /**
     * @brief Indices into m_arrowTex[2] (+0x4c; kArrowNames).
     */
    enum ArrowTex {
        kArrowRecommend = 0, /**< The "circle" recommend arrow. */
        kArrowWarning = 1,   /**< "vie_cmn_warning@2x" friend-request / over-score badge. */
    };

    /**
     * @brief Group base offsets into m_digitTex[60] (+0x5c; kDigitAtlasNames).
     *
     * Each group is 10 consecutive glyphs (0..9), so the digit is `base + n`.
     */
    enum DigitGroup {
        kDigitScore = 0,   /**< num_score_0..9. */
        kDigitPoints = 10, /**< num_points0..9. */
        kDigitJkDif = 20,  /**< num_jk_dif_0..9. */
        kDigitRank = 30,   /**< Rank block: green, yellow and pink tens at 30, 40 and 50. */
    };

    /**
     * @brief Hit-test a UI-scaled button rect against a tap.
     * @param tapX Tap x in screen pixels.
     * @param tapY Tap y in screen pixels.
     * @param button Button whose rect to test.
     * @param cellIndex Selects the rect for per-cell buttons; -1 otherwise.
     * @return true if the tap falls inside the button.
     * @note Ghidra: pointInRect @ 0x2d974, inlined in MainTask::update @ 0x35914.
     */
    inline bool hitButton(int tapX, int tapY, Button button, int cellIndex = -1) const;

    /**
     * @brief Map a Button to its widget cell (index into m_cells).
     * @param button Button to map.
     * @return The widget-cell index, or -1 for kBtnBackToMenu.
     */
    inline int widgetIndexForButton(Button button) const;

    /**
     * @brief Seed the three difficulty-star background layer frame counters (@ +0x170). The
     * state-3/4 seam.
     */
    inline void seedDiffStarLayerFrames();
    /**
     * @brief Re-read the three difficulty score rows for the current song.
     */
    inline void refreshScoreRows();

    /**
     * @brief Release the old list and clear the 27 jacket cells.
     * @ghidraAddress 0x3cfb0
     */
    void Cleanup();

    struct MusicSelCell; // forward-declared for the reference param below
    /**
     * @brief Fetch a song's three difficulty score rows into a cell's detail block.
     * @param cell Destination jacket cell.
     * @param musicId Song id to fetch.
     * @note De-inlined from MainTask::rebuildList @ 0x3835c.
     */
    inline void loadCellScoreRows(MusicSelCell &cell, unsigned musicId);

    /**
     * @brief Background jacket loader: the dispatch_async body rebuildList() starts.
     *
     * Ghidra names it resultTaskSetup @ 0x3d048, mislabelled by binary proximity.
     */
    void backgroundCellLoader();

    /**
     * @brief One widget cell of the select scene (the cell array @ +0x2d8, stride 0x38).
     */
    struct MusicSelCell { // 0x38 bytes
        union {
            float scale;   // +0x00 per-widget UI scale (button widgets)
            int songIndex; // +0x00 jacket cells: list index of the song
        };
        int loadState; /**< +0x04 Jacket state: 0 empty, 3 ready. */
        // ARC-strong: the binary's MRC path transfers a -copy (+1) into the cell and
        // releases it in cleanup, so the cell OWNS these. Declaring them
        // __unsafe_unretained left the assigned strings/data unowned, so ARC freed them
        // at the assignment's scope end and the per-frame draw retained a dangling
        // pointer (SIGSEGV in objc_retain, from musicSelLoadColumn's -copy name and its
        // truncated-name temporary). Strong keeps them alive until cleanup nils them.
        id imageData; /**< +0x08 Bundled PNG data, released after upload. */
        std::unique_ptr<neTextureForiOS> texture; /**< +0x0c Uploaded jacket texture. */
        id name;                                  /**< +0x10 Truncated song-name string. */
        /**
         * @brief +0x14 A jacket cell's per-difficulty score rows. 0x24 bytes.
         */
        struct ScoreRows {
            int score[3];         /**< +0x00 Per-difficulty best score. */
            int playCnt[3];       /**< +0x0c Per-difficulty play count. */
            short rank[3];        /**< +0x18 Per-difficulty rank. */
            uint8_t fullCombo[3]; /**< +0x1e Full-combo medal, per difficulty. */
            uint8_t perfect[3];   /**< +0x21 Perfect medal, per difficulty. */
        };
        /**
         * @brief A {x, y, w, h} view of a packed hit-rect (seam). 0x10 bytes.
         */
        struct WidgetRect {
            int x; /**< Left edge, in screen pixels. */
            int y; /**< Top edge, in screen pixels. */
            int w; /**< Width, in screen pixels. */
            int h; /**< Height, in screen pixels. */
        };
        union {
            uint8_t detail[0x24]; // widget state (button/UI widgets)
            ScoreRows scores;     // jacket-cell score rows
            WidgetRect widget;    // UI cells: representative packed hit-rect
        };
    };

    /**
     * @brief The packed per-song select state (documented tail seam). 0x40 bytes.
     */
    struct MusicSelState {
        uint8_t inviteOpen; /**< EX unlocked for this invite song. */
        /**
         * +0x91a Preview BGM (re)load in progress; the async loadMusicPreviewBgm block clears it.
         */
        uint8_t previewBgmLoading;
        uint8_t diffDirty;       /**< Difficulty changed; refresh the score rows. */
        uint8_t favorite;        /**< Favourite toggle. */
        uint8_t tutorialOffered; /**< First-play tutorial offered for the tapped cell. */
        uint8_t scrollLatchA;    /**< List-scroll latch (difficulty toggle). */
        uint8_t scrollLatchB;    /**< List-scroll latch (friend score). */
        // Always exactly the three difficulties (accessed individually, never by a
        // runtime index or loop), so these are named triples rather than [3] arrays.
        /** Full-combo medals, one per difficulty. */
        struct {
            uint8_t normal; /**< Normal-difficulty medal. */
            uint8_t hyper;  /**< Hyper-difficulty medal. */
            uint8_t ex;     /**< EX-difficulty medal. */
        } fullCombo;
        /** Perfect medals, one per difficulty. */
        struct {
            uint8_t normal; /**< Normal-difficulty medal. */
            uint8_t hyper;  /**< Hyper-difficulty medal. */
            uint8_t ex;     /**< EX-difficulty medal. */
        } perfect;
        uint8_t _pad0[3]; /**< Alignment padding. */
        unsigned musicId; /**< Current song id. */
        // The selected difficulty lives in the real field m_resultSheet (+0x904),
        // the three levels in m_diffLevel (+0x908), and the fade-out handoff waits
        // on m_loaderCursor (+0xa8c) -- all outside this seam.
        int selectSeId;    /**< Select-SE source id. */
        int selectSeInst;  /**< Select-SE playing instance, used to stop it. */
        int scrollConfig;  /**< Per-column scroll config. */
        int overRowLen[3]; /**< Over-score display row lengths (unused seam field). */
    };

    // ---- work-area layout (offsets are binary-exact) ----
    AepManager *m_aep = nullptr; /**< +0x28 Aep context (AepManager::shared). */
#ifndef ENABLE_PATCHES
    /** +0x2c Unused 4-byte slot (Ghidra: no field access). */
    uint8_t unused_2c[0x30 - 0x2c] = {};
#endif
    __unsafe_unretained id m_musicList = nullptr;   /**< +0x30 NSArray<MusicInfo*>*. */
    std::unique_ptr<AepLyrCtrl> m_layers[4];        /**< +0x34 BG / preview / loop transports. */
    std::unique_ptr<AepLyrCtrl> m_introLayers[2];   /**< +0x44 Intro transports. */
    std::unique_ptr<neTextureForiOS> m_arrowTex[2]; /**< +0x4c Recommend / over-score arrows. */
    std::unique_ptr<neTextureForiOS> m_nameTex;     /**< +0x54 Song-name banner. */
    std::unique_ptr<neTextureForiOS> m_artistTex;   /**< +0x58 Artist-name banner. */
    /** +0x5c Score, points and rank digit atlases. */
    std::unique_ptr<neTextureForiOS> m_digitTex[60];
    // Resolved Aep handle tables (+0x14c..+0x2d8), filled by Setup() via getLyrNo /
    // layerFrameCount / getFrameNo / getUserNo over the const name lists in MainTask.mm.
    int m_bgLyrNo[3] = {};     /**< +0x14c getLyrNo(BG_NEKO / DIFFICULTY_STAR_OPEN / _OUT). */
    int m_bgLyrFrames[3] = {}; /**< +0x158 layerFrameCount of each m_bgLyrNo entry. */
    int m_diffIntroFrame = 0;  /**< +0x164 Difficulty-intro sweep frame counter. */
#ifndef ENABLE_PATCHES
    /** +0x168 Unused two ints (Ghidra: no access). */
    uint8_t unused_168[0x170 - 0x168] = {};
#endif
    /** +0x170 Difficulty-star background layer frame counters. */
    int m_diffStarLayerFrame[3] = {};
    int m_frmNo[24] = {};         /**< +0x17c getFrameNo(kFrmNames[24]) button/icon frames. */
    int m_starFrmNo[3] = {};      /**< +0x1dc getFrameNo(DIFFICULTY_STAR_GREEN/YELLOW/RED). */
    int m_musicRankFrmNo[7] = {}; /**< +0x1e8 getFrameNo(MUSIC_RUNK_NUMBER_S/AAA/AA/A/B/C/D). */
    /** +0x204 getFrameNo(DIFFICULTY_RUNK_NUMBER_S/AAA/AA/A/B/C/D). */
    int m_diffRankFrmNo[7] = {};
    int m_jacketTipFrmNo[3] = {}; /**< +0x220 getFrameNo(JACKET_TIP00/01/02). */
    /** +0x22c getUserNo(kElemUsrNames[22]); the draw dispatch keys. */
    int m_elemUsrNo[22] = {};
    int m_scoreDigitUsrNo[6] = {}; /**< +0x284 getUserNo(SCORE0 .. SCORE000000). */
    int m_diffBlackUsrNo[3] = {};  /**< +0x29c getUserNo(DIFFICULTY_BLACK/BLACK2/BLACK3). */
    int m_placeDigitUsrNo[9] = {}; /**< +0x2a8 getUserNo(GREEN/YELLOW/PINK _0/_0_0/_0_0_0). */
    int m_jacketTipUsrNo[3] = {};  /**< +0x2cc getUserNo(JACKET_TIP00/01/02). */
    MusicSelCell m_cells[27] = {}; /**< +0x2d8 Jacket and widget array (stride 0x38). */
    // Three per-column row-load latches (0xff == idle); a latch holds the row index
    // whose jacket column is currently streaming.
    uint8_t m_prevColLatch = 0xff; /**< +0x8c0 Previous-column row-load latch. */
    uint8_t m_curColLatch = 0xff;  /**< +0x8c1 Current-column widget-row latch. */
    uint8_t m_nextColLatch = 0xff; /**< +0x8c2 Next-column row-load latch. */
#ifndef ENABLE_PATCHES
    /** +0x8c3 Alignment pad before m_seId (no access). */
    uint8_t _pad_8c3[0x8c4 - 0x8c3] = {};
#endif
    int m_seId[5] = {};               /**< +0x8c4 Loaded touch-SE source ids. */
    int m_seInst[5] = {};             /**< +0x8d8 Touch-SE instance handles; -1 when idle. */
    int m_songCount = 0;              /**< +0x8ec Total songs in m_musicList (rebuildList). */
    int m_columnIndex = 0;            /**< +0x8f0 Current list column. */
    int m_columnCount = 0;            /**< +0x8f4 Total columns. */
    int m_chosenIndex = 0;            /**< +0x8f8 Chosen song's list index (saved). */
    int m_appliedSort = 0;            /**< +0x8fc Music sort order rebuildList last applied. */
    int m_chosenMusicId = 0;          /**< +0x900 Chosen music id (saved at launch). */
    int m_resultSheet = 0;            /**< +0x904 Saved result sheet (difficulty). */
    int m_diffLevel[3] = {};          /**< +0x908 Per-difficulty level (lvNormal/Hyper/Ex). */
    uint8_t m_fullComboMedal[3] = {}; /**< +0x914 Per-sheet full-combo medal (fullComboN/H/Ex). */
    uint8_t m_perfectMedal[3] = {};   /**< +0x917 Per-sheet perfect medal (perfectN/H/Ex). */
    /** +0x91a Preview-BGM async load in flight; cleared by loadBgm. */
    bool m_bgmLoading = false;
    bool m_suppressDraw = false; /**< +0x91b Hide the scene during teardown. */
    /** +0x91c Show the numeric level instead of the rank frame. */
    bool m_showLevelNumbers = false;
    bool m_diffIntroActive = false; /**< +0x91d Difficulty-intro sweep playing. */
    bool m_tutorialBadge = false;   /**< +0x91e First-play tutorial badge visible. */
    bool m_recommendBadge = false;  /**< +0x91f New-recommend badge visible. */
    /** +0x920 Re-fetch the three cells' scores after the friend-score panel closes. */
    bool m_scoreRefreshPending = false;
    /** +0x921 Chosen invite music is open; gates EX cell select. */
    bool m_inviteMusicOpen = false;
    bool m_cellLoaderStarted = false; /**< +0x922 Background jacket loader launched. */
    bool m_noSaveMode = false;        /**< +0x923 Guest / no-save teardown flag. */
    bool m_overScoreBadge = false;    /**< +0x924 Over-score badge visible. */
    bool m_isPadDisplay = false;      /**< +0x925 Pad-class display. */
#ifndef ENABLE_PATCHES
    /** +0x926 Alignment pad before m_selectedCell. */
    uint8_t _pad_926[0x928 - 0x926] = {};
#endif
    /** +0x928 Drag touch id / chosen cell; -1 from the constructor. */
    int m_selectedCell = -1;
    // List-scroll fling ring (Update @ 0x34f4c): the drag finger is sampled into
    // a 10-deep ring each frame ([0] newest); the two arrays are contiguous.
    int m_dragSampleTime[10] = {};               /**< +0x92c Sample timestamps (ms), [0] newest. */
    int m_dragSampleX[10] = {};                  /**< +0x954 Sample touch x (px), [0] newest. */
    float m_scrollVelocity = 0.0f;               /**< +0x97c Fling velocity, in px/ms. */
    int m_scrollOffset = 0;                      /**< +0x980 Scroll offset in the column (px). */
    int m_scrollState = 0;                       /**< +0x984 Settle state; see ScrollState. */
    int m_layoutRects[(0xa64 - 0x988) / 4] = {}; /**< +0x988 Setup()-filled button rects. */
    int m_screenWidth = 0;                       /**< +0xa64 Aep screen width. */
    int m_screenHeight = 0;                      /**< +0xa68 Aep screen height. */
    float m_uiScale = 0.0f;       /**< +0xa6c UI scale factor (g_uiScale = screenScale * 0.5). */
    int m_treasurePoint = 0;      /**< +0xa70 Treasure-point count. */
    int m_columnStride = 0;       /**< +0xa74 Cells per column: 6 on phones, 9 on pads. */
    int m_touchX = -1;            /**< +0xa78 Current-frame drag touch x; -1 when there is none. */
    int m_touchY = -1;            /**< +0xa7c Current-frame drag touch y; -1 when there is none. */
    bool m_touchReleased = false; /**< +0xa80 Finger lifted this frame; triggers the settle. */
#ifndef ENABLE_PATCHES
    /** +0xa81 Alignment pad before m_layoutBaseX. */
    uint8_t _pad_a81[0xa84 - 0xa81] = {};
#endif
    int m_layoutBaseX = 0;                    /**< +0xa84 Layout base x (phone). */
    int m_layoutBaseY = 0;                    /**< +0xa88 Layout base y. */
    int m_loaderCursor = 0;                   /**< +0xa8c Async jacket-loader progress cursor. */
    dispatch_semaphore_t m_cellSem = nullptr; /**< +0xa90 Guards the jacket cell array. */
    int m_highlightAnim = 0;                  /**< +0xa94 Highlight pulse phase (0..0x96). */
    __unsafe_unretained id m_overScoreDict = nullptr; /**< +0xa98 Over-score "touched" set. */
    int m_overScorePulse = 0; /**< +0xa9c Over-score badge pulse phase (0..0x96). */
    /** +0xaa0 Launched play / tutorial / menu sub-task. */
    ne::C_TASK *m_spawnedTask = nullptr;
    /**
     * @brief The music-select flow states, in the order update() walks them (Ghidra:
     * MainTask_update). Value 0xb is unused.
     */
    enum SelectState {
        kSelSetup = 0,            /**< Build the scene, start the BGM, fetch the recommend list. */
        kSelFadeIn = 1,           /**< Fade the select scene in, start the intro layers. */
        kSelSelect = 2,           /**< Interactive song / menu select. */
        kSelSongChosen = 3,       /**< A song was chosen: preview the BGM and load textures. */
        kSelDifficulty = 4,       /**< Difficulty / option select plus the BGM preview loop. */
        kSelGotoSettings = 5,     /**< Open the settings screen. */
        kSelWaitSettings = 6,     /**< Wait for settings to close, or relaunch the title. */
        kSelGotoSort = 7,         /**< Open the sort-select modal. */
        kSelSortModal = 8,        /**< Sort modal shown; resume select. */
        kSelGotoScoreLog = 9,     /**< Open the over-score (friend score) log. */
        kSelScoreLogModal = 10,   /**< Score-log modal shown; resume select. */
        kSelPlayLaunch = 0xc,     /**< Play-launch handoff. */
        kSelPlayLaunchWait = 0xd, /**< Play-launch intermediate wait. */
        kSelFadeOut = 0xe,        /**< Fade out, signal the async loader to stop. */
        kSelWaitFadeOut = 0xf,    /**< Wait for the fade-out and the loader to stop. */
        kSelTeardown = 0x10,      /**< Tear down once the select SEs finish. */
    };
    SelectState m_state = kSelSetup; /**< +0xaa4 State-machine field. */
    MusicSelState m_sel = {};        /**< +0xaa8 Packed per-song select state (seam). */
    /** +0xae8..0xcc1 Remaining Setup and layout tail. */
    uint8_t _reservedTail[0xcc1 - 0xae8] = {};

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

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
