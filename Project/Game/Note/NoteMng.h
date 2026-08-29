/**
 * @file
 * The standard-mode note manager.
 *
 * It parses a decoded chart (the "info" entry of a %09d.orb file), builds the play-data timeline,
 * converts chart ticks to milliseconds via the tempo map, and drives note judgement during play.
 * Arcade charts, ac%09d.acv, are handled by the parallel AcNoteMng.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin
 * (Project/Game/Note/NoteMng.mm). The .orb/.acv container is a ZIP whose "info" entry is
 * BFCodec-encrypted; MusicManager decrypts it, and the plaintext is the chart described below.
 *
 * Chart-load flow: a %09d.orb / ac%09d.acv file (ZIP plus BFCodec-encrypted entries) is decoded
 * into an (Ac)MusicData object; the play loader picks the sheet for the chosen difficulty
 * (-[AcMusicData sheetEasy/sheetNormal/sheetHyper/sheetEx], the "sheet_es/n/h/ex" ZIP entries) and
 * passes it to -[NoteMng initPlayDataWithData:] on the global manager (Ghidra: DAT_00173ea4).
 */

#pragma once

#include <cstddef>
#include <cstdint>
#include <span>

#import <Foundation/Foundation.h>

#ifdef __OBJC__
@class NSData;
#endif

// Chart format (decoded "info" payload). Layout: a 4-byte header — a little-endian float32, the
// chart's base hi-speed / scroll multiplier, stored into m_hiSpeed (Ghidra: InitPlayData 0x335fc
// stores it to +0x13cc0; computeScrollY reads it back as a float @ 0x34d1e) — then N note records
// of 20 bytes each, where N = (payloadSize - 4) / 20 (Ghidra: InitPlayData @ 0x335a4). The record
// `type` byte at +0x8 selects how the other fields are read.

/**
 * The chart record kind, stored in NoteRecord::type, selecting how the other fields are
 * read.
 */
enum NoteType : uint8_t {
    NOTE_TYPE_NORMAL = 0, /**< A playable tap note, counted into the note total. */
    NOTE_TYPE_MARK = 1,   /**< Stores its tick into a play-data field: a start or marker. */
    NOTE_TYPE_TEMPO = 2,  /**< A tempo/BPM event: `value` (+0xc) is the BPM, `tick` the position. */
    NOTE_TYPE_END = 3,    /**< The end-of-chart terminator. */
    NOTE_TYPE_BAR = 4,    /**< A measure bar line, counted by registerTempoEvents(). */
};

/**
 * One 20-byte chart record.
 *
 * Verified fields: `tick` (+0x0), `type` (+0x8) and `value` (+0xc, the BPM for NOTE_TYPE_TEMPO,
 * whose minimum and maximum across the chart are tracked at InitPlayData time). The remaining
 * words are type-dependent and are copied verbatim into the runtime note slot.
 */
struct NoteRecord {
    uint32_t tick;       /**< +0x0 Timing position, in chart ticks. */
    uint32_t param;      /**< +0x4 Type-dependent parameter. */
    uint8_t type;        /**< +0x8 The record kind, a NoteType. */
    uint8_t reserved[3]; /**< +0x9 Padding. */
    uint16_t value;      /**< +0xc The BPM for NOTE_TYPE_TEMPO; otherwise type-dependent. */
    uint16_t value2;     /**< +0xe Type-dependent. */
    uint32_t extra;      /**< +0x10 Type-dependent. */
};
static_assert(sizeof(NoteRecord) == 20, "chart note record is 20 bytes");

/**
 * The maximum number of simultaneously-active note slots the manager pools.
 *
 * Ghidra: the 1000-entry free list built in InitPlayData, stride 0x3c.
 */
constexpr int kMaxActiveNotes = 1000;

/**
 * The render kind, recomputed into a NoteRenderData by copyNoteRenderData (@ 0x34758).
 */
enum NoteRenderKind : uint8_t {
    NOTE_RENDER_NORMAL = 0,  /**< An ordinary note. */
    NOTE_RENDER_SPECIAL = 1, /**< A special chart kind, 6..9. */
    NOTE_RENDER_LONG = 2,    /**< A long / hold note: start tick is before end tick. */
};

