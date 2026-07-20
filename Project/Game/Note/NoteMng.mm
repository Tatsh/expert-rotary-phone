//
//  NoteMng.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (Project/Game/Note/NoteMng.mm). Implements the standard-mode note manager:
//  chart parsing, the tick<->millisecond tempo map, the play clock, note
//  spawning, and hit judgement. The engine keeps one global instance
//  (Ghidra: DAT_00173ea4).
//
//  Faithful to the decompiled algorithms; the play-data is modelled with named
//  members (the original was one flat ~0x13cbc-byte struct) so the source
//  builds cleanly for the 64-bit target rather than mirroring the armv7 byte
//  layout.
//

#import "NoteMng.h"

#include <cassert>
#include <cstddef>
#include <cstring>
#include <span>
#include <sys/time.h>

#import <Foundation/Foundation.h>

#import "AepManager.h"
#import "AudioManager.h"
#import "neEngineBridge.h"

// The global standard-mode note manager (Ghidra: DAT_00173ea4). Ghidra:
// NoteMng_shared (FUN_0000b278) is a ___cxa_guard'd lazy accessor; the
// function- local static below reproduces that construct-once-on-first-use
// semantics. NoteMng_init (FUN_00033514) zeroes the object and sets the
// defaults captured by the member initialisers.
NoteMng &NoteMng::shared() {
    static NoteMng instance;
    return instance;
}

// Ghidra: NEEngine_onResignActivePushHook (FUN_00034510). Fired when the app is
// about to resign active (push notification / home button / interruption)
// mid-play: freeze the note timeline exactly as a pause does — stop the BGM,
// anchor the current play position, and set the hold/freeze flag — so
// togglePause folds the frozen span back on the return to active. No-op if the
// engine is already frozen (a menu pause, etc.).
void NoteMng::onResignActivePushHook() {
    if (m_holdFlag) {
        return;
    }
    [[AudioManager sharedManager] stopBgm:0.0f]; // 0s fade = stop now
    m_holdElapsed = getElapsedTimeMs();          // anchor the play position (+0x4e40)
    m_holdFlag = true;                           // freeze the timeline (+0x4e51 bit0)
}

namespace {

// Byte accessors into a 20-byte record's type-dependent fields (matches the
// offsets MakeNote reads).
inline uint8_t recByte(const NoteRecord *r, int off) {
    return reinterpret_cast<const uint8_t *>(r)[off];
}

} // namespace

// Ghidra: InitPlayData @ 0x335a4. Parse the decoded payload (4-byte header then
// 20-byte records) into the timeline.
int NoteMng::initPlayData(std::span<const std::byte> data,
                          void (*missCallback)(void *),
                          void *missCallbackArg) {
    assert(!data.empty()); // NoteMng.mm:0x45 (0x335b4/0x335ba)
    // The binary only asserts here, so a release build dereferences a nil sheet
    // (the assert compiles out) and crashes in the memcpy below. Guard it: a
    // missing / unreadable chart (e.g. the tutorial's .orb whose sheet entry did
    // not decode) leaves the note manager uninitialised rather than faulting.
    if (data.empty() || data.data() == nullptr) {
        return -1;
    }
    const int size = static_cast<int>(data.size());
    assert(static_cast<unsigned>(size - 24) <= 0x4e0bu); // NoteMng.mm:0x59 (0x3360c/0x33618): the
                                                         // record span must fit the note pool

    // The miss hook detectMiss fires when a note scrolls past un-tapped (Ghidra:
    // the callback stored at +0x13cbc and its argument at +0x13cb8, both read back
    // by detectMiss @ 0x33e16/0x33e24).
    m_missCallback = missCallback;
    m_missCallbackArg = missCallbackArg;

    // The chart's leading 4 bytes are a float32 — the base hi-speed / scroll
    // multiplier computeScrollY multiplies by — stored verbatim into the float
    // field; the BGM start position is armed to the -1 sentinel updatePlaying
    // tests. Ghidra: 0x335d6 stores -1 to +0x13cc8 (before the memset, which
    // stops at +0x13cbc) and 0x335fc stores the header word to +0x13cc0.
    std::memcpy(&m_hiSpeed, data.data(), sizeof(m_hiSpeed));
    m_bgmStartPos = -1;

    // Reset play state.
    m_recordCount = 0;
    m_totalNotes = 0;
    m_minTempoValue = 0x7fff;
    m_maxTempoValue = 0;
    m_endValue = 0;
    m_expectedTimeBase = 0;
    m_scrollCount = 0;
    m_combo = 0;
    m_maxCombo = 0;
    m_startSec = m_startUsec = 0;
    std::memset(m_tally, 0, sizeof(m_tally));
    std::memset(m_earlyMiss, 0, sizeof(m_earlyMiss));

    const int count = (size - 4) / 20;
    const NoteRecord *src = reinterpret_cast<const NoteRecord *>(data.data() + 4);

    // Copy the records and scan for note-total, tempo range and the mark tick.
    m_records = new NoteRecord[count + 1];
    for (int i = 0; i < count; i++) {
        m_records[i] = src[i];
        switch (m_records[i].type) {
        case NOTE_TYPE_NORMAL:
            m_totalNotes++; // the chart's playable-note total (Ghidra: DAT_00178ccc)
            break;
        case NOTE_TYPE_MARK:
            m_expectedTimeBase = m_records[i].tick; // +0x4e48 (BGM drift-sync base)
            break;
        case NOTE_TYPE_TEMPO:
            if (m_records[i].value > m_maxTempoValue) {
                m_maxTempoValue = m_records[i].value;
            }
            if (m_records[i].value < m_minTempoValue) {
                m_minTempoValue = m_records[i].value;
            }
            break;
        case NOTE_TYPE_END:
            m_endValue = m_records[i].tick; // +0x4e2c (last end-marker tick)
            break;
        default:
            break;
        }
    }
    // Append a terminator (type 3) copied from the last record.
    m_records[count] = m_records[count > 0 ? count - 1 : 0];
    m_records[count].type = NOTE_TYPE_END;
    m_recordCount = count;

    // Spawning starts at the first record; play state is armed to the
    // "end-spawned" sentinel (1) so primePlay's spawnNotes does not emit the end
    // record before the clock is running — startClock later resets it to 0
    // (Ghidra: InitPlayData 0x336c6 stores 1 to +0x5158, startClock 0x3450c
    // stores 0).
    m_spawnCursor = m_records;
    m_state = NOTE_STATE_END_SPAWNED;
    m_endFlag = false;
    m_barCount = 0;

    // Build the free list over the whole note pool. Each slot's permanent pool
    // id (its own array index) is stamped once here: the judge pass reads it back
    // out of the render descriptor and uses it to re-address the slot (Ghidra:
    // the Note+0x8 write at pool-build time).
    m_freeList = nullptr;
    m_activeList = nullptr;
    for (int i = 0; i < kMaxActiveNotes; i++) {
        m_notePool[i].poolId = static_cast<uint32_t>(i);
        m_notePool[i].next = m_freeList;
        m_freeList = &m_notePool[i];
    }

    // Copy the six timing windows (Ghidra: g_noteJudgeWindows @ 0x12e64c).
    static constexpr int kJudgeWindows[6] = {-280, -280, -120, 120, 280, 280};
    std::memcpy(m_judgeWindows, kJudgeWindows, sizeof(m_judgeWindows));

    registerTempoEvents();
    changeTempo(0);

    // Mark the play session as owning the manager. Ghidra InitPlayData tail:
    // `this[1].pReserved0[0x102] = 1`, i.e. m_playActive @ +0x13cb6 := 1 (the struct
    // stride 0x13bb4 + 0x102 = 0x13cb6). -[AppDelegate applicationWillResignActive]
    // reads this flag to freeze play when the app backgrounds; PlayNoteMngDetach
    // clears it on teardown. Without this set the resign path never saw an active
    // play, so locking/unlocking the screen resumed the song mid-play.
    m_playActive = true;
    return 0;
}

