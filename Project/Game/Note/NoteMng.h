//
//  NoteMng.h
//  pop'n rhythmin
//
//  The standard-mode note manager: it parses a decoded chart (the "info" entry
//  of a %09d.orb file), builds the play-data timeline, converts chart ticks to
//  milliseconds via the tempo map, and drives note judgement during play.
//  (Arcade charts, ac%09d.acv, are handled by the parallel AcNoteMng.)
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (Project/Game/Note/NoteMng.mm). The .orb/.acv container is a ZIP whose "info"
//  entry is BFCodec-encrypted; MusicManager decrypts it, and the plaintext is the
//  chart described below.
//

//  Chart-load flow: a %09d.orb / ac%09d.acv file (ZIP + BFCodec-encrypted entries)
//  is decoded into an (Ac)MusicData object; the play loader picks the sheet for
//  the chosen difficulty (-[AcMusicData sheetEasy/sheetNormal/sheetHyper/sheetEx],
//  the "sheet_es/n/h/ex" ZIP entries) and passes it to
//  -[NoteMng initPlayDataWithData:] on the global manager (Ghidra: DAT_00173ea4).
//

#pragma once

#include <cstdint>

#ifdef __OBJC__
@class NSData;
#endif

// ---------------------------------------------------------------------------
// Chart format (decoded "info" payload)
// ---------------------------------------------------------------------------
// Layout: a 4-byte header word, then N note records of 20 bytes each, where
//   N = (payloadSize - 4) / 20   (Ghidra: InitPlayData @ 0x335a4).
// The record `type` byte at +0x8 selects how the other fields are read.
enum NoteType : uint8_t {
    NOTE_TYPE_NORMAL = 0,   // a playable tap note (counted into the note total)
    NOTE_TYPE_MARK = 1,     // stores its `tick` into a play-data field (start/marker)
    NOTE_TYPE_TEMPO = 2,    // tempo/BPM event: `value` (+0xc) is the BPM, `tick` the position
    NOTE_TYPE_END = 3,      // end-of-chart terminator
    NOTE_TYPE_BAR = 4,      // measure bar line (counted by registerTempoEvents)
};

// One 20-byte chart record. Verified fields: `tick` (+0x0), `type` (+0x8),
// `value` (+0xc, the BPM for NOTE_TYPE_TEMPO; its min/max across the chart are
// tracked at InitPlayData time). The remaining words are type-dependent and are
// copied verbatim into the runtime note slot.
struct NoteRecord {
    uint32_t tick;      // +0x0  timing position, in chart ticks
    uint32_t param;     // +0x4  type-dependent
    uint8_t  type;      // +0x8  NoteType
    uint8_t  reserved[3]; // +0x9
    uint16_t value;     // +0xc  NOTE_TYPE_TEMPO: BPM
    uint16_t value2;    // +0xe  type-dependent
    uint32_t extra;     // +0x10 type-dependent
};
static_assert(sizeof(NoteRecord) == 20, "chart note record is 20 bytes");

// Maximum simultaneously-active note slots the manager pools (Ghidra: the 1000
// entry free list built in InitPlayData, stride 0x3c).
constexpr int kMaxActiveNotes = 1000;

// Render kind, recomputed into a NoteRenderData by copyNoteRenderData (@ 0x34758):
// 1 for a special chart kind (6..9), 2 for a long/hold note (start < end), else 0.
enum NoteRenderKind : uint8_t {
    NOTE_RENDER_NORMAL = 0,
    NOTE_RENDER_SPECIAL = 1,
    NOTE_RENDER_LONG = 2,
};

// A live note object, pooled in the free/active singly-linked lists. 60 bytes,
// laid out from the decompiled slot (makeNote @ 0x341a4). makeNote fills the
// screen position from the chart record's lane/position bytes scaled by the live
// screen size; makeEvent (@ 0x343c8) spawns non-note events with kind 10.
struct ActiveNote {
    ActiveNote *next;       // +0x00  free/active list link
    const NoteRecord *rec;  // +0x04  source chart record
    uint32_t reserved08;    // +0x08
    uint32_t startTick;     // +0x0c
    uint32_t endTick;       // +0x10  == startTick for taps, later for holds
    float scaleX;           // +0x14  (default 1024.0)
    float scaleY;           // +0x18  (default 1024.0)
    uint8_t kind;           // +0x1c  note kind (>= 10 marks an event)
    uint8_t kindHi;         // +0x1d
    uint8_t reserved1e[2];  // +0x1e
    float x;                // +0x20  on-screen position
    float y;                // +0x24
    float x2;               // +0x28  hold-note end position
    float y2;               // +0x2c
    float targetX;          // +0x30  judge-line target
    float targetY;          // +0x34
    uint16_t flags;         // +0x38  bit 0x80 = judged / inactive
    uint8_t spawnKind;      // +0x3a  1..5 (from the type-6..9 table, else 1)
    uint8_t reserved3b;     // +0x3b
};
// The original armv7 slot was 60 bytes (stride 0x3c); the two pointers widen it
// on the 64-bit rebuild target, so only assert the packed size on 32-bit.
#if !defined(__LP64__) || !__LP64__
static_assert(sizeof(ActiveNote) == 60, "active note slot is 60 bytes on armv7");
#endif

