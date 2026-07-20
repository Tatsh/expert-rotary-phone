/** @file
 * Sound-effect backend built on AVFoundation, used for the SE groups the low-latency CoreAudio
 * backend (neAVCAPlayer) does not serve. It owns a pool of AVBus voices (each wrapping one
 * AVAudioPlayer) and a table of loaded sources; a play handle packs the voice index and a per-voice
 * generation so a stale handle cannot restart a recycled voice.
 */

#pragma once

#include <cstdint>

#import <Foundation/Foundation.h>

@class AVBus;

/** Marks an AVFoundation instance in a play handle (compare neAVCAPlayer). */
constexpr uint32_t kAVSePlayerHandleFlag = 0x10000000;

/**
 * @brief AVFoundation sound-effect backend for the SE groups the CoreAudio backend does not serve.
 *
 * Owns a pool of AVBus voices and a table of loaded sources; a play handle packs the voice index
 * and a per-voice generation so a stale handle cannot restart a recycled voice.
 */
class neAVSePlayer {
public:
    /**
     * Tear down the AVFoundation SE engine: drop the source table, the name map, and the AVBus
     * voice pool.
     * @ghidraAddress 0x212a0
     */
    ~neAVSePlayer();

    /**
     * Load a URL into a new source slot.
     * @param url The audio file URL to load as a source.
     * @param loop Whether the source should loop when played.
     * @return The new source index, or -1 on failure.
     * @ghidraAddress 0x212d0
     */
    int load(NSURL *url, bool loop);

    /**
     * As load(), but also register a call-name for later lookup by name.
     * @param url The audio file URL to load as a source.
     * @param callName The name under which the source may later be looked up.
     * @param loop Whether the source should loop when played.
     * @return The new source index, or -1 on failure.
     * @ghidraAddress 0x21328
     */
    int loadNamed(NSURL *url, NSString *callName, bool loop);

    /**
     * Start the AVFoundation SE pool with the given number of AVBus voices, and build the empty
     * source table and call-name map.
     * @param voices The number of AVBus voices to allocate in the pool.
     * @ghidraAddress 0x2120c
     */
    void systemStart(int voices);

    /**
     * Reserve a playing instance for a loaded source identified by id, at the given volume.
     * @param sourceId The index of the loaded source to play.
     * @param volume The playback volume as a level from 0 to 127.
     * @return The play handle, or -1/0 on failure.
     * @ghidraAddress 0x21438
     */
    uint32_t prepare(uint32_t sourceId, float volume);

    /**
     * Reserve a playing instance for a loaded source identified by call name, at the given volume.
     * @param callName The registered name of the loaded source to play.
     * @param volume The playback volume as a level from 0 to 127.
     * @return The play handle, or -1/0 on failure.
     * @ghidraAddress 0x21464
     */
    uint32_t prepareNamed(NSString *callName, float volume);

    /**
     * Start the voice named by the handle.
     * @param handle The play handle identifying the voice.
     * @return True if the handle resolved to a live voice, otherwise false.
     * @ghidraAddress 0x214a8
     */
    bool play(uint32_t handle);

    /**
     * Stop the voice named by the handle.
     * @param handle The play handle identifying the voice.
     * @return True if the handle resolved to a live voice, otherwise false.
     * @ghidraAddress 0x214c0
     */
    bool stop(uint32_t handle);

    /**
     * Pause the voice named by the handle.
     * @param handle The play handle identifying the voice.
     * @return True if the handle resolved to a live voice, otherwise false.
     * @ghidraAddress 0x214d8
     */
    bool pause(uint32_t handle);

    /**
     * Stop the voice named by the handle and detach its source so the voice is immediately free.
     * @param handle The play handle identifying the voice.
     * @ghidraAddress 0x21588
     */
    void stopAndRemove(uint32_t handle);

    /**
     * Report the voice's AVBus status (-1 none, 1 prepared, 2 playing, 3 paused, 4 stopped).
     * @param handle The play handle identifying the voice.
     * @return The voice's AVBus status, or -1 for a stale handle.
     * @ghidraAddress 0x214f0
     */
    int voiceState(uint32_t handle);

    /**
     * Unload a loaded source identified by id: detach it from every voice, then free it.
     * @param sourceId The index of the loaded source to unload.
     * @ghidraAddress 0x213d4
     */
    void unregisterSource(uint32_t sourceId);

    /**
     * Unload a loaded source identified by call name: detach it from every voice, then free it.
     * @param callName The registered name of the loaded source to unload.
     * @ghidraAddress 0x213fc
     */
    void unregisterSourceNamed(NSString *callName);

    /**
     * Set the volume of every voice in the pool from an integer level 0 to 127; the method converts
     * the level to a 0 to 1 gain internally before applying it per player.
     * @param level The group volume level from 0 to 127.
     * @ghidraAddress 0x2108c
     */
    void setGroupVolume(int level);

    /**
     * Handle an AudioSession interruption by pausing every voice.
     * @ghidraAddress 0x21288
     */
    void suspend();

    /**
     * Handle the end of an AudioSession interruption by resuming every paused voice.
     * @ghidraAddress 0x21294
     */
    void resume();

private:
    int addSource(NSURL *url,
                  bool loop); // build a descriptor (soundSourceInit) into a free slot

    // Reserve the first free source slot, growing the table when it is full.
    // Ghidra: allocSoundSlot
    // @ 0x21510.
    int allocSoundSlot();

    // Resolve a (voice << 16 | generation) play handle to its live AVBus voice,
    // or nil for a stale handle. Ghidra: getAudioBusForHandle @ 0x20fd8.
    AVBus *busForHandle(uint32_t handle);

    // The AVBus voice pool (Ghidra: the "audioMixer" object at +0x0, its voice
    // array at +0x8).
    NSMutableArray *m_buses = nil;        // AVBus voices
    int m_voiceCount = 0;                 // mixer +0x4
    NSMutableDictionary *m_nameMap = nil; // +0x04  call name -> source id
    NSMutableArray *m_sources = nil;      // +0x08  loaded sources (NSNull = free slot)
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