// Ghidra: initPlayDataWithData @ 0x33550.
int NoteMng::initPlayDataWithData(NSData *data,
                                  void (*missCallback)(void *),
                                  void *missCallbackArg) {
    return initPlayData(
        {static_cast<const std::byte *>(data.bytes), data.length}, missCallback, missCallbackArg);
}

// Ghidra: registerTempoEvents @ 0x337e0. Register every tempo (type 2) event
// and count bar lines (type 4); stop at the end marker (type 3).
void NoteMng::registerTempoEvents() {
    for (int i = 0; i < m_recordCount; i++) {
        const NoteRecord &r = m_records[i];
        if (r.type == NOTE_TYPE_END) {
            return;
        }
        if (r.type == NOTE_TYPE_BAR) {
            m_chartBarCount++; // Ghidra: registerTempoEvents increments +0x4e36 per type-4
            continue;
        }
        if (r.type == NOTE_TYPE_TEMPO) {
            // In auto/preview mode the BPM is clamped to 200 (Ghidra: DAT_00013cc4).
            int16_t bpm = m_autoPlay ? 200 : static_cast<int16_t>(r.value);
            [[maybe_unused]] const int rc = advanceRegisterEvent(bpm, r.tick);
            assert(rc == 0); // NoteMng.mm:0x4ae "AdvanceRegisterEvent"
        }
    }
}

// Ghidra: AdvanceRegisterEvent @ 0x34bf0. Insert one tempo/scroll segment, kept
// sorted by startTick (scroll speed = bpm * 1024 / 480000, DAT_00034cd0).
// Returns non-zero if the segment table is full (max 63). Also refreshes the
// spawn look-ahead.
int NoteMng::advanceRegisterEvent(int bpm, uint32_t tick) {
    if (m_scrollCount >= 0x3f) {
        return 1; // overflow -> assert at the call site
    }
    int k = 0;
    while (k <= 0x3e && m_scrollMap[k].startTick <= tick) {
        k++;
    }
    for (int j = m_scrollCount; j > k; j--) {
        m_scrollMap[j] = m_scrollMap[j - 1];
    }
    m_scrollMap[k].bpm = static_cast<int16_t>(bpm);
    m_scrollMap[k].startTick = tick;
    m_scrollMap[k].speed = static_cast<float>(bpm << 10) / 480000.0f;
    m_scrollCount++;
    recomputeSpawnLookahead(tick);
    return 0;
}

// Ghidra: the shared tail of AdvanceRegisterEvent / ChangeTempo — walk up to 8
// front segments summing 60000/BPM (ms), advancing when the next segment's
// startTick is reached. The sentinel startTick (-1) on unregistered segments
// blocks over-advance.
void NoteMng::recomputeSpawnLookahead(uint32_t pos) {
    int seg = 0;
    int accum = 0;
    for (int step = 0; step < 8; step++) {
        accum += 60000 / m_scrollMap[seg].bpm;
        if (m_scrollMap[seg + 1].startTick <=
            static_cast<uint32_t>(accum + static_cast<int>(pos))) {
            seg++;
        }
    }
    m_spawnLookahead = accum;
}

// Ghidra: FUN_00034cd4 — integrate scroll speed x elapsed span across the
// scroll segments from `pos` up to `targetTick`, scale by the hi-speed
// multiplier, clamp +-8192. Each segment's speed applies until the NEXT
// segment's startTick (a -1 sentinel on the last leaves the rest at it).
float NoteMng::computeScrollY(uint32_t targetTick, uint32_t pos) const {
    float accum = 0.0f;
    if (pos < targetTick) {
        int seg = 0;
        do {
            uint32_t span = targetTick - pos;
            const uint32_t segSpan = m_scrollMap[seg + 1].startTick - pos;
            if (segSpan < span) {
                span = segSpan;
            }
            accum += m_scrollMap[seg].speed * static_cast<float>(span);
            pos += span;
            seg++;
        } while (pos < targetTick);
    }
    accum *= m_hiSpeed;
    if (!(accum < 8192.0f)) { // NaN-safe upper clamp (matches the binary's vcmpe/mi)
        accum = 8192.0f;
    }
    if (accum < -8192.0f) {
        accum = -8192.0f;
    }
    return accum;
}

