//
//  AcNoteMng.h
//  pop'n rhythmin
//
//  The arcade note manager: parses an arcade chart (a "sheet_*" entry of an
//  ac%09d.acv, provided by AcMusicData) and drives arcade-mode play. It parallels
//  the standard NoteMng but uses a different, more compact chart format.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (Project/Game/Note/AcNoteMng.mm; InitPlayData FUN_0007a774).
//

#pragma once

#include <cstdint>

#ifdef __OBJC__
@class NSData;
#endif

// Arcade chart: an 8-byte header (magic 'E' at offset +4) then N 8-byte note
// records, N = (size / 8) - 2. Each record's type byte is at +0x4, its value
// (lane/BPM) at +0x6.
// NOTE: the names below are historical; the binary's semantics (from InitPlayData /
// the update closure) are: type 3 = BGM-start / drift-sync anchor (its tick -> the sync
// reference time), type 6 = the true end-of-chart marker (its tick -> the end value, and
// the appended terminator is stamped type 6 so update() can raise the end flag).
enum AcNoteType : uint8_t {
    AC_NOTE_TAP = 1,     // playable note (counted per lane)
    AC_NOTE_END = 3,     // BGM-start / drift-sync anchor (NOT the chart end)
    AC_NOTE_TEMPO = 4,   // tempo/BPM event (min/max tracked)
    AC_NOTE_EVENT = 6,   // the real end-of-chart marker
};

// One 8-byte arcade chart record.
struct AcNoteRecord {
    uint32_t tick;      // +0x0  timing position
    uint8_t  type;      // +0x4  AcNoteType
    uint8_t  reserved5; // +0x5
    uint16_t value;     // +0x6  lane (low nibble) / BPM
};
static_assert(sizeof(AcNoteRecord) == 8, "arcade note record is 8 bytes");

// One active (on-screen / in-flight) note. A fixed pool is threaded onto either the free
// list or the active list; play never allocates. Layout mirrors the binary's node:
// next@0x0, record@0x4, tick@0x8, drawY@0xc, lane@0x10, flags@0x12.
struct AcActiveNote {
    AcActiveNote *next = nullptr;          // +0x00 free/active list link
    const AcNoteRecord *record = nullptr;  // +0x04 source chart record
    uint32_t tick = 0;                     // +0x08 timing (copied from the record)
    float drawY = 0.0f;                    // +0x0c on-screen scroll position (init 1024.0)
    uint8_t lane = 0;                      // +0x10 lane 0..8, or 9 = non-playable event
    uint8_t _pad11 = 0;                    // +0x11
    uint16_t flags = 0;                    // +0x12 bit0=counted, bit2=judged, bit5=handled
};

// The render descriptor GetNoteObject copies out for one active arcade note: its tick,
// lane, flags and current on-screen scroll position. Ghidra: the 12-byte struct
// acNoteGetNoteObject (@ 0x7b968) fills — tick@+0x0, lane@+0x4, flags@+0x6, drawY@+0x8.
struct AcNoteObject {
    uint32_t tick;   // +0x0  timing (copied from the node)
    uint8_t  lane;   // +0x4  lane 0..8
    uint8_t  _pad5;  // +0x5
    uint16_t flags;  // +0x6  node flags
    float    drawY;  // +0x8  on-screen scroll position
};

// One scroll/tempo segment (the binary's 0xc-byte record at +0xfa4c, stride 0xc): a scroll
// speed (bpm * 1024 / 480000), the tick it starts at, and the raw BPM. The segment array is
// kept sorted by startTick; changeTempo() pops the front as play passes each boundary.
struct AcScrollSegment {
    float speed = 0.0f;            // +0x0  units/ms (0 until registered)
    uint32_t startTick = 0xffffffff; // +0x4  sentinel -1 until registered
    int16_t bpm = -1;              // +0x8  sentinel -1 until registered
};

// Arcade layout lane count (the per-lane tap counters at play-data +0xfa14).
constexpr int kAcLaneCount = 16;

// Maximum simultaneously-active note slots (the 1000-entry free list).
constexpr int kAcMaxActiveNotes = 1000;

// Number of hi-speed steps selectable at play start (difficulty 0..10).
constexpr int kAcHiSpeedCount = 11;

class AcNoteMng {
public:
    // Parse a decoded arcade chart into the play timeline, selecting the hi-speed
    // multiplier for `difficulty` (0..10 -> 1.2x .. 6.0x). Returns 0 on success,
    // -3 if the magic byte is not 'E'. Ghidra: InitPlayData FUN_0007a774.
    int initPlayData(const void *data, int size, int difficulty);

#ifdef __OBJC__
    int initPlayDataWithData(NSData *data, int difficulty);
#endif

    // Register tempo events / convert ticks to ms (arcade tempo map). Ghidra:
    // FUN_0007aa90 / FUN_0007aaf8. registerTempoEvents walks the chart and inserts a scroll
    // segment per tempo event; changeTempo pops the front segment once play passes it and
    // recomputes the spawn look-ahead, returning non-zero while a segment was retired.
    void registerTempoEvents();
    int changeTempo(uint32_t tick);