// Judgement tiers (best to worst). The numeric value doubles as the per-kind
// hit-tally index. Ghidra: judgeNoteHit assigns these from the timing delta.
enum NoteJudge {
    NOTE_JUDGE_COOL = 0,
    NOTE_JUDGE_GREAT = 1,
    NOTE_JUDGE_GOOD = 2,
    NOTE_JUDGE_BAD = 3,
    NOTE_JUDGE_MISS = -1,   // outside every window (getNoteObject returns nothing)
    NOTE_JUDGE_TIER_COUNT = 4,
};

// The engine distinguishes this many note "kinds" (each keeps its own hit tally).
constexpr int kNoteKindCount = 10;

// Per-note render descriptor the renderer receives from getNoteObject: the ticks,
// kind, scale and positions copied out of the ActiveNote plus a freshly-computed
// NoteRenderKind. Ghidra: copyNoteRenderData @ 0x34758.
struct NoteRenderData {
    const NoteRecord *rec;
    uint32_t startTick;
    uint32_t endTick;
    uint8_t kind;
    uint8_t kindHi;
    uint16_t flags;
    NoteRenderKind renderKind;
    float scaleX;
    float scaleY;
    uint8_t spawnKind;
    float x;
    float y;
    float x2;         // hold-note end
    float y2;
    float targetX;    // judge-line target
    float targetY;
};

class NoteMng {
public:
    // Parse a decoded chart into the play-data timeline. `data` points at the
    // 4-byte header; `size` is the whole payload length. Ghidra: InitPlayData
    // @ 0x335a4 (asserts size validity at NoteMng.mm:0x45/0x59).
    int initPlayData(const void *data, int size, uint32_t arg4, uint32_t arg5);

#ifdef __OBJC__
    // Parse a chart straight from an NSData (bytes + length -> initPlayData); the
    // sheet the play loader selected for the difficulty. Ghidra: @ 0x33550.
    int initPlayDataWithData(NSData *data, uint32_t arg3, uint32_t arg4);
#endif

    // Walk the parsed records and register every tempo (type 2) event into the
    // tempo map, counting bar lines (type 4). Ghidra: @ 0x337e0.
    void registerTempoEvents();

    // Convert a chart position `tick` to elapsed milliseconds by accumulating
    // 60000/BPM across the tempo segments up to it. Ghidra: ChangeTempo @ 0x33864.
    void changeTempo(uint32_t tick);

    // Register one tempo segment (bpm, at tick) into the tempo map. Ghidra:
    // AdvanceRegisterEvent @ 0x34bf0.
    int advanceRegisterEvent(int bpm, uint32_t tick);

    // Spawn a live note from a chart record: take a free slot, copy the ticks,
    // compute the on-screen position, and move it to the active list. Ghidra:
    // MakeNote @ 0x341a4.
    void makeNote(const NoteRecord *rec);

    // Spawn a non-note event (kind 10) from a chart record. Ghidra: MakeEvent @ 0x343c8.
    void makeEvent(const NoteRecord *rec);

    // Milliseconds elapsed since play start (gettimeofday minus the stored start
    // time; 0 before the clock is armed). Ghidra: @ 0x33c04.
    int getElapsedTimeMs() const;

    // The current chart scroll position, derived from getElapsedTimeMs() plus the
    // per-play offsets — the time base every note is judged and drawn against.
    // Ghidra: @ 0x34164 (used pervasively: 12 call sites).
    int getCurrentPosition() const;

    // YES once the chart has emitted its last note and no notes remain live (the
    // play-loop watches this to end the song). Ghidra: FUN_0003181c.
    bool isFinished() const;

    // Fill `out` with the render data of the `index`-th still-judgeable active
    // note (kind < 10, not flagged 0x80). Ghidra: GetNoteObject @ 0x346c0, which
    // delegates the field copy to copyNoteRenderData (@ 0x34758).
    void getNoteObject(NoteRenderData *out, int index);

