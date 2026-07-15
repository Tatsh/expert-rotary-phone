//
//  AcNoteMng.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The arcade
//  note manager: parses an arcade chart and builds the play timeline. Parallels
//  NoteMng but with 8-byte records and a difficulty-selected hi-speed.
//  Ghidra: InitPlayData FUN_0007a774, registerTempoEvents FUN_0007aa90,
//  changeTempo FUN_0007aaf8.
//

#include <cassert>
#include <cstring>
#include <ctime>
#include <sys/time.h>

#import <Foundation/Foundation.h>

#import "../../System/src/Sound/AudioManager.h" // BGM start / drift sync (triggerBgmStart, applyBgmSync)
#import "AcNoteMng.h"

// Arcade-viewer judge-result globals (Ghidra: DAT_0016ebe0 / DAT_0016ebe4).
// Verified via xref: the ONLY references in the binary are two READs from
// aepHudDrawCallback (@ 0x23514 / 0x235c0); nothing ever writes them, and their
// baked initial value is 0. The arcade viewer is a non-scored preview, so the
// COOL/GREAT HUD readouts are always 0 in the binary too -- this
// init-0-and-read model is exact, not a gap.
int g_dwAcCoolCount = 0;
int g_dwAcGreatCount = 0;
bool g_bAcNoteFinished = false;

// Hi-speed multiplier per hi-speed level (Ghidra: the switch in InitPlayData).
static const float kAcHiSpeed[kAcHiSpeedCount] = {
    1.2f,
    1.5f,
    2.0f,
    2.5f,
    3.0f,
    3.5f,
    4.0f,
    4.5f,
    5.0f,
    5.5f,
    6.0f,
};

// The global arcade note manager (Ghidra: DAT_0015f1b0). AcNoteMng_shared
// (FUN_0000b35c) is a ___cxa_guard'd lazy accessor; the function-local static
// reproduces its construct-once semantics. AcNoteMng_init (FUN_0007a744) zeroes
// the object and defaults the hi-speed to 1.2 (captured by the member init).
AcNoteMng &AcNoteMng::shared() {
    static AcNoteMng instance;
    return instance;
}

