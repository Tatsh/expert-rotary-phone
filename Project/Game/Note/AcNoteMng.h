/**
 * @file
 * @brief The arcade note manager.
 *
 * It parses an arcade chart (a "sheet_*" entry of an ac%09d.acv, provided by AcMusicData) and
 * drives arcade-mode play. It parallels the standard NoteMng but uses a different, more compact
 * chart format. Reconstructed from Ghidra project rb420, program PopnRhythmin
 * (Project/Game/Note/AcNoteMng.mm; InitPlayData FUN_0007a774).
 */

#pragma once

#include <cstddef>
#include <cstdint>
#include <span>

#import <Foundation/Foundation.h>

#ifdef __OBJC__
@class NSData;
#endif

// Arcade chart: an 8-byte header (magic 'E' at offset +4) then N 8-byte note records, where
// N = (size / 8) - 2. Each record's type byte is at +0x4 and its value (lane or BPM) at +0x6.

/**
 * @brief The arcade chart record kind, stored in AcNoteRecord::type.
 *
 * The names are historical; the semantics below are the binary's, taken from InitPlayData and the
 * update closure.
 */
enum AcNoteType : uint8_t {
    AC_NOTE_TAP = 1, /**< A playable note, counted per lane. */
    /** The BGM-start / drift-sync anchor — NOT the chart end; its tick becomes the sync
     * reference time. */
    AC_NOTE_END = 3,
    AC_NOTE_TEMPO = 4, /**< A tempo/BPM event; its minimum and maximum are tracked. */
    /** The real end-of-chart marker; its tick becomes the end value, and the appended terminator
     * is stamped with this type so update() can raise the end flag. */
    AC_NOTE_EVENT = 6,
    AC_NOTE_MEASURE = 0xa, /**< A measure boundary, advancing the bar counter. */
    AC_NOTE_BEAT = 0xb,    /**< A beat boundary, advancing the beat counter. */
    AC_NOTE_ADJUST = 0xf,  /**< A synthesised BGM drift-sync adjust event (applyBgmSync). */
};

/**
 * @brief The playback state machine (m_state @ +0xfd50).
 */
enum AcNoteMngState {
    AC_NOTE_STATE_IDLE = 0,     /**< Before playback starts, or after a reset. */
    AC_NOTE_STATE_PLAYING = 1,  /**< Notes are scrolling and being spawned. */
    AC_NOTE_STATE_SEEKING = 2,  /**< Seeking to a new position. */
    AC_NOTE_STATE_ENDING = 3,   /**< The chart-end marker was reached; draining the field. */
    AC_NOTE_STATE_FINISHED = 4, /**< Playback is complete. */
};

/**
 * @brief One 8-byte arcade chart record.
 */
struct AcNoteRecord {
    uint32_t tick;     /**< +0x0 Timing position, in chart ticks. */
    uint8_t type;      /**< +0x4 The record kind, an AcNoteType. */
    uint8_t reserved5; /**< +0x5 Padding. */
    uint16_t value;    /**< +0x6 The lane, in the low nibble, or the BPM. */
};
static_assert(sizeof(AcNoteRecord) == 8, "arcade note record is 8 bytes");

/**
 * @brief AcActiveNote::flags bits.
 *
 * The arcade viewer, a non-scored preview, only ever sets bits 0, 2 and 5. The two guard masks
 * below are over-broad — they also cover bits 1, 3 and 4 that the fuller standard-engine flag
 * scheme (NoteFlag in NoteMng.h) uses but this preview never sets — so in practice they test
 * AC_NOTE_FLAG_COUNTED and AC_NOTE_FLAG_HANDLED respectively.
 */
enum AcNoteFlag : uint16_t {
    AC_NOTE_FLAG_COUNTED = 0x1,     /**< Bit 0: counted into the per-lane tally. */
    AC_NOTE_FLAG_JUDGED = 0x4,      /**< Bit 2: the head has scrolled past the judge line. */
    AC_NOTE_FLAG_HANDLED = 0x20,    /**< Bit 5: the note's event fired, or it is resolved. */
    AC_NOTE_FLAG_COUNT_GUARD = 0xb, /**< Bits 0, 1 and 3: the "already counted" retire/skip
                                         guard. */
    AC_NOTE_FLAG_RETIRE = 0x30,     /**< Bits 4 and 5: the "resolved" retire guard. */
};