    // Arm the play clock and begin: set state=playing, freeze the clock, stamp the start time,
    // settle the tempo, and prime one frame. Ghidra: FUN_0007b86c.
    void startPlay(uint32_t pos);

    // --- Play clock --------------------------------------------------------
    // Wall-clock ms since play start (gettimeofday delta; 0 before the clock is
    // armed). Ghidra: FUN_0007b5e0.
    int getElapsedTimeMs() const;

    // The current chart position the arcade note update judges + scrolls against:
    // the elapsed time (frozen while the hold bit is set) plus the per-play offset,
    // added onto the smoothed scroll base once it passes the start threshold. Ghidra:
    // FUN_0007aeb4. (The offset / threshold / scroll-base fields are driven by the
    // arcade per-frame update -update(), below; until play starts they are 0, so this
    // returns the scroll base like the standard engine's lead-in path.)
    int getCurrentPosition();

    // Arcade per-frame update: smooth the scroll base one step toward its target, spawn every
    // chart record now due, judge + retire the active notes, advance the tempo, then refresh
    // each note's scroll position and the per-lane "nearest note" table that input resolves
    // against. Ghidra: FUN_0007ac00.
    void update();

    // --- Pause / resume (input-driven, mirrors NoteMng::togglePause) -------
    // Pause play: stop the BGM and stamp the pause time, then set the freeze bit so the
    // play clock stops advancing. No-op if already held. Ghidra: acNotePause @ 0x7b638.
    void pause();
    // Resume play: fold the paused span into the start threshold, clear the freeze bit,
    // re-seek + restart the BGM at the current position and arm a drift-sync adjust event.
    // No-op unless currently held. Ghidra: acNoteResume @ 0x7b698.
    void resume();

    // Arm the play clock from now (gettimeofday baseline), clear the pause/offset fields and
    // set state = playing. A lighter clock-start than startPlay(). Ghidra: acNoteStartPlayback
    // @ 0x7b5a0.
    void startPlayback();

    // Clear the per-play "playing" flag (Ghidra: the byte @ +0x14cc2, cleared on teardown).
    // Ghidra: acNoteResetPlayFlag @ 0x7aea4.
    void resetPlayFlag();

    // Build the logical-lane -> display-lane table for the selected lane option: 1/3 = random
    // (a time-seeded derangement of lanes 0..8, retried until no lane maps to itself), 2 = mirror
    // (lane i -> 8-i), anything else = identity. Ghidra: acNoteSetupLaneMapping @ 0x7ad14.
    void setupLaneMapping(int mode);

    // --- Play-state queries the draw / result passes read --------------------
    // The chart's total playable-note count (sum of the 9 per-lane tap counters). Ghidra:
    // acNoteGetTotalNoteCount @ 0x7b8ec.
    int getTotalNoteCount() const;
    // The running judged-note total: the sum of the 9x4 per-lane score/judge table (low 16
    // bits). Ghidra: acNoteGetJudgeTotal @ 0x7b908.
    int getJudgeTotal() const;
    // The number of still-unresolved on-screen notes (lane < 9, "handled" bit 5 clear). Ghidra:
    // acNoteCountActiveNotes @ 0x7b93c.
    int countActiveNotes() const;
    // Copy the `index`-th still-unresolved on-screen note (lane < 9, bit 5 clear) into `out`;
    // asserts on a null out or an out-of-range index. Ghidra: acNoteGetNoteObject @ 0x7b968.
    void getNoteObject(AcNoteObject *out, int index) const;
    // OR `flags` into the `index`-th still-unresolved on-screen note (input marks a note hit).
    // Ghidra: acNoteSetNoteFlag @ 0x7b9fc.
    void setNoteFlag(int index, uint16_t flags);

    // The engine keeps one global arcade manager (Ghidra: DAT_0015f1b0), reached
    // through a ___cxa_guard'd lazy accessor. Ghidra: AcNoteMng_shared
    // (FUN_0000b35c), which constructs it once via AcNoteMng_init (FUN_0007a744).
    static AcNoteMng &shared();

private:
    // --- arcade per-frame update helpers (Ghidra addresses noted) ---
    void spawnNotes(uint32_t pos);                            // FUN_0007aef8
    void makeNoteEvent(const AcNoteRecord *rec);              // FUN_0007b2f4 ("MakeNoteEvent")
    void makeEvent(const AcNoteRecord *rec);                  // FUN_0007b3dc ("MakeEvent")
    void makeAdjustEvent(uint32_t tick);                      // FUN_0007b790 ("MakeAdjustEvent")
    void judgeActiveNote(AcActiveNote *node, uint32_t pos);   // FUN_0007b028
    void retireActiveNote(AcActiveNote **node, uint32_t pos); // FUN_0007b0a8
    void updateNearest(AcActiveNote *node, uint32_t pos);     // FUN_0007b1bc
    void updateDrawPos(AcActiveNote *node, uint32_t pos);     // FUN_0007b268
    float computeScrollY(const AcActiveNote *node, uint32_t pos) const; // FUN_0007bb30
    void triggerBgmStart();                                   // FUN_0007b484
    void applyBgmSync(const AcNoteRecord *rec);               // FUN_0007b4f0
    // List moves shared by the make*/retire helpers.
    void moveNodeFreeToActive(AcActiveNote *node);
    void retireNode(AcActiveNote *node);
    // Build the free list from the node pool (tail of InitPlayData FUN_0007a774).
    void initNodePool();
    // Insert one tempo/scroll segment sorted by startTick; returns non-zero if the table is
    // full (max 63). Ghidra: FUN_0007ba3c ("AdvanceRegisterEvent").
    int registerScrollSegment(int16_t bpm, uint32_t tick);
    // Recompute the spawn look-ahead (m_spawnLookahead) from the front scroll segments (shared
    // tail of registerScrollSegment / changeTempo).
    void recomputeSpawnLookahead(uint32_t pos);

