//
//  neAVSePlayer.h
//  pop'n rhythmin
//
//  Sound-effect backend built on AVFoundation (AVAudioPlayer), used for the SE
//  groups the low-latency CoreAudio backend (neAVCAPlayer) does not serve. It
//  keeps a pool of AVAudioPlayer instances indexed by a play handle. Reconstructed
//  from Ghidra project rb420, program PopnRhythmin (FUN_00021xxx).
//

#pragma once

#include <cstdint>

#import <Foundation/Foundation.h>

// 0x10000000 marks an AVFoundation instance in a play handle (cf. neAVCAPlayer).
constexpr uint32_t kAVSePlayerHandleFlag = 0x10000000;

class neAVSePlayer {
public:
    // Load a URL into a new AVAudioPlayer slot; returns its index, or -1 on
    // failure. Ghidra: FUN_000212d0.
    int load(NSURL *url, bool loop);

    // As load(), but also register a call-name for later lookup. Ghidra: FUN_00021328.
    int loadNamed(NSURL *url, NSString *callName, bool loop);

    // Start the AVFoundation SE pool with `voices` concurrent players. Ghidra:
    // FUN_0002120c.
    void systemStart(int voices);

    // Reserve a playing instance for a loaded source (by id or call name) at the
    // given volume; returns the play handle, or -1 on failure. Ghidra: by-id
    // FUN_00021438 / by-name FUN_00021464.
    uint32_t prepare(uint32_t sourceId, float volume);
    uint32_t prepareNamed(NSString *callName, float volume);

    // Start the AVAudioPlayer referenced by `handle`. Ghidra: FUN_000214a8.
    bool play(uint32_t handle);

    // Stop the voice named by `handle`. Ghidra: FUN_000214c0.
    bool stop(uint32_t handle);

    // The voice's state (-1 free/idle, 1 playing). Ghidra: FUN_000214f0.
    int voiceState(uint32_t handle);

    // Set the volume (0..1) of every voice in the pool.
    void setGroupVolume(float volume);

    // AudioSession interruption handling. Ghidra: suspend FUN_00021288 /
    // resume FUN_00021294.
    void suspend();
    void resume();

private:
    int addSource(NSURL *url, bool loop);   // first free slot, growing the pool

    NSMutableArray *m_voices = nil;       // +0x08  AVAudioPlayer voice pool
    NSMutableDictionary *m_nameMap = nil; // +0x04  call name -> source id
    NSMutableArray *m_sources = nil;      // loaded source URLs
    int m_capacity = 0;                   // +0x0c
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