/**
 * A live note object, pooled in the free and active singly-linked lists.
 *
 * 60 bytes, laid out from the decompiled slot (makeNote @ 0x341a4). makeNote fills the screen
 * position from the chart record's lane and position bytes scaled by the live screen size;
 * makeEvent (@ 0x343c8) spawns non-note events with kind 10.
 */
struct ActiveNote {
    ActiveNote *next;      /**< +0x00 Free or active list link. */
    const NoteRecord *rec; /**< +0x04 The source chart record. */
    /**
     * +0x08 This slot's permanent pool index, 0..999, stamped once at initPlayData. The judge pass
     * reads it out (copyNoteRenderData) and passes it back to judgeNoteHit(), judgeHold(),
     * updateLongNote() and setLaneFlag(), all of which index m_notePool by it. Ghidra: Note+0x8
     * (pReserved8).
     */
    uint32_t poolId;
    uint32_t startTick; /**< +0x0c The note's start position, in chart ticks. */
    uint32_t endTick;   /**< +0x10 The note's end tick; equal to startTick for taps, later for
                             holds. */
    /** +0x14 Head scroll position (Ghidra flScrollStart); defaults to 1024.0 and is updated by
     * updateDrawPos. */
    float scrollStart;
    float scrollEnd;       /**< +0x18 Tail scroll position (Ghidra flScrollEnd); defaults to
                                1024.0. */
    uint8_t kind;          /**< +0x1c The note kind; 10 or above marks an event. */
    uint8_t kindHi;        /**< +0x1d The note sub-kind. */
    uint8_t reserved1e[2]; /**< +0x1e Padding. */
    /**
     * +0x20 The x of the intersection the two buttons converge on — the hit target. Chart
     * byte[0xe] as a plain percentage of the base (no +150/-75), so it always lands on-screen.
     * Taps and judge-line effects test against this point.
     */
    float hitX;
    float hitY; /**< +0x24 The y of the hit target; chart byte[0xf], same encoding as hitX. */
    /** +0x28 Incoming button A start x; chart byte[0x10], base+150 then -75, so it can start off
     * the edge. */
    float buttonAX;
    float buttonAY; /**< +0x2c Incoming button A start y; chart byte[0x11]. */
    float buttonBX; /**< +0x30 Incoming button B start x; chart byte[0x12], same off-edge offset. */
    /** +0x34 Incoming button B start y; chart byte[0x13]. Both buttons interpolate toward (hitX,
     * hitY); copyNoteRenderData @ 0x34758 reorders these six floats in the descriptor. */
    float buttonBY;
    uint16_t flags;     /**< +0x38 NoteFlag bits; 0x80 marks the note judged or inactive. */
    uint8_t spawnKind;  /**< +0x3a 1..5, from the type-6..9 table; otherwise 1. */
    uint8_t reserved3b; /**< +0x3b Padding. */
};
// The original armv7 slot was 60 bytes (stride 0x3c); the two pointers widen it
// on the 64-bit rebuild target, so only assert the packed size on 32-bit.
#if !defined(__LP64__) || !__LP64__
static_assert(sizeof(ActiveNote) == 60, "active note slot is 60 bytes on armv7");
#endif

/**
 * The judgement tiers.
 *
 * The numeric value doubles as the per-kind hit-tally column index: the tally lives at NoteMng +
 * 0x5164 + kind*0x10 + tier*4 (absolute 0x179008 + ... when the singleton is at 0x173ea4), and
 * judgeNoteHit() stores each hit in the column matching the note flag it sets. Ordered worst to
 * best to match that layout, which is also the order the scorer weights the columns (FUN_0002ff7c
 * multiplies them by 0, 0.4, 0.7 and 1.0). Ghidra: judgeNoteHit @ 0x347e8.
 */
enum NoteJudge {
    /** Note flag 8 (column +0x5164): pressed outside the scored windows; breaks combo, no score
     * weight. */
    NOTE_JUDGE_BAD = 0,
    NOTE_JUDGE_GOOD = 1,  /**< Note flag 1 (column +0x5168): score weight 0.4. */
    NOTE_JUDGE_GREAT = 2, /**< Note flag 2 (column +0x516c): score weight 0.7. */
    /** Note flag 4 (column +0x5170): the central band, |delta| < 50 — the tightest and best hit,
     * score weight 1.0. */
    NOTE_JUDGE_COOL = 3,
    NOTE_JUDGE_MISS = -1,      /**< No note in any window; judgeNoteHit found nothing to grade. */
    NOTE_JUDGE_TIER_COUNT = 4, /**< The number of scored tiers. */
};

