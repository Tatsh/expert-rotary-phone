/** @file
 * The low-latency SE mixer: an AUGraph of a 3D-mixer AudioUnit feeding a RemoteIO output. Each
 * mixer input ("voice") streams one CASound's PCM through a render callback. This is the
 * lib_rsnd / caplayer engine, reconstructed rather than imported.
 */

#pragma once

#include <memory>
#include <vector>

#import <AudioToolbox/AudioToolbox.h>

class CASound;

/**
 * @brief The low-latency SE mixer: an AUGraph of a 3D-mixer AudioUnit feeding a RemoteIO output.
 *
 * Each mixer input ("voice") streams one CASound's PCM through a render callback. This is the
 * lib_rsnd / caplayer engine, reconstructed rather than imported.
 */
class CAComponent {
public:
    /**
     * @brief Build the AUGraph and, if that succeeds, size and initialise the mixer.
     * @param voices Number of mixer inputs (voices) to allocate.
     */
    explicit CAComponent(int voices);

    /**
     * @brief Tear the AUGraph down and free the voice pool via terminate().
     */
    ~CAComponent();

    /**
     * @brief Start the graph and unmute it.
     * @ghidraAddress 0x23ccc
     */
    void start();

    /**
     * @brief Stop the graph.
     * @ghidraAddress 0x23d0c
     */
    void stop();

    /**
     * @brief Report whether the graph is currently running.
     * @return True while the graph is started, false otherwise.
     */
    bool isRunning() const {
        return m_running;
    }

    /**
     * @brief Reserve a free voice for a source, wire it up, and return its play handle.
     * @details Finds a voice in the free (state -1) or finished (state 4) state, wires its stream
     * format and render callback, and returns the play handle (generation | voice << 16), or
     * 0xffffffff when the mixer is full.
     * @param source The sound whose PCM the reserved voice will stream.
     * @param volumeIndex Index into the volume-level table for the voice's initial gain.
     * @return The packed play handle, or 0xffffffff when no voice is free.
     * @ghidraAddress 0x23f08
     */
    uint32_t reserveVoice(CASound *source, int volumeIndex);

    /**
     * @brief Set a voice's mixer gain from the volume-level table.
     * @param volumeIndex Index into the volume-level table.
     * @param voice The voice to set the gain for.
     * @return True on success, false when the voice index is out of range or the set fails.
     * @ghidraAddress 0x23eb0
     */
    bool setPlayerVolume(int volumeIndex, int voice);

    /**
     * @brief Resume or start a voice named by a raw packed play handle.
     * @details Extracts voice = handle >> 16, bounds-checks it, and verifies
     * generation = handle & 0xffff against the voice's stored generation so a stale handle is
     * rejected. Moves a prepared (1) or paused (3) voice to playing (2).
     * @param handle The raw packed play handle (voice << 16 | generation).
     * @return True when the voice was moved to playing, false for a stale or ineligible handle.
     * @ghidraAddress 0x23f5c
     */
    bool startVoice(int handle);

    /**
     * @brief Stop a voice named by a raw packed play handle, marking it finished (4).
     * @details Extracts voice = handle >> 16, bounds-checks it, and verifies
     * generation = handle & 0xffff against the voice's stored generation so a stale handle is
     * rejected.
     * @param handle The raw packed play handle (voice << 16 | generation).
     * @return True when the voice was marked finished, false for a stale or out-of-range handle.
     * @ghidraAddress 0x23f90
     */
    bool stopVoice(int handle);

    /**
     * @brief Query the state of a voice named by a raw packed play handle.
     * @details Extracts voice = handle >> 16, bounds-checks it, and verifies
     * generation = handle & 0xffff against the voice's stored generation so a stale handle is
     * rejected.
     * @param handle The raw packed play handle (voice << 16 | generation).
     * @return The voice state, or -1 for an out-of-range or stale handle.
     * @ghidraAddress 0x23fe8
     */
    int voiceState(int handle) const;