    // Number of active notes still awaiting judgement (kind < 10, flag 0x80
    // clear). Ghidra: @ 0x34694.
    int getActiveNoteCount() const;

    // --- Judgement ---------------------------------------------------------
    // Grade a tap against the note `index`: delta = noteTick - getCurrentPosition
    // is bucketed against the six timing windows (Ghidra: g_noteJudgeWindows @
    // 0x12e64c = {-280,-280,-120,+120,+280,+280} ms, copied into the play data at
    // InitPlayData). The tightest central band (|delta| within ~50 ms of the
    // -120..+120 window) is the best tier; then the ±120 and ±280 bands; a delta
    // outside ±280 misses (returns -1). Returns a tier 0..3 that also indexes the
    // per-note-kind hit tally, sets the note's judged flags, and updates the
    // current/max combo. Ghidra: judgeNoteHit @ 0x347e8.
    int judgeNoteHit(unsigned index);

    // Resolve a long/hold note once its tail passes: if released too late
    // (delta < -60 ms) the hold fails (flag 0x200, "NOTE_FLAGS_LONG_FAILED"),
    // otherwise it succeeds (flag 0x100, "NOTE_FLAGS_LONG_SUCCESS") and counts
    // toward the combo + tally. Ghidra: @ 0x34a78.
    int updateLongNote(unsigned index);

    int combo() const { return m_combo; }
    int maxCombo() const { return m_maxCombo; }
    int judgeCount(int kind, NoteJudge tier) const { return m_tally[kind][tier]; }

    // The chart's total playable-note count, fixed once the chart is parsed at
    // initPlayData (the count of NOTE_TYPE_NORMAL records): the running score's
    // denominator (PlayCurrentScore) and the full-combo / all-perfect threshold the
    // song-clear jingles test. Ghidra: DAT_00178ccc.
    int totalNoteCount() const { return m_totalNotes; }

    // The engine keeps one global standard-mode manager (Ghidra: DAT_00173ea4),
    // reached through a ___cxa_guard'd lazy accessor. Ghidra: NoteMng_shared
    // (FUN_0000b278), which constructs it once via NoteMng_init (FUN_00033514).
    static NoteMng &shared();

    // Resign/suspend hook (app resigns active): stop the BGM and remember the
    // current play position so it can resume, guarded to run once. Ghidra:
    // NEEngine_onResignActivePushHook (FUN_00034510), invoked on the global.
    void onResignActivePushHook();

private:
    // One BPM segment of the tempo map (registered from NOTE_TYPE_TEMPO records).
    struct TempoSegment {
        uint32_t startTick;   // chart tick this BPM takes effect
        uint32_t startMs;     // its start time in ms (cumulative)
        int16_t bpm;
    };

    ActiveNote *allocNote();                     // pop a free slot (nullptr if none)
    void moveToActive(ActiveNote *note);         // free list -> active list
    ActiveNote *activeNoteAt(unsigned index);    // n-th judgeable active note

    // Parsed chart (records copied out of the decoded payload).
    NoteRecord *m_records = nullptr;
    int m_recordCount = 0;
    uint16_t m_minTempoValue = 0x7fff;
    uint16_t m_maxTempoValue = 0;
    uint32_t m_endValue = 0;

    // Tempo map + derived current time.
    TempoSegment m_tempoMap[512] = {};
    int m_tempoCount = 0;
    uint32_t m_currentMs = 0;

    // Play clock (gettimeofday at play start).
    long m_startSec = 0;
    long m_startUsec = 0;
    int m_positionLeadIn = 0;   // constant offset added to elapsed by getCurrentPosition

    // Timing windows, copied from g_noteJudgeWindows at initPlayData.
    int m_judgeWindows[6] = {};

    // Pooled note objects + the free/active singly-linked lists.
    ActiveNote m_notePool[kMaxActiveNotes] = {};
    ActiveNote *m_freeList = nullptr;
    ActiveNote *m_activeList = nullptr;

    // Scoring.
    int m_combo = 0;
    int m_maxCombo = 0;
    int m_tally[kNoteKindCount][NOTE_JUDGE_TIER_COUNT] = {};   // per-kind hit counts
    int m_totalNotes = 0;   // chart playable-note total (Ghidra: DAT_00178ccc)
    int m_earlyMiss[kNoteKindCount] = {};                     // too-early presses

    bool m_autoPlay = false;   // Ghidra flag @ +0x13cb5 (skips manual judgement)

    // Resign/suspend bookkeeping (Ghidra: within the play-data region, near +0x05;
    // the recorded position field is written by FUN_00034510).
    bool m_suspendedForResign = false;
    int  m_resignPositionMs = 0;
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
