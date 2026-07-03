//
//  MainTask.h
//  pop'n rhythmin
//
//  The standard-mode MUSIC-SELECT task: the song list + score display + option
//  navigation that the mode menu (MenuMainTask) launches. It previews BGM, shows
//  the player's ScoreData, routes to recommend / sort / over-score-log / settings,
//  and spawns the actual note-play (or first-play tutorial) task once a song is
//  chosen. Reconstructed from Ghidra project rb420, program PopnRhythmin (ctor
//  MainTask_ctor FUN_00034d48, dtor mainTask_dtor FUN_00034d90, update
//  MainTask_update FUN_00035914).
//
//  "MusicSelTask" is the binary's own name for THIS class: the dtor returns
//  MusicSelTask* and DownloadMain.cppDelegateRecommendList is typed MusicSelTask*,
//  both of which the code compares against `this` (a MainTask*). There is no
//  separate ObjC class of that name (it is absent from the program's class list),
//  so `MusicSelTask` is exposed below as a typedef of MainTask and the identity
//  casts in the .mm are removed.
//
//  ---- work area (this class IS the 0xcc1-byte "MusicSelTask" struct) ----
//  C_TASK's base is exactly 0x28 bytes, so the members below land at their true
//  binary offsets. Offsets that are read by flat `*(T*)(this+off)` accesses in the
//  binary (the ctor + the setup / list-update / all-cells-ready / highlight /
//  stop-and-save / info-panel helpers) are exact and named. The per-song "packed
//  select state" (MusicSelState) is threaded through the widget array in the binary
//  (element 0x15); its individual byte positions do not decompile cleanly, so this
//  reconstruction gathers those scalars into a named block in the object tail — a
//  documented seam (their ROLES and the control flow reading them are exact).
//

#pragma once

#include <cstdint>
#include <dispatch/dispatch.h>

#include "C_TASK.h"

class AepManager;
class AepLyrCtrl;
class neTextureForiOS;

class MainTask : public C_TASK {
public:
    MainTask();                          // Ghidra: MainTask_ctor  (FUN_00034d48)
    ~MainTask() override;                // Ghidra: mainTask_dtor  (FUN_00034d90)
    void update(int deltaMs) override;   // Ghidra: MainTask_update (FUN_00035914)

    // ---- de-externed helpers: real methods (were extern "C" seams) ----
    // Each takes `this` in the binary, so each is a MainTask method here.
    void setup();                        // Ghidra: musicSelTaskSetup     (FUN_000370f0)
    void updateList();                   // Ghidra: mainTaskUpdate (FUN_00034f4c) — per-frame scroll
    void rebuildList();                  // Ghidra: musicSelUpdate (FUN_0003835c) — re-sort / rebuild
    bool allCellsReady();                // Ghidra: musicSelAllCellsReady  (FUN_00037f38)
    void updateHighlight();              // Ghidra: musicSelUpdateHighlight (FUN_000355fc)
    void stopAndSave();                  // Ghidra: musicSelStopAndSave     (FUN_00038008)
    void updateInfoPanel(int mode);      // Ghidra: musicSelUpdateInfoPanel (FUN_00037c88)

    // Stream the jacket cells of the next / previous list column into the widget row
    // `column` (guarded by the per-direction latch @ +0x8c2/+0x8c0 and the cell semaphore
    // @ +0xa90): release the row's old image/texture, then point each cell at the song
    // index for the adjacent column (or -1 past the ends). Ghidra: musicSelLoadColumnNext
    // (FUN_00035448) / musicSelLoadColumnPrev (FUN_00035520).
    void loadColumnNext(int column);     // @ 0x35448
    void loadColumnPrev(int column);     // @ 0x35520

private:
    // The music-select buttons hit-tested each frame. hitButton() maps each to its
    // stored screen rectangle in the layout block and tests the current tap against
    // it (via the engine point-in-rect primitive, Ghidra FUN_0002d974).
    enum Button {
        kBtnSettings, kBtnSort, kBtnRecommend, kBtnOverScoreLog,   // state 2 top row
        kBtnBackToMenu, kBtnTutorial, kBtnDiffToggle,              // state 2 overlay
        kBtnSongCell, kBtnFavToggle,                               // state 2 song grid
        kBtnPlay, kBtnFriendScore, kBtnDifficulty,                 // state 4 preview
    };

    // Hit-test `button` (screen rect scaled by the work area's UI-scale factor) against
    // the tap at (tapX, tapY). Ghidra: the inline FixedToFP/FloatVectorMult(...scale...)
    // transform feeding pointInRect (FUN_0002d974) — the ~13x-repeated inlined block
    // extracted here. `cellIndex` selects the rect for the per-cell buttons.
    bool hitButton(int tapX, int tapY, Button button, int cellIndex = -1) const;