    /**
     * @brief Set the mixer's master gain from the volume-level table.
     * @details Forwards to setPlayerVolume(volumeIndex, 0), which writes the master output-scope
     * gain.
     * @param volumeIndex Index into the volume-level table.
     * @ghidraAddress 0x267e4
     */
    void setAllVolume(int volumeIndex);

    /**
     * @brief Detach a source from any voice still referencing it.
     * @details Called when the source is unloaded so no voice keeps a dangling back-pointer.
     * @param source The sound to detach from the voices.
     * @ghidraAddress 0x24014
     */
    void clearSourceRef(CASound *source);

    /**
     * @brief Pause a voice named by a raw packed play handle, setting state 3.
     * @details Extracts voice = handle >> 16 and generation = handle & 0xffff; a stale handle is
     * ignored.
     * @param handle The raw packed play handle (voice << 16 | generation).
     * @return True when the voice was paused, false for a stale or out-of-range handle.
     * @ghidraAddress 0x23fbc
     */
    bool pauseVoice(int handle);

    /**
     * @brief Stop and clear a voice named by a raw packed play handle.
     * @details Frees the voice (state 4 and drops the source) so reserveVoice can recycle it.
     * Extracts voice = handle >> 16 and generation = handle & 0xffff; a stale handle is ignored.
     * @param handle The raw packed play handle (voice << 16 | generation).
     * @ghidraAddress 0x2406c
     */
    void stopAndClearVoice(int handle);

    /**
     * @brief Prepare a specific voice for a source (the fixed-voice SetGroup path).
     * @details Wires the voice's stream format and render callback, sets its volume, marks it
     * playing, and returns the play handle (generation | voice << 16), or -1 if the voice is busy.
     * @param source The sound whose PCM the voice will stream.
     * @param voice The specific voice to prepare.
     * @param volumeIndex Index into the volume-level table for the voice's gain.
     * @return The packed play handle, or -1 when the voice is busy.
     * @ghidraAddress 0x23dac
     */
    int preparePlayer(CASound *source, int voice, int volumeIndex);

    /**
     * @brief Tear the AUGraph down and free the voices (idempotent).
     * @ghidraAddress 0x23d40
     */
    void terminate();

private:
    // A single mixer input. Ghidra: the 0x18-byte object built in initGraph.
    struct CAVoice {
        CASound *source = nullptr; // +0x00
        bool callbackSet = false;  // +0x04
        uint16_t generation = 0;   // +0x10
        uint32_t playPos = 0;      // +0x08  byte offset into source buffer
        uint32_t total = 0;        // +0x0c  bytes played this pass (reset on loop wrap)
        int32_t state = -1;        // +0x14  -1 free, 1 prepared, 2 playing, 3 paused, 4 finished

        // Mix this voice's next PCM span into `dst` when it is actively playing
        // (state 2); on the source running dry, mark the voice finished. Returns
        // the bytes copied. Ghidra: auMixerStartIfReady @ 0x23a20 (the per-voice
        // body of the render callback).
        size_t readInto(void *dst, size_t size);
    };

    bool prepareGraph();               // FUN_00023a6c
    bool initGraph(int voices);        // FUN_00023b74
    void setRenderCallback(int voice); // FUN_00023e5c

    // The AURenderCallback that copies a voice's PCM into the mixer.
    // FUN_00024044.
    static OSStatus renderProc(void *refCon,
                               AudioUnitRenderActionFlags *flags,
                               const AudioTimeStamp *timeStamp,
                               UInt32 bus,
                               UInt32 frames,
                               AudioBufferList *data);

    AUGraph m_graph = nullptr;
    AUNode m_ioNode = 0;
    AUNode m_mixerNode = 0;
    AudioUnit m_ioUnit = nullptr;                   // +0x0c
    AudioUnit m_mixerUnit = nullptr;                // +0x10
    bool m_running = false;                         // +0x14
    int m_voiceCount = 0;                           // +0x18
    std::vector<std::unique_ptr<CAVoice>> m_voices; // +0x1c
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