// ---------------------------------------------------------------------------
// Standard per-frame update cluster (FUN_00033ae4 and its closure). The
// active-note list is a singly-linked list of pooled slots; retiring a slot
// pushes it back onto the free-list head. The note slot's flags field (@ +0x38)
// is the NoteFlag bit set defined in NoteMng.h.
// ---------------------------------------------------------------------------

// Ghidra: FUN_00034468 — the kind-1 (mark) event: start the BGM once and
// remember the position.
void NoteMng::triggerBgmStart() {
    if (m_endFlag) {
        return;
    }
    [[AudioManager sharedManager] playBgm:0];
    m_bgmStartPos = getCurrentPosition();
}

// Unlink `node` from the active list and push it onto the free-list head
// (33ca8's recycle tail).
void NoteMng::retireNode(ActiveNote *node) {
    if (m_activeList == node) {
        m_activeList = node->next;
    } else {
        for (ActiveNote *p = m_activeList; p != nullptr; p = p->next) {
            if (p->next == node) {
                p->next = node->next;
                break;
            }
        }
    }
    node->next = m_freeList;
    m_freeList = node;
}

// Ghidra: FUN_00033c5c — first per-note pass: once a note's time arrives, fire
// its event side effect (kind 1 starts the BGM, kind 4 counts a measure) and
// mark it handled (bit 0x80).
void NoteMng::judgeActiveNote(ActiveNote *node, uint32_t pos) {
    const uint16_t flags = node->flags;
    if ((flags & NOTE_FLAG_HANDLED) != 0 || node->startTick > pos) {
        return;
    }
    const uint8_t type = node->rec->type;
    if (type == NOTE_TYPE_MARK) { // 1: start BGM
        triggerBgmStart();
        node->flags = static_cast<uint16_t>(flags | NOTE_FLAG_HANDLED);
    } else if (type == NOTE_TYPE_BAR) { // 4: measure line
        m_barCount++;
        node->flags = static_cast<uint16_t>(flags | NOTE_FLAG_HANDLED);
    }
    // other types are handled elsewhere (or not at all)
}

// Ghidra: FUN_00033ca8 — second per-note pass: retire notes that have scrolled
// fully past
// (> 10 s old, excluding the end marker) or that were already resolved (flags
// 0x40/0x80), then advance the caller's cursor to the next node.
void NoteMng::retireActiveNote(ActiveNote **pnode, uint32_t pos) {
    ActiveNote *node = *pnode;
    ActiveNote *next = node->next;
    if (node->startTick + 10000u < pos && node->rec->type != NOTE_TYPE_END) {
        retireNode(node);
    } else if ((node->flags & NOTE_FLAG_RETIRE) != 0) {
        retireNode(node);
    }
    *pnode = next;
}

// Ghidra: FUN_00033d5c — miss detection (manual play): a gradeable note that
// scrolled more than ~280 ms past its window without being hit is a miss —
// reset the combo, tally a BAD, fire the miss callback. The special-note window
// widens with the spawn-kind gap.
void NoteMng::detectMiss(ActiveNote *node, uint32_t pos) {
    const unsigned kind = node->kind;
    const unsigned k = kind - 6;
    const bool special = (k < 4) && !m_autoPlay;
    const uint16_t flags = node->flags;
    if (((flags & NOTE_FLAG_RESOLVED) == 0 ||
         (special && (flags & NOTE_FLAG_MISSED) == 0 && node->spawnKind != 0)) &&
        kind < 10) {
        unsigned sk = (k < 4) ? ((0x05040302u >> (k * 8)) & 0xff) : 1;
        int window = 0x118; // 280 ms
        if (special) {
            int d = static_cast<int8_t>(sk - node->spawnKind);
            if (d > 0) {
                window = d * 0x118 + 0x118;
            }
        }
        if (window < static_cast<int>(pos - node->startTick)) {
            node->flags =
                static_cast<uint16_t>(flags | (node->startTick < node->endTick ?
                                                   (NOTE_FLAG_MISSED | NOTE_FLAG_LONG_FAILED) :
                                                   NOTE_FLAG_MISSED));
            m_combo = 0;
            m_tally[kind][NOTE_JUDGE_BAD]++;
            if (m_missCallback != nullptr) {
                m_missCallback(m_missCallbackArg);
            }
        }
    }
}

// Ghidra: FUN_00033e40 — long-note tail completion: when the hold's end tick
// passes and its head was graded, credit the tail at the head's tier (combo +
// tally).
void NoteMng::completeLongNoteTail(ActiveNote *node, uint32_t pos) {
    if (node->startTick >= node->endTick) {
        return; // not a long note
    }
    const uint16_t flags = node->flags;
    if (node->endTick <= pos && (flags & NOTE_FLAG_RESOLVED) != 0 &&
        (flags & NOTE_FLAG_MISSED) == 0 && (flags & NOTE_FLAG_LONG_DONE) == 0) {
        int tier = (flags & NOTE_FLAG_GOOD)  ? 1 :
                   (flags & NOTE_FLAG_GREAT) ? 2 :
                   (flags & NOTE_FLAG_COOL)  ? 3 :
                                               0;
        node->flags = static_cast<uint16_t>(flags | NOTE_FLAG_LONG_SUCCESS);
        uint32_t c = static_cast<uint32_t>(m_combo) + 1;
        m_combo = static_cast<int>(c);
        if (static_cast<uint32_t>(m_maxCombo) < c) {
            m_maxCombo = static_cast<int>(c);
        }
        m_tally[node->kind][tier]++;
    }
}

// Ghidra: FUN_00033edc — auto-play head grade: an un-judged note inside the
// window is auto-hit as a COOL (long notes credit only the head here; the tail
// is handled by autoGradeTail).
void NoteMng::autoGradeHead(ActiveNote *node, uint32_t pos) {
    if ((node->flags & NOTE_FLAG_RESOLVED) != 0 || node->kind >= 10) {
        return;
    }
    const int dt = static_cast<int>(pos) - static_cast<int>(node->startTick);
    const int adt = (dt < 0) ? -dt : dt;
    if (adt < 0x200 && dt >= 0 && dt <= m_judgeWindows[5]) { // DAT_00013ca8 == judge window[5]
        node->flags |= NOTE_FLAG_COOL;
        node->spawnKind = 0;
        if (node->startTick < node->endTick) {
            return; // long note: grade the tail separately
        }
        m_tally[node->kind][NOTE_JUDGE_COOL]++;
        uint32_t c = static_cast<uint32_t>(m_combo) + 1;
        m_combo = static_cast<int>(c);
        if (static_cast<uint32_t>(m_maxCombo) < c) {
            m_maxCombo = static_cast<int>(c);
        }
    }
}

