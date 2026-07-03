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
//  members (the original was one flat ~0x13cbc-byte struct) so the source builds
//  cleanly for the 64-bit target rather than mirroring the armv7 byte layout.
//

#include <cassert>
#include <cstring>
#include <sys/time.h>

#import <Foundation/Foundation.h>

#import "AudioManager.h"
#import "NoteMng.h"
#import "neEngineBridge.h"

// The global standard-mode note manager (Ghidra: DAT_00173ea4). Ghidra:
// NoteMng_shared (FUN_0000b278) is a ___cxa_guard'd lazy accessor; the function-
// local static below reproduces that construct-once-on-first-use semantics.
// NoteMng_init (FUN_00033514) zeroes the object and sets the defaults captured by
// the member initialisers.
NoteMng &NoteMng::shared() {
    static NoteMng instance;
    return instance;
}

// Ghidra: NEEngine_onResignActivePushHook (FUN_00034510). Runs once on resign:
// stop the BGM and stash the current play position; a flag guards re-entry.
void NoteMng::onResignActivePushHook() {
    if (m_suspendedForResign) {
        return;
    }
    [[AudioManager sharedManager] stopBgm:0.0f];   // 0s fade = stop now
    m_resignPositionMs = getElapsedTimeMs();
    m_suspendedForResign = true;
}

namespace {

// Byte accessors into a 20-byte record's type-dependent fields (matches the
// offsets MakeNote reads).
inline uint8_t recByte(const NoteRecord *r, int off) {
    return reinterpret_cast<const uint8_t *>(r)[off];
}

}  // namespace

// Ghidra: InitPlayData @ 0x335a4. Parse the decoded payload (4-byte header then
// 20-byte records) into the timeline.
int NoteMng::initPlayData(const void *data, int size, uint32_t /*arg4*/, uint32_t /*arg5*/) {
    assert(data != nullptr && size > 0);
    assert(size >= 4 && (size - 4) % 20 == 0);   // NoteMng.mm:0x45/0x59

    // Reset play state.
    m_recordCount = 0;
    m_totalNotes = 0;
    m_minTempoValue = 0x7fff;
    m_maxTempoValue = 0;
    m_endValue = 0;
    m_scrollCount = 0;
    m_combo = 0;
    m_maxCombo = 0;
    m_startSec = m_startUsec = 0;
    std::memset(m_tally, 0, sizeof(m_tally));
    std::memset(m_earlyMiss, 0, sizeof(m_earlyMiss));

    const uint8_t *bytes = static_cast<const uint8_t *>(data);
    const int count = (size - 4) / 20;
    const NoteRecord *src = reinterpret_cast<const NoteRecord *>(bytes + 4);

    // Copy the records and scan for note-total, tempo range and the mark tick.
    m_records = new NoteRecord[count + 1];
    for (int i = 0; i < count; i++) {
        m_records[i] = src[i];
        switch (m_records[i].type) {
            case NOTE_TYPE_NORMAL:
                m_totalNotes++;   // the chart's playable-note total (Ghidra: DAT_00178ccc)
                break;
            case NOTE_TYPE_MARK:
                m_endValue = m_records[i].tick;
                break;
            case NOTE_TYPE_TEMPO:
                if (m_records[i].value > m_maxTempoValue) m_maxTempoValue = m_records[i].value;
                if (m_records[i].value < m_minTempoValue) m_minTempoValue = m_records[i].value;
                break;
            default:
                break;
        }
    }
    // Append a terminator (type 3) copied from the last record.
    m_records[count] = m_records[count > 0 ? count - 1 : 0];
    m_records[count].type = NOTE_TYPE_END;
    m_recordCount = count;

    // Spawning starts at the first record; play state begins "playing".
    m_spawnCursor = m_records;
    m_state = 0;
    m_endFlag = false;
    m_barCount = 0;

    // Build the free list over the whole note pool.
    m_freeList = nullptr;
    m_activeList = nullptr;
    for (int i = 0; i < kMaxActiveNotes; i++) {
        m_notePool[i].next = m_freeList;
        m_freeList = &m_notePool[i];
    }

    // Copy the six timing windows (Ghidra: g_noteJudgeWindows @ 0x12e64c).
    static const int kJudgeWindows[6] = { -280, -280, -120, 120, 280, 280 };
    std::memcpy(m_judgeWindows, kJudgeWindows, sizeof(m_judgeWindows));

    registerTempoEvents();
    changeTempo(0);
    return 0;
}