    // state 3/4 seams into the packed select state (documented in MainTask.mm).
    void initOverscoreRows();            // fill the 3 over-score display counters
    void refreshScoreRows();             // re-read the 3 difficulty score rows

    // Release the old list + clear the 27 jacket cells before a re-sort/rebuild.
    void cleanup();                      // Ghidra: musicSelCleanup (FUN_0003cfb0)

    // De-inlined from rebuildList: fetch this song's three difficulty score rows into the
    // jacket cell's detail block (the inner fetchScoreDataForMusic loop @ 0x3835c).
    void loadCellScoreRows(MusicSelCell &cell, unsigned musicId);

    // ---- one widget cell of the select scene (Ghidra field26_0x2b0[], stride 0x38) ----
    // Indices 0..0x13 are the song jacket cells (imageData/texture/loadState below);
    // the higher indices are UI/button/state widgets whose per-widget detail (rect +
    // animation + select state) lives in `detail` (its sub-layout is a seam).
    struct MusicSelCell {                // 0x38 bytes
        // +0x00 is a float UI-scale for the button/UI widgets (indices >= 0x14, used by
        // the pointInRect math); for the jacket cells (0..0x13) the SAME word instead
        // holds the running list index of the song shown (rebuildList / loadColumn write
        // it as an int). A documented overlap seam.
        union {
            float         scale;         // +0x00 per-widget UI scale (button widgets)
            int           songIndex;     // +0x00 jacket cells: list index of the song
        };
        int               loadState;     // +0x04 jacket state: 0 empty / 3 ready
        __unsafe_unretained id imageData;// +0x08 bundled PNG data (released after upload)
        neTextureForiOS  *texture;       // +0x0c uploaded jacket texture
        __unsafe_unretained id name;     // +0x10 truncated song-name string (jacket cells)
        uint8_t           detail[0x24];  // +0x14..0x38 per-cell score rows / widget state (seam)
    };

    // ---- packed per-song select state (documented seam; see header note) ----
    struct MusicSelState {               // 0x40 bytes
        uint8_t  listReady;              // song list built (else stream jacket textures)
        uint8_t  inviteOpen;             // EX unlocked for this invite song
        uint8_t  previewReady;           // jackets + score loaded (state 4 gate)
        uint8_t  diffDirty;              // difficulty changed -> refresh score rows
        uint8_t  favorite;               // favourite toggle
        uint8_t  tutorialOffered;        // first-play tutorial offered for the tapped cell
        uint8_t  scrollLatchA;           // list-scroll latch pair (diff-toggle / friend-score)
        uint8_t  scrollLatchB;
        uint8_t  fullCombo[3];           // FC medals  N / H / EX
        uint8_t  perfect[3];             // PERFECT medals N / H / EX
        uint8_t  _pad0[2];
        unsigned musicId;                // current song id
        int      difficulty;             // selected difficulty (0 N / 1 H / 2 EX)
        int      levels[3];              // song levels N / H / EX
        int      transitionLatch;        // fade-out phase latch (state 0xe/0xf)
        int      selectSeId;             // select-SE source id
        int      selectSeInst;           // select-SE playing instance (for stop)
        int      scrollConfig;           // per-column scroll config (field14_0x13c[0])
        int      overRowLen[3];          // over-score display row lengths
    };

