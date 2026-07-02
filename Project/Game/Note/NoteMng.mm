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
    m_tempoCount = 0;
    m_currentMs = 0;
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

// Ghidra: AdvanceRegisterEvent @ 0x34bf0. Append a tempo segment.
int NoteMng::advanceRegisterEvent(int bpm, uint32_t tick) {
    if (m_tempoCount >= (int)(sizeof(m_tempoMap) / sizeof(m_tempoMap[0]))) {
        return 1;   // overflow -> assert at the call site
    }
    TempoSegment &seg = m_tempoMap[m_tempoCount++];
    seg.startTick = tick;
    seg.bpm = (int16_t)bpm;
    // startMs is filled cumulatively by changeTempo as it walks the segments.
    seg.startMs = 0;
    return 0;
}

// Ghidra: ChangeTempo @ 0x33864. Advance the current-time base up to chart
// position `tick` by accumulating 60000/BPM across the tempo segments.
void NoteMng::changeTempo(uint32_t tick) {
    int ms = 0;
    int seg = 0;
    for (int step = 0; step < 8 && seg + 1 < m_tempoCount; step++) {
        int bpm = m_tempoMap[seg].bpm;
        if (bpm != 0) {
            ms += 60000 / bpm;
        }
        if (m_tempoMap[seg + 1].startTick <= ms + tick) {
            seg++;
        }
    }
    m_currentMs = ms;
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
                    tier = NOTE_JUDGE_COOL; note->flags |= 8;
                    m_combo = 0;
                    countsCombo = false;
                } else {
                    tier = NOTE_JUDGE_GREAT; note->flags |= 1;
                }
            } else {
                // Central band: within ~50 ms is the tightest tier.
                if ((unsigned)(delta + 50) < 101) {
                    tier = NOTE_JUDGE_BAD; note->flags |= 4;
                } else {
                    tier = NOTE_JUDGE_GOOD; note->flags |= 2;
                }
            }
        } else {
            tier = NOTE_JUDGE_GREAT; note->flags |= 1;
        }
        if (countsCombo && !(note->startTick < note->endTick) && !special) {
            m_combo++;
            if (m_combo > m_maxCombo) m_maxCombo = m_combo;
        }
    } else {
        tier = NOTE_JUDGE_COOL; note->flags |= 8;
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
