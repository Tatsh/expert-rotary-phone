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
enum AcNoteType : uint8_t {
    AC_NOTE_TAP = 1,     // playable note (counted per lane)
    AC_NOTE_END = 3,     // end-of-chart marker
    AC_NOTE_TEMPO = 4,   // tempo/BPM event (min/max tracked)
    AC_NOTE_EVENT = 6,   // stored as the last event value
};

// One 8-byte arcade chart record.
struct AcNoteRecord {
    uint32_t tick;      // +0x0  timing position
    uint8_t  type;      // +0x4  AcNoteType
    uint8_t  reserved5; // +0x5
    uint16_t value;     // +0x6  lane (low nibble) / BPM
};
static_assert(sizeof(AcNoteRecord) == 8, "arcade note record is 8 bytes");

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
    // FUN_0007aa90 / FUN_0007aaf8.
    void registerTempoEvents();
    void changeTempo(uint32_t tick);

private:
    struct TempoSegment { uint32_t startTick; uint32_t startMs; int16_t bpm; };

    // Parsed chart.
    AcNoteRecord *m_records = nullptr;
    int m_recordCount = 0;
    uint16_t m_minTempoValue = 0x7fff;
    uint16_t m_maxTempoValue = 0;
    uint32_t m_endValue = 0;
    int16_t m_laneCounts[kAcLaneCount] = {};

    // Play state.
    float m_hiSpeed = 1.0f;              // +0x14cc4
    TempoSegment m_tempoMap[512] = {};
    int m_tempoCount = 0;
    uint32_t m_currentMs = 0;

    // Timing windows (Ghidra: copied from DAT_0012f868).
    int m_judgeWindows[6] = {};

    // Scoring.
    int m_combo = 0;
    int m_maxCombo = 0;
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