// Ghidra: FUN_00033f58 — auto-play long-note tail grade: once the hold's end
// passes (within the window) auto-credit the tail as a COOL.
void NoteMng::autoGradeTail(ActiveNote *node, uint32_t pos) {
    if (node->startTick >= node->endTick || node->kind >= 10 ||
        (node->flags & NOTE_FLAG_LONG_DONE) != 0) {
        return;
    }
    const int dt = static_cast<int>(pos) - static_cast<int>(node->endTick);
    if (dt < 0 || m_judgeWindows[5] < dt) { // DAT_00013ca8 == judge window[5]
        return;
    }
    m_tally[node->kind][NOTE_JUDGE_COOL]++;
    node->flags |= (NOTE_FLAG_COOL | NOTE_FLAG_LONG_SUCCESS);
    node->spawnKind = 0;
    uint32_t c = static_cast<uint32_t>(m_combo) + 1;
    m_combo = static_cast<int>(c);
    if (static_cast<uint32_t>(m_maxCombo) < c) {
        m_maxCombo = static_cast<int>(c);
    }
}

// Ghidra: FUN_00033a08 — refresh a note's on-screen scroll position (head at
// +0x14 / tail at +0x18, from computeScrollY), mark the head scrolled once it
// passes the judge line, and let a passed head/tail slide off (speed * -16),
// clamping un-passed positions at 0.
void NoteMng::updateDrawPos(ActiveNote *node, uint32_t pos) {
    const uint16_t flags = node->flags;
    const uint32_t startTick = node->startTick;
    const uint32_t endTick = node->endTick;

    if ((flags & NOTE_FLAG_HEAD_SCROLLED) == 0 && node->kind < 10) {
        node->scrollStart = computeScrollY(startTick, pos); // +0x14 head scroll position
    }
    if (endTick > startTick && pos <= endTick && node->kind < 10) {
        node->scrollEnd = computeScrollY(endTick, pos); // +0x18 tail scroll position
    }

    if (startTick < pos) {
        if ((flags & NOTE_FLAG_HEAD_SCROLLED) == 0) {
            node->flags = static_cast<uint16_t>(flags | NOTE_FLAG_HEAD_SCROLLED);
        }
        node->scrollStart = node->scrollStart + m_scrollMap[0].speed * -16.0f;
    } else if (node->scrollStart < 0.0f) {
        node->scrollStart = 0.0f;
    }

    if (startTick < endTick) {
        if (pos <= endTick) {
            if (node->scrollEnd < 0.0f) {
                node->scrollEnd = 0.0f;
            }
        } else {
            node->scrollEnd = node->scrollEnd + m_scrollMap[0].speed * -16.0f;
        }
    }
}

// Ghidra: FUN_00033ae4 — the standard note engine's per-frame update.
void NoteMng::update() {
    const uint32_t pos = static_cast<uint32_t>(getCurrentPosition());

    if (m_state != NOTE_STATE_FINISHED) {
        spawnNotes(pos);
        ActiveNote *node = m_activeList;
        while (node != nullptr) {
            judgeActiveNote(node, pos);
            retireActiveNote(&node, pos); // advances `node`
        }
        if (m_endFlag) {
            m_state = NOTE_STATE_FINISHED;
        }
    }

    changeTempo(pos);

    for (ActiveNote *node = m_activeList; node != nullptr; node = node->next) {
        detectMiss(node, pos);
        completeLongNoteTail(node, pos);
        if (m_autoPlay) {
            autoGradeHead(node, pos);
            autoGradeTail(node, pos);
        }
        updateDrawPos(node, pos);
        if (!m_endFlag && node->rec->type == NOTE_TYPE_END && node->startTick <= pos) {
            node->flags |= NOTE_FLAG_HANDLED;
            m_endFlag = true;
        }
    }
}

// Ghidra: FUN_0003396c — bring-up: spawn the lead-in records, settle the tempo,
// and position every note, all at position 0 (state 1, before the clock is
// armed).
void NoteMng::primePlay() {
    spawnNotes(0);
    changeTempo(0);
    for (ActiveNote *node = m_activeList; node != nullptr; node = node->next) {
        updateDrawPos(node, 0);
    }
}

// Ghidra: FUN_000344c4 — arm the play clock: stamp the start time and clear the
// per-play offset, scroll target, hold/sync flags and state so
// getCurrentPosition starts from 0.
void NoteMng::startClock() {
    timeval tv;
    gettimeofday(&tv, nullptr);
    m_startSec = tv.tv_sec;
    m_startUsec = tv.tv_usec;
    // The binary also stamps getElapsedTimeMs() into +0x4e38 (0x344de) and zeroes
    // +0x4e44 (0x344f0); both are write-only dead fields never read back, so they
    // are dropped. It does zero m_positionLeadIn (+0x4e3c) and m_holdElapsed
    // (+0x4e40), which getCurrentPosition consumes.
    m_positionLeadIn = 0;
    m_holdElapsed = 0;
    m_scrollTarget = 0;
    m_bgmSynced = false;
    m_holdFlag = false;
    m_state = NOTE_STATE_PLAYING;
}