/**
 * @brief One active (on-screen or in-flight) note.
 *
 * A fixed pool is threaded onto either the free list or the active list; play never allocates. The
 * layout mirrors the binary's node: next @ 0x0, record @ 0x4, tick @ 0x8, drawY @ 0xc, lane @
 * 0x10, flags @ 0x12.
 */
struct AcActiveNote {
    AcActiveNote *next = nullptr;         /**< +0x00 Free or active list link. */
    const AcNoteRecord *record = nullptr; /**< +0x04 The source chart record. */
    uint32_t tick = 0;                    /**< +0x08 Timing, copied from the record. */
    float drawY = 0.0f; /**< +0x0c On-screen scroll position; initialised to 1024.0. */
    uint8_t lane = 0;   /**< +0x10 Lane 0..8, or 9 for a non-playable event. */
    uint8_t _pad11 = 0; /**< +0x11 Padding. */
    uint16_t flags = 0; /**< +0x12 AcNoteFlag bits. */
};

/**
 * @brief The render descriptor getNoteObject() copies out for one active arcade note.
 *
 * Ghidra: the 12-byte struct acNoteGetNoteObject (@ 0x7b968) fills — tick @ +0x0, lane @ +0x4,
 * flags @ +0x6, drawY @ +0x8.
 */
struct AcNoteObject {
    uint32_t tick;  /**< +0x0 Timing, copied from the node. */
    uint8_t lane;   /**< +0x4 Lane 0..8. */
    uint8_t _pad5;  /**< +0x5 Padding. */
    uint16_t flags; /**< +0x6 The node's AcNoteFlag bits. */
    float drawY;    /**< +0x8 On-screen scroll position. */
};

/**
 * @brief One scroll/tempo segment: the binary's 0xc-byte record at +0xfa4c, stride 0xc.
 *
 * The segment array is kept sorted by startTick; changeTempo() pops the front as play passes each
 * boundary.
 */
struct AcScrollSegment {
    float speed = 0.0f; /**< +0x0 Scroll speed in units/ms, bpm * 1024 / 480000; 0 until
                             registered. */
    uint32_t startTick = 0xffffffff; /**< +0x4 The tick the segment starts at; -1 until
                                          registered. */
    int16_t bpm = -1;                /**< +0x8 The raw BPM; -1 until registered. */
};

/**
 * @brief The arcade layout lane count (the per-lane tap counters at play-data +0xfa14).
 */
constexpr int kAcLaneCount = 16;

/**
 * @brief The maximum number of simultaneously-active note slots: the 1000-entry free list.
 */
constexpr int kAcMaxActiveNotes = 1000;

/**
 * @brief The number of hi-speed steps selectable at play start, difficulty 0..10.
 */
constexpr int kAcHiSpeedCount = 11;

/**
 * @brief The arcade note manager: arcade chart parsing, the tempo map, note spawning and the
 * arcade-viewer play clock.
 */
class AcNoteMng {
public:
    /**
     * @brief Parse a decoded arcade chart into the play timeline.
     * @param data The whole chart payload.
     * @param hiSpeedLevel The acvHiSpeed setting, 0..10, selecting a 1.2x to 6.0x multiplier.
     * @return 0 on success, or -3 if the magic byte is not 'E'.
     * @ghidraAddress 0x7a774
     */
    int initPlayData(std::span<const std::byte> data, int hiSpeedLevel);

#ifdef __OBJC__
    /**
     * @brief Parse an arcade chart straight from an NSData; the bytes and length are forwarded to
     * initPlayData().
     * @param data The sheet the play loader selected.
     * @param hiSpeedLevel The acvHiSpeed setting, 0..10.
     * @return 0 on success, or -3 if the magic byte is not 'E'.
     */
    int initPlayDataWithData(NSData *data, int hiSpeedLevel);
#endif

