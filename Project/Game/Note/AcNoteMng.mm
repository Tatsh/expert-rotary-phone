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

#import "AcNoteMng.h"

#include <cassert>
#include <cstddef>
#include <cstring>
#include <ctime>
#include <span>
#include <sys/time.h>
#include <utility>

#import <Foundation/Foundation.h>

#import "../../System/src/Sound/AudioManager.h" // BGM start / drift sync (triggerBgmStart, applyBgmSync)
#import "../Util/Random.h"
#import "neDebugLog.h"

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
constexpr float kAcHiSpeed[kAcHiSpeedCount] = {
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
// The binary keeps the chart records in an inline buffer at the object base
// (pChartCursor = this, @ 0x7a98a); this reconstruction models that buffer as a
// heap array (m_records / m_spawnCursor) for readability. Behaviour, field
// offsets, and control flow are otherwise disassembly-faithful.
int AcNoteMng::initPlayData(std::span<const std::byte> data, int hiSpeedLevel) {
    assert(!data.empty()); // AcNoteMng.mm:0x59
    const int size = static_cast<int>(data.size());

    m_recordCount = 0;
    m_minTempoValue = 0x7fff;
    m_maxTempoValue = 0;
    m_endValue = 0;
    m_scrollCount = 0;
    m_chartBarCount = 0;
    m_combo = 0;
    m_maxCombo = 0;
    std::memset(m_laneCounts, 0, sizeof(m_laneCounts));

    // The binary starts InitPlayData with memset(this, 0, 0x14cc4), zeroing the
    // whole play-data region. Reset the play clock and scroll state the setup
    // update() below reads so a reused AcNoteMng does not carry a stale baseline:
    // getElapsedTimeMs() returns "now - m_startSec" (0 only while the stamp is
    // zero), so a leftover stamp makes the first getCurrentPosition() enormous,
    // the spawn window then covers the entire chart, and spawnNotes drains the
    // 1000-node pool and writes through a null free node.
    m_startSec = 0;
    m_startUsec = 0;
    m_frozenElapsed = 0;
    m_holdElapsed = 0;
    m_positionOffset = 0;
    m_startThreshold = 0;
    m_scrollBase = 0;
    m_scrollTarget = 0;
    m_holdFlags = 0;
    m_adjustRecord = {};

    if (hiSpeedLevel >= 0 && hiSpeedLevel < kAcHiSpeedCount) {
        m_hiSpeed = kAcHiSpeed[hiSpeedLevel];
    }

    const uint8_t *bytes = reinterpret_cast<const uint8_t *>(data.data());
    // The record-count bound is checked BEFORE the magic byte: the binary runs
    // the 7999 assert (@ 0x7a86e-0x7a87c, bcs -> ___assert_rtn 0x69) first, and
    // only then compares bytes[4] to 'E' (@ 0x7a880-0x7a886). An oversized chart
    // therefore asserts even when the magic is wrong.
    const int count = (size / 8) - 2;
    assert(count >= 0 && static_cast<unsigned>(count) < 7999); // AcNoteMng.mm:0x69

    // Magic: byte at +4 must be 'E' (arcade chart tag), else reject.
    if (bytes[4] != 'E') {
        return -3;
    }
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
            m_expectedTimeBase = static_cast<int>(m_records[i].tick);
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
    m_state = AC_NOTE_STATE_IDLE;
    m_autoPlay = true; // +0x14cc1: InitPlayData enables auto-play (attract/demo default)
    m_endFlag = false;
    m_barCount = 0;
    m_beatCount = 0;
    m_spawnLookahead = 0;

    // Judge windows (Ghidra: DAT_0012f868).
    static constexpr int kAcJudgeWindows[6] = {-250, -250, -80, 120, 250, 250};
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
    return initPlayData({static_cast<const std::byte *>(data.bytes), data.length}, hiSpeedLevel);
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
        if (r.type == AC_NOTE_MEASURE) { // measure line
            m_chartBarCount++;
        } else if (r.type == AC_NOTE_TEMPO) {
            // The binary asserts ("AdvanceRegisterEvent") if the segment table
            // overflows.
            assert(registerScrollSegment(static_cast<int16_t>(r.value), r.tick) == 0);
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
    m_scrollMap[k].speed = static_cast<float>(bpm) * 1024.0f / 480000.0f;
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
        if (m_scrollMap[seg + 1].startTick <=
            static_cast<uint32_t>(accum + static_cast<int>(pos))) {
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
    if (static_cast<uint32_t>(m_positionOffset) < endValue) {
        proceed = true;
    } else {
        proceed = (pos < endValue);
    }
    if (!proceed) {
        return;
    }

    m_state = AC_NOTE_STATE_SEEKING; // seeking
    m_frozenElapsed = 0;
    m_holdElapsed = 0;
    m_startThreshold = 0;
    m_holdFlags = 1; // freeze the clock until the lead-in completes
    m_positionOffset = static_cast<int>((pos < endValue) ? pos : endValue); // clamp to the end

    timeval tv;
    gettimeofday(&tv, nullptr); // stamp m_startSec/m_startUsec (@ +0x14cb8)
    m_startSec = tv.tv_sec;
    m_startUsec = tv.tv_usec;

    const uint32_t p = static_cast<uint32_t>(getCurrentPosition());
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
    return static_cast<int>((now.tv_sec - m_startSec) * 1000 + (now.tv_usec - m_startUsec) / 1000);
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
    const uint32_t pos = static_cast<uint32_t>(elapsed + m_positionOffset);
    int result = m_scrollBase;
    if (m_startThreshold <= pos) {
        result += static_cast<int>(pos - m_startThreshold);
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
        lane = (lane + static_cast<int>(rec->tick / 0x48)) % 9;
    }
    AcActiveNote *node = m_freeHead;
#if RHYDBG
    // The 1000-node pool should never run dry: the binary asserts here too (@ 0x483).
    // Faithful analysis of every shipped chart shows the init spawn window is only a
    // few thousand ms, so a real exhaustion means the spawn window (or the loaded
    // sheet) is not what the offline model expects. Capture the context and bail
    // instead of faulting so the RHYDBG session can report it; the release build
    // keeps the original assert.
    if (node == nullptr) {
        neDebugLog("AcNote POOL EXHAUSTED makeNoteEvent recCount=%d rec.tick=%u lane=%d state=%d",
                   m_recordCount,
                   rec->tick,
                   rec->value & 0xf,
                   static_cast<int>(m_state));
        return;
    }
#endif
    assert(node != nullptr); // "MakeNoteEvent" AcNoteMng.mm:0x483
    node->record = rec;
    node->tick = rec->tick;
    node->lane = static_cast<uint8_t>(m_laneRemap[lane]);
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
    m_adjustRecord.type = AC_NOTE_ADJUST;
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
        int drift = (bgmMs > 0.0) ? static_cast<int>(static_cast<long long>(bgmMs)) : 0;
        m_scrollTarget += drift + (expected - cur);
    } else {
        makeAdjustEvent(rec->tick + 0x20);
    }
}

// Ghidra: FUN_0007aef8 — spawn every chart record that has come due (within the
// look-ahead). Off-window taps in auto-play are counted immediately; chart
// events fire their side effects.
void AcNoteMng::spawnNotes(uint32_t pos) {
    if (m_state == AC_NOTE_STATE_ENDING || m_state == AC_NOTE_STATE_FINISHED) {
        return; // nothing left to spawn
    }
    AcNoteRecord *rec = m_spawnCursor;
    const uint32_t spawnUntil = static_cast<uint32_t>(m_spawnLookahead + static_cast<int>(pos));
    if (NE_DBG_FIRST(8)) {
        // First few spawn passes (the init pass is where the arcade viewer faults):
        // log the window so a device run shows whether spawnUntil covers the whole
        // chart (pool-drain risk) versus the small look-ahead the offline model
        // predicts.
        neDebugLog("AcNote spawnNotes pos=%u until=%u lookahead=%d recCount=%d cursorTick=%u "
                   "state=%d",
                   pos,
                   spawnUntil,
                   m_spawnLookahead,
                   m_recordCount,
                   rec->tick,
                   static_cast<int>(m_state));
    }
    if (rec->tick > spawnUntil) {
        return;
    }
    do {
        const int dt = (pos <= rec->tick) ? 0 : static_cast<int>(pos - rec->tick);
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
            m_state = AC_NOTE_STATE_ENDING;
            break;
        case AC_NOTE_MEASURE: // measure boundary
            if (dt < 4000) {
                makeEvent(rec);
            } else {
                m_barCount++;
                m_beatCount = 0;
            }
            break;
        case AC_NOTE_BEAT: // beat boundary
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
        // Bound the scan to the record array. m_records[m_recordCount] is the
        // type-6 terminator (the last element of new AcNoteRecord[m_recordCount +
        // 1]); once the cursor advances past it, stop before dereferencing rec.
        // The binary relies on allocation slack + the terminator's tick to halt
        // here, which faults on a short chart (spawn window >= chart length, e.g.
        // an Arcade Viewer preview) with an exactly-sized allocation.
    } while (rec <= &m_records[m_recordCount] && rec->tick <= spawnUntil);
}

// Ghidra: FUN_0007b028 — first per-note pass: once a note's time has arrived,
// fire its event side effect (BGM start, bar/beat counters, adjust sync) and
// mark it handled (bit 5).
void AcNoteMng::judgeActiveNote(AcActiveNote *node, uint32_t pos) {
    const uint16_t flags = node->flags;
    if (flags & AC_NOTE_FLAG_HANDLED) {
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
        if (m_state != AC_NOTE_STATE_PLAYING) {
            return;
        }
        triggerBgmStart();
        node->flags |= AC_NOTE_FLAG_HANDLED;
        return;
    case AC_NOTE_MEASURE:
        m_barCount++;
        m_beatCount = 0;
        break;
    case AC_NOTE_BEAT:
        m_beatCount++;
        break;
    case AC_NOTE_ADJUST:
        applyBgmSync(node->record);
        node->flags |= AC_NOTE_FLAG_HANDLED;
        return;
    default:
        return; // unhandled type: leave un-marked
    }
    node->flags |= AC_NOTE_FLAG_HANDLED;
}

// Ghidra: FUN_0007b0a8 — second per-note pass: retire notes that have scrolled
// fully past
// (>4 s old; auto-miss-counted in auto-play) or that were already resolved
// (bits 4/5), then advance the caller's cursor to the next node.
void AcNoteMng::retireActiveNote(AcActiveNote **pnode, uint32_t pos) {
    AcActiveNote *node = *pnode;
    AcActiveNote *next = node->next;
    if (node->tick + 4000u < pos) {
        if (m_autoPlay && (node->flags & AC_NOTE_FLAG_COUNT_GUARD) == 0) {
            node->flags |= AC_NOTE_FLAG_COUNTED;
            m_laneResult[node->lane].hits++;
        }
        retireNode(node);
    } else if (node->flags & AC_NOTE_FLAG_RETIRE) {
        retireNode(node);
    }
    *pnode = next;
}

// Ghidra: FUN_0007b1bc — refresh the per-lane "nearest note" candidate for
// input, and (in auto-play) auto-hit notes at/after their time, feeding the
// combo counter.
void AcNoteMng::updateNearest(AcActiveNote *node, uint32_t pos) {
    const uint16_t flags = node->flags;
    if ((flags & AC_NOTE_FLAG_COUNT_GUARD) != 0) {
        return;
    }
    const uint8_t lane = node->lane;
    if (lane >= 9) {
        return;
    }
    const int dt = static_cast<int>(pos) - static_cast<int>(node->tick);
    if (m_autoPlay && dt >= 0) {
        m_laneResult[lane].hits++;
        node->flags = static_cast<uint16_t>(flags | AC_NOTE_FLAG_COUNTED);
        const uint32_t combo = static_cast<uint32_t>(m_combo) + 1;
        m_combo = static_cast<int>(combo);
        if (static_cast<uint32_t>(m_maxCombo) < combo) {
            m_maxCombo = static_cast<int>(combo);
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
// slide off; clamp non-past notes at 0.  The `m_playSpeed` used in the manual
// non-auto slide (@ 0x7b2c0, vldr from +0xfa4c) is the front scroll segment's
// speed, i.e. m_scrollMap[0].speed.
void AcNoteMng::updateDrawPos(AcActiveNote *node, uint32_t pos) {
    const uint16_t flags = node->flags;
    if ((flags & AC_NOTE_FLAG_JUDGED) == 0 && node->lane < 9) {
        node->drawY = computeScrollY(node, pos);
    }
    if (node->tick < pos) {
        if ((flags & AC_NOTE_FLAG_JUDGED) == 0) {
            node->flags = static_cast<uint16_t>(flags | AC_NOTE_FLAG_JUDGED);
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
            accum += m_scrollMap[seg].speed * static_cast<float>(span);
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

    const uint32_t pos = static_cast<uint32_t>(getCurrentPosition());

    if (m_state != AC_NOTE_STATE_FINISHED) {
        spawnNotes(pos);
        AcActiveNote *node = m_activeHead;
        while (node != nullptr) {
            judgeActiveNote(node, pos);
            retireActiveNote(&node, pos); // advances `node` to the next active note
        }
        if (m_endFlag) {
            m_state = AC_NOTE_STATE_FINISHED;
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
            node->flags |= AC_NOTE_FLAG_HANDLED;
            m_endFlag = true;
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
    m_state = AC_NOTE_STATE_PLAYING;
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
    m_state = AC_NOTE_STATE_PLAYING;

    const uint32_t pos = static_cast<uint32_t>(getCurrentPosition());
    if (pos >= static_cast<uint32_t>(m_expectedTimeBase) && m_endFlag == 0) {
        AudioManager *am = [AudioManager sharedManager];
        float seconds = static_cast<float>(static_cast<int>(pos) - m_expectedTimeBase) /
                        1000.0f; // DAT_0007b78c = 1000.0
        [am setBgmCurrentTime:seconds];
        [[AudioManager sharedManager] playBgm:0];
        makeAdjustEvent(pos + 0x20);
    }
}

// Ghidra: acNoteResetPlayFlag @ 0x7aea4.
void AcNoteMng::resetPlayFlag() {
    m_playFlag = false;
}

// Ghidra: acNoteSetupLaneMapping @ 0x7ad14 — build the lane-remap table for the
// option. Modes 1 and 3 shuffle with the engine's Random (xorshift128) seeded
// from time(): the array is seeded to identity ONCE (@ 0x7adbe), then an outer
// pass loop runs a fixed 100000 times (@ 0x7ae3a). Each pass walks positions
// i = 0..8, at each doing a single Fisher-Yates swap of m_laneRemap[i] with
// m_laneRemap[i + rand(9 - i)] (@ 0x7ade2-0x7ae00) on the accumulating array,
// then inspecting it: while the array is still pure identity it advances to the
// next position (@ 0x7ae04), and once it is non-identity it also checks whether
// the array is exactly the mirror permutation (m_laneRemap[k] == 8 - k,
// @ 0x7ae14) — a pure-identity or pure-mirror array advances the position, while
// any other (the usual non-trivial) permutation ends the pass. There is no early
// success exit, so the loop always burns all 100000 passes and keeps whatever
// permutation the array holds at the end. Mode 2 is the mirror map; the default
// is identity.
void AcNoteMng::setupLaneMapping(int mode) {
    m_laneMode = mode;
    if (mode == 1 || mode == 3) {
        Random rng;
        rng.setSeed(static_cast<uint32_t>(time(nullptr)));

        // Identity seed, once, before the pass loop.
        for (int i = 0; i < 9; i++) {
            m_laneRemap[i] = i;
        }

        int attempt = 0;
        do {
            for (int i = 0; i < 9; i++) {
                const int j = i + rng.getRandRangeInt(9 - i);
                std::swap(m_laneRemap[i], m_laneRemap[j]);

                bool identity = true;
                for (int k = 0; k < 9; k++) {
                    if (m_laneRemap[k] != k) {
                        identity = false;
                        break;
                    }
                }
                if (identity) {
                    continue;
                }

                bool mirror = true;
                for (int k = 0; k < 9; k++) {
                    if (m_laneRemap[k] != 8 - k) {
                        mirror = false;
                        break;
                    }
                }
                if (mirror) {
                    continue;
                }

                // Non-identity, non-mirror permutation: end this pass.
                break;
            }
            attempt++;
        } while (attempt < 100000);
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
    return static_cast<int>(static_cast<int16_t>(total));
}

// Ghidra: acNoteGetJudgeTotal @ 0x7b908 — sum the whole 9x4 per-lane
// score/judge table (m_laneResult, stride 0x10) and return the low 16 bits. The
// table base is +0xfd5c; the .hits counter (written elsewhere @ +0xfd68) is the
// fourth int of each 0x10-byte lane record, so summing all four fields covers
// it. Order within the sum is irrelevant.
int AcNoteMng::getJudgeTotal() const {
    int total = 0;
    for (int lane = 0; lane < 9; lane++) {
        total += m_laneResult[lane]._unwritten[0];
        total += m_laneResult[lane]._unwritten[1];
        total += m_laneResult[lane]._unwritten[2];
        total += m_laneResult[lane].hits;
    }
    return static_cast<int>(static_cast<int16_t>(total));
}

// Ghidra: acNoteCountActiveNotes @ 0x7b93c — count on-screen notes (lane < 9)
// whose "handled" bit (0x20) is still clear.
int AcNoteMng::countActiveNotes() const {
    int count = 0;
    for (const AcActiveNote *node = m_activeHead; node != nullptr; node = node->next) {
        if (node->lane < 9 && (node->flags & AC_NOTE_FLAG_HANDLED) == 0) {
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
        if (node->lane < 9 && (node->flags & AC_NOTE_FLAG_HANDLED) == 0) {
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
        if (node->lane < 9 && (node->flags & AC_NOTE_FLAG_HANDLED) == 0) {
            if (seen == index) {
                node->flags |= flags;
                return;
            }
            seen++;
        }
    }
}
