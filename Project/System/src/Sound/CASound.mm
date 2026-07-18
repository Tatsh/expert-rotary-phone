//
//  CASound.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Decodes an
//  audio file into an interleaved signed-16-bit LPCM buffer using ExtAudioFile.
//

#include <cstdlib>
#include <cstring>

#import "CASound.h"

// Ghidra: FUN_00027bac.
// @complete
CASound::CASound() = default;

// Ghidra: FUN_00027bdc.
// @complete
CASound::~CASound() {
    freeBuffer();
}

// Ghidra: caSourceFreeBuffer @ 0x27bc0.
// @complete
void CASound::freeBuffer() {
    if (m_buffer != nullptr) {
        free(m_buffer);
    }
    m_buffer = nullptr;
    m_bufferSize = 0;
}

// Ghidra: caSourceRead @ 0x27e10 — the mixer render read. Copies from the
// current byte cursor, clamping each copy to the buffer end; a looped source
// wraps (and clears the pass total), a one-shot stops at the end.
// @complete
size_t CASound::read(void *dst, size_t bytes, UInt32 *total, UInt32 *pos) const {
    if (bytes == 0) {
        return 0;
    }
    size_t copied = 0;
    UInt32 cursor = *pos;
    const uint8_t *src = static_cast<const uint8_t *>(m_buffer) + cursor;
    uint8_t *out = static_cast<uint8_t *>(dst);
    while (true) {
        size_t chunk = bytes;
        if (static_cast<int>(cursor + bytes) >= static_cast<int>(m_bufferSize)) {
            chunk = m_bufferSize - cursor;
        }
        if (chunk != 0) {
            memcpy(out, src, chunk);
        }
        copied += chunk;
        const bool done = (bytes == chunk);
        cursor += static_cast<UInt32>(chunk);
        *pos = cursor;
        *total += static_cast<UInt32>(chunk);
        bytes -= chunk;
        if (done || !m_loop) {
            break;
        }
        // Loop: restart from the top of the buffer and reset the pass total.
        src = static_cast<const uint8_t *>(m_buffer);
        cursor = 0;
        *pos = 0;
        *total = 0;
        out += chunk;
    }
    return copied;
}

// Ghidra: FUN_00027bf8 — build a CFURL from the path and load through it.
// In the binary the `loop` flag is passed on to loadURL, which performs the
// m_loop store (0x27c62); setting it here first is behaviourally identical since
// nothing reads m_loop before readFrames runs.
// @complete
bool CASound::load(const char *path, bool loop) {
    m_loop = loop;
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(
        kCFAllocatorDefault, reinterpret_cast<const UInt8 *>(path), strlen(path), false);
    if (url == nullptr) {
        NSLog(@"CASource load failed: CFURLCreateFromFileSystemRepresentation(%s)", path);
        return false;
    }
    bool ok = loadURL(url);
    CFRelease(url);
    return ok;
}

// Ghidra: FUN_00027c58. In the binary this also takes the loop flag and stores
// m_loop (strb r2,[this,#0xc]); that store is hoisted into load() here.
// @complete
bool CASound::loadURL(CFURLRef url) {
    ExtAudioFileRef file = nullptr;
    if (ExtAudioFileOpenURL(url, &file) != noErr) {
        NSLog(@"CASource load error");
        return false;
    }
    bool ok = configureFormat(file) && readFrames(file);
    if (ExtAudioFileDispose(file) != noErr) {
        NSLog(@"CASource load file close error");
    }
    return ok;
}

// Ghidra: FUN_00027cb8 — read the file's format + length, then derive the
// interleaved signed-16-bit LPCM client format to decode into.
// @complete
bool CASound::configureFormat(ExtAudioFileRef file) {
    AudioStreamBasicDescription fileFormat = {};
    UInt32 size = sizeof(fileFormat);
    if (ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &size, &fileFormat) !=
        noErr) {
        NSLog(@"ExtFileDecoder init failed: kExtAudioFileProperty_FileDataFormat");
        return false;
    }

    SInt64 lengthFrames = 0;
    size = sizeof(lengthFrames);
    if (ExtAudioFileGetProperty(
            file, kExtAudioFileProperty_FileLengthFrames, &size, &lengthFrames) != noErr) {
        NSLog(@"ExtFileDecoder init failed: kExtAudioFileProperty_FileLengthFrames");
        return false;
    }

    UInt32 channels = fileFormat.mChannelsPerFrame;
    UInt32 bytesPerFrame = channels * 2; // signed 16-bit, interleaved

    m_format = fileFormat; // keep the sample rate
    m_format.mFormatID = kAudioFormatLinearPCM;
    m_format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked; // 0xc
    m_format.mBitsPerChannel = 16;
    m_format.mFramesPerPacket = 1;
    m_format.mBytesPerFrame = bytesPerFrame;
    m_format.mBytesPerPacket = bytesPerFrame;
    m_format.mChannelsPerFrame = channels;

    m_frameCount = channels; // (matches the decompiled +0x8 store)
    m_bufferSize = static_cast<UInt32>(lengthFrames * bytesPerFrame);
    return true;
}

// Ghidra: FUN_00027d50 — allocate the buffer, set the client format, and read
// every frame in with ExtAudioFileRead.
// The binary loops purely on `remaining > 0` (mls/mla update per read) with no
// frames==0 guard; the `break` on end-of-file here is a reconstruction-added
// safety that only fires on a short/malformed read the binary would spin on.
// @complete
bool CASound::readFrames(ExtAudioFileRef file) {
    if (m_bufferSize == 0) {
        return false;
    }
    free(m_buffer);
    m_buffer = calloc(1, m_bufferSize);

    if (ExtAudioFileSetProperty(
            file, kExtAudioFileProperty_ClientDataFormat, sizeof(m_format), &m_format) != noErr) {
        NSLog(@"ExtFileDecoder init memory decoder failed: "
              @"kExtAudioFileProperty_ClientDataFormat");
        return false;
    }

    UInt32 remaining = m_bufferSize;
    UInt32 bytesPerFrame = m_format.mBytesPerFrame;
    UInt32 offset = 0;
    while (remaining > 0) {
        AudioBufferList list;
        list.mNumberBuffers = 1;
        list.mBuffers[0].mNumberChannels = m_format.mChannelsPerFrame;
        list.mBuffers[0].mDataByteSize = remaining;
        list.mBuffers[0].mData = static_cast<uint8_t *>(m_buffer) + offset;

        UInt32 frames = remaining / bytesPerFrame;
        if (ExtAudioFileRead(file, &frames, &list) != noErr) {
            NSLog(@"ExtFileDecoder init memory decoder failed: ExtAudioFileRead");
            return false;
        }
        if (frames == 0) {
            break; // end of file
        }
        UInt32 consumed = frames * bytesPerFrame;
        remaining -= consumed;
        offset += consumed;
    }
    return true;
}
