//
//  CASound.h
//  pop'n rhythmin
//
//  One decoded sound effect: an audio file (m4a/caf/…) read into an interleaved
//  16-bit LPCM buffer via ExtAudioFile, ready to be handed to the CAComponent
//  mixer. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (the lib_rsnd / caplayer sound engine; ctor FUN_00027bac, load FUN_00027bf8,
//  dtor FUN_00027bdc).
//

#pragma once

#import <AudioToolbox/AudioToolbox.h>

class CASound {
public:
    CASound();
    ~CASound();

    // Decode `path` into the PCM buffer; `loop` marks it for looped playback.
    // Returns false on any ExtAudioFile error. Ghidra: FUN_00027bf8 -> FUN_00027c58.
    bool load(const char *path, bool loop);

    const void *buffer() const { return m_buffer; }
    UInt32 bufferSize() const { return m_bufferSize; }
    UInt32 frameCount() const { return m_frameCount; }
    const AudioStreamBasicDescription &format() const { return m_format; }
    bool isLoop() const { return m_loop; }

private:
    bool loadURL(CFURLRef url);                     // FUN_00027c58
    bool configureFormat(ExtAudioFileRef file);     // FUN_00027cb8
    bool readFrames(ExtAudioFileRef file);          // FUN_00027d50

    AudioStreamBasicDescription m_format = {};  // client (LPCM) format
    UInt32 m_frameCount = 0;
    bool m_loop = false;
    void *m_buffer = nullptr;
    UInt32 m_bufferSize = 0;
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
