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

#pragma once

#include <cstdint>

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

// The note manager owns a large (~0x13cbc byte) play-data block. Only the pieces
// recovered so far are modelled; the rest of the block is opaque runtime state.
class NoteMng {
public:
    // Parse a decoded chart into the play-data timeline. `data` points at the
    // 4-byte header; `size` is the whole payload length. Ghidra: InitPlayData
    // @ 0x335a4 (asserts size validity at NoteMng.mm:0x45/0x59).
    int initPlayData(const void *data, int size, uint32_t arg4, uint32_t arg5);

    // Walk the parsed records and register every tempo (type 2) event into the
    // tempo map, counting bar lines (type 4). Ghidra: @ 0x337e0.
    void registerTempoEvents();

    // Convert a chart position `tick` to elapsed milliseconds by accumulating
    // 60000/BPM across the tempo segments up to it. Ghidra: ChangeTempo @ 0x33864.
    void changeTempo(uint32_t tick);

    // Register one tempo segment (bpm, at tick) into the tempo map. Ghidra:
    // AdvanceRegisterEvent @ 0x34bf0.
    int advanceRegisterEvent(int bpm, uint32_t tick);
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