/**
 * The number of note "kinds" the engine distinguishes; each keeps its own hit tally.
 */
constexpr int kNoteKindCount = 10;

/**
 * ActiveNote::flags bits, verified against the judge, miss, retire and draw passes and the
 * binary's NOTE_FLAGS_LONG_* debug strings.
 *
 * Bits 0..3 are the judge-result flags the judge OR-sets, one per tier (see NoteJudge).
 */
enum NoteFlag : uint16_t {
    NOTE_FLAG_GOOD = 0x1,           /**< Bit 0: graded GOOD. */
    NOTE_FLAG_GREAT = 0x2,          /**< Bit 1: graded GREAT. */
    NOTE_FLAG_COOL = 0x4,           /**< Bit 2: graded COOL, the tightest tier. */
    NOTE_FLAG_BAD = 0x8,            /**< Bit 3: graded BAD, hit in the bad window. */
    NOTE_FLAG_HEAD_SCROLLED = 0x10, /**< Bit 4: the head has passed the judge line. */
    NOTE_FLAG_MISSED = 0x20,        /**< Bit 5: scrolled past un-hit, an auto-BAD miss. */
    NOTE_FLAG_LANE_HELD = 0x40,     /**< Bit 6: a finger is on this note's lane. */
    NOTE_FLAG_HANDLED = 0x80,       /**< Bit 7: event fired, retire-eligible or inactive. */
    NOTE_FLAG_LONG_SUCCESS = 0x100, /**< Bit 8: the hold tail completed. */
    NOTE_FLAG_LONG_FAILED = 0x200,  /**< Bit 9: the hold tail failed. */
    /** GOOD|GREAT|COOL|BAD|MISSED: any grade result. */
    NOTE_FLAG_RESOLVED = 0x2f,
    NOTE_FLAG_RETIRE = 0xc0,     /**< LANE_HELD|HANDLED: retire-eligible. */
    NOTE_FLAG_LONG_DONE = 0x300, /**< LONG_SUCCESS|LONG_FAILED: the hold resolved. */
};

/**
 * The playback state machine (m_state @ +0x5158).
 *
 * It advances once the end (type 3) note is spawned, then once every note has been retired.
 */
enum NoteMngState {
    NOTE_STATE_PLAYING = 0,     /**< Notes are still scrolling or being spawned. */
    NOTE_STATE_END_SPAWNED = 1, /**< The end note has been spawned; draining the field. */
    NOTE_STATE_FINISHED = 2,    /**< Every note has retired; playback is complete. */
};

/**
 * The per-note render descriptor the renderer receives from getNoteObject().
 *
 * The ticks, kind, scale and positions copied out of the ActiveNote plus a freshly-computed
 * NoteRenderKind. Ghidra: copyNoteRenderData @ 0x34758.
 */
struct NoteRenderData {
    /**
     * +0x00 The note's pool id, copied from ActiveNote::poolId. The judge pass keys its judge slot
     * on this and passes it to judgeNoteHit(), judgeHold(), updateLongNote() and setLaneFlag().
     * Ghidra: nField0 = *(int *)Note+0x8.
     */
    uint32_t noteId;
    uint32_t startTick;        /**< The note's start position, in chart ticks. */
    uint32_t endTick;          /**< The note's end position, in chart ticks. */
    uint8_t kind;              /**< The note kind. */
    uint8_t kindHi;            /**< The note sub-kind. */
    uint16_t flags;            /**< The note's NoteFlag bits. */
    NoteRenderKind renderKind; /**< The freshly-computed render kind. */
    float scrollStart;         /**< Head scroll position (Ghidra flScrollStart). */
    float scrollEnd;           /**< Tail scroll position (Ghidra flScrollEnd). */
    uint8_t spawnKind;         /**< The spawn kind, 1..5. */
    float hitX;                /**< The x of the intersection both buttons converge on. */
    float hitY;                /**< The y of the intersection both buttons converge on. */
    float buttonAX;            /**< Incoming button A start x. */
    float buttonAY;            /**< Incoming button A start y. */
    float buttonBX;            /**< Incoming button B start x. */
    float buttonBY;            /**< Incoming button B start y. */
};