    /**
     * @brief Walk the chart and insert a scroll segment per tempo event.
     * @ghidraAddress 0x7aa90
     */
    void registerTempoEvents();
    /**
     * @brief Pop the front scroll segment once play passes it and recompute the spawn look-ahead.
     * @param tick The current chart position.
     * @return Non-zero while a segment was retired.
     * @ghidraAddress 0x7aaf8
     */
    int changeTempo(uint32_t tick);

    /**
     * @brief Seek or fast-forward the internal play clock to a target position.
     *
     * A no-op if the current offset and the requested position are both already at or past the
     * chart end, or if the target is not ahead of the current offset. Otherwise it enters the
     * seeking state (m_state = 2), clears the frozen-elapsed, hold and start-threshold fields,
     * freezes the clock (m_holdFlags = 1), clamps and stores the target as the play offset,
     * restamps the wall clock, settles every tempo segment up to the new position, then primes one
     * frame so the active-note cursor is rebuilt at the seek target.
     * @param pos The target position, in milliseconds.
     * @ghidraAddress 0x7b86c
     */
    void seekTo(uint32_t pos);

    /**
     * @brief Wall-clock milliseconds since play start, as a gettimeofday delta.
     * @return The elapsed milliseconds, or 0 before the clock is armed.
     * @ghidraAddress 0x7b5e0
     */
    int getElapsedTimeMs() const;

    /**
     * @brief The current chart position the arcade note update judges and scrolls against.
     *
     * The elapsed time (frozen while the hold bit is set) plus the per-play offset, added onto the
     * smoothed scroll base once it passes the start threshold. The offset, threshold and
     * scroll-base fields are driven by update(); until play starts they are 0, so this returns the
     * scroll base like the standard engine's lead-in path.
     * @return The chart position, in milliseconds.
     * @ghidraAddress 0x7aeb4
     */
    int getCurrentPosition();

    /**
     * @brief The arcade per-frame update.
     *
     * Smooths the scroll base one step toward its target, spawns every chart record now due,
     * judges and retires the active notes, advances the tempo, then refreshes each note's scroll
     * position and the per-lane "nearest note" table that input resolves against.
     * @ghidraAddress 0x7ac00
     */
    void update();

    /**
     * @brief Pause play: stop the BGM, stamp the pause time, then set the freeze bit so the play
     * clock stops advancing. A no-op if already held.
     * @ghidraAddress 0x7b638
     */
    void Pause();
    /**
     * @brief Resume play: fold the paused span into the start threshold, clear the freeze bit,
     * re-seek and restart the BGM at the current position, and arm a drift-sync adjust event. A
     * no-op unless currently held.
     * @ghidraAddress 0x7b698
     */
    void resume();

    /**
     * @brief Arm the play clock from now (a gettimeofday baseline), clear the pause and offset
     * fields, and set the state to playing. A lighter clock start than seekTo().
     * @ghidraAddress 0x7b5a0
     */
    void startPlayback();

    /**
     * @brief Clear the per-play "playing" flag (the byte @ +0x14cc2), on teardown.
     * @ghidraAddress 0x7aea4
     */
    void resetPlayFlag();

    /**
     * @brief The per-play "playing" flag (m_playFlag @ +0x14cc2).
     *
     * It gates the on-resign arcade pause; -[AppDelegate applicationWillResignActive] @ 0x95a8
     * reads AcNoteMng+0x14cc2.
     * @return true while a play is running.
     */
    bool isPlaying() const {
        return m_playFlag;
    }

    /**
     * @brief Build the logical-lane to display-lane table for the selected lane option.
     * @param mode 1 or 3 for random (a time-seeded derangement of lanes 0..8, retried until no
     * lane maps to itself), 2 for mirror (lane i maps to 8-i), anything else for identity.
     * @ghidraAddress 0x7ad14
     */
    void setupLaneMapping(int mode);