// Ghidra: initPlayDataWithData @ 0x33550.
int NoteMng::initPlayDataWithData(NSData *data, uint32_t arg3, uint32_t arg4) {
    return initPlayData(data.bytes, (int)data.length, arg3, arg4);
}

// Ghidra: registerTempoEvents @ 0x337e0. Register every tempo (type 2) event and
// count bar lines (type 4); stop at the end marker (type 3).
void NoteMng::registerTempoEvents() {
    for (int i = 0; i < m_recordCount; i++) {
        const NoteRecord &r = m_records[i];
        if (r.type == NOTE_TYPE_END) {
            return;
        }
        if (r.type == NOTE_TYPE_BAR) {
            // bar count lives with the play stats; tracked as a tempo-map marker.
            continue;
        }
        if (r.type == NOTE_TYPE_TEMPO) {
            // In auto/preview mode the BPM is clamped to 200 (Ghidra: DAT_00013cc4).
            int16_t bpm = m_autoPlay ? 200 : (int16_t)r.value;
            int rc = advanceRegisterEvent(bpm, r.tick);
            assert(rc == 0);   // NoteMng.mm:0x4ae "AdvanceRegisterEvent"
        }
    }
}

// Ghidra: AdvanceRegisterEvent @ 0x34bf0. Insert one tempo/scroll segment, kept sorted by
// startTick (scroll speed = bpm * 1024 / 480000, DAT_00034cd0). Returns non-zero if the segment
// table is full (max 63). Also refreshes the spawn look-ahead.
int NoteMng::advanceRegisterEvent(int bpm, uint32_t tick) {
    if (m_scrollCount >= 0x3f) {
        return 1;   // overflow -> assert at the call site
    }
    int k = 0;
    while (k <= 0x3e && m_scrollMap[k].startTick <= tick) {
        k++;
    }
    for (int j = m_scrollCount; j > k; j--) {
        m_scrollMap[j] = m_scrollMap[j - 1];
    }
    m_scrollMap[k].bpm = (int16_t)bpm;
    m_scrollMap[k].startTick = tick;
    m_scrollMap[k].speed = (float)(bpm << 10) / 480000.0f;
    m_scrollCount++;
    recomputeSpawnLookahead(tick);
    return 0;
}

// Ghidra: the shared tail of AdvanceRegisterEvent / ChangeTempo — walk up to 8 front segments
// summing 60000/BPM (ms), advancing when the next segment's startTick is reached. The sentinel
// startTick (-1) on unregistered segments blocks over-advance.
void NoteMng::recomputeSpawnLookahead(uint32_t pos) {
    int seg = 0;
    int accum = 0;
    for (int step = 0; step < 8; step++) {
        accum += 60000 / m_scrollMap[seg].bpm;
        if (m_scrollMap[seg + 1].startTick <= (uint32_t)(accum + (int)pos)) {
            seg++;
        }
    }
    m_spawnLookahead = accum;
}

// Ghidra: FUN_00034cd4 — integrate scroll speed x elapsed span across the scroll segments from
// `pos` up to `targetTick`, scale by the hi-speed multiplier, clamp +-8192. Each segment's speed
// applies until the NEXT segment's startTick (a -1 sentinel on the last leaves the rest at it).
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
            accum += m_scrollMap[seg].speed * (float)span;
            pos += span;
            seg++;
        } while (pos < targetTick);
    }
    accum *= m_hiSpeed;
    if (!(accum < 8192.0f)) {   // NaN-safe upper clamp (matches the binary's vcmpe/mi)
        accum = 8192.0f;
    }
    if (accum < -8192.0f) {
        accum = -8192.0f;
    }
    return accum;
}

// ---------------------------------------------------------------------------
// Standard per-frame update cluster (FUN_00033ae4 and its closure). The active-note list is a
// singly-linked list of pooled slots; retiring a slot pushes it back onto the free-list head.
// Note slot flags (@ +0x38): 0x80 = handled by the judge pass, 0x10 = head scrolled off, 0x4 =
// auto-graded, 0x100 = long-note tail done, 0x20/0x220 = missed, 0x2f / 0x300 = per-tier masks.
// ---------------------------------------------------------------------------

// Ghidra: FUN_00034468 — the kind-1 (mark) event: start the BGM once and remember the position.
void NoteMng::triggerBgmStart() {
    if (m_endFlag) {
        return;
    }
    [[AudioManager sharedManager] playBgm:0];
    m_bgmStartPos = getCurrentPosition();
}