    // Parsed chart.
    AcNoteRecord *m_records = nullptr;
    int m_recordCount = 0;
    uint16_t m_minTempoValue = 0x7fff;
    uint16_t m_maxTempoValue = 0;
    uint32_t m_endValue = 0;
    int16_t m_laneCounts[kAcLaneCount] = {};

    // Play state.
    float m_hiSpeed = 1.2f;              // +0x14cc4 (AcNoteMng_init default = 0x3f99999a)
    int16_t m_scrollCount = 0;           // +0xfd4c  live scroll-segment count (max 63)
    int16_t m_chartBarCount = 0;         // +0xfa32  total measure lines seen while registering

    // Play clock (Ghidra fields inside the arcade play-data region). m_startSec/
    // m_startUsec (@ +0x14cb8/+0x14cbc) are the gettimeofday stamp taken when play
    // starts; the rest are driven by the per-frame update FUN_0007ac00.
    long m_startSec = 0;
    long m_startUsec = 0;
    int  m_frozenElapsed = 0;   // +0xfa38  cached elapsed while the hold bit is set
    int  m_holdElapsed = 0;     // +0xfa40  hold/pause clock accumulator (reset on startPlay)
    int  m_positionOffset = 0;  // +0xfa44  constant offset added to elapsed
    uint32_t m_startThreshold = 0; // +0xfa3c  position at which the scroll base advances
    int  m_scrollBase = 0;      // +0xfe18  smoothed scroll/position base
    uint8_t m_holdFlags = 0;    // +0xfa48  bit 0 = freeze the clock (pause/hold)

    // Timing windows (Ghidra: copied from DAT_0012f868).
    int m_judgeWindows[6] = {};

    // Scoring.
    int m_combo = 0;            // +0xfd54
    int m_maxCombo = 0;         // +0xfd58

    // --- per-frame arcade update state (Ghidra offsets into the play-data blob) ---
    int m_state = 0;                 // +0xfd50  1=playing, 3=ending, 4=finished
    int m_scrollTarget = 0;          // +0xfe14  scroll base is smoothed toward this
    int m_expectedTimeBase = 0;      // +0xfe10  expected time used by the BGM drift sync
    AcNoteRecord *m_spawnCursor = nullptr; // +0xfa0c  next chart record awaiting spawn
    int m_spawnLookahead = 0;        // +0xfa2c  look-ahead added to the position for spawning
    int16_t m_barCount = 0;          // +0xfa30  measure counter
    int16_t m_beatCount = 0;         // +0xfa34  beat counter (reset each measure)
    float m_playSpeed = 0.0f;        // +0xfa4c  base scroll speed (also scroll segment 0's speed)
    uint8_t m_endFlag = 0;           // +0x14cc0 the end (type 6) note has been reached
    uint8_t m_autoPlay = 0;          // +0x14cc1 auto-play (attract/replay) drives the hits itself
    uint8_t m_playFlag = 0;          // +0x14cc2 per-play "playing" flag (cleared by resetPlayFlag)
    int m_laneMode = 0;              // +0x14cc8 3 = rotating lane assignment
    int32_t m_laneRemap[16] = {};    // +0x14ccc logical lane -> display lane
    int m_nearestThreshold = 0;      // +0x14c58 max +dt still eligible as the lane's "nearest"
    AcNoteRecord m_adjustRecord = {};// +0xfa04 injected BGM-sync event; its .value (@+0xfa0a)
                                     //          doubles as the "adjust in flight" flag
    AcActiveNote *m_activeHead = nullptr;  // +0x14c40 on-screen notes
    AcActiveNote *m_freeHead = nullptr;    // +0x14c3c recycled-node free list
    AcActiveNote m_notePool[kAcMaxActiveNotes] = {}; // the fixed node pool (linked at play init)
    AcScrollSegment m_scrollMap[64] = {};  // +0xfa4c scroll/tempo segments (max 63 + guard)

    struct LaneResult { int hits = 0; int _reserved[3] = {}; }; // +0xfd68, stride 0x10
    LaneResult m_laneResult[9];
    struct NearestNote { AcActiveNote *note = nullptr; int dt = 0; }; // +0x14c5c, stride 8
    NearestNote m_nearest[9];
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