    // ================= work-area layout (offsets are binary-exact) =================
    AepManager      *m_aep = nullptr;                 // +0x28 Aep context (AepManager::shared)
    uint8_t          _rsvd_2c[0x30 - 0x2c] = {};      // +0x2c
    __unsafe_unretained id m_musicList = nullptr;         // +0x30 NSArray<MusicInfo*>*
    AepLyrCtrl      *m_layers[4] = {};                // +0x34 BG / preview / loop transports
    AepLyrCtrl      *m_introLayers[2] = {};           // +0x44 intro transports
    neTextureForiOS *m_arrowTex[2] = {};              // +0x4c recommend / over-score arrows
    neTextureForiOS *m_nameTex = nullptr;             // +0x54 song-name banner
    neTextureForiOS *m_artistTex = nullptr;           // +0x58 artist-name banner
    neTextureForiOS *m_digitTex[60] = {};             // +0x5c score/points/rank digit atlases
    uint8_t          _rsvd_aepHandles[0x2d8 - 0x14c] = {}; // +0x14c resolved Aep lyr/frm/usr no. arrays
    MusicSelCell     m_cells[27] = {};                // +0x2d8 jacket + widget array (stride 0x38)
    int16_t          m_highlight = -1;                // +0x8c0 highlight index (ctor 0xffff)
    uint8_t          m_highlightPrev = 0xff;          // +0x8c2 previous-highlight sentinel
    uint8_t          _rsvd_8c3[0x8c4 - 0x8c3] = {};   // +0x8c3
    int              m_seId[5] = {};                  // +0x8c4 loaded touch-SE source ids
    int              m_seInst[5] = {};                // +0x8d8 touch-SE instance handles (-1 idle)
    int              m_songCount = 0;                 // +0x8ec total songs in m_musicList (rebuildList)
    int              m_columnIndex = 0;               // +0x8f0 current list column
    int              m_columnCount = 0;               // +0x8f4 total columns
    int              m_chosenIndex = 0;               // +0x8f8 chosen song list index (save)
    int              m_appliedSort = 0;               // +0x8fc music-sort rebuildList last applied
    uint8_t          _rsvd_900[0x904 - 0x900] = {};   // +0x900
    int              m_resultSheet = 0;               // +0x904 saved result sheet (difficulty)
    uint8_t          _rsvd_908[0x91b - 0x908] = {};   // +0x908
    uint8_t          m_suppressDraw = 0;              // +0x91b hide the scene during teardown
    uint8_t          _rsvd_91c[0x91e - 0x91c] = {};   // +0x91c
    uint8_t          m_tutorialBadge = 0;             // +0x91e first-play tutorial badge visible
    uint8_t          m_recommendBadge = 0;            // +0x91f new-recommend badge visible
    uint8_t          _rsvd_920[0x922 - 0x920] = {};   // +0x920
    uint8_t          m_cellLoaderStarted = 0;         // +0x922 background jacket loader launched
    uint8_t          m_noSaveMode = 0;                // +0x923 guest / no-save teardown flag
    uint8_t          m_overScoreBadge = 0;            // +0x924 over-score badge visible
    uint8_t          m_isPadDisplay = 0;              // +0x925 pad-class display
    uint8_t          _rsvd_926[0x928 - 0x926] = {};   // +0x926
    int              m_selectedCell = -1;             // +0x928 drag touch id / chosen cell (ctor -1)
    uint8_t          _rsvd_scroll[0x988 - 0x92c] = {};// +0x92c list-scroll physics ring (updateList)
    int              m_layoutRects[(0xa64 - 0x988) / 4] = {}; // +0x988 setup()-filled button rects
    int              m_screenWidth = 0;               // +0xa64 aep screen width
    int              m_screenHeight = 0;              // +0xa68 aep screen height
    int              m_uiScale = 0;                   // +0xa6c UI scale factor (g_dwUiScale)
    int              m_treasurePoint = 0;             // +0xa70 treasure-point count
    int              m_columnStride = 0;              // +0xa74 cells per column (6 phone / 9 pad)
    uint8_t          _rsvd_touch[0xa84 - 0xa78] = {}; // +0xa78 current touch x / y / moved (updateList)
    int              m_layoutBaseX = 0;               // +0xa84 layout base x (phone)
    int              m_layoutBaseY = 0;               // +0xa88 layout base y
    int              m_loaderCursor = 0;              // +0xa8c async jacket-loader progress cursor
    dispatch_semaphore_t m_cellSem = nullptr;         // +0xa90 guards the jacket cell array
    int              m_highlightAnim = 0;             // +0xa94 highlight pulse phase (0..0x96)
    __unsafe_unretained id m_overScoreDict = nullptr;     // +0xa98 over-score "touched" set
    uint8_t          _rsvd_a9c[0xaa0 - 0xa9c] = {};   // +0xa9c
    C_TASK          *m_spawnedTask = nullptr;         // +0xaa0 launched play / tutorial / menu sub-task
    int              m_state = 0;                     // +0xaa4 state-machine field
    MusicSelState    m_sel = {};                      // +0xaa8 packed per-song select state (seam)
    uint8_t          _reservedTail[0xcc1 - 0xae8] = {}; // +0xae8..0xcc1 remaining setup/layout tail
};

// The music-select scene's per-layer Aep draw callback (installed as the group draw
// callback; `context` is the owning MainTask). It dispatches on the layer's resolved
// user number (@ +0x22c etc.) and blits that scene element: the current / next / prev
// column jacket grids, the song-name / artist banners, the score / level / rank digit
// runs, and the badges. Ghidra: musicSelAepDrawCallback (FUN_000389fc) — a ~98 KB draw
// routine; reconstructed best-effort (the jacket-grid dispatch is recovered, the long
// tail of per-element branches is a documented seam). @ 0x389fc.
void MusicSelAepDraw(unsigned child, int frame, int x, int y, int scaleX, int scaleY,
                     int anchorX, int anchorY, int color, int alpha, short rotation,
                     int blend, int p13, int p14, void *context);

// "MusicSelTask" is the binary's name for this very task (see header note); make the
// two names one type so the DownloadMain delegate / MainViewController Goto* seams
// take `this` directly with no identity cast.
using MusicSelTask = MainTask;

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