// Unlink `node` from the active list and push it onto the free-list head (33ca8's recycle tail).
void NoteMng::retireNode(ActiveNote *node) {
    if (m_activeList == node) {
        m_activeList = node->next;
    } else {
        for (ActiveNote *p = m_activeList; p != nullptr; p = p->next) {
            if (p->next == node) { p->next = node->next; break; }
        }
    }
    node->next = m_freeList;
    m_freeList = node;
}

// Ghidra: FUN_00033c5c — first per-note pass: once a note's time arrives, fire its event side
// effect (kind 1 starts the BGM, kind 4 counts a measure) and mark it handled (bit 0x80).
void NoteMng::judgeActiveNote(ActiveNote *node, uint32_t pos) {
    const uint16_t flags = node->flags;
    if ((flags & 0x80) != 0 || node->startTick > pos) {
        return;
    }
    const uint8_t type = node->rec->type;
    if (type == NOTE_TYPE_MARK) {          // 1: start BGM
        triggerBgmStart();
        node->flags = (uint16_t)(flags | 0x80);
    } else if (type == NOTE_TYPE_BAR) {    // 4: measure line
        m_barCount++;
        node->flags = (uint16_t)(flags | 0x80);
    }
    // other types are handled elsewhere (or not at all)
}

// Ghidra: FUN_00033ca8 — second per-note pass: retire notes that have scrolled fully past
// (> 10 s old, excluding the end marker) or that were already resolved (flags 0x40/0x80), then
// advance the caller's cursor to the next node.
void NoteMng::retireActiveNote(ActiveNote **pnode, uint32_t pos) {
    ActiveNote *node = *pnode;
    ActiveNote *next = node->next;
    if (node->startTick + 10000u < pos && node->rec->type != NOTE_TYPE_END) {
        retireNode(node);
    } else if ((node->flags & 0xc0) != 0) {
        retireNode(node);
    }
    *pnode = next;
}

// Ghidra: FUN_00033d5c — miss detection (manual play): a gradeable note that scrolled more than
// ~280 ms past its window without being hit is a miss — reset the combo, tally a BAD, fire the
// miss callback. The special-note window widens with the spawn-kind gap.
void NoteMng::detectMiss(ActiveNote *node, uint32_t pos) {
    const unsigned kind = node->kind;
    const unsigned k = kind - 6;
    const bool special = (k < 4) && !m_autoPlay;
    const uint16_t flags = node->flags;
    if (((flags & 0x2f) == 0 ||
         (special && (flags & 0x20) == 0 && node->spawnKind != 0)) && kind < 10) {
        unsigned sk = (k < 4) ? ((0x05040302u >> (k * 8)) & 0xff) : 1;
        int window = 0x118;   // 280 ms
        if (special) {
            int d = (int8_t)(sk - node->spawnKind);
            if (d > 0) {
                window = d * 0x118 + 0x118;
            }
        }
        if (window < (int)(pos - node->startTick)) {
            node->flags = (uint16_t)(flags | (node->startTick < node->endTick ? 0x220 : 0x20));
            m_combo = 0;
            m_tally[kind][NOTE_JUDGE_BAD]++;
            if (m_missCallback != nullptr) {
                m_missCallback(m_missCallbackArg);
            }
        }
    }
}

// Ghidra: FUN_00033e40 — long-note tail completion: when the hold's end tick passes and its head
// was graded, credit the tail at the head's tier (combo + tally).
void NoteMng::completeLongNoteTail(ActiveNote *node, uint32_t pos) {
    if (node->startTick >= node->endTick) {
        return;   // not a long note
    }
    const uint16_t flags = node->flags;
    if (node->endTick <= pos && (flags & 0x2f) != 0 && (flags & 0x20) == 0 && (flags & 0x300) == 0) {
        int tier = (flags & 1) ? 1 : (flags & 2) ? 2 : (flags & 4) ? 3 : 0;
        node->flags = (uint16_t)(flags | 0x100);
        uint32_t c = (uint32_t)m_combo + 1;
        m_combo = (int)c;
        if ((uint32_t)m_maxCombo < c) {
            m_maxCombo = (int)c;
        }
        m_tally[node->kind][tier]++;
    }
}

