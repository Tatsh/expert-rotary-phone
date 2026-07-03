//
//  CAComponent.h
//  pop'n rhythmin
//
//  The low-latency SE mixer: an AUGraph of a 3D-mixer AudioUnit feeding a
//  RemoteIO output. Each mixer input ("voice") streams one CASound's PCM through
//  a render callback. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (the lib_rsnd / caplayer engine — reconstructed, not imported).
//    prepareGraph  FUN_00023a6c   initGraph     FUN_00023b74
//    start         FUN_00023ccc   stop          (AUGraphStop, FUN_000261e0)
//    reserveVoice  FUN_00023f08   preparePlayer FUN_00023dac
//    setVolume     FUN_00023eb0   renderProc    FUN_00024044
//

#pragma once

#import <AudioToolbox/AudioToolbox.h>

class CASound;

class CAComponent {
public:
    explicit CAComponent(int voices);
    ~CAComponent();

    void start();                 // AUGraphStart + unmute
    void stop();                  // AUGraphStop
    bool isRunning() const { return m_running; }

    // Reserve a free voice for `source` (state -1/free or 4/finished), wire its
    // stream format + render callback, and return the play handle
    // (generation | voice << 16), or 0xffffffff when the mixer is full.
    uint32_t reserveVoice(CASound *source, int volumeIndex);

    // Set a voice's mixer gain from the volume-level table. Ghidra: FUN_00023eb0.
    bool setPlayerVolume(int volumeIndex, int voice);

    // Stop a voice (make it reusable) and query its state (-1 free/1 playing/
    // 4 finished). `voice` is a play-handle's slot index.
    bool stopVoice(int voice);
    int voiceState(int voice) const;

    // Set the mixer gain of every voice from the volume-level table.
    void setAllVolume(int volumeIndex);

    // Detach `source` from any voice still referencing it (called when the source is unloaded).
    // Ghidra: auClearSourceRef @ 0x24014.
    void clearSourceRef(CASound *source);

    // Pause / stop-and-clear a single voice, guarded by its generation (a stale play handle is
    // ignored). pauseVoice sets state 3; stopAndClearVoice frees the voice (state 4 + drop the
    // source). Ghidra: caHandlePause @ 0x267b4 / caHandleStopAndClear @ 0x26864.
    bool pauseVoice(int voice, uint16_t generation);
    void stopAndClearVoice(int voice, uint16_t generation);

    // Prepare a *specific* voice for `source` (the fixed-voice SetGroup path): wire its stream
    // format + render callback, set volume, mark it playing, and return the play handle
    // (generation | voice << 16), or -1 if the voice is busy. Ghidra: auMixerPreparePlayer.
    int preparePlayer(CASound *source, int voice, int volumeIndex);

    // Tear the AUGraph down and free the voices (idempotent). Ghidra: auGraphTerminate @ 0x23d40.
    void terminate();

private:
    // A single mixer input. Ghidra: the 0x18-byte object built in initGraph.
    struct CAVoice {
        CASound *source = nullptr;    // +0x00
        bool callbackSet = false;     // +0x04
        uint16_t generation = 0;      // +0x10
        uint32_t playPos = 0;         // +0x08  byte offset into source buffer
        uint32_t total = 0;           // +0x0c  bytes played this pass (reset on loop wrap)
        int32_t state = -1;           // +0x14  -1 free, 1 playing, 3 paused, 4 finished
    };

    bool prepareGraph();                                  // FUN_00023a6c
    bool initGraph(int voices);                           // FUN_00023b74
    void setRenderCallback(int voice);                    // FUN_00023e5c

    // The AURenderCallback that copies a voice's PCM into the mixer. FUN_00024044.
    static OSStatus renderProc(void *refCon, AudioUnitRenderActionFlags *flags,
                               const AudioTimeStamp *timeStamp, UInt32 bus,
                               UInt32 frames, AudioBufferList *data);

    AUGraph m_graph = nullptr;
    AUNode m_ioNode = 0;
    AUNode m_mixerNode = 0;
    AudioUnit m_ioUnit = nullptr;      // +0x0c
    AudioUnit m_mixerUnit = nullptr;   // +0x10
    bool m_running = false;            // +0x14
    int m_voiceCount = 0;              // +0x18
    CAVoice **m_voices = nullptr;      // +0x1c
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