// Ghidra: FUN_00033fc0 — the playing-state per-frame update. Identical to
// update() except it freezes while held and, once, nudges the scroll target to
// the BGM playhead (drift correction).
void NoteMng::updatePlaying() {
    if (m_holdFlag) {
        return;
    }
    const uint32_t pos = static_cast<uint32_t>(getCurrentPosition());

    // One-shot BGM drift sync: align the scroll to the actual audio playhead.
    if (!m_bgmSynced) {
        AudioManager *am = [AudioManager sharedManager];
        if ([am isPlayingBgm]) {
            double bgmMs = [am bgmCurrentTime] * 1000.0; // DAT_00034158 = 1000.0
            int drift = (bgmMs > 0.0) ? static_cast<int>(static_cast<long long>(bgmMs)) : 0;
            m_scrollTarget = drift + (m_expectedTimeBase - static_cast<int>(pos));
            m_bgmSynced = true;
        }
    }

    if (m_state != NOTE_STATE_FINISHED) {
        spawnNotes(pos);
        ActiveNote *node = m_activeList;
        while (node != nullptr) {
            judgeActiveNote(node, pos);
            retireActiveNote(&node, pos);
        }
        if (m_endFlag) {
            m_state = NOTE_STATE_FINISHED;
        }
    }

    changeTempo(pos);

    for (ActiveNote *node = m_activeList; node != nullptr; node = node->next) {
        detectMiss(node, pos);
        completeLongNoteTail(node, pos);
        if (m_autoPlay) {
            autoGradeHead(node, pos);
            autoGradeTail(node, pos);
        }
        updateDrawPos(node, pos);
        if (!m_endFlag && node->rec->type == NOTE_TYPE_END && node->startTick <= pos) {
            node->flags |= NOTE_FLAG_HANDLED;
            m_endFlag = true;
        }
    }
}

// Ghidra: ChangeTempo @ 0x33864. Once play passes the current segment (the next
// segment's startTick has arrived), retire the front segment (shift the array
// down); always refresh the spawn look-ahead.
void NoteMng::changeTempo(uint32_t tick) {
    if (m_scrollMap[1].startTick <= tick) {
        for (int j = 0; j < m_scrollCount; j++) {
            m_scrollMap[j] = m_scrollMap[j + 1];
        }
        m_scrollMap[m_scrollCount].speed = 0.0f;
        m_scrollMap[m_scrollCount].startTick = 0xffffffff;
        m_scrollMap[m_scrollCount].bpm = -1;
        m_scrollCount--;
        assert(m_scrollMap[0].bpm >= 1); // "ChangeTempo" NoteMng.mm:0x5dc
    }
    recomputeSpawnLookahead(tick);
}

// Ghidra: getElapsedTimeMs @ 0x33c04.
int NoteMng::getElapsedTimeMs() const {
    if (m_startSec == 0 && m_startUsec == 0) {
        return 0;
    }
    timeval now;
    gettimeofday(&now, nullptr);
    return static_cast<int>((now.tv_sec - m_startSec) * 1000 + (now.tv_usec - m_startUsec) / 1000);
}

// Ghidra: getCurrentPosition @ 0x34164. The current scroll/judge position in
// ms.
//   pos = elapsed + [0x4e44] + m_scrollTarget(0x4e4c) -
//   m_positionLeadIn(0x4e3c)
// clamped at 0 with an *unsigned* compare (borrow -> 0). Field 0x4e44 is
// provably always 0 (347k-instruction scan: its only writer is startClock,
// which zeroes it), so it drops out. m_positionLeadIn accumulates total paused
// time (added by togglePause as `elapsed - m_holdElapsed`) and is *subtracted*
// here. m_scrollTarget is the one-shot BGM-drift alignment set once per song by
// updatePlaying/updateBgmSync and must be added so the notes lock to the actual
// audio playhead. When the hold bit is set the live elapsed cancels against
// m_holdElapsed, freezing the position at the pause instant.
int NoteMng::getCurrentPosition() const {
    const int elapsed = getElapsedTimeMs();
    uint32_t sub = static_cast<uint32_t>(m_positionLeadIn);
    if (m_holdFlag) {
        sub += static_cast<uint32_t>(elapsed) -
               static_cast<uint32_t>(m_holdElapsed); // freeze while held
    }
    const uint32_t val = static_cast<uint32_t>(elapsed) + static_cast<uint32_t>(m_scrollTarget);
    return (val < sub) ? 0 : static_cast<int>(val - sub);
}

// Ghidra: getActiveNoteCount @ 0x34694. Count active notes still awaiting
// judgement (kind < 10, judged flag 0x80 clear).
int NoteMng::getActiveNoteCount() const {
    int n = 0;
    for (ActiveNote *note = m_activeList; note != nullptr; note = note->next) {
        if (note->kind < 10 && (note->flags & NOTE_FLAG_HANDLED) == 0) {
            n++;
        }
    }
    return n;
}

// Ghidra: FUN_0003181c. The number of playable notes still awaiting judgement:
// the chart's note total (nJudgeThreshold @ +0x4e28, incremented per type-0
// record at InitPlayData — the same value as the score's total) minus the sum of
// every per-kind/per-tier hit tally (the 10x4 int grid @ +0x5164), clamped to
// >= 0. The armv7 tail at 0x3185e subtracts, sign-extends to 16-bit, and clamps
// only the negative case to zero — it returns this remaining count, NOT a 0/1
// flag. PlayTask::update tests it == 0 for the song-end latch (isFinished).
int NoteMng::remainingNoteCount() const {
    int judged = 0;
    for (int kind = 0; kind < kNoteKindCount; kind++) {
        for (int tier = 0; tier < NOTE_JUDGE_TIER_COUNT; tier++) {
            judged += m_tally[kind][tier];
        }
    }
    const int remaining = m_totalNotes - judged;
    return remaining < 1 ? 0 : remaining;
}

// The chart is finished once no playable notes remain to be judged.
bool NoteMng::isFinished() const {
    return remainingNoteCount() == 0;
}

ActiveNote *NoteMng::allocNote() {
    assert(m_freeList != nullptr); // NoteMng.mm MakeNote:0x4e7
    ActiveNote *note = m_freeList;
    m_freeList = note->next;
    return note;
}

void NoteMng::moveToActive(ActiveNote *note) {
    note->next = m_activeList;
    m_activeList = note;
}