/**
 * The standard-mode note manager: chart parsing, the tempo map, note spawning and note
 * judgement.
 */
class NoteMng {
public:
    /**
     * Parse a decoded chart into the play-data timeline.
     *
     * @p missCallback (with @p missCallbackArg, the owning play data) is stored as the miss hook
     * that detectMiss fires when a note scrolls past un-tapped — the play scene passes its
     * gauge-penalty function here. Ghidra: InitPlayData @ 0x335a4, which asserts size validity at
     * NoteMng.mm:0x45 and :0x59 and maps arg4/arg5 to +0x104/+0x108.
     * @param data The whole payload, starting at the 4-byte header.
     * @param missCallback Fired when a note scrolls past un-tapped.
     * @param missCallbackArg Passed to @p missCallback; the owning play data.
     * @return Non-zero on success.
     */
    int initPlayData(std::span<const std::byte> data,
                     void (*missCallback)(void *),
                     void *missCallbackArg);

#ifdef __OBJC__
    /**
     * Parse a chart straight from an NSData: the bytes and length are forwarded to
     * initPlayData().
     * @param data The sheet the play loader selected for the difficulty.
     * @param missCallback Fired when a note scrolls past un-tapped.
     * @param missCallbackArg Passed to @p missCallback; the owning play data.
     * @return Non-zero on success.
     * @ghidraAddress 0x33550
     */
    int initPlayDataWithData(NSData *data, void (*missCallback)(void *), void *missCallbackArg);
#endif

    /**
     * Walk the parsed records and register every tempo (type 2) event into the tempo map,
     * counting bar lines (type 4).
     * @ghidraAddress 0x337e0
     */
    void registerTempoEvents();

    /**
     * Convert a chart position to elapsed milliseconds by accumulating 60000/BPM across the
     * tempo segments up to it.
     * @param tick The chart position to convert.
     * @ghidraAddress 0x33864
     */
    void changeTempo(uint32_t tick);

    /**
     * Register one tempo segment into the tempo map.
     * @param bpm The segment's BPM.
     * @param tick The chart tick the segment starts at.
     * @return Non-zero on success.
     * @ghidraAddress 0x34bf0
     */
    int advanceRegisterEvent(int bpm, uint32_t tick);

    /**
     * Spawn a live note from a chart record: take a free slot, copy the ticks, compute the
     * on-screen position, and move it to the active list.
     * @param rec The chart record to spawn from.
     * @ghidraAddress 0x341a4
     */
    void makeNote(const NoteRecord *rec);

    /**
     * Spawn a non-note event (kind 10) from a chart record.
     * @param rec The chart record to spawn from.
     * @ghidraAddress 0x343c8
     */
    void makeEvent(const NoteRecord *rec);

    /**
     * Spawn every chart record now due: notes via makeNote(), and mark, bar and end records
     * via makeEvent().
     *
     * The end record is a one-shot that advances the play state. Driven each frame by the
     * per-frame update. Ghidra: FUN_000339a0.
     * @param pos The current chart position; a record is due when its tick falls within the spawn
     * look-ahead of it.
     */
    void spawnNotes(uint32_t pos);

    /**
     * Milliseconds elapsed since play start: gettimeofday minus the stored start time.
     * @return The elapsed milliseconds, or 0 before the clock is armed.
     * @ghidraAddress 0x33c04
     */
    int getElapsedTimeMs() const;

    /**
     * The current chart scroll position, derived from getElapsedTimeMs() plus the per-play
     * offsets — the time base every note is judged and drawn against.
     * @return The chart position.
     * @ghidraAddress 0x34164
     */
    int getCurrentPosition() const;

    /**
     * The number of playable notes still awaiting judgement: the note total minus every hit
     * tally, clamped at 0. Ghidra: FUN_0003181c.
     * @return The remaining note count.
     */
    int remainingNoteCount() const;

