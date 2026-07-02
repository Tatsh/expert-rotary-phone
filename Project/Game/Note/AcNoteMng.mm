//
//  AcNoteMng.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The arcade note
//  manager: parses an arcade chart and builds the play timeline. Parallels
//  NoteMng but with 8-byte records and a difficulty-selected hi-speed.
//  Ghidra: InitPlayData FUN_0007a774, registerTempoEvents FUN_0007aa90,
//  changeTempo FUN_0007aaf8.
//

#include <cassert>
#include <cstring>

#import <Foundation/Foundation.h>

#import "AcNoteMng.h"

// Hi-speed multiplier per difficulty (Ghidra: the switch in InitPlayData).
static const float kAcHiSpeed[kAcHiSpeedCount] = {
    1.2f, 1.5f, 2.0f, 2.5f, 3.0f, 3.5f, 4.0f, 4.5f, 5.0f, 5.5f, 6.0f,
};

// Ghidra: FUN_0007a774. `data` points at the 8-byte header (magic 'E' at +4).
int AcNoteMng::initPlayData(const void *data, int size, int difficulty) {
    assert(data != nullptr && size > 0);   // AcNoteMng.mm:0x59

    m_recordCount = 0;
    m_minTempoValue = 0x7fff;
    m_maxTempoValue = 0;
    m_endValue = 0;
    m_tempoCount = 0;
    m_currentMs = 0;
    m_combo = 0;
    m_maxCombo = 0;
    std::memset(m_laneCounts, 0, sizeof(m_laneCounts));

    if (difficulty >= 0 && difficulty < kAcHiSpeedCount) {
        m_hiSpeed = kAcHiSpeed[difficulty];
    }

    const uint8_t *bytes = static_cast<const uint8_t *>(data);
    // Magic: byte at +4 must be 'E' (arcade chart tag), else reject.
    if (bytes[4] != 'E') {
        return -3;
    }

    const int count = (size / 8) - 2;
    assert(count >= 0 && (unsigned)count < 7999);   // AcNoteMng.mm:0x69
    const AcNoteRecord *src = reinterpret_cast<const AcNoteRecord *>(bytes);

    m_records = new AcNoteRecord[count + 1];
    for (int i = 0; i < count; i++) {
        m_records[i] = src[i];
        switch (m_records[i].type) {
            case AC_NOTE_TAP:
                m_laneCounts[m_records[i].value & 0xf]++;
                break;
            case AC_NOTE_END:
                m_endValue = m_records[i].tick;
                break;
            case AC_NOTE_TEMPO:
                if (m_records[i].value > m_maxTempoValue) m_maxTempoValue = m_records[i].value;
                if (m_records[i].value < m_minTempoValue) m_minTempoValue = m_records[i].value;
                break;
            default:
                break;
        }
    }
    // Append the terminator (type 6/end) copied from the last record.
    m_records[count] = m_records[count > 0 ? count - 1 : 0];
    m_records[count].type = AC_NOTE_END;
    m_records[count].value = 0;
    m_recordCount = count;

    // Judge windows (Ghidra: DAT_0012f868).
    static const int kAcJudgeWindows[6] = { -250, -250, -80, 120, 250, 250 };
    std::memcpy(m_judgeWindows, kAcJudgeWindows, sizeof(m_judgeWindows));

    registerTempoEvents();
    changeTempo(0);
    return 0;
}

int AcNoteMng::initPlayDataWithData(NSData *data, int difficulty) {
    return initPlayData(data.bytes, (int)data.length, difficulty);
}

// Ghidra: FUN_0007aa90 — register every tempo (type 4) event; stop at the end.
void AcNoteMng::registerTempoEvents() {
    for (int i = 0; i < m_recordCount; i++) {
        const AcNoteRecord &r = m_records[i];
        if (r.type == AC_NOTE_END) {
            return;
        }
        if (r.type == AC_NOTE_TEMPO) {
            if (m_tempoCount < (int)(sizeof(m_tempoMap) / sizeof(m_tempoMap[0]))) {
                TempoSegment &seg = m_tempoMap[m_tempoCount++];
                seg.startTick = r.tick;
                seg.bpm = (int16_t)r.value;
                seg.startMs = 0;
            }
        }
    }
}

// Ghidra: FUN_0007aaf8 — advance the time base to `tick` via 60000/BPM.
void AcNoteMng::changeTempo(uint32_t tick) {
    int ms = 0;
    int seg = 0;
    for (int step = 0; step < 8 && seg + 1 < m_tempoCount; step++) {
        int bpm = m_tempoMap[seg].bpm;
        if (bpm != 0) {
            ms += 60000 / bpm;
        }
        if (m_tempoMap[seg + 1].startTick <= ms + (int)tick) {
            seg++;
        }
    }
    m_currentMs = (uint32_t)ms;
}