// Ghidra: MakeNote @ 0x341a4. Spawn a playable note from a chart record and
// compute its on-screen position from the record's lane/position bytes scaled
// by the live screen size.
void NoteMng::makeNote(const NoteRecord *rec) {
    ActiveNote *note = allocNote();
    note->rec = rec;
    note->startTick = rec->tick;
    note->endTick = rec->param < rec->tick ? rec->tick : rec->param; // max(param, tick)
    note->kind = static_cast<uint8_t>(rec->value & 0xff);
    note->kindHi = static_cast<uint8_t>(rec->value >> 8);
    note->flags = 0;
    note->scrollStart = 1024.0f;
    note->scrollEnd = 1024.0f;

    // Render/spawn kind: chart kinds 6..9 map to 2..5 (unless auto-play), else 1.
    unsigned k = (rec->value & 0xff) - 6;
    note->spawnKind =
        (!m_autoPlay && k < 4) ? static_cast<uint8_t>((0x05040302u >> (k * 8)) & 0xff) : 1;

    // On-screen position. The hitX / buttonAX / buttonBX triplet scales off the
    // base width; the hitY / buttonAY / buttonBY triplet off the base height. Six
    // record bytes (0xe..0x13) drive the six coordinates — the binary reads them
    // as three 16-bit words (0xe/0x10/0x12) split into low/high byte lanes by the
    // NEON pack, so the odd bytes (0xf/0x11/0x13) feed the y triplet. (constants
    // 150/75; MakeNote @ 0x341a4.)
    //
    // The binary derived the base from the drawable size (DAT_00187b78/7c) over
    // the note scale (DAT_00187b80 = UIScreen.scale * 0.5): on the 2014 retina
    // iPad that resolved to the exact 1536x2048 the sprites are authored for, so
    // notes landed in the render canvas. This build pins the AEP canvas to that
    // authored resolution (MainViewController loadView) and stretches it to the
    // real drawable, so on a larger drawable (e.g. 2048x2732 on a 12.9" iPad Pro)
    // the old formula pushed the note/intersection coordinates far off the canvas.
    // Take the base straight from the AEP canvas the notes actually render in:
    // identical to the binary on the original hardware, correct on any device.
    const int baseX = AepManager::shared().screenWidth();  // AEP canvas width (authored res)
    const int baseY = AepManager::shared().screenHeight(); // AEP canvas height
    // The intersection (hit target) is a plain percentage of the base, so it
    // always lands on-screen; the two incoming buttons add 150 to the base before
    // the percentage then subtract 75, so they can start off the canvas edges.
    note->hitX = static_cast<float>((baseX * recByte(rec, 0xe)) / 100);
    note->hitY = static_cast<float>((baseY * recByte(rec, 0xf)) / 100);
    note->buttonAX = static_cast<float>(((baseX + 150) * recByte(rec, 0x10)) / 100 - 75);
    note->buttonAY = static_cast<float>(((baseY + 150) * recByte(rec, 0x11)) / 100 - 75);
    note->buttonBX = static_cast<float>(((baseX + 150) * recByte(rec, 0x12)) / 100 - 75);
    note->buttonBY = static_cast<float>(((baseY + 150) * recByte(rec, 0x13)) / 100 - 75);

    moveToActive(note);
}

// Ghidra: MakeEvent @ 0x343c8. Spawn a non-note event (kind 10).
void NoteMng::makeEvent(const NoteRecord *rec) {
    ActiveNote *note = allocNote();
    note->rec = rec;
    note->startTick = rec->tick;
    note->endTick = rec->tick;
    note->kind = 10;
    note->flags = 0;
    note->scrollStart = 1024.0f;
    note->scrollEnd = 1024.0f;
    moveToActive(note);
}

// Ghidra: FUN_000339a0 — spawn every chart record whose tick is within the
// spawn look-ahead of the current position. Note records (type 0) become live
// notes; mark/bar (types 1/4) become events; the end record (type 3) is spawned
// once and advances the play state.
void NoteMng::spawnNotes(uint32_t pos) {
    NoteRecord *rec = m_spawnCursor;
    const uint32_t spawnUntil = static_cast<uint32_t>(m_spawnLookahead + static_cast<int>(pos));
    if (rec->tick > spawnUntil) {
        return;
    }
    do {
        switch (rec->type) {
        case NOTE_TYPE_NORMAL: // 0: playable note
            makeNote(rec);
            break;
        case NOTE_TYPE_MARK: // 1
        case NOTE_TYPE_BAR:  // 4
            makeEvent(rec);
            break;
        case NOTE_TYPE_END: // 3: one-shot terminator
            if (m_state != NOTE_STATE_PLAYING) {
                return;
            }
            makeEvent(rec);
            m_state = NOTE_STATE_END_SPAWNED;
            return;
        default: // type 2 (tempo) is consumed at register time
            break;
        }
        m_spawnCursor = rec + 1;
        rec = m_spawnCursor;
    } while (rec->tick <= spawnUntil);
}

ActiveNote *NoteMng::activeNoteAt(unsigned index) {
    unsigned i = 0;
    for (ActiveNote *note = m_activeList; note != nullptr; note = note->next) {
        if (note->kind < 10 && (note->flags & NOTE_FLAG_HANDLED) == 0) {
            if (i == index) {
                return note;
            }
            i++;
        }
    }
    return nullptr;
}

// Ghidra: GetNoteObject @ 0x346c0 + copyNoteRenderData @ 0x34758. Copy the
// index-th judgeable note into a render descriptor.
void NoteMng::getNoteObject(NoteRenderData *out, int index) {
    ActiveNote *note = activeNoteAt(static_cast<unsigned>(index));
    assert(note != nullptr); // NoteMng.mm GetNoteObject:0x32b/0x344

    out->noteId = note->poolId; // Ghidra: nField0 = *(int *)pNote->pReserved8
    out->startTick = note->startTick;
    out->endTick = note->endTick;
    out->kind = note->kind;
    out->kindHi = note->kindHi;
    out->flags = note->flags;
    out->scrollStart = note->scrollStart;
    out->scrollEnd = note->scrollEnd;
    out->spawnKind = note->spawnKind;
    out->hitX = note->hitX;
    out->hitY = note->hitY;
    out->buttonAX = note->buttonAX;
    out->buttonAY = note->buttonAY;
    out->buttonBX = note->buttonBX;
    out->buttonBY = note->buttonBY;

    // Recompute the render kind: special (chart kind 6..9), long (start < end),
    // else normal.
    if (!m_autoPlay && static_cast<uint8_t>(note->kind - 6) < 4) {
        out->renderKind = NOTE_RENDER_SPECIAL;
    } else if (note->startTick < note->endTick) {
        out->renderKind = NOTE_RENDER_LONG;
    } else {
        out->renderKind = NOTE_RENDER_NORMAL;
    }
}