    /**
     * Whether no playable notes remain to be judged; the play loop watches this to end the
     * song. Ghidra: FUN_0003181c tested against 0.
     * @return true once remainingNoteCount() reaches 0.
     */
    bool isFinished() const;

    /**
     * The standard-mode per-frame update.
     *
     * Reads the position, spawns due records, judges and retires the active notes (marking the
     * end), advances the tempo, then runs the miss and auto-grade passes and refreshes each note's
     * scroll position. Ghidra: FUN_00033ae4, used by the pause state.
     */
    void update();

    /**
     * The bring-up pass (play state 1): spawn the lead-in records, settle the tempo, and
     * position every note, all at position 0. Ghidra: FUN_0003396c.
     */
    void primePlay();

    /**
     * The playing-state per-frame update (play state 6): like update(), but it skips while
     * held and, once, syncs the scroll to the BGM playhead. Ghidra: FUN_00033fc0.
     */
    void updatePlaying();

    /**
     * Arm the play clock (play state 4 to 6): stamp the start time and clear the per-play
     * offsets, hold/sync flags and state. Ghidra: FUN_000344c4.
     */
    void startClock();

    /**
     * Fill @p out with the render data of the @p index -th still-judgeable active note
     * (kind below 10, not flagged 0x80).
     *
     * Ghidra: GetNoteObject @ 0x346c0, which delegates the field copy to copyNoteRenderData
     * (@ 0x34758).
     * @param out Receives the note's render descriptor.
     * @param index The index among the still-judgeable active notes.
     */
    void getNoteObject(NoteRenderData *out, int index);

    /**
     * The number of active notes still awaiting judgement: kind below 10 with flag 0x80
     * clear.
     * @return The judgeable active-note count.
     * @ghidraAddress 0x34694
     */
    int getActiveNoteCount() const;

    /**
     * Grade a tap against a pooled note.
     *
     * delta = noteTick - getCurrentPosition() is bucketed against the six timing windows (Ghidra:
     * g_noteJudgeWindows @ 0x12e64c = {-280, -280, -120, +120, +280, +280} ms, copied into the
     * play data at InitPlayData). The tightest central band (|delta| within ~50 ms of the
     * -120..+120 window) is the best tier; then the +/-120 and +/-280 bands. The call also sets
     * the note's judged flags and updates the current and max combo.
     * @param noteId A raw pool slot id, 0..999 — not an active-list index; the binary indexes
     * m_notePool by it directly, bounded by (noteId >> 3) < 0x7d.
     * @return A tier 0..3, which also indexes the per-note-kind hit tally, or -1 when the delta
     * falls outside +/-280 ms.
     * @ghidraAddress 0x347e8
     */
    int judgeNoteHit(unsigned noteId);

    /**
     * Resolve a long / hold note once its tail passes.
     *
     * Released too late (delta below -60 ms) fails the hold (flag 0x200,
     * "NOTE_FLAGS_LONG_FAILED"); otherwise it succeeds (flag 0x100, "NOTE_FLAGS_LONG_SUCCESS") and
     * counts toward the combo and tally.
     * @param index The pool slot id of the hold note.
     * @return Non-zero when the hold succeeded.
     * @ghidraAddress 0x34a78
     */
    int updateLongNote(unsigned index);

    /**
     * The per-frame hold-note tick judge, for a long note held down.
     *
     * Counts down the note pool slot's hold-segment counter; if the head has scrolled too far past
     * the note the hold breaks and the combo resets, otherwise once the counter reaches zero the
     * hold completes and the combo and per-kind tally advance.
     * @param noteId The pool slot id of the hold note.
     * @param tier The tally column to credit, 0..3.
     * @return The remaining hold-segment count.
     * @ghidraAddress 0x34964
     */
    int judgeHold(unsigned noteId, unsigned tier);

    /**
     * Mark a note pool slot with the "long-note lane held" flag (0x40). Input sets this
     * while a lane is held.
     * @param noteId The pool slot id.
     * @ghidraAddress 0x347c8
     */
    void setLaneFlag(unsigned noteId);

    /**
     * Resume play from a pause: the standard-mode twin of AcNoteMng::resume().
     *
     * Folds the paused span into the lead-in, clears the freeze bit, and re-seeks and restarts the
     * BGM at the current position. It only acts while play is currently held.
     * @ghidraAddress 0x34570
     */
    void togglePause();