// Ghidra: FUN_0007a774. `data` points at the 8-byte header (magic 'E' at +4).
int AcNoteMng::initPlayData(const void *data, int size, int hiSpeedLevel) {
    assert(data != nullptr && size > 0); // AcNoteMng.mm:0x59

    m_recordCount = 0;
    m_minTempoValue = 0x7fff;
    m_maxTempoValue = 0;
    m_endValue = 0;
    m_scrollCount = 0;
    m_chartBarCount = 0;
    m_combo = 0;
    m_maxCombo = 0;
    std::memset(m_laneCounts, 0, sizeof(m_laneCounts));

    if (hiSpeedLevel >= 0 && hiSpeedLevel < kAcHiSpeedCount) {
        m_hiSpeed = kAcHiSpeed[hiSpeedLevel];
    }

    const uint8_t *bytes = static_cast<const uint8_t *>(data);
    // Magic: byte at +4 must be 'E' (arcade chart tag), else reject.
    if (bytes[4] != 'E') {
        return -3;
    }

    const int count = (size / 8) - 2;
    assert(count >= 0 && (unsigned)count < 7999); // AcNoteMng.mm:0x69
    // Ghidra iVar15: the copy/tally loop runs over EVERY record (indices
    // 0..lastIndex, i.e. count + 2 of them), then re-stamps the last one as the
    // terminator.
    const int lastIndex = (size / 8) - 1;
    const AcNoteRecord *src = reinterpret_cast<const AcNoteRecord *>(bytes);

    m_records = new AcNoteRecord[lastIndex + 1];
    for (int i = 0; i <= lastIndex; i++) {
        m_records[i] = src[i];
        m_records[i].type = bytes[i * 8 + 5]; // input record's type byte is at +5 (re-packed to +4)
        switch (m_records[i].type) {
        case AC_NOTE_TAP:
            m_laneCounts[m_records[i].value & 0xf]++;
            break;
        case AC_NOTE_END: // type 3: the BGM-start anchor -> the drift-sync
                          // reference time
            m_expectedTimeBase = (int)m_records[i].tick;
            break;
        case AC_NOTE_EVENT: // type 6: the real end-of-chart tick
            m_endValue = m_records[i].tick;
            break;
        case AC_NOTE_TEMPO:
            if (m_records[i].value > m_maxTempoValue) {
                m_maxTempoValue = m_records[i].value;
            }
            if (m_records[i].value < m_minTempoValue) {
                m_minTempoValue = m_records[i].value;
            }
            break;
        default:
            break;
        }
    }
    // Re-stamp the last record (index lastIndex = count + 1) as the terminator,
    // type 6 (AC_NOTE_EVENT) — this is what update()/spawnNotes scan for to raise
    // the end flag. Its tick is copied from record `count` (Ghidra: dest[iVar15]
    // <- dest[uVar6]).
    m_records[lastIndex] = m_records[count];
    m_records[lastIndex].type = AC_NOTE_EVENT;
    m_records[lastIndex].value = 0;
    // registerTempoEvents() walks records until the type-6 terminator; bound the
    // walk so it can reach record `count` (the one just before the terminator),
    // matching the binary's pointer scan.
    m_recordCount = lastIndex;

    // Prime the arcade play state the per-frame update() drives.
    m_spawnCursor = m_records; // +0xfa0c: spawning starts at the first record
    m_state = 0;
    m_autoPlay = 1; // +0x14cc1: InitPlayData enables auto-play (attract/demo default)
    m_endFlag = 0;
    m_barCount = 0;
    m_beatCount = 0;
    m_spawnLookahead = 0;

    // Judge windows (Ghidra: DAT_0012f868).
    static const int kAcJudgeWindows[6] = {-250, -250, -80, 120, 250, 250};
    std::memcpy(m_judgeWindows, kAcJudgeWindows, sizeof(m_judgeWindows));

    registerTempoEvents();
    changeTempo(0);

    // Thread the fixed node pool onto the free list, then prime the first frame —
    // the binary ends InitPlayData with exactly this pool build + a single
    // update() call.
    initNodePool();
    update();
    return 0;
}

// Ghidra: the tail of InitPlayData (FUN_0007a774) — append every pooled node to
// the free list (the same O(n^2) tail walk the binary does; run once at play
// setup).
void AcNoteMng::initNodePool() {
    m_freeHead = nullptr;
    m_activeHead = nullptr;
    for (int i = 0; i < kAcMaxActiveNotes; i++) {
        AcActiveNote *node = &m_notePool[i];
        node->next = nullptr;
        if (m_freeHead == nullptr) {
            m_freeHead = node;
        } else {
            AcActiveNote *tail = m_freeHead;
            while (tail->next != nullptr) {
                tail = tail->next;
            }
            tail->next = node;
        }
    }
}

int AcNoteMng::initPlayDataWithData(NSData *data, int hiSpeedLevel) {
    return initPlayData(data.bytes, (int)data.length, hiSpeedLevel);
}

// Ghidra: FUN_0007aa90 — walk the chart from the first record; register a
// scroll segment for each tempo (type 4) event and count measure lines (type
// 10); stop at the end marker (type 6).
void AcNoteMng::registerTempoEvents() {
    for (int i = 0; i < m_recordCount; i++) {
        const AcNoteRecord &r = m_records[i];
        if (r.type == AC_NOTE_EVENT) { // type 6: end of chart
            return;
        }
        if (r.type == 10) { // measure line
            m_chartBarCount++;
        } else if (r.type == AC_NOTE_TEMPO) {
            // The binary asserts ("AdvanceRegisterEvent") if the segment table
            // overflows.
            assert(registerScrollSegment((int16_t)r.value, r.tick) == 0);
        }
    }
}

