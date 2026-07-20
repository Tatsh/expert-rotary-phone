/** @file
 * One decoded sound effect: an audio file (m4a, caf, or similar) read into an interleaved 16-bit
 * LPCM buffer via ExtAudioFile, ready to be handed to the CAComponent mixer. Part of the
 * lib_rsnd / caplayer sound engine.
 */

#pragma once

#import <AudioToolbox/AudioToolbox.h>

/**
 * @brief One decoded sound effect read into an interleaved 16-bit LPCM buffer.
 *
 * Loads an audio file via ExtAudioFile, ready to be handed to the CAComponent mixer. Part of the
 * lib_rsnd / caplayer sound engine.
 */
class CASound {
public:
    /**
     * @brief Construct an empty sound with no decoded buffer.
     * @ghidraAddress 0x27bac
     */
    CASound();

    /**
     * @brief Free the decoded buffer and destroy the sound.
     * @ghidraAddress 0x27bdc
     */
    ~CASound();

    /**
     * @brief Decode an audio file into the PCM buffer.
     * @details Reads @p path via ExtAudioFile into the interleaved 16-bit LPCM buffer. The @p loop
     * flag marks the sound for looped playback so that read() wraps to the start rather than
     * stopping. Returns false on any ExtAudioFile error.
     * @param path Filesystem path to the audio file to decode.
     * @param loop Whether the sound is marked for looped playback.
     * @return True on success, false on any ExtAudioFile error.
     * @ghidraAddress 0x27bf8
     */
    bool load(const char *path, bool loop);

    /**
     * @brief Pointer to the decoded interleaved 16-bit LPCM buffer.
     * @return The PCM buffer, or null when nothing is loaded.
     */
    const void *buffer() const {
        return m_buffer;
    }

    /**
     * @brief Size of the decoded PCM buffer in bytes.
     * @return The buffer size in bytes.
     */
    UInt32 bufferSize() const {
        return m_bufferSize;
    }

    /**
     * @brief Number of frames represented by the decoded buffer.
     * @return The frame count.
     */
    UInt32 frameCount() const {
        return m_frameCount;
    }

    /**
     * @brief Client (LPCM) audio format the buffer was decoded into.
     * @return A reference to the stream format description.
     */
    const AudioStreamBasicDescription &format() const {
        return m_format;
    }

    /**
     * @brief Whether the sound is marked for looped playback.
     * @return True if looped, false for a one-shot source.
     */
    bool isLoop() const {
        return m_loop;
    }

    /**
     * @brief Copy PCM from the play cursor into a destination buffer.
     * @details Copies @p bytes of PCM starting at the play cursor @p pos (a byte offset) into
     * @p dst. When a non-looped source runs out it stops at the end; a looped source restarts from
     * the top of the buffer and resets @p total. @p total accumulates the bytes played for the
     * current pass, and @p pos is advanced. This is the mixer render read.
     * @param dst Destination buffer to receive the copied PCM.
     * @param bytes Number of bytes requested.
     * @param total Running total of bytes played for the current pass; advanced, and reset to zero
     * when a looped source wraps.
     * @param pos Play cursor as a byte offset; advanced, and reset to zero when a looped source
     * wraps.
     * @return The number of bytes actually copied.
     * @ghidraAddress 0x27e10
     */
    size_t read(void *dst, size_t bytes, UInt32 *total, UInt32 *pos) const;

    /**
     * @brief Free the decoded PCM buffer and null it, leaving the object reusable.
     * @ghidraAddress 0x27bc0
     */
    void freeBuffer();

private:
    bool loadURL(CFURLRef url);                 // FUN_00027c58
    bool configureFormat(ExtAudioFileRef file); // FUN_00027cb8
    bool readFrames(ExtAudioFileRef file);      // FUN_00027d50

    AudioStreamBasicDescription m_format = {}; // client (LPCM) format
    UInt32 m_frameCount = 0;
    bool m_loop = false;
    void *m_buffer = nullptr;
    UInt32 m_bufferSize = 0;
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