    /**
     * @brief The chart's total playable-note count: the sum of the nine per-lane tap counters.
     * @return The playable-note total.
     * @ghidraAddress 0x7b8ec
     */
    int getTotalNoteCount() const;
    /**
     * @brief The chart's end tick: the type-6 end marker's tick (+0xfe18 nPlayheadMs), the
     * denominator for the play-progress timeline bar.
     * @return The end tick, in milliseconds.
     */
    uint32_t playheadMs() const {
        return m_endValue;
    }
    /**
     * @brief Whether the type-6 end note has passed the judge line.
     *
     * In the binary this is the g_abAcNoteMng.bBgmMuted field, read by the arcade viewer as
     * DAT_00173e70 to detect chart completion and return to the song menu.
     * @return true once the chart has ended.
     */
    bool isFinished() const {
        return m_endFlag;
    }
    /**
     * @brief The running judged-note total: the sum of the 9x4 per-lane score/judge table, low 16
     * bits.
     * @return The judged-note total.
     * @ghidraAddress 0x7b908
     */
    int getJudgeTotal() const;
    /**
     * @brief The number of still-unresolved on-screen notes: lane below 9 with the "handled" bit 5
     * clear.
     * @return The unresolved note count.
     * @ghidraAddress 0x7b93c
     */
    int countActiveNotes() const;
    /**
     * @brief Copy the @p index -th still-unresolved on-screen note (lane below 9, bit 5 clear)
     * into @p out. Asserts on a null @p out or an out-of-range @p index.
     * @param out Receives the note's render descriptor.
     * @param index The index among the still-unresolved notes.
     * @ghidraAddress 0x7b968
     */
    void getNoteObject(AcNoteObject *out, int index) const;
    /**
     * @brief OR @p flags into the @p index -th still-unresolved on-screen note; input marks a note
     * hit this way.
     * @param index The index among the still-unresolved notes.
     * @param flags The AcNoteFlag bits to set.
     * @ghidraAddress 0x7b9fc
     */
    void setNoteFlag(int index, uint16_t flags);

    /**
     * @brief The one global arcade manager (Ghidra: DAT_0015f1b0), reached through a
     * ___cxa_guard'd lazy accessor.
     *
     * Ghidra: AcNoteMng_shared (FUN_0000b35c), which constructs it once via AcNoteMng_init
     * (FUN_0007a744).
     * @return The manager.
     */
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
    float computeScrollY(const AcActiveNote *node,
                         uint32_t pos) const;   // FUN_0007bb30
    void triggerBgmStart();                     // FUN_0007b484
    void applyBgmSync(const AcNoteRecord *rec); // FUN_0007b4f0
    // List moves shared by the make*/retire helpers.
    void moveNodeFreeToActive(AcActiveNote *node);
    void retireNode(AcActiveNote *node);
    // Build the free list from the node pool (tail of InitPlayData FUN_0007a774).
    void initNodePool();
    // Insert one tempo/scroll segment sorted by startTick; returns non-zero if
    // the table is full (max 63). Ghidra: FUN_0007ba3c ("AdvanceRegisterEvent").
    int registerScrollSegment(int16_t bpm, uint32_t tick);
    // Recompute the spawn look-ahead (m_spawnLookahead) from the front scroll
    // segments (shared tail of registerScrollSegment / changeTempo).
    void recomputeSpawnLookahead(uint32_t pos);

    // Parsed chart.
    AcNoteRecord *m_records = nullptr;
    int m_recordCount = 0;
    uint16_t m_minTempoValue = 0x7fff;
    uint16_t m_maxTempoValue = 0;
    uint32_t m_endValue = 0;
    int16_t m_laneCounts[kAcLaneCount] = {};

    // Play state.
    float m_hiSpeed = 1.2f;      // +0x14cc4 (AcNoteMng_init default = 0x3f99999a)
    int16_t m_scrollCount = 0;   // +0xfd4c  live scroll-segment count (max 63)
    int16_t m_chartBarCount = 0; // +0xfa32  total measure lines seen while registering

    // Play clock (Ghidra fields inside the arcade play-data region). m_startSec/
    // m_startUsec (@ +0x14cb8/+0x14cbc) are the gettimeofday stamp taken when
    // play starts; the rest are driven by the per-frame update FUN_0007ac00.
    long m_startSec = 0;
    long m_startUsec = 0;
    int m_frozenElapsed = 0;       // +0xfa38  cached elapsed while the hold bit is set
    int m_holdElapsed = 0;         // +0xfa40  hold/pause clock accumulator (reset on seekTo)
    int m_positionOffset = 0;      // +0xfa44  constant offset added to elapsed
    uint32_t m_startThreshold = 0; // +0xfa3c  position at which the scroll base advances
    int m_scrollBase = 0;          // +0xfe18  smoothed scroll/position base
    uint8_t m_holdFlags = 0;       // +0xfa48  bit 0 = freeze the clock (pause/hold)