    /**
     * The live combo count.
     * @return The current combo.
     */
    int combo() const {
        return m_combo;
    }
    /**
     * The best combo reached this play.
     * @return The max combo.
     */
    int maxCombo() const {
        return m_maxCombo;
    }
    /**
     * The hit tally for one note kind and judgement tier.
     * @param kind The note kind, 0..kNoteKindCount-1.
     * @param tier The judgement tier.
     * @return The number of hits recorded in that column.
     */
    int judgeCount(int kind, NoteJudge tier) const {
        return m_tally[kind][tier];
    }

    /**
     * The "a note-play session owns the manager" flag (Ghidra @ +0x13cb6).
     *
     * Read by -[AppDelegate applicationWillResignActive] to auto-pause play when the app is
     * backgrounded; the play scene clears it on teardown (Ghidra: FUN_0003395c, via
     * PlayNoteMngDetach).
     * @return true while a play session owns the manager.
     */
    bool isPlayActive() const {
        return m_playActive;
    }
    /**
     * Set the play-active flag.
     * @param active true while a play session owns the manager.
     */
    void setPlayActive(bool active) {
        m_playActive = active;
    }

    /**
     * The chart's total playable-note count, fixed once the chart is parsed at
     * initPlayData() as the count of NOTE_TYPE_NORMAL records.
     *
     * This is the running score's denominator (PlayCurrentScore) and the full-combo /
     * all-perfect threshold the song-clear jingles test. Ghidra: DAT_00178ccc.
     * @return The playable-note total.
     */
    int totalNoteCount() const {
        return m_totalNotes;
    }

    /**
     * The pooled slot backing the free tone-graphic accessors below.
     *
     * The play draw pass queries a note by raw pool id (0..999); the tone graphic, flags, count and
     * state it wants are just fields of that pooled slot (kind, kindHi, spawnKind, and start
     * versus end tick).
     * @param noteId The pool slot id, 0..999.
     * @return The pooled note slot.
     */
    const ActiveNote &toneSlot(unsigned noteId) const {
        return m_notePool[noteId];
    }

    /**
     * The armed beat-tempo BPM (Ghidra +0x4e5c) — simply the BPM of the front scroll
     * segment. NoteBeatIntervalMs() divides 60000 by it.
     * @return The BPM.
     */
    int beatTempoValue() const {
        return m_scrollMap[0].bpm;
    }

    /**
     * Whether the chart's type-3 END record has passed the judge line (Ghidra +0x13cb4).
     *
     * A reconstruction seam rather than a recovered selector: the binary has no such method and
     * PlayTask::update reads the byte directly (@ 0x2e19e) to choose between the song-end handoff
     * and the in-play pause hold.
     * @return true once the END record has passed.
     */
    bool isEndReached() const {
        return m_endFlag;
    }

    /**
     * The one global standard-mode manager (Ghidra: DAT_00173ea4), reached through a
     * ___cxa_guard'd lazy accessor.
     *
     * Ghidra: NoteMng_shared (FUN_0000b278), which constructs it once via NoteMng_init
     * (FUN_00033514).
     * @return The manager.
     */
    static NoteMng &shared();

    /**
     * The resign / suspend hook, run when the app resigns active: stop the BGM and remember
     * the current play position so it can resume. Guarded to run once.
     *
     * Ghidra: NEEngine_onResignActivePushHook (FUN_00034510), invoked on the global.
     */
    void onResignActivePushHook();

private:
    // One scroll/tempo segment (the binary's 0xc-byte record at +0x4e54, stride
    // 0xc), kept sorted by startTick: a scroll speed (bpm * 1024 / 480000), its
    // start tick, and the raw BPM.
    struct NoteScrollSegment {
        float speed = 0.0f;              // +0x0 units/ms
        uint32_t startTick = 0xffffffff; // +0x4 sentinel -1 until registered
        int16_t bpm = -1;                // +0x8 sentinel -1 until registered (+0x4e5c = segment[0])
    };
    // Shared 8-segment spawn look-ahead recompute (tail of AdvanceRegisterEvent /
    // ChangeTempo).
    void recomputeSpawnLookahead(uint32_t pos);
    // On-screen scroll distance from `pos` up to `targetTick`: integrate the
    // per-segment scroll speed over the elapsed span, scale by the hi-speed
    // multiplier, clamp +-8192. Ghidra: FUN_00034cd4.
    float computeScrollY(uint32_t targetTick, uint32_t pos) const;