// Ghidra: judgeNoteHit @ 0x347e8. Grade a tap against pool note `noteId`.
// Addressed by raw pool slot id (like judgeHold / updateLongNote / setLaneFlag),
// not by active-list index: the binary indexes m_notePool[noteId] directly and
// bounds it with the same (noteId >> 3) < 0x7d gate.
int NoteMng::judgeNoteHit(unsigned noteId) {
    if (noteId >> 3 >= 0x7d) { // noteId >= 1000
        return NOTE_JUDGE_MISS;
    }
    ActiveNote &note = m_notePool[noteId];
    if ((note.flags & NOTE_FLAG_RESOLVED) != 0) {
        return NOTE_JUDGE_MISS; // already judged
    }

    bool special = !m_autoPlay && static_cast<uint8_t>(note.kind - 6) < 4;
    int delta = static_cast<int>(note.startTick) - getCurrentPosition(); // + = early, - = late
    if (delta <= m_judgeWindows[0]) {
        return NOTE_JUDGE_MISS; // already past the note
    }

    int tier;
    bool countsCombo = true;
    if (m_judgeWindows[1] < delta) {
        if (m_judgeWindows[2] < delta) {
            if (m_judgeWindows[3] < delta) {
                if (m_judgeWindows[4] < delta) {
                    if (m_judgeWindows[5] < delta) {
                        // Too early: bump the early-miss counter, no judgement.
                        m_earlyMiss[note.kind]++;
                        return NOTE_JUDGE_MISS;
                    }
                    // BAD: a long note also latches LONG_FAILED (0x200) here.
                    tier = NOTE_JUDGE_BAD;
                    note.flags |= (note.startTick < note.endTick) ?
                                      (NOTE_FLAG_BAD | NOTE_FLAG_LONG_FAILED) :
                                      NOTE_FLAG_BAD;
                    m_combo = 0;
                    countsCombo = false;
                } else {
                    tier = NOTE_JUDGE_GOOD;
                    note.flags |= NOTE_FLAG_GOOD;
                }
            } else {
                // Central band: within ~50 ms is the tightest tier.
                if (static_cast<unsigned>(delta + 50) < 101) {
                    tier = NOTE_JUDGE_COOL;
                    note.flags |= NOTE_FLAG_COOL;
                } else {
                    tier = NOTE_JUDGE_GREAT;
                    note.flags |= NOTE_FLAG_GREAT;
                }
            }
        } else {
            tier = NOTE_JUDGE_GOOD;
            note.flags |= NOTE_FLAG_GOOD;
        }
        if (countsCombo && !(note.startTick < note.endTick) && !special) {
            m_combo++;
            if (m_combo > m_maxCombo) {
                m_maxCombo = m_combo;
            }
        }
    } else {
        // BAD (late): a long note also latches LONG_FAILED (0x200) here.
        tier = NOTE_JUDGE_BAD;
        note.flags |= (note.startTick < note.endTick) ? (NOTE_FLAG_BAD | NOTE_FLAG_LONG_FAILED) :
                                                        NOTE_FLAG_BAD;
        m_combo = 0;
        countsCombo = false;
    }

    if (!(note.startTick < note.endTick) && !special) {
        m_tally[note.kind][tier]++;
    }
    // Each graded hit counts down the note's remaining-taps counter (spawnKind,
    // Ghidra: the DAT_00005266 = flags+2 decrement at the tail; misses return
    // early and never reach it).
    if (static_cast<int8_t>(note.spawnKind) > 0) {
        note.spawnKind--;
    }
    return tier;
}

// Ghidra: updateLongNote @ 0x34a78. Resolve a held note whose tail has passed.
// Addressed by raw note-pool slot id (like judgeHold / setLaneFlag), not by
// active-list index; the same (noteId >> 3) < 0x7d gate bounds it to [0, 1000).
int NoteMng::updateLongNote(unsigned noteId) {
    if (m_autoPlay) {
        return 0;
    }
    if (noteId >> 3 >= 0x7d) { // noteId >= 1000
        return 0;
    }
    ActiveNote &note = m_notePool[noteId];
    if ((note.flags & NOTE_FLAG_RESOLVED) == 0 || (note.flags & NOTE_FLAG_LONG_DONE) != 0) {
        return note.flags;
    }

    // Ghidra uses 0x523c (endTick), not startTick: a hold whose finger lifted
    // more than 60 ticks BEFORE the tail is a fail. (Pre-existing reconstruction
    // bug, decompile-confirmed.)
    int delta = getCurrentPosition() - static_cast<int>(note.endTick);
    int tier;
    if (delta < -60) {
        note.flags |= NOTE_FLAG_LONG_FAILED; // NOTE_FLAGS_LONG_FAILED
        m_combo = 0;
        tier = 0;
        NSLog(@"NOTE_FLAGS_LONG_FAILED");
    } else {
        note.flags |= NOTE_FLAG_LONG_SUCCESS; // NOTE_FLAGS_LONG_SUCCESS
        m_combo++;
        if (m_combo > m_maxCombo) {
            m_maxCombo = m_combo;
        }
        int f = note.flags;
        tier = (f & NOTE_FLAG_GOOD) ? 1 : (f & NOTE_FLAG_GREAT) ? 2 : (f & NOTE_FLAG_COOL) ? 3 : 0;
        NSLog(@"NOTE_FLAGS_LONG_SUCCESS");
    }
    m_tally[note.kind][tier]++;
    return note.flags;
}