    // Timing windows (Ghidra: copied from DAT_0012f868).
    int m_judgeWindows[6] = {};

    // Scoring.
    int m_combo = 0;    // +0xfd54
    int m_maxCombo = 0; // +0xfd58

    // --- per-frame arcade update state (Ghidra offsets into the play-data blob)
    // ---
    AcNoteMngState m_state = AC_NOTE_STATE_IDLE; // +0xfd50 playback state machine
    int m_scrollTarget = 0;                      // +0xfe14  scroll base is smoothed toward this
    int m_expectedTimeBase = 0;            // +0xfe10  expected time used by the BGM drift sync
    AcNoteRecord *m_spawnCursor = nullptr; // +0xfa0c  next chart record awaiting spawn
    int m_spawnLookahead = 0;              // +0xfa2c  look-ahead added to the position for spawning
    int16_t m_barCount = 0;                // +0xfa30  measure counter
    int16_t m_beatCount = 0;               // +0xfa34  beat counter (reset each measure)
    float m_playSpeed = 0.0f;         // +0xfa4c  base scroll speed (also scroll segment 0's speed)
    bool m_endFlag = false;           // +0x14cc0 the end (type 6) note has been reached
    bool m_autoPlay = false;          // +0x14cc1 auto-play (attract/replay) drives the hits itself
    bool m_playFlag = false;          // +0x14cc2 per-play "playing" flag (cleared by resetPlayFlag)
    int m_laneMode = 0;               // +0x14cc8 3 = rotating lane assignment
    int32_t m_laneRemap[16] = {};     // +0x14ccc logical lane -> display lane
    int m_nearestThreshold = 0;       // +0x14c58 max +dt still eligible as the lane's "nearest"
    AcNoteRecord m_adjustRecord = {}; // +0xfa04 injected BGM-sync event; its .value (@+0xfa0a)
                                      //          doubles as the "adjust in flight" flag
    AcActiveNote *m_activeHead = nullptr;            // +0x14c40 on-screen notes
    AcActiveNote *m_freeHead = nullptr;              // +0x14c3c recycled-node free list
    AcActiveNote m_notePool[kAcMaxActiveNotes] = {}; // the fixed node pool (linked at play init)
    AcScrollSegment m_scrollMap[64] = {}; // +0xfa4c scroll/tempo segments (max 63 + guard)

    // One lane's judgement tally (Ghidra aJudgeTally row: 4 ints, stride 0x10).
    // Only the 4th int (the hit counter) is written in this arcade-viewer /
    // auto-play mode; the leading three are the binary's other judge-tier slots,
    // never written here. getJudgeTotal() sums all four per lane.
    struct LaneResult {
        int _unwritten[3] = {}; // +0x00 other judge-tier slots (unwritten in this mode)
        int hits = 0;           // +0x0c the auto-play hit counter
    }; // +0xfd5c, stride 0x10
    LaneResult m_laneResult[9];
    struct NearestNote {
        AcActiveNote *note = nullptr;
        int dt = 0;
    }; // +0x14c5c, stride 8
    NearestNote m_nearest[9];
};

// Arcade-viewer judge-result globals read by the HUD draw callback (Ghidra: g_dwAcCoolCount /
// g_dwAcGreatCount @ DAT_0016ebe0 / DAT_0016ebe4). Xref-verified: the binary only reads them
// (aepHudDrawCallback), never writes them, and their baked value is 0 — the non-scored arcade
// preview shows 0 for COOL and GREAT. The init-0-and-read model is exact.

/** @brief The arcade-viewer COOL count the HUD draw callback reads; always 0. */
extern int g_dwAcCoolCount;
/** @brief The arcade-viewer GREAT count the HUD draw callback reads; always 0. */
extern int g_dwAcGreatCount;

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
