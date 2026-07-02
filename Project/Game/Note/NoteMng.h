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

//  Chart-load flow: a %09d.orb / ac%09d.acv file (ZIP + BFCodec-encrypted "info")
//  is decoded into a MusicData object; the play loader picks the sheet for the
//  chosen difficulty (-[MusicData sheetNormal/sheetHyper/sheetEx]) and passes it
//  to -[NoteMng initPlayDataWithData:] on the global manager (Ghidra: DAT_00173ea4).
//

#pragma once

#include <cstdint>

#ifdef __OBJC__
@class NSData;
#endif

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

// Render kind, recomputed into a NoteRenderData by copyNoteRenderData (@ 0x34758):
// 1 for a special chart kind (6..9), 2 for a long/hold note (start < end), else 0.
enum NoteRenderKind : uint8_t {
    NOTE_RENDER_NORMAL = 0,
    NOTE_RENDER_SPECIAL = 1,
    NOTE_RENDER_LONG = 2,
};

// A live note object, pooled in the free/active singly-linked lists. 60 bytes,
// laid out from the decompiled slot (makeNote @ 0x341a4). makeNote fills the
// screen position from the chart record's lane/position bytes scaled by the live
// screen size; makeEvent (@ 0x343c8) spawns non-note events with kind 10.
struct ActiveNote {
    ActiveNote *next;       // +0x00  free/active list link
    const NoteRecord *rec;  // +0x04  source chart record
    uint32_t reserved08;    // +0x08
    uint32_t startTick;     // +0x0c
    uint32_t endTick;       // +0x10  == startTick for taps, later for holds
    float scaleX;           // +0x14  (default 1024.0)
    float scaleY;           // +0x18  (default 1024.0)
    uint8_t kind;           // +0x1c  note kind (>= 10 marks an event)
    uint8_t kindHi;         // +0x1d
    uint8_t reserved1e[2];  // +0x1e
    float x;                // +0x20  on-screen position
    float y;                // +0x24
    float x2;               // +0x28  hold-note end position
    float y2;               // +0x2c
    float targetX;          // +0x30  judge-line target
    float targetY;          // +0x34
    uint16_t flags;         // +0x38  bit 0x80 = judged / inactive
    uint8_t spawnKind;      // +0x3a  1..5 (from the type-6..9 table, else 1)
    uint8_t reserved3b;     // +0x3b
};
static_assert(sizeof(ActiveNote) == 60, "active note slot is 60 bytes");

// Per-note render descriptor the renderer receives from getNoteObject: a subset
// of ActiveNote (ticks, kind, scale, positions) plus the NoteRenderKind byte
// recomputed at copy time. Field offsets mirror the ActiveNote block above.
struct NoteRenderData;

// The note manager owns a large (~0x13cbc byte) play-data block. Only the pieces
// recovered so far are modelled; the rest of the block is opaque runtime state.
class NoteMng {
public:
    // Parse a decoded chart into the play-data timeline. `data` points at the
    // 4-byte header; `size` is the whole payload length. Ghidra: InitPlayData
    // @ 0x335a4 (asserts size validity at NoteMng.mm:0x45/0x59).
    int initPlayData(const void *data, int size, uint32_t arg4, uint32_t arg5);

#ifdef __OBJC__
    // Parse a chart straight from an NSData (bytes + length -> initPlayData); the
    // sheet the play loader selected for the difficulty. Ghidra: @ 0x33550.
    int initPlayDataWithData(NSData *data, uint32_t arg3, uint32_t arg4);
#endif

    // Walk the parsed records and register every tempo (type 2) event into the
    // tempo map, counting bar lines (type 4). Ghidra: @ 0x337e0.
    void registerTempoEvents();

    // Convert a chart position `tick` to elapsed milliseconds by accumulating
    // 60000/BPM across the tempo segments up to it. Ghidra: ChangeTempo @ 0x33864.
    void changeTempo(uint32_t tick);

    // Register one tempo segment (bpm, at tick) into the tempo map. Ghidra:
    // AdvanceRegisterEvent @ 0x34bf0.
    int advanceRegisterEvent(int bpm, uint32_t tick);

    // Spawn a live note from a chart record: take a free slot, copy the ticks,
    // compute the on-screen position, and move it to the active list. Ghidra:
    // MakeNote @ 0x341a4.
    void makeNote(const NoteRecord *rec);

    // Spawn a non-note event (kind 10) from a chart record. Ghidra: MakeEvent @ 0x343c8.
    void makeEvent(const NoteRecord *rec);

    // Fill `out` with the render data of the `index`-th still-judgeable active
    // note (kind < 10, not flagged 0x80). Ghidra: GetNoteObject @ 0x346c0, which
    // delegates the field copy to copyNoteRenderData (@ 0x34758).
    void getNoteObject(NoteRenderData *out, int index);
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
