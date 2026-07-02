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
CASound::CASound() = default;

// Ghidra: FUN_00027bdc.
CASound::~CASound() {
    free(m_buffer);
    m_buffer = nullptr;
}

// Ghidra: FUN_00027bf8 — build a CFURL from the path and load through it.
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

// Ghidra: FUN_00027c58.
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
bool CASound::configureFormat(ExtAudioFileRef file) {
    AudioStreamBasicDescription fileFormat = {};
    UInt32 size = sizeof(fileFormat);
    if (ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &size, &fileFormat) != noErr) {
        NSLog(@"ExtFileDecoder init failed: kExtAudioFileProperty_FileDataFormat");
        return false;
    }

    SInt64 lengthFrames = 0;
    size = sizeof(lengthFrames);
    if (ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileLengthFrames, &size, &lengthFrames) != noErr) {
        NSLog(@"ExtFileDecoder init failed: kExtAudioFileProperty_FileLengthFrames");
        return false;
    }

    UInt32 channels = fileFormat.mChannelsPerFrame;
    UInt32 bytesPerFrame = channels * 2;   // signed 16-bit, interleaved

    m_format = fileFormat;                 // keep the sample rate
    m_format.mFormatID = kAudioFormatLinearPCM;
    m_format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;  // 0xc
    m_format.mBitsPerChannel = 16;
    m_format.mFramesPerPacket = 1;
    m_format.mBytesPerFrame = bytesPerFrame;
    m_format.mBytesPerPacket = bytesPerFrame;
    m_format.mChannelsPerFrame = channels;

    m_frameCount = channels;               // (matches the decompiled +0x8 store)
    m_bufferSize = (UInt32)(lengthFrames * bytesPerFrame);
    return true;
}

// Ghidra: FUN_00027d50 — allocate the buffer, set the client format, and read
// every frame in with ExtAudioFileRead.
bool CASound::readFrames(ExtAudioFileRef file) {
    if (m_bufferSize == 0) {
        return false;
    }
    free(m_buffer);
    m_buffer = calloc(1, m_bufferSize);

    if (ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat,
                                sizeof(m_format), &m_format) != noErr) {
        NSLog(@"ExtFileDecoder init memory decoder failed: kExtAudioFileProperty_ClientDataFormat");
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
            break;   // end of file
        }
        UInt32 consumed = frames * bytesPerFrame;
        remaining -= consumed;
        offset += consumed;
    }
    return true;
}