// Ghidra: FUN_00033edc — auto-play head grade: an un-judged note inside the window is auto-hit
// as a COOL (long notes credit only the head here; the tail is handled by autoGradeTail).
void NoteMng::autoGradeHead(ActiveNote *node, uint32_t pos) {
    if ((node->flags & 0x2f) != 0 || node->kind >= 10) {
        return;
    }
    const int dt = (int)pos - (int)node->startTick;
    const int adt = (dt < 0) ? -dt : dt;
    if (adt < 0x200 && dt >= 0 && dt <= m_nearestThreshold) {
        node->flags |= 4;
        node->spawnKind = 0;
        if (node->startTick < node->endTick) {
            return;   // long note: grade the tail separately
        }
        m_tally[node->kind][NOTE_JUDGE_COOL]++;
        uint32_t c = (uint32_t)m_combo + 1;
        m_combo = (int)c;
        if ((uint32_t)m_maxCombo < c) {
            m_maxCombo = (int)c;
        }
    }
}

// Ghidra: FUN_00033f58 — auto-play long-note tail grade: once the hold's end passes (within the
// window) auto-credit the tail as a COOL.
void NoteMng::autoGradeTail(ActiveNote *node, uint32_t pos) {
    if (node->startTick >= node->endTick || node->kind >= 10 || (node->flags & 0x300) != 0) {
        return;
    }
    const int dt = (int)pos - (int)node->endTick;
    if (dt < 0 || m_nearestThreshold < dt) {
        return;
    }
    m_tally[node->kind][NOTE_JUDGE_COOL]++;
    node->flags |= 0x104;
    node->spawnKind = 0;
    uint32_t c = (uint32_t)m_combo + 1;
    m_combo = (int)c;
    if ((uint32_t)m_maxCombo < c) {
        m_maxCombo = (int)c;
    }
}

// Ghidra: FUN_00033a08 — refresh a note's on-screen scroll position (head at +0x14 / tail at
// +0x18, from computeScrollY), mark the head scrolled once it passes the judge line, and let a
// passed head/tail slide off (speed * -16), clamping un-passed positions at 0.
void NoteMng::updateDrawPos(ActiveNote *node, uint32_t pos) {
    const uint16_t flags = node->flags;
    const uint32_t startTick = node->startTick;
    const uint32_t endTick = node->endTick;

    if ((flags & 0x10) == 0 && node->kind < 10) {
        node->scaleX = computeScrollY(startTick, pos);   // +0x14 head scroll position
    }
    if (endTick > startTick && pos <= endTick && node->kind < 10) {
        node->scaleY = computeScrollY(endTick, pos);     // +0x18 tail scroll position
    }

    if (startTick < pos) {
        if ((flags & 0x10) == 0) {
            node->flags = (uint16_t)(flags | 0x10);
        }
        node->scaleX = node->scaleX + m_scrollMap[0].speed * -16.0f;
    } else if (node->scaleX < 0.0f) {
        node->scaleX = 0.0f;
    }

    if (startTick < endTick) {
        if (pos <= endTick) {
            if (node->scaleY < 0.0f) {
                node->scaleY = 0.0f;
            }
        } else {
            node->scaleY = node->scaleY + m_scrollMap[0].speed * -16.0f;
        }
    }
}

// Ghidra: FUN_00033ae4 — the standard note engine's per-frame update.
void NoteMng::update() {
    const uint32_t pos = (uint32_t)getCurrentPosition();

    if (m_state != 2) {
        spawnNotes(pos);
        ActiveNote *node = m_activeList;
        while (node != nullptr) {
            judgeActiveNote(node, pos);
            retireActiveNote(&node, pos);   // advances `node`
        }
        if (m_endFlag) {
            m_state = 2;
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
            node->flags |= 0x80;
            m_endFlag = true;
        }
    }
}

// Ghidra: FUN_0003396c — bring-up: spawn the lead-in records, settle the tempo, and position
// every note, all at position 0 (state 1, before the clock is armed).
void NoteMng::primePlay() {
    spawnNotes(0);
    changeTempo(0);
    for (ActiveNote *node = m_activeList; node != nullptr; node = node->next) {
        updateDrawPos(node, 0);
    }
}

// Ghidra: FUN_000344c4 — arm the play clock: stamp the start time and clear the per-play offset,
// scroll target, hold/sync flags and state so getCurrentPosition starts from 0.
void NoteMng::startClock() {
    timeval tv;
    gettimeofday(&tv, nullptr);
    m_startSec = tv.tv_sec;
    m_startUsec = tv.tv_usec;
    m_positionLeadIn = 0;   // the binary zeroes the three +0x4e3c/40/44 offset fields
    m_scrollTarget = 0;
    m_bgmSynced = false;
    m_holdFlag = false;
    m_state = 0;
}