    // --- per-frame update cluster (Ghidra addresses noted) ---
    void triggerBgmStart();                                    // FUN_00034468 (kind-1 event)
    void judgeActiveNote(ActiveNote *node, uint32_t pos);      // FUN_00033c5c
    void retireActiveNote(ActiveNote **node, uint32_t pos);    // FUN_00033ca8
    void detectMiss(ActiveNote *node, uint32_t pos);           // FUN_00033d5c
    void completeLongNoteTail(ActiveNote *node, uint32_t pos); // FUN_00033e40
    void autoGradeHead(ActiveNote *node, uint32_t pos);        // FUN_00033edc
    void autoGradeTail(ActiveNote *node, uint32_t pos);        // FUN_00033f58
    void updateDrawPos(ActiveNote *node, uint32_t pos);        // FUN_00033a08
    void retireNode(ActiveNote *node);                         // unlink active -> free-list head

    ActiveNote *allocNote();                  // pop a free slot (nullptr if none)
    void moveToActive(ActiveNote *note);      // free list -> active list
    ActiveNote *activeNoteAt(unsigned index); // n-th judgeable active note

    // Parsed chart (records copied out of the decoded payload).
    NoteRecord *m_records = nullptr;
    NoteRecord *m_spawnCursor = nullptr;       // +0x4e20 next chart record awaiting spawn
    NoteMngState m_state = NOTE_STATE_PLAYING; // +0x5158 playback state machine
    int m_recordCount = 0;
    uint16_t m_minTempoValue = 0x7fff;
    uint16_t m_maxTempoValue = 0;
    uint32_t m_endValue = 0;

    // Tempo / scroll segment map (Ghidra +0x4e54, stride 0xc, max 63). Kept
    // sorted by startTick and filled by AdvanceRegisterEvent; ChangeTempo pops
    // the front as play passes each boundary. The beat-tempo word at +0x4e5c
    // (read by beatTempoValue / NoteBeatIntervalMs, copied by PlayTask_init) is
    // exactly m_scrollMap[0].bpm — resolving the earlier "writer not located"
    // note: AdvanceRegisterEvent is the writer.
    NoteScrollSegment m_scrollMap[64] = {};
    int16_t m_scrollCount = 0; // +0x5154 live segment count
    int m_spawnLookahead = 0;  // +0x4e30 spawn look-ahead (ms), recomputed each register/change
    float m_hiSpeed = 1.0f;    // +0x13cc0 scroll-speed multiplier, seeded from the
                               //          chart's float32 header word at initPlayData

    // Play clock (gettimeofday at play start).
    long m_startSec = 0;
    long m_startUsec = 0;
    int m_positionLeadIn = 0; // +0x4e3c accumulated paused time; SUBTRACTED by getCurrentPosition

    // Timing windows, copied from g_noteJudgeWindows at initPlayData.
    int m_judgeWindows[6] = {};

    // Pooled note objects + the free/active singly-linked lists.
    ActiveNote m_notePool[kMaxActiveNotes] = {};
    ActiveNote *m_freeList = nullptr;
    ActiveNote *m_activeList = nullptr;

    // Scoring.
    int m_combo = 0;    // +0x515c live combo (judgeNoteHit: reset 0x348dc, inc 0x34928)
    int m_maxCombo = 0; // +0x5160 best combo this play
    int m_tally[kNoteKindCount][NOTE_JUDGE_TIER_COUNT] = {}; // +0x5164 per-kind hit counts
    int m_totalNotes = 0;                 // chart playable-note total (Ghidra: DAT_00178ccc)
    int m_earlyMiss[kNoteKindCount] = {}; // +0x5204 too-early presses

    bool m_autoPlay = false;   // Ghidra flag @ +0x13cb5 (auto-play: engine grades
                               // the notes itself)
    bool m_playActive = false; // Ghidra flag @ +0x13cb6 (a play session is running)

