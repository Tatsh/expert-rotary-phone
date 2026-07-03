//
//  neAVSePlayer.h
//  pop'n rhythmin
//
//  Sound-effect backend built on AVFoundation, used for the SE groups the low-latency
//  CoreAudio backend (neAVCAPlayer) does not serve. It owns a pool of AVBus voices (each
//  wrapping one AVAudioPlayer) and a table of loaded sources; a play handle packs the voice
//  index and a per-voice generation so a stale handle can't restart a recycled voice.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (FUN_00020xxx / FUN_00021xxx;
//  the "audioMixer" of AVBus voices at +0x0, the source table at +0x8).
//

#pragma once

#include <cstdint>

#import <Foundation/Foundation.h>

// 0x10000000 marks an AVFoundation instance in a play handle (cf. neAVCAPlayer).
constexpr uint32_t kAVSePlayerHandleFlag = 0x10000000;

class neAVSePlayer {
public:
    // Tear down the AVFoundation SE engine: drop the source table, the name map and the AVBus
    // voice pool. Ghidra: audioMixerDtor @ 0x212a0.
    ~neAVSePlayer();

    // Load a URL into a new source slot; returns its index, or -1 on failure. Ghidra:
    // registerSound @ 0x212d0.
    int load(NSURL *url, bool loop);

    // As load(), but also register a call-name for later lookup. Ghidra: registerSoundNamed
    // @ 0x21328.
    int loadNamed(NSURL *url, NSString *callName, bool loop);

    // Start the AVFoundation SE pool with `voices` AVBus voices. Ghidra: soundEngine_ctor
    // @ 0x2120c (which calls audioMixerInit @ 0x20d1c).
    void systemStart(int voices);

    // Reserve a playing instance for a loaded source (by id or call name) at the given volume;
    // returns the play handle, or -1/0 on failure. Ghidra: playSoundByIndex @ 0x21438 /
    // playSoundNamed @ 0x21464 (both delegate the voice grab to audioPlaySource @ 0x20ed8).
    uint32_t prepare(uint32_t sourceId, float volume);
    uint32_t prepareNamed(NSString *callName, float volume);

    // Start / stop / pause the voice named by `handle`. Ghidra: audioHandlePlay @ 0x214a8 /
    // audioHandleStop @ 0x214c0 / audioHandlePause @ 0x214d8.
    bool play(uint32_t handle);
    bool stop(uint32_t handle);
    bool pause(uint32_t handle);

    // Stop the voice named by `handle` and detach its source so the voice is immediately free.
    // Ghidra: audioHandleStopAndRemove @ 0x21588.
    void stopAndRemove(uint32_t handle);

    // The voice's AVBus status (-1 none / 1 prepared / 2 playing / 3 paused / 4 stopped), or
    // -1 for a stale handle. Ghidra: audioHandleGetStatus @ 0x214f0.
    int voiceState(uint32_t handle);

    // Unload a loaded source (by id or call name): detach it from every voice, then free it.
    // Ghidra: unregisterSound @ 0x213d4 / unregisterSoundNamed @ 0x213fc.
    void unregisterSource(uint32_t sourceId);
    void unregisterSourceNamed(NSString *callName);

    // Set the volume (0..1) of every voice in the pool.
    void setGroupVolume(float volume);

    // AudioSession interruption handling. Ghidra: audioPauseAll @ 0x21288 (pause every voice) /
    // audioResumeAll @ 0x21294 (offPause every voice).
    void suspend();
    void resume();

private:
    int addSource(NSURL *url, bool loop);   // first free slot, growing the table (allocSoundSlot)

    // The AVBus voice pool (Ghidra: the "audioMixer" object at +0x0, its voice array at +0x8).
    NSMutableArray *m_buses = nil;          // AVBus voices
    int m_voiceCount = 0;                   // mixer +0x4
    NSMutableDictionary *m_nameMap = nil;   // +0x04  call name -> source id
    NSMutableArray *m_sources = nil;        // +0x08  loaded sources (NSNull = free slot)
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