// Ghidra: FUN_00033fc0 — the playing-state per-frame update. Identical to update() except it
// freezes while held and, once, nudges the scroll target to the BGM playhead (drift correction).
void NoteMng::updatePlaying() {
    if (m_holdFlag) {
        return;
    }
    const uint32_t pos = (uint32_t)getCurrentPosition();

    // One-shot BGM drift sync: align the scroll to the actual audio playhead.
    if (!m_bgmSynced) {
        AudioManager *am = [AudioManager sharedManager];
        if ([am isPlayingBgm]) {
            double bgmMs = [am bgmCurrentTime] * 1000.0;   // DAT_00034158 = 1000.0
            int drift = (bgmMs > 0.0) ? (int)(long long)bgmMs : 0;
            m_scrollTarget = drift + (m_expectedTimeBase - (int)pos);
            m_bgmSynced = true;
        }
    }

    if (m_state != 2) {
        spawnNotes(pos);
        ActiveNote *node = m_activeList;
        while (node != nullptr) {
            judgeActiveNote(node, pos);
            retireActiveNote(&node, pos);
        }
        if (m_endFlag) {
            m_state = 2;
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
            node->flags |= 0x80;
            m_endFlag = true;
        }
    }
}

// Ghidra: ChangeTempo @ 0x33864. Once play passes the current segment (the next segment's
// startTick has arrived), retire the front segment (shift the array down); always refresh the
// spawn look-ahead.
void NoteMng::changeTempo(uint32_t tick) {
    if (m_scrollMap[1].startTick <= tick) {
        for (int j = 0; j < m_scrollCount; j++) {
            m_scrollMap[j] = m_scrollMap[j + 1];
        }
        m_scrollMap[m_scrollCount].speed = 0.0f;
        m_scrollMap[m_scrollCount].startTick = 0xffffffff;
        m_scrollMap[m_scrollCount].bpm = -1;
        m_scrollCount--;
        assert(m_scrollMap[0].bpm >= 1);   // "ChangeTempo" NoteMng.mm:0x5dc
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
    return (int)((now.tv_sec - m_startSec) * 1000 + (now.tv_usec - m_startUsec) / 1000);
}

// Ghidra: getCurrentPosition @ 0x34164. The current scroll position: the elapsed
// play time offset by the chart's lead-in / start fields, clamped at zero.
int NoteMng::getCurrentPosition() const {
    // Ghidra: position = (elapsed + leadIn) clamped at 0. The original adds three
    // per-play offset fields; their net effect is a constant lead-in on top of the
    // elapsed play time (and a "hold" flag can freeze it, which cancels the elapsed
    // term). Modelled here as elapsed plus the lead-in offset.
    int pos = getElapsedTimeMs() + m_positionLeadIn;
    return pos < 0 ? 0 : pos;
}

// Ghidra: getActiveNoteCount @ 0x34694. Count active notes still awaiting
// judgement (kind < 10, judged flag 0x80 clear).
int NoteMng::getActiveNoteCount() const {
    int n = 0;
    for (ActiveNote *note = m_activeList; note != nullptr; note = note->next) {
        if (note->kind < 10 && (note->flags & 0x80) == 0) {
            n++;
        }
    }
    return n;
}

// Ghidra: FUN_0003181c. The chart is finished once every playable note has been graded:
// the manager sums all per-kind/per-tier hit tallies (the 10x4 int grid @ +0x5164) and
// reports done when that reaches the chart's playable-note total (short @ +0x4e28).
// (The decompiler renders the closing `cmp/it ls` as a subtract-and-clamp; the armv7
// disassembly @ 0x318a0 is a plain `totalNotes <= judged` comparison returning 0/1.)
bool NoteMng::isFinished() const {
    int judged = 0;
    for (int kind = 0; kind < kNoteKindCount; kind++) {
        for (int tier = 0; tier < NOTE_JUDGE_TIER_COUNT; tier++) {
            judged += m_tally[kind][tier];
        }
    }
    return m_totalNotes <= judged;
}

ActiveNote *NoteMng::allocNote() {
    assert(m_freeList != nullptr);   // NoteMng.mm MakeNote:0x4e7
    ActiveNote *note = m_freeList;
    m_freeList = note->next;
    return note;
}

void NoteMng::moveToActive(ActiveNote *note) {
    note->next = m_activeList;
    m_activeList = note;
}

// Ghidra: MakeNote @ 0x341a4. Spawn a playable note from a chart record and
// compute its on-screen position from the record's lane/position bytes scaled by
// the live screen size.
void NoteMng::makeNote(const NoteRecord *rec) {
    ActiveNote *note = allocNote();
    note->rec = rec;
    note->startTick = rec->tick;
    note->endTick = rec->param < rec->tick ? rec->tick : rec->param;   // max(param, tick)
    note->kind = (uint8_t)(rec->value & 0xff);
    note->kindHi = (uint8_t)(rec->value >> 8);
    note->flags = 0;
    note->scaleX = 1024.0f;
    note->scaleY = 1024.0f;

    // Render/spawn kind: chart kinds 6..9 map to 2..5 (unless auto-play), else 1.
    unsigned k = (rec->value & 0xff) - 6;
    note->spawnKind = (!m_autoPlay && k < 4) ? (uint8_t)((0x05040302u >> (k * 8)) & 0xff) : 1;

    // On-screen position (Ghidra math: screen metrics / scale, then per-record
    // percentage offsets; constants 150 and 75 from MakeNote).
    float scale = neSceneManager::screenScale();
    int sx = (int)(neSceneManager::screenWidth() / scale);
    int sy = (int)(neSceneManager::screenHeight() / scale) + 150;
    note->x = (float)((sx * recByte(rec, 0xe)) / 100);
    note->y = (float)((sy * recByte(rec, 0x10)) / 100 - 75);
    note->x2 = (float)((sy * recByte(rec, 0x12)) / 100 - 75);
    note->y2 = (float)(((recByte(rec, 0x13)) * (sx + 150)) / 100 - 75);
    note->targetX = note->x;
    note->targetY = note->y;

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
    note->scaleX = 1024.0f;
    note->scaleY = 1024.0f;
    moveToActive(note);
}

// Ghidra: FUN_000339a0 — spawn every chart record whose tick is within the spawn look-ahead of
// the current position. Note records (type 0) become live notes; mark/bar (types 1/4) become
// events; the end record (type 3) is spawned once and advances the play state.
void NoteMng::spawnNotes(uint32_t pos) {
    NoteRecord *rec = m_spawnCursor;
    const uint32_t spawnUntil = (uint32_t)(m_spawnLookahead + (int)pos);
    if (rec->tick > spawnUntil) {
        return;
    }
    do {
        switch (rec->type) {
            case NOTE_TYPE_NORMAL:   // 0: playable note
                makeNote(rec);
                break;
            case NOTE_TYPE_MARK:     // 1
            case NOTE_TYPE_BAR:      // 4
                makeEvent(rec);
                break;
            case NOTE_TYPE_END:      // 3: one-shot terminator
                if (m_state != 0) {
                    return;
                }
                makeEvent(rec);
                m_state = 1;
                return;
            default:                 // type 2 (tempo) is consumed at register time
                break;
        }
        m_spawnCursor = rec + 1;
        rec = m_spawnCursor;
    } while (rec->tick <= spawnUntil);
}

ActiveNote *NoteMng::activeNoteAt(unsigned index) {
    unsigned i = 0;
    for (ActiveNote *note = m_activeList; note != nullptr; note = note->next) {
        if (note->kind < 10 && (note->flags & 0x80) == 0) {
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
    ActiveNote *note = activeNoteAt((unsigned)index);
    assert(note != nullptr);   // NoteMng.mm GetNoteObject:0x32b/0x344

    out->rec = note->rec;
    out->startTick = note->startTick;
    out->endTick = note->endTick;
    out->kind = note->kind;
    out->kindHi = note->kindHi;
    out->flags = note->flags;
    out->scaleX = note->scaleX;
    out->scaleY = note->scaleY;
    out->spawnKind = note->spawnKind;
    out->x = note->x;
    out->y = note->y;
    out->x2 = note->x2;
    out->y2 = note->y2;
    out->targetX = note->targetX;
    out->targetY = note->targetY;

    // Recompute the render kind: special (chart kind 6..9), long (start < end), else normal.
    if (!m_autoPlay && (uint8_t)(note->kind - 6) < 4) {
        out->renderKind = NOTE_RENDER_SPECIAL;
    } else if (note->startTick < note->endTick) {
        out->renderKind = NOTE_RENDER_LONG;
    } else {
        out->renderKind = NOTE_RENDER_NORMAL;
    }
}

// Ghidra: judgeNoteHit @ 0x347e8. Grade a tap against note `index`.
int NoteMng::judgeNoteHit(unsigned index) {
    ActiveNote *note = activeNoteAt(index);
    if (note == nullptr || (note->flags & 0x2f) != 0) {
        return NOTE_JUDGE_MISS;
    }

    bool special = !m_autoPlay && (uint8_t)(note->kind - 6) < 4;
    int delta = (int)note->startTick - getCurrentPosition();   // + = early, - = late
    if (delta <= m_judgeWindows[0]) {
        return NOTE_JUDGE_MISS;   // already past the note
    }

    int tier;
    bool countsCombo = true;
    if (m_judgeWindows[1] < delta) {
        if (m_judgeWindows[2] < delta) {
            if (m_judgeWindows[3] < delta) {
                if (m_judgeWindows[4] < delta) {
                    if (m_judgeWindows[5] < delta) {
                        // Too early: bump the early-miss counter, no judgement.
                        m_earlyMiss[note->kind]++;
                        return NOTE_JUDGE_MISS;
                    }
                    tier = NOTE_JUDGE_BAD; note->flags |= 8;
                    m_combo = 0;
                    countsCombo = false;
                } else {
                    tier = NOTE_JUDGE_GOOD; note->flags |= 1;
                }
            } else {
                // Central band: within ~50 ms is the tightest tier.
                if ((unsigned)(delta + 50) < 101) {
                    tier = NOTE_JUDGE_COOL; note->flags |= 4;
                } else {
                    tier = NOTE_JUDGE_GREAT; note->flags |= 2;
                }
            }
        } else {
            tier = NOTE_JUDGE_GOOD; note->flags |= 1;
        }
        if (countsCombo && !(note->startTick < note->endTick) && !special) {
            m_combo++;
            if (m_combo > m_maxCombo) m_maxCombo = m_combo;
        }
    } else {
        tier = NOTE_JUDGE_BAD; note->flags |= 8;
        m_combo = 0;
        countsCombo = false;
    }

    if (!(note->startTick < note->endTick) && !special) {
        m_tally[note->kind][tier]++;
    }
    return tier;
}

// Ghidra: updateLongNote @ 0x34a78. Resolve a held note whose tail has passed.
int NoteMng::updateLongNote(unsigned index) {
    if (m_autoPlay) {
        return 0;
    }
    ActiveNote *note = activeNoteAt(index);
    if (note == nullptr) {
        return 0;
    }
    if ((note->flags & 0x2f) == 0 || (note->flags & 0x300) != 0) {
        return note ? note->flags : 0;
    }

    int delta = getCurrentPosition() - (int)note->startTick;
    int tier;
    if (delta < -60) {
        note->flags |= 0x200;   // NOTE_FLAGS_LONG_FAILED
        m_combo = 0;
        tier = 0;
        NSLog(@"NOTE_FLAGS_LONG_FAILED");
    } else {
        note->flags |= 0x100;   // NOTE_FLAGS_LONG_SUCCESS
        m_combo++;
        if (m_combo > m_maxCombo) m_maxCombo = m_combo;
        int f = note->flags;
        tier = (f & 1) ? 1 : (f & 2) ? 2 : (f & 4) ? 3 : 0;
        NSLog(@"NOTE_FLAGS_LONG_SUCCESS");
    }
    m_tally[note->kind][tier]++;
    return note->flags;
}

// Ghidra: noteMngJudgeHold @ 0x34964. Per-frame long-note "still held" judge, addressed by pool
// slot id. The slot's spawnKind byte is repurposed as a hold-segment countdown: each call it is
// decremented and the note's remaining distance to the judge line checked. If the head has
// scrolled more than (graphic+1) judge-windows (0x118 = 280) past the note, the hold breaks and
// the combo resets; when the countdown reaches zero the hold completes, advancing the combo and
// the per-kind/tier tally. `tier` (< 4) selects the tally column. Returns the remaining count.
int NoteMng::judgeHold(unsigned noteId, unsigned tier) {
    if (noteId >> 3 >= 0x7d) {   // noteId >= 1000
        return 0;
    }
    ActiveNote &slot = m_notePool[noteId];
    if (tier >= 4) {
        return (int)(int8_t)slot.spawnKind;
    }
    if ((slot.flags & 0x2f) == 0 || (int8_t)slot.spawnKind < 1) {
        slot.spawnKind = 0;
        return 0;
    }

    const int startTick = (int)slot.startTick;
    const int pos = getCurrentPosition();
    // The note's spawn graphic (chart kind 6..9 -> 2..5, else 1), used as a distance scale.
    int graphic;
    if ((uint8_t)(slot.kind - 6) < 4) {
        graphic = (int)(int8_t)(0x5040302 >> (((slot.kind - 6) & 0x1f) << 3));
    } else {
        graphic = 1;
    }
    const int8_t remaining = (int8_t)slot.spawnKind;
    graphic -= remaining;
    int8_t next = remaining;
    if (remaining > 0) {
        next = remaining - 1;
        slot.spawnKind = (uint8_t)next;
    }

    if (graphic * 0x118 + 0x118 < startTick - pos) {
        m_combo = 0;   // released too far from the note: the hold breaks
    } else if (next == 0) {
        int c = m_combo + 1;
        m_combo = c;
        if (m_maxCombo < c) {
            m_maxCombo = c;
        }
        m_tally[slot.kind][tier]++;
    }
    return (int)(int8_t)slot.spawnKind;
}

// Ghidra: noteMngSetLaneFlag @ 0x347c8 — set the "lane held" flag (0x40) on note pool slot noteId.
void NoteMng::setLaneFlag(unsigned noteId) {
    if (noteId >> 3 >= 0x7d) {   // noteId >= 1000
        return;
    }
    m_notePool[noteId].flags |= 0x40;
}

// Ghidra: noteMngTogglePause @ 0x34570 — resume play from a pause (the standard-mode twin of
// AcNoteMng::resume). Only acts while held: fold the paused span into the lead-in, clear the
// freeze bit, then (when the BGM start position is known and the chart has not ended) re-seek the
// BGM to the current position and restart it.
void NoteMng::togglePause() {
    if (!m_holdFlag) {
        return;
    }
    m_positionLeadIn += getElapsedTimeMs() - m_holdElapsed;
    m_scrollTarget = 0;
    m_bgmSynced = false;
    m_holdElapsed = 0;
    m_holdFlag = !m_holdFlag;   // clear the freeze bit

    if (m_bgmStartPos != -1 && !m_endFlag) {
        const int pos = getCurrentPosition();
        AudioManager *am = [AudioManager sharedManager];
        double seconds = (double)(pos - m_bgmStartPos) / 1000.0;   // DAT_00034660 = 1000.0
        [am setBgmCurrentTime:seconds];
    }
    [[AudioManager sharedManager] playBgm:0];
}

// --- Per-note tone-graphic accessors (free functions the draw pass calls) -----------
// Each reads one field of the standard manager's note pool slot `noteId` (the play
// draw pass never touches a NoteMng instance directly). All share the same bounds gate
// as the binary: (noteId >> 3) < 0x7d, i.e. noteId in [0, 1000).

// Ghidra: FUN_00034bb4 — the slot's chart kind (drives the tone graphic).
int NoteToneGraphic(int noteId) {
    if ((unsigned)noteId >> 3 < 0x7d) {
        return NoteMng::shared().toneSlot(noteId).kind;
    }
    return 0;
}

// Ghidra: FUN_00034b98 — the slot's high kind byte.
int NoteToneFlags(int noteId) {
    if ((unsigned)noteId >> 3 < 0x7d) {
        return NoteMng::shared().toneSlot(noteId).kindHi;
    }
    return 0;
}

// Ghidra: FUN_00034b5c — 1 for a special chart kind (6..9), else 2 for a long/hold note
// (start tick before end tick), else 0. This mirrors NoteRenderKind.
int NoteToneState(int noteId) {
    if ((unsigned)noteId >> 3 < 0x7d) {
        const ActiveNote &slot = NoteMng::shared().toneSlot(noteId);
        if ((uint8_t)(slot.kind - 6) < 4) {
            return 1;
        }
        return (slot.startTick < slot.endTick) ? 2 : 0;
    }
    return 0;
}

// Ghidra: FUN_00034a5c — the spawn graphic for a chart type: 6->2, 7->3, 8->4, 9->5,
// anything else 1. (Same packed table makeNote uses to fill a slot's spawnKind.)
int NoteToneDefaultGraphic(int type) {
    if ((unsigned)(type - 6) < 4) {
        return (int)(char)(0x5040302 >> (((type - 6) & 0x1f) << 3));
    }
    return 1;
}

// Ghidra: FUN_00034bd0 — the slot's spawn graphic (read back as a signed byte).
int NoteToneCount(int noteId) {
    if ((unsigned)noteId >> 3 < 0x7d) {
        return (int)(int8_t)NoteMng::shared().toneSlot(noteId).spawnKind;
    }
    return 0;
}

// Ghidra: FUN_00034664 — 60000 / the armed beat tempo, in ms; 0 while it is not positive.
float NoteBeatIntervalMs() {
    int16_t tempo = (int16_t)NoteMng::shared().beatTempoValue();
    if (tempo < 1) {
        return 0.0f;
    }
    return 60000.0f / (float)tempo;
}