    // Per-frame update cluster state.
    bool m_endFlag = false;      // +0x13cb4 the end (type 3) note has scrolled past
    int16_t m_barCount = 0;      // +0x4e34 measures elapsed during play (type-4 events,
                                 //         judge pass: ProcessEventNote increments as bars pass)
    int16_t m_chartBarCount = 0; // +0x4e36 total type-4 (bar/section) events in the chart,
                                 //         counted once at parse (registerTempoEvents)
    // NB: the auto-grade "+dt eligible" bound the binary reads at +0x13ca8 is
    // exactly m_judgeWindows[5] (the +280 upper window);
    // autoGradeHead/autoGradeTail use it directly.
    int m_bgmStartPos = 0; // +0x13cc8 chart position captured when the BGM started;
                           //          initPlayData arms it to the -1 "no BGM yet"
                           //          sentinel updatePlaying tests
    void (*m_missCallback)(void *) = nullptr; // +0x13cb8 fired on a miss (score/UI hook)
    void *m_missCallbackArg = nullptr;        // +0x13cbc

    // Playing-state clock/scroll extras (used by updatePlaying / startClock).
    int m_scrollTarget = 0;     // +0x4e4c scroll base target (nudged to the BGM playhead)
    int m_expectedTimeBase = 0; // +0x4e48 expected time used by the BGM drift sync
    bool m_bgmSynced = false;   // +0x4e50 the one-shot BGM drift sync has run
    bool m_holdFlag = false;    // +0x4e51 bit0: play is held/paused (freezes the update).
                                // Both a menu pause and onResignActivePushHook (app
                                // backgrounded) set this; togglePause clears it.
    int m_holdElapsed = 0;      // +0x4e40 elapsed time stamped when play was frozen
                                // (a pause or a resign); folded back by togglePause.
};

// Per-note tone-graphic state accessors. The play-scene per-frame draw pass (PlayTaskDraw) reads
// these to choose the tone sprite for a note. They index the standard manager's note pool directly
// by note id (Ghidra: singleton + 0x522C + noteId*0x3c, that is m_notePool[noteId]; guarded by
// (noteId >> 3) < 0x7d, so noteId < 1000 = kMaxActiveNotes). The disassembly resolves their raw
// offsets to pooled-slot fields, verified against makeNote @ 0x341a4:
//   +0x5248 -> slot +0x1c = kind      (NoteToneGraphic)
//   +0x5249 -> slot +0x1d = kindHi    (NoteToneFlags)
//   +0x5266 -> slot +0x3a = spawnKind (NoteToneCount)
//   +0x5238/+0x523c -> slot +0x0c/+0x10 = startTick/endTick (NoteToneState)

/**
 * The tone graphic of a pooled note: its slot kind.
 * @param noteId The pool slot id, 0..999.
 * @return The slot's kind field.
 * @ghidraAddress 0x34bb4
 */
int NoteToneGraphic(int noteId);
/**
 * The tone flags of a pooled note: its slot sub-kind.
 * @param noteId The pool slot id, 0..999.
 * @return The slot's kindHi field.
 * @ghidraAddress 0x34b98
 */
int NoteToneFlags(int noteId);
/**
 * The tone state of a pooled note.
 * @param noteId The pool slot id, 0..999.
 * @return 1 for a special note, 2 for a long note, 0 for a normal one.
 * @ghidraAddress 0x34b5c
 */
int NoteToneState(int noteId);
/**
 * The default tone graphic for a chart record type.
 * @param type The chart record type.
 * @return 2..5 for types 6..9, otherwise 1.
 * @ghidraAddress 0x34a5c
 */
int NoteToneDefaultGraphic(int type);
/**
 * The tone count of a pooled note: its spawn kind.
 * @param noteId The pool slot id, 0..999.
 * @return The slot's spawnKind field.
 * @ghidraAddress 0x34bd0
 */
int NoteToneCount(int noteId);

/**
 * The current beat interval: 60000 divided by the armed beat tempo.
 *
 * Ghidra: FUN_00034664 reads the signed short @ mgr+0x4e5c; DAT_00034690 = 60000.0f.
 * @return The beat interval in milliseconds, or 0 when the tempo word is not positive.
 */
float NoteBeatIntervalMs();

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