// Ghidra: noteMngJudgeHold @ 0x34964. Per-frame long-note "still held" judge,
// addressed by pool slot id. The slot's spawnKind byte is repurposed as a
// hold-segment countdown: each call it is decremented and the note's remaining
// distance to the judge line checked. If the head has scrolled more than
// (graphic+1) judge-windows (0x118 = 280) past the note, the hold breaks and
// the combo resets; when the countdown reaches zero the hold completes,
// advancing the combo and the per-kind/tier tally. `tier` (< 4) selects the
// tally column. Returns the remaining count.
int NoteMng::judgeHold(unsigned noteId, unsigned tier) {
    if (noteId >> 3 >= 0x7d) { // noteId >= 1000
        return 0;
    }
    ActiveNote &slot = m_notePool[noteId];
    if (tier >= 4) {
        return static_cast<int>(static_cast<int8_t>(slot.spawnKind));
    }
    if ((slot.flags & NOTE_FLAG_RESOLVED) == 0 || static_cast<int8_t>(slot.spawnKind) < 1) {
        slot.spawnKind = 0;
        return 0;
    }

    const int startTick = static_cast<int>(slot.startTick);
    const int pos = getCurrentPosition();
    // The note's spawn graphic (chart kind 6..9 -> 2..5, else 1), used as a
    // distance scale.
    int graphic;
    if (static_cast<uint8_t>(slot.kind - 6) < 4) {
        graphic =
            static_cast<int>(static_cast<int8_t>(0x5040302 >> (((slot.kind - 6) & 0x1f) << 3)));
    } else {
        graphic = 1;
    }
    const int8_t remaining = static_cast<int8_t>(slot.spawnKind);
    graphic -= remaining;
    int8_t next = remaining;
    if (remaining > 0) {
        next = remaining - 1;
        slot.spawnKind = static_cast<uint8_t>(next);
    }

    if (graphic * 0x118 + 0x118 < startTick - pos) {
        m_combo = 0; // released too far from the note: the hold breaks
    } else if (next == 0) {
        int c = m_combo + 1;
        m_combo = c;
        if (m_maxCombo < c) {
            m_maxCombo = c;
        }
        m_tally[slot.kind][tier]++;
    }
    return static_cast<int>(static_cast<int8_t>(slot.spawnKind));
}

// Ghidra: noteMngSetLaneFlag @ 0x347c8 — set the "lane held" flag (0x40) on
// note pool slot noteId.
void NoteMng::setLaneFlag(unsigned noteId) {
    if (noteId >> 3 >= 0x7d) { // noteId >= 1000
        return;
    }
    m_notePool[noteId].flags |= NOTE_FLAG_LANE_HELD;
}

// Ghidra: noteMngTogglePause @ 0x34570 — resume play from a pause (the
// standard-mode twin of AcNoteMng::resume). Only acts while held: fold the
// paused span into the lead-in, clear the freeze bit, then (when the BGM start
// position is known and the chart has not ended) re-seek the BGM to the current
// position and restart it.
void NoteMng::togglePause() {
    if (!m_holdFlag) {
        return;
    }
    m_positionLeadIn += getElapsedTimeMs() - m_holdElapsed;
    m_scrollTarget = 0;
    m_bgmSynced = false;
    m_holdElapsed = 0;
    m_holdFlag = !m_holdFlag; // clear the freeze bit

    if (m_bgmStartPos != -1 && !m_endFlag) {
        const int pos = getCurrentPosition();
        AudioManager *am = [AudioManager sharedManager];
        double seconds = static_cast<double>(pos - m_bgmStartPos) / 1000.0; // DAT_00034660 = 1000.0
        [am setBgmCurrentTime:seconds];
    }
    [[AudioManager sharedManager] playBgm:0];
}

// --- Per-note tone-graphic accessors (free functions the draw pass calls)
// ----------- Each reads one field of the standard manager's note pool slot
// `noteId` (the play draw pass never touches a NoteMng instance directly). All
// share the same bounds gate as the binary: (noteId >> 3) < 0x7d, i.e. noteId
// in [0, 1000).

// Ghidra: FUN_00034bb4 — the slot's chart kind (drives the tone graphic).
int NoteToneGraphic(int noteId) {
    if (static_cast<unsigned>(noteId) >> 3 < 0x7d) {
        return NoteMng::shared().toneSlot(noteId).kind;
    }
    return 0;
}

// Ghidra: FUN_00034b98 — the slot's high kind byte.
int NoteToneFlags(int noteId) {
    if (static_cast<unsigned>(noteId) >> 3 < 0x7d) {
        return NoteMng::shared().toneSlot(noteId).kindHi;
    }
    return 0;
}

// Ghidra: FUN_00034b5c — 1 for a special chart kind (6..9), else 2 for a
// long/hold note (start tick before end tick), else 0. This mirrors
// NoteRenderKind.
int NoteToneState(int noteId) {
    if (static_cast<unsigned>(noteId) >> 3 < 0x7d) {
        const ActiveNote &slot = NoteMng::shared().toneSlot(noteId);
        if (static_cast<uint8_t>(slot.kind - 6) < 4) {
            return 1;
        }
        return (slot.startTick < slot.endTick) ? 2 : 0;
    }
    return 0;
}

// Ghidra: FUN_00034a5c — the spawn graphic for a chart type: 6->2, 7->3, 8->4,
// 9->5, anything else 1. (Same packed table makeNote uses to fill a slot's
// spawnKind.)
int NoteToneDefaultGraphic(int type) {
    if (static_cast<unsigned>(type - 6) < 4) {
        return static_cast<int>(static_cast<char>(0x5040302 >> (((type - 6) & 0x1f) << 3)));
    }
    return 1;
}

// Ghidra: FUN_00034bd0 — the slot's spawn graphic (read back as a signed byte).
int NoteToneCount(int noteId) {
    if (static_cast<unsigned>(noteId) >> 3 < 0x7d) {
        return static_cast<int>(static_cast<int8_t>(NoteMng::shared().toneSlot(noteId).spawnKind));
    }
    return 0;
}

// Ghidra: FUN_00034664 — 60000 / the armed beat tempo, in ms; 0 while it is not
// positive.
float NoteBeatIntervalMs() {
    int16_t tempo = static_cast<int16_t>(NoteMng::shared().beatTempoValue());
    if (tempo < 1) {
        return 0.0f;
    }
    return 60000.0f / static_cast<float>(tempo);
}