// Ghidra: FUN_0007ba3c — insert one tempo/scroll segment, kept sorted by
// startTick. The scroll speed is bpm * 1024 / 480000 (DAT_0007bb28 /
// DAT_0007bb24). Returns non-zero if the table is full (max 63). Also refreshes
// the spawn look-ahead.
int AcNoteMng::registerScrollSegment(int16_t bpm, uint32_t tick) {
    if (m_scrollCount >= 0x3f) {
        return 1;
    }
    int k = 0;
    while (k <= 0x3e && m_scrollMap[k].startTick <= tick) {
        k++;
    }
    for (int j = m_scrollCount; j > k; j--) {
        m_scrollMap[j] = m_scrollMap[j - 1];
    }
    m_scrollMap[k].bpm = bpm;
    m_scrollMap[k].startTick = tick;
    m_scrollMap[k].speed = (float)bpm * 1024.0f / 480000.0f;
    m_scrollCount++;
    recomputeSpawnLookahead(tick);
    return 0;
}

// Ghidra: the shared tail of FUN_0007ba3c / FUN_0007aaf8 — walk up to 8 front
// segments summing 60000/BPM (ms), advancing when the next segment's startTick
// is reached; the total is the spawn look-ahead. The sentinel startTick (-1) on
// unregistered segments blocks over-advance.
void AcNoteMng::recomputeSpawnLookahead(uint32_t pos) {
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

// Ghidra: FUN_0007aaf8 — once play passes the current segment (the next
// segment's startTick has arrived), retire the front segment (shift the array
// down) and report it; always refresh the spawn look-ahead. Returns non-zero
// while a segment was retired (seekTo loops on it).
int AcNoteMng::changeTempo(uint32_t tick) {
    int ret = 0;
    if (m_scrollMap[1].startTick <= tick) {
        for (int j = 0; j < m_scrollCount; j++) {
            m_scrollMap[j] = m_scrollMap[j + 1];
        }
        m_scrollMap[m_scrollCount].speed = 0.0f;
        m_scrollMap[m_scrollCount].startTick = 0xffffffff;
        m_scrollMap[m_scrollCount].bpm = -1;
        m_scrollCount--;
        assert(m_scrollMap[0].bpm >= 1); // "ChangeTempo" AcNoteMng.mm:0x565
        ret = 1;
    }
    recomputeSpawnLookahead(tick);
    return ret;
}

// Seek / fast-forward the internal play clock to the target tick `pos`. Skips
// if play is already at/past the end (both the current offset and the requested
// position past the end value) or the target is not ahead of it; else
// re-anchors the clock and rebuilds the active notes at the seek target. The
// arcade engine uses one operation for both the initial start (seek from 0) and
// the mid-play re-seek after an option change. // @ 0x7b86c (acNoteSeekTo)
void AcNoteMng::seekTo(uint32_t pos) {
    const uint32_t endValue = m_endValue;
    bool proceed;
    if ((uint32_t)m_positionOffset < endValue) {
        proceed = true;
    } else {
        proceed = (pos < endValue);
    }
    if (!proceed) {
        return;
    }

    m_state = 2; // seeking
    m_frozenElapsed = 0;
    m_holdElapsed = 0;
    m_startThreshold = 0;
    m_holdFlags = 1; // freeze the clock until the lead-in completes
    m_positionOffset = (int)((pos < endValue) ? pos : endValue); // clamp to the end

    timeval tv;
    gettimeofday(&tv, nullptr); // stamp m_startSec/m_startUsec (@ +0x14cb8)
    m_startSec = tv.tv_sec;
    m_startUsec = tv.tv_usec;

    const uint32_t p = (uint32_t)getCurrentPosition();
    while (changeTempo(p) != 0) { // settle the tempo segments to the start position
    }
    update(); // prime the first frame
}

// Ghidra: FUN_0007b5e0 — wall-clock ms since the play clock was armed (0 until
// then).
int AcNoteMng::getElapsedTimeMs() const {
    if (m_startSec == 0 && m_startUsec == 0) {
        return 0;
    }
    timeval now;
    gettimeofday(&now, nullptr);
    return (int)((now.tv_sec - m_startSec) * 1000 + (now.tv_usec - m_startUsec) / 1000);
}

// Ghidra: FUN_0007aeb4 — the current chart position. Uses live elapsed time
// unless the hold bit is set (then the last cached elapsed), applies the
// per-play offset, and adds the excess past the start threshold onto the
// smoothed scroll base.
int AcNoteMng::getCurrentPosition() {
    int elapsed;
    if ((m_holdFlags & 1) == 0) {
        elapsed = getElapsedTimeMs();
        m_frozenElapsed = elapsed;
    } else {
        elapsed = m_frozenElapsed;
    }
    const uint32_t pos = (uint32_t)(elapsed + m_positionOffset);
    int result = m_scrollBase;
    if (m_startThreshold <= pos) {
        result += (int)(pos - m_startThreshold);
    }
    return result;
}

// ---------------------------------------------------------------------------
// Arcade per-frame update (FUN_0007ac00 and its closure). The active-note pool
// is a dual linked list: nodes live on the free list (m_freeHead) until spawned
// onto the active list (m_activeHead), and return to the free list once
// retired. All geometry/flag constants are byte/disasm-verified against the
// binary.
// ---------------------------------------------------------------------------

// Detach `node` from the free list and append it to the active-list tail.
// Shared tail of makeNoteEvent / makeEvent / makeAdjustEvent (each first pops
// m_freeHead into `node`).
void AcNoteMng::moveNodeFreeToActive(AcActiveNote *node) {
    if (m_freeHead == node) {
        m_freeHead = node->next;
    } else {
        for (AcActiveNote *p = m_freeHead; p != nullptr; p = p->next) {
            if (p->next == node) {
                p->next = node->next;
                break;
            }
        }
    }
    node->next = nullptr;
    if (m_activeHead == nullptr) {
        m_activeHead = node;
    } else {
        AcActiveNote *tail = m_activeHead;
        while (tail->next != nullptr) {
            tail = tail->next;
        }
        tail->next = node;
    }
}

// Unlink `node` from the active list and append it to the free-list tail
// (retirement).
void AcNoteMng::retireNode(AcActiveNote *node) {
    if (m_activeHead == node) {
        m_activeHead = node->next;
    } else {
        for (AcActiveNote *p = m_activeHead; p != nullptr; p = p->next) {
            if (p->next == node) {
                p->next = node->next;
                break;
            }
        }
    }
    node->next = nullptr;
    if (m_freeHead == nullptr) {
        m_freeHead = node;
    } else {
        AcActiveNote *tail = m_freeHead;
        while (tail->next != nullptr) {
            tail = tail->next;
        }
        tail->next = node;
    }
}

// Ghidra: FUN_0007b2f4 — spawn a playable note onto the active list (lane from
// the chart, optionally rotated in lane-mode 3), draw position primed at 1024.
void AcNoteMng::makeNoteEvent(const AcNoteRecord *rec) {
    int lane = rec->value & 0xf;
    if (m_laneMode == 3) {
        lane = (lane + (int)(rec->tick / 0x48)) % 9;
    }
    AcActiveNote *node = m_freeHead;
    assert(node != nullptr); // "MakeNoteEvent" AcNoteMng.mm:0x483
    node->record = rec;
    node->tick = rec->tick;
    node->lane = (uint8_t)m_laneRemap[lane];
    node->flags = 0;
    node->drawY = 1024.0f; // 0x44800000
    moveNodeFreeToActive(node);
}

// Ghidra: FUN_0007b3dc — spawn a non-playable chart event (lane 9).
void AcNoteMng::makeEvent(const AcNoteRecord *rec) {
    AcActiveNote *node = m_freeHead;
    assert(node != nullptr); // "MakeEvent" AcNoteMng.mm:0x4c9
    node->record = rec;
    node->tick = rec->tick;
    node->lane = 9;
    node->flags = 0;
    node->drawY = 1024.0f;
    moveNodeFreeToActive(node);
}

// Ghidra: FUN_0007b790 — inject the BGM re-sync ("adjust") event once. Resets
// the scroll base and arms a type-0xf event whose judgement (applyBgmSync)
// corrects the scroll for BGM drift.
void AcNoteMng::makeAdjustEvent(uint32_t tick) {
    AcActiveNote *node = m_freeHead;
    assert(node != nullptr);         // "MakeAdjustEvent" AcNoteMng.mm:0x4a7
    if (m_adjustRecord.value != 0) { // +0xfa0a: an adjust is already in flight
        return;
    }
    m_scrollTarget = 0;
    m_scrollBase = 0;
    m_adjustRecord.tick = tick;
    m_adjustRecord.type = 0xf;
    m_adjustRecord.value = 1; // mark the adjust in flight
    node->record = &m_adjustRecord;
    node->tick = tick;
    node->lane = 9;
    node->flags = 0;
    node->drawY = 1024.0f;
    moveNodeFreeToActive(node);
}

// Ghidra: FUN_0007b484 — the type-3 chart event: start the BGM exactly once.
void AcNoteMng::triggerBgmStart() {
    if (m_endFlag) {
        return;
    }
    AudioManager *am = [AudioManager sharedManager];
    if ([am isPlayingBgm]) {
        return;
    }
    [am playBgm:0];
}

// Ghidra: FUN_0007b4f0 — the type-0xf adjust event: clear the in-flight flag
// and, if the BGM is playing, nudge the scroll target by the measured drift
// (BGM playhead vs expected time); otherwise re-arm the adjust a little later.
void AcNoteMng::applyBgmSync(const AcNoteRecord *rec) {
    AudioManager *am = [AudioManager sharedManager];
    m_adjustRecord.value = 0;
    if ([am isPlayingBgm]) {
        int cur = getCurrentPosition();
        int expected = m_expectedTimeBase;
        double bgmMs = [am bgmCurrentTime] * 1000.0; // DAT_0007b598 = 1000.0
        int drift = (bgmMs > 0.0) ? (int)(long long)bgmMs : 0;
        m_scrollTarget += drift + (expected - cur);
    } else {
        makeAdjustEvent(rec->tick + 0x20);
    }
}

// Ghidra: FUN_0007aef8 — spawn every chart record that has come due (within the
// look-ahead). Off-window taps in auto-play are counted immediately; chart
// events fire their side effects.
void AcNoteMng::spawnNotes(uint32_t pos) {
    if ((unsigned)(m_state - 3) <= 1) { // state 3 or 4: nothing left to spawn
        return;
    }
    AcNoteRecord *rec = m_spawnCursor;
    const uint32_t spawnUntil = (uint32_t)(m_spawnLookahead + (int)pos);
    if (rec->tick > spawnUntil) {
        return;
    }
    do {
        const int dt = (pos <= rec->tick) ? 0 : (int)(pos - rec->tick);
        switch (rec->type) {
        case AC_NOTE_TAP: // 1
            if (dt < 4000) {
                makeNoteEvent(rec);
            } else if (m_autoPlay) {
                m_laneResult[rec->value & 0xf].hits++;
            }
            break;
        case AC_NOTE_END: // 3 (BGM start / sync anchor)
            makeEvent(rec);
            makeAdjustEvent(rec->tick + 0x20);
            break;
        case AC_NOTE_EVENT: // 6 (begin the ending)
            makeEvent(rec);
            m_state = 3;
            break;
        case 10: // 0xa: measure boundary
            if (dt < 4000) {
                makeEvent(rec);
            } else {
                m_barCount++;
                m_beatCount = 0;
            }
            break;
        case 11: // 0xb: beat boundary
            if (dt < 4000) {
                makeEvent(rec);
            } else {
                m_beatCount++;
            }
            break;
        default:
            break;
        }
        m_spawnCursor = rec + 1;
        rec = m_spawnCursor;
    } while (rec->tick <= spawnUntil);
}

// Ghidra: FUN_0007b028 — first per-note pass: once a note's time has arrived,
// fire its event side effect (BGM start, bar/beat counters, adjust sync) and
// mark it handled (bit 5).
void AcNoteMng::judgeActiveNote(AcActiveNote *node, uint32_t pos) {
    const uint16_t flags = node->flags;
    if (flags & 0x20) {
        return;
    }
    if (pos < node->tick) {
        return;
    }
    switch (node->record->type) {
    case 2:
    case 7:
    case 8:
    case 9:
    case 0xc:
    case 0xd:
        break; // no side effect; just mark handled below
    case 3:
        if (m_state != 1) {
            return;
        }
        triggerBgmStart();
        node->flags |= 0x20;
        return;
    case 10:
        m_barCount++;
        m_beatCount = 0;
        break;
    case 11:
        m_beatCount++;
        break;
    case 0xf:
        applyBgmSync(node->record);
        node->flags |= 0x20;
        return;
    default:
        return; // unhandled type: leave un-marked
    }
    node->flags |= 0x20;
}

// Ghidra: FUN_0007b0a8 — second per-note pass: retire notes that have scrolled
// fully past
// (>4 s old; auto-miss-counted in auto-play) or that were already resolved
// (bits 4/5), then advance the caller's cursor to the next node.
void AcNoteMng::retireActiveNote(AcActiveNote **pnode, uint32_t pos) {
    AcActiveNote *node = *pnode;
    AcActiveNote *next = node->next;
    if (node->tick + 4000u < pos) {
        if (m_autoPlay && (node->flags & 0xb) == 0) {
            node->flags |= 1;
            m_laneResult[node->lane].hits++;
        }
        retireNode(node);
    } else if (node->flags & 0x30) {
        retireNode(node);
    }
    *pnode = next;
}

// Ghidra: FUN_0007b1bc — refresh the per-lane "nearest note" candidate for
// input, and (in auto-play) auto-hit notes at/after their time, feeding the
// combo counter.
void AcNoteMng::updateNearest(AcActiveNote *node, uint32_t pos) {
    const uint16_t flags = node->flags;
    if ((flags & 0xb) != 0) {
        return;
    }
    const uint8_t lane = node->lane;
    if (lane >= 9) {
        return;
    }
    const int dt = (int)pos - (int)node->tick;
    if (m_autoPlay && dt >= 0) {
        m_laneResult[lane].hits++;
        node->flags = (uint16_t)(flags | 1);
        const uint32_t combo = (uint32_t)m_combo + 1;
        m_combo = (int)combo;
        if ((uint32_t)m_maxCombo < combo) {
            m_maxCombo = (int)combo;
        }
    }
    const int adt = (dt < 0) ? -dt : dt;
    if (adt < 0x200 && dt <= m_nearestThreshold) {
        const int cur = m_nearest[lane].dt;
        const int acur = (cur < 0) ? -cur : cur;
        if (acur <= adt) {
            return; // an equally-or-closer candidate is already held
        }
        m_nearest[lane].note = node;
        m_nearest[lane].dt = dt;
    }
}

// Ghidra: FUN_0007b268 — refresh a note's on-screen scroll position; once past
// the judge line mark it judged (bit 2) and, when not auto-playing, let it
// slide off; clamp non-past notes at 0.
void AcNoteMng::updateDrawPos(AcActiveNote *node, uint32_t pos) {
    const uint16_t flags = node->flags;
    if ((flags & 4) == 0 && node->lane < 9) {
        node->drawY = computeScrollY(node, pos);
    }
    if (node->tick < pos) {
        if ((flags & 4) == 0) {
            node->flags = (uint16_t)(flags | 4);
        }
        if (!m_autoPlay) {
            node->drawY = node->drawY + m_playSpeed * -16.0f;
        }
    } else if (node->drawY < 0.0f) {
        node->drawY = 0.0f;
    }
}

// Ghidra: FUN_0007bb30 — integrate scroll speed x elapsed span across the
// scroll-speed segments from `pos` up to the note's tick, scale by the hi-speed
// multiplier, clamp +-8192.
float AcNoteMng::computeScrollY(const AcActiveNote *node, uint32_t pos) const {
    const uint32_t tick = node->tick;
    float accum = 0.0f;
    if (pos < tick) {
        int seg = 0;
        do {
            uint32_t span = tick - pos;
            // Segment `seg`'s speed applies until the NEXT segment's startTick (a -1
            // sentinel on the last one leaves the whole remaining span at this
            // speed).
            const uint32_t segSpan = m_scrollMap[seg + 1].startTick - pos;
            if (segSpan < span) {
                span = segSpan;
            }
            accum += m_scrollMap[seg].speed * (float)span;
            pos += span;
            seg++;
        } while (pos < tick);
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

// Ghidra: FUN_0007ac00 — the arcade note engine's per-frame update.
void AcNoteMng::update() {
    // Smooth the scroll base one step toward its target (+-1 per frame).
    if (m_scrollTarget != m_scrollBase) {
        const int diff = m_scrollTarget - m_scrollBase;
        const int mag = (diff < 0) ? -diff : diff;
        if (mag < 1) {
            m_scrollBase = m_scrollTarget;
        } else {
            m_scrollBase += (diff < 0) ? -1 : 1;
        }
    }

    const uint32_t pos = (uint32_t)getCurrentPosition();

    if (m_state != 4) {
        spawnNotes(pos);
        AcActiveNote *node = m_activeHead;
        while (node != nullptr) {
            judgeActiveNote(node, pos);
            retireActiveNote(&node, pos); // advances `node` to the next active note
        }
        if (m_endFlag) {
            m_state = 4;
        }
    }

    changeTempo(pos);

    // Rebuild the per-lane "nearest note" table (9 lanes) from scratch each
    // frame.
    for (int lane = 0; lane < 9; lane++) {
        m_nearest[lane].note = nullptr;
        m_nearest[lane].dt = 0x400; // 1024
    }

    for (AcActiveNote *node = m_activeHead; node != nullptr; node = node->next) {
        updateNearest(node, pos);
        updateDrawPos(node, pos);
        if (!m_endFlag && node->record->type == AC_NOTE_EVENT && node->tick <= pos) {
            node->flags |= 0x20;
            m_endFlag = 1;
        }
    }
}

// ---------------------------------------------------------------------------
// Pause / resume + play-clock control (input-driven, outside the per-frame
// update).
// ---------------------------------------------------------------------------

// Ghidra: acNoteStartPlayback @ 0x7b5a0 — stamp the wall-clock baseline and
// clear the pause/offset state so the play clock runs from now; state = 1
// (playing).
void AcNoteMng::startPlayback() {
    timeval tv;
    gettimeofday(&tv, nullptr); // -> m_startSec/m_startUsec (@ +0x14cb8)
    m_startSec = tv.tv_sec;
    m_startUsec = tv.tv_usec;
    m_frozenElapsed = getElapsedTimeMs();
    m_startThreshold = 0;
    m_holdElapsed = 0;
    m_holdFlags = 0;
    m_state = 1;
}

// Ghidra: AcNoteMng::Pause @ 0x7b638 — freeze the clock and stop the BGM,
// remembering the elapsed time at the pause so resume() can fold the paused
// span back in. No-op if held.
void AcNoteMng::Pause() {
    if (m_holdFlags & 1) {
        return;
    }
    [[AudioManager sharedManager] stopBgm:0];
    m_holdElapsed = getElapsedTimeMs(); // +0xfa40: the pause timestamp
    m_holdFlags |= 1;
}

// Ghidra: acNoteResume @ 0x7b698 — release the freeze: advance the start
// threshold by the paused span, reset the smoothed scroll base, then (once play
// is far enough in and the chart has not ended) re-seek the BGM to the current
// position, restart it, and arm a drift-sync adjust event. No-op unless
// currently held.
void AcNoteMng::resume() {
    if ((m_holdFlags & 1) == 0) {
        return;
    }
    m_startThreshold += getElapsedTimeMs() - m_holdElapsed;
    m_scrollTarget = 0;
    m_scrollBase = 0;
    m_holdElapsed = 0;
    m_holdFlags ^= 1; // clear bit 0
    m_state = 1;

    const uint32_t pos = (uint32_t)getCurrentPosition();
    if (pos >= (uint32_t)m_expectedTimeBase && m_endFlag == 0) {
        AudioManager *am = [AudioManager sharedManager];
        float seconds = (float)((int)pos - m_expectedTimeBase) / 1000.0f; // DAT_0007b78c = 1000.0
        [am setBgmCurrentTime:seconds];
        [[AudioManager sharedManager] playBgm:0];
        makeAdjustEvent(pos + 0x20);
    }
}

// Ghidra: acNoteResetPlayFlag @ 0x7aea4.
void AcNoteMng::resetPlayFlag() {
    m_playFlag = 0;
}

// Ghidra: acNoteSetupLaneMapping @ 0x7ad14 — build the lane-remap table for the
// option. The random modes (1/3) shuffle lanes 0..8 with a time-seeded
// generator and retry until the result is a derangement (no lane maps to
// itself), capped at 100000 attempts as the binary does.
void AcNoteMng::setupLaneMapping(int mode) {
    m_laneMode = mode;
    if (mode == 1 || mode == 3) {
        // The binary uses the engine's C_Rand (rngStateInit / rngSeed(time) /
        // GetRandRangeInt); modelled here with the same construction: time-seeded,
        // in-place Fisher-Yates, retried until no fixed point remains.
        unsigned rng = (unsigned)time(nullptr);
        auto nextRange = [&rng](int range) -> int {
            rng = rng * 1103515245u + 12345u;
            return (int)((rng >> 16) % (unsigned)range);
        };
        for (int attempt = 0; attempt <= 99999; attempt++) {
            for (int i = 0; i < 9; i++) {
                m_laneRemap[i] = i;
            }
            for (int i = 0; i < 9; i++) {
                int r = nextRange(9 - i);
                int32_t tmp = m_laneRemap[i + r];
                m_laneRemap[i + r] = m_laneRemap[i];
                m_laneRemap[i] = tmp;
            }
            bool deranged = true;
            for (int i = 0; i < 9; i++) {
                if (m_laneRemap[i] == i) {
                    deranged = false;
                    break;
                }
            }
            if (deranged) {
                break;
            }
        }
    } else if (mode == 2) {
        for (int i = 0; i < 9; i++) {
            m_laneRemap[i] = 8 - i;
        }
    } else {
        for (int i = 0; i < 9; i++) {
            m_laneRemap[i] = i;
        }
    }
}

// ---------------------------------------------------------------------------
// Play-state queries.
// ---------------------------------------------------------------------------

// Ghidra: acNoteGetTotalNoteCount @ 0x7b8ec — sum the 9 per-lane tap counters.
int AcNoteMng::getTotalNoteCount() const {
    int total = 0;
    for (int lane = 0; lane < 9; lane++) {
        total += m_laneCounts[lane];
    }
    return (int)(int16_t)total;
}

// Ghidra: acNoteGetJudgeTotal @ 0x7b908 — sum the whole 9x4 per-lane
// score/judge table (m_laneResult, stride 0x10) and return the low 16 bits.
int AcNoteMng::getJudgeTotal() const {
    int total = 0;
    for (int lane = 0; lane < 9; lane++) {
        total += m_laneResult[lane].hits;
        total += m_laneResult[lane]._reserved[0];
        total += m_laneResult[lane]._reserved[1];
        total += m_laneResult[lane]._reserved[2];
    }
    return (int)(int16_t)total;
}

// Ghidra: acNoteCountActiveNotes @ 0x7b93c — count on-screen notes (lane < 9)
// whose "handled" bit (0x20) is still clear.
int AcNoteMng::countActiveNotes() const {
    int count = 0;
    for (const AcActiveNote *node = m_activeHead; node != nullptr; node = node->next) {
        if (node->lane < 9 && (node->flags & 0x20) == 0) {
            count++;
        }
    }
    return count;
}

// Ghidra: acNoteGetNoteObject @ 0x7b968 — copy the `index`-th still-unresolved
// note into `out`.
void AcNoteMng::getNoteObject(AcNoteObject *out, int index) const {
    assert(out != nullptr); // "GetNoteObject" AcNoteMng.mm:0x37c
    int seen = 0;
    for (const AcActiveNote *node = m_activeHead; node != nullptr; node = node->next) {
        if (node->lane < 9 && (node->flags & 0x20) == 0) {
            if (seen == index) {
                out->tick = node->tick;
                out->lane = node->lane;
                out->flags = node->flags;
                out->drawY = node->drawY;
                return;
            }
            seen++;
        }
    }
    assert(false); // "GetNoteObject" AcNoteMng.mm:0x395 (index out of range)
}

// Ghidra: acNoteSetNoteFlag @ 0x7b9fc — OR `flags` into the `index`-th
// still-unresolved note.
void AcNoteMng::setNoteFlag(int index, uint16_t flags) {
    int seen = 0;
    for (AcActiveNote *node = m_activeHead; node != nullptr; node = node->next) {
        if (node->lane < 9 && (node->flags & 0x20) == 0) {
            if (seen == index) {
                node->flags |= flags;
                return;
            }
            seen++;
        }
    }
}
