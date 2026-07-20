/** @file
 * Low-latency sound-effect backend built on CoreAudio (the caplayer / lib_rsnd layer described in
 * the bundle's readme.txt). It owns a pool of CASound slots; a play handle packs the slot index and
 * a generation counter so a stale handle cannot restart a recycled slot.
 */

#pragma once

#include <cstdint>

#import <Foundation/Foundation.h>

class CAComponent;
class CASound;

/**
 * @brief Handle bit that marks a CoreAudio (caplayer) instance.
 * @details The handle layout is shared with AudioManager: the low 28 bits hold
 * `(slot << 16) | generation`, and this bit distinguishes a caplayer handle from other backends.
 */
constexpr uint32_t kCAPlayerHandleFlag = 0x20000000;

/**
 * @brief Low-latency CoreAudio sound-effect backend (the caplayer / lib_rsnd layer).
 *
 * Owns a pool of CASound slots; a play handle packs the slot index and a generation counter so a
 * stale handle cannot restart a recycled slot.
 */
class neAVCAPlayer {
public:
    /**
     * @brief Tear down the CoreAudio SE engine.
     * @details Terminates and deletes the mixer, frees every loaded CASound, and drops the source
     * array and the name map.
     * @ghidraAddress 0x261f8
     */
    ~neAVCAPlayer();

    /**
     * @brief Load a file into a new CASound slot.
     * @param path Path to the sound file to load.
     * @param loop Whether the loaded source should loop on playback.
     * @return The new source id, or 0xffffffff on failure.
     * @ghidraAddress 0x26320
     */
    uint32_t load(const char *path, bool loop);

    /**
     * @brief Load a file into a new CASound slot and register a call-name for later lookup.
     * @param path Path to the sound file to load.
     * @param callName Name under which the source can be looked up.
     * @param loop Whether the loaded source should loop on playback.
     * @return The new source id, or 0xffffffff on failure.
     * @ghidraAddress 0x2648c
     */
    uint32_t loadNamed(const char *path, const char *callName, bool loop);

    /**
     * @brief Start CoreAudio with the given number of concurrent channels.
     * @param voices Number of concurrent voices to allocate.
     * @ghidraAddress 0x2615c
     */
    void systemStart(int voices);

    /**
     * @brief Reserve a playing instance for a loaded source by id at the given volume.
     * @param sourceId Id of the loaded source to reserve.
     * @param volume Playback volume for the reserved instance.
     * @return The play handle, or -1 on failure.
     * @ghidraAddress 0x2669c
     */
    uint32_t prepare(uint32_t sourceId, float volume);

    /**
     * @brief Reserve a playing instance for a loaded source by call name at the given volume.
     * @param callName Call name of the loaded source to reserve.
     * @param volume Playback volume for the reserved instance.
     * @return The play handle, or -1 on failure.
     * @ghidraAddress 0x266f8
     */
    uint32_t prepareNamed(const char *callName, float volume);

    /**
     * @brief Reserve a playing instance for a loaded source id targeting a fixed voice index.
     * @details Used by AudioManager's SetGroup pool, which owns each caplayer voice permanently.
     * @param sourceId Id of the loaded source to reserve.
     * @param voiceIndex Fixed mixer voice index to target.
     * @return The play handle, or -1 on failure.
     * @ghidraAddress 0x266c0
     */
    uint32_t prepareAtVoice(uint32_t sourceId, int voiceIndex);

    /**
     * @brief Reserve a playing instance for a loaded source by call name targeting a fixed voice.
     * @details Used by AudioManager's SetGroup pool, which owns each caplayer voice permanently.
     * @param callName Call name of the loaded source to reserve.
     * @param voiceIndex Fixed mixer voice index to target.
     * @return The play handle, or -1 on failure.
     * @ghidraAddress 0x2673c
     */
    uint32_t prepareNamedAtVoice(NSString *callName, int voiceIndex);

    /**
     * @brief Start the sound referenced by a handle.
     * @details The slot generation must still match for playback to begin.
     * @param handle Play handle previously returned by a prepare call.
     * @return True if the voice started playing, false otherwise.
     * @ghidraAddress 0x26784
     */
    bool play(uint32_t handle);

    /**
     * @brief Stop the voice named by a handle.
     * @param handle Play handle previously returned by a prepare call.
     * @return True if the voice was stopped, false otherwise.
     * @ghidraAddress 0x2679c
     */
    bool stop(uint32_t handle);

    /**
     * @brief Pause the voice named by a handle.
     * @details Resume the paused voice via play().
     * @param handle Play handle previously returned by a prepare call.
     * @return True if the voice was paused, false otherwise.
     * @ghidraAddress 0x267b4
     */
    bool pause(uint32_t handle);

    /**
     * @brief Stop the voice named by a handle and drop its source so the mixer can recycle it.
     * @details Used when reaping a finished SetGroup voice, freeing the slot immediately.
     * @param handle Play handle previously returned by a prepare call.
     * @ghidraAddress 0x26864
     */
    void stopAndClear(uint32_t handle);

    /**
     * @brief Query the state of the voice named by a handle.
     * @param handle Play handle previously returned by a prepare call.
     * @return The voice state: -1 free, 1 playing, or 4 finished.
     * @ghidraAddress 0x267cc
     */
    int voiceState(uint32_t handle);

    /**
     * @brief Unload a loaded source by id, freeing its CASound slot.
     * @param sourceId Id of the loaded source to unload.
     * @ghidraAddress 0x26610
     */
    void unregisterSource(uint32_t sourceId);

    /**
     * @brief Unload a loaded source by call name, freeing its CASound slot.
     * @param callName Call name of the loaded source to unload.
     * @ghidraAddress 0x26644
     */
    void unregisterSourceNamed(NSString *callName);

    /**
     * @brief Set the gain of every voice.
     * @param level Volume level in the range 0 to 127.
     * @ghidraAddress 0x267e4
     */
    void setAllVoiceVolume(int level);

    /**
     * @brief Handle an AudioSession interruption by stopping the mixer.
     * @ghidraAddress 0x261e0
     */
    void suspend();

    /**
     * @brief Resume from an AudioSession interruption by restarting the mixer.
     * @ghidraAddress 0x261ec
     */
    void resume();

private:
    uint32_t addSource(CASound *source); // first free slot, growing the array

    CAComponent *m_component = nullptr;   // +0x00  the AUGraph mixer
    NSMutableDictionary *m_nameMap = nil; // +0x04  call name -> source id
    CASound **m_sources = nullptr;        // +0x08  loaded sources
    int m_capacity = 0;                   // +0x0c
};

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
