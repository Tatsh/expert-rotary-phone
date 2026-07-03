//
//  neAVCAPlayer.h
//  pop'n rhythmin
//
//  Low-latency sound-effect backend built on CoreAudio (the caplayer / lib_rsnd
//  layer described in the bundle's readme.txt). It owns a pool of CASound slots;
//  a play handle packs the slot index and a generation counter so a stale handle
//  can't restart a recycled slot. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin (Project/System/src/Sound region, FUN_00026xxx).
//

#pragma once

#include <cstdint>

#import <Foundation/Foundation.h>

class CAComponent;
class CASound;

// Handle bit layout (shared with AudioManager): low 28 bits = (slot << 16) |
// generation; 0x20000000 marks a CoreAudio (caplayer) instance.
constexpr uint32_t kCAPlayerHandleFlag = 0x20000000;

class neAVCAPlayer {
public:
    // Load a file into a new CASound slot; returns a source id, or 0xffffffff on
    // failure. Ghidra: FUN_00026320.
    uint32_t load(const char *path, bool loop);

    // As load(), but also register a call-name for later lookup. Ghidra: FUN_0002648c.
    uint32_t loadNamed(const char *path, const char *callName, bool loop);

    // Start CoreAudio with `voices` concurrent channels. Ghidra: FUN_0002615c.
    void systemStart(int voices);

    // Reserve a playing instance for a loaded source (by id or call name) at the
    // given volume; returns the play handle, or -1 on failure. Ghidra: by-id
    // FUN_0002669c / by-name FUN_000266f8.
    uint32_t prepare(uint32_t sourceId, float volume);
    uint32_t prepareNamed(const char *callName, float volume);

    // Reserve a playing instance targeting a *fixed* voice index (used by
    // AudioManager's SetGroup pool, which owns each caplayer voice permanently),
    // by source id or by call name. Returns the play handle, or -1 on failure.
    // Ghidra: caPrepareSourceByIndex / caPrepareSourceNamed.
    uint32_t prepareAtVoice(uint32_t sourceId, int voiceIndex);
    uint32_t prepareNamedAtVoice(NSString *callName, int voiceIndex);

    // Start the sound referenced by `handle` (slot generation must still match).
    // Ghidra: FUN_00026784.
    bool play(uint32_t handle);

    // Stop the voice named by `handle`. Ghidra: FUN_0002679c.
    bool stop(uint32_t handle);

    // Pause the voice named by `handle` (resume via play()). Ghidra: caHandlePause.
    bool pause(uint32_t handle);

    // The voice's state (-1 free / 1 playing / 4 finished). Ghidra: FUN_000267cc.
    int voiceState(uint32_t handle);

    // Unload a loaded source (by id or call name), freeing its CASound slot.
    // Ghidra: caUnregisterSource / caUnregisterSourceNamed.
    void unregisterSource(uint32_t sourceId);
    void unregisterSourceNamed(NSString *callName);

    // Set the gain (volume level 0..127) of every voice. Ghidra: FUN_000267e4.
    void setAllVoiceVolume(int level);

    // AudioSession interruption handling. Ghidra: suspend FUN_000261e0 /
    // resume FUN_000261ec.
    void suspend();
    void resume();

private:
    uint32_t addSource(CASound *source);   // first free slot, growing the array

    CAComponent *m_component = nullptr;     // +0x00  the AUGraph mixer
    NSMutableDictionary *m_nameMap = nil;   // +0x04  call name -> source id
    CASound **m_sources = nullptr;          // +0x08  loaded sources
    int m_capacity = 0;                     // +0x0c
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
