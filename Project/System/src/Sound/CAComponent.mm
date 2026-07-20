//
//  CAComponent.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. An AUGraph
//  (3D-mixer -> RemoteIO) whose mixer inputs each stream one CASound via a
//  render callback. Output format: 32000 Hz, stereo, interleaved signed 16-bit.
//

#import "CAComponent.h"

#include <cstring>
#include <memory>

#import "CASound.h"
#import "SDKCompat.h"

namespace {

// Per-voice mixer gains, indexed by the caller's volume level, backed by a float gain table.
// Modelled as a normalised 0..1 ramp; the exact table values live in the binary if a byte-accurate
// copy is needed.
float caGainForLevel(int level) {
    if (level < 0) {
        level = 0;
    }
    if (level > 100) {
        level = 100;
    }
    return static_cast<float>(level) / 100.0f;
}

// Voice states, as stored at CAVoice::state (offset 0x14).
enum : int {
    kVoiceFree = -1,
    kVoicePrepared = 1,
    kVoicePlaying = 2,
    kVoicePaused = 3,
    kVoiceFinished = 4,
};

} // namespace

// Build the AUGraph (prepareGraph) and, only if that succeeds, size and initialise the mixer
// (initGraph). The caplayer manager ctor runs this on a freshly-allocated CAComponent.
CAComponent::CAComponent(int voices) {
    if (prepareGraph()) {
        initGraph(voices);
    }
}

CAComponent::~CAComponent() {
    terminate();
}

// Stop the graph, dispose it, and free the voice pool. Idempotent: safe to call from both the
// caplayer dtor and ~CAComponent. Verified against the disassembly:
//   * stop() is guarded on m_running (offset 0x14), not on m_graph.
//   * DisposeAUGraph(m_graph) is called UNCONDITIONALLY (offset 0); there is no
//     AUGraphUninitialize / AUGraphClose. On a non-zero (failure) status the binary logs and
//     returns early, so the voice pool is only freed when the dispose succeeds; m_graph is never
//     nulled.
//   * The voice free-loop is guarded on m_voices (offset 0x1c): each voice's source (offset 0) is
//     zeroed then the voice is `operator delete`d, and the pool itself is released with
//     `operator delete[]`, after which m_voices is set to nullptr.
void CAComponent::terminate() {
    if (m_running) {
        stop(); // auGraphStop (only if still running)
    }
    if (DisposeAUGraph(m_graph) != noErr) {
        NSLog(@"CAComponent terminate: DisposeAUGraph failed.");
        return;
    }
    for (auto &v : m_voices) {
        v->source = nullptr; // clear the back-pointer before the voice is destroyed
    }
    m_voices.clear(); // unique_ptr elements delete each CAVoice
}

// Build the AUGraph: a 3D-mixer feeding RemoteIO output. The RemoteIO/Output descriptor
// ('auou'/'rioc'/'appl') is added first (m_ioNode), the 3D-mixer descriptor ('aumx'/'3dem'/'appl',
// i.e. SpatialMixer's FourCC) second (m_mixerNode); the connect wires mixer output 0 -> io
// input 0. Verified against the byte-exact FourCCs.
bool CAComponent::prepareGraph() {
    AudioComponentDescription outDesc = {
        kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple, 0, 0};
    AudioComponentDescription mixDesc = {
        kAudioUnitType_Mixer, kAudioUnitSubType_SpatialMixer, kAudioUnitManufacturer_Apple, 0, 0};

    if (NewAUGraph(&m_graph) != noErr) {
        NSLog(@"CAComponent prepareGraph: NewAUGraph failed");
        return false;
    }
    if (AUGraphAddNode(m_graph, &outDesc, &m_ioNode) != noErr) {
        NSLog(@"CAComponent prepareGraph: AUGraphAddNode remoteIO failed");
        return false;
    }
    if (AUGraphAddNode(m_graph, &mixDesc, &m_mixerNode) != noErr) {
        NSLog(@"CAComponent prepareGraph: AUGraphAddNode mixer failed");
        return false;
    }
    if (AUGraphConnectNodeInput(m_graph, m_mixerNode, 0, m_ioNode, 0) != noErr) {
        NSLog(@"CAComponent prepareGraph: AUGraphConnectNodeInput failed");
        return false;
    }
    if (AUGraphOpen(m_graph) != noErr) {
        NSLog(@"CAComponent prepareGraph: AUGraphOpen failed");
        return false;
    }
    if (AUGraphNodeInfo(m_graph, m_ioNode, nullptr, &m_ioUnit) != noErr) {
        NSLog(@"CAComponent prepareGraph: AUGraphNodeInfo remoteIO failed");
        return false;
    }
    if (AUGraphNodeInfo(m_graph, m_mixerNode, nullptr, &m_mixerUnit) != noErr) {
        NSLog(@"CAComponent prepareGraph: AUGraphNodeInfo mixer failed");
        return false;
    }
    return true;
}

// Size the mixer, allocate the voices, set the output format, then initialise the graph.
// The voice pool is `operator new[]` and each voice `operator new` (24 bytes) in the binary; the
// loop writes every slot. All ASBD fields (32000.0 sample rate, 'lpcm', flags 0xc2c, 4/1/4/2/16)
// verified byte-exact.
bool CAComponent::initGraph(int voices) {
    if (voices > 0xfff) {
        return false;
    }
    UInt32 count = static_cast<UInt32>(voices);
    if (AudioUnitSetProperty(m_mixerUnit,
                             kAudioUnitProperty_ElementCount,
                             kAudioUnitScope_Input,
                             0,
                             &count,
                             sizeof(count)) != noErr) {
        NSLog(@"CAComponent initGraph: ElementCount failed");
        m_voiceCount = 0;
        return false;
    }
    m_voiceCount = static_cast<int>(count);
    m_voices.clear();
    m_voices.reserve(count);
    for (int i = 0; i < m_voiceCount; i++) {
        m_voices.push_back(std::make_unique<CAVoice>()); // state -1 (free), generation 0
    }

    AudioStreamBasicDescription out = {};
    out.mSampleRate = 32000.0;
    out.mFormatID = kAudioFormatLinearPCM;
    out.mFormatFlags = 0xc2c; // raw value from binary (signed|packed|alignedHigh
                              // + bits 0x400/0x800)
    out.mBytesPerPacket = 4;
    out.mFramesPerPacket = 1;
    out.mBytesPerFrame = 4;
    out.mChannelsPerFrame = 2;
    out.mBitsPerChannel = 16;
    if (AudioUnitSetProperty(m_ioUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             0,
                             &out,
                             sizeof(out)) != noErr) {
        NSLog(@"CAComponent initGraph: RemoteIO stream format failed");
        return false;
    }
    AudioUnitSetParameter(m_mixerUnit, 3 /* gain */, kAudioUnitScope_Output, 0, 0, 0);

    AUGraphUpdate(m_graph, nullptr);
    if (AUGraphInitialize(m_graph) != noErr) {
        NSLog(@"CAComponent initGraph: AUGraphInitialize failed");
        return false;
    }
    AUGraphUpdate(m_graph, nullptr);
    return true;
}

void CAComponent::start() {
    if (!m_running) {
        if (AUGraphStart(m_graph) != noErr) {
            NSLog(@"CAComponent start: AUGraphStart failed");
            return;
        }
        m_running = true;
    }
    setPlayerVolume(0x7f, 0);
}

// Also reached via the caplayer's suspend path.
void CAComponent::stop() {
    if (m_running) {
        if (AUGraphStop(m_graph) != noErr) {
            NSLog(@"CAComponent suspend: AUGraphStop failed");
            return;
        }
        m_running = false;
    }
}

// Find a free (or finished) voice and prepare it.
uint32_t CAComponent::reserveVoice(CASound *source, int volumeIndex) {
    for (int i = 0; i < m_voiceCount; i++) {
        int state = m_voices[i]->state;
        if (state == -1 || state == 4) {
            return static_cast<uint32_t>(preparePlayer(source, i, volumeIndex));
        }
    }
    NSLog(@"CAComponent: no free voice");
    return 0xffffffff;
}

// Bind `source` to voice `voice`: set the input stream format, install the render callback, set
// volume, reset the cursors, mark it playing.
int CAComponent::preparePlayer(CASound *source, int voice, int volumeIndex) {
    CAVoice *v = m_voices[voice].get();
    if (v->state != -1 && v->state != 4) {
        return -1;
    }
    v->source = source;
    uint16_t generation = static_cast<uint16_t>(v->generation + 1);
    v->generation = generation;

    AudioStreamBasicDescription in = source->format();
    in.mFormatID = kAudioFormatLinearPCM;
    in.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    in.mBitsPerChannel = 16;
    in.mFramesPerPacket = 1;
    in.mBytesPerFrame = in.mChannelsPerFrame * 2;
    in.mBytesPerPacket = in.mBytesPerFrame;
    if (AudioUnitSetProperty(m_mixerUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             voice,
                             &in,
                             sizeof(in)) != noErr) {
        NSLog(@"CAComponent preparePlayer: input stream format failed");
        return -1;
    }

    setRenderCallback(voice);
    setPlayerVolume(volumeIndex, voice);
    v->playPos = 0;
    v->total = 0;
    v->state = 1; // playing
    return static_cast<int>(generation | (voice << 16));
}

// Install the render callback for a voice's mixer input.
void CAComponent::setRenderCallback(int voice) {
    if (voice >= m_voiceCount || m_voices[voice]->callbackSet) {
        return;
    }
    AURenderCallbackStruct cb;
    cb.inputProc = &CAComponent::renderProc;
    cb.inputProcRefCon = m_voices[voice].get(); // raw CAVoice* handed to the CoreAudio callback
    if (AudioUnitSetProperty(m_mixerUnit,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input,
                             voice,
                             &cb,
                             sizeof(cb)) == noErr) {
        m_voices[voice]->callbackSet = true;
    } else {
        NSLog(@"CAComponent setRenderCallback: SetRenderCallback failed");
    }
}

// Set a voice's mixer gain from the volume table.
// Control flow verified: bounds-check voice against m_voiceCount, then
// AudioUnitSetParameter(mixerUnit, id 3, Output scope, element 0, gain, 0). The gain is a float
// loaded from the table indexed by volumeIndex; caGainForLevel models this as a 0..1 ramp: the
// value is an acknowledged approximation, the lookup structure is exact.
bool CAComponent::setPlayerVolume(int volumeIndex, int voice) {
    if (voice >= m_voiceCount) {
        return false;
    }
    // Binary sets the mixer output-scope element 0 (master) gain; `voice` is only
    // used for the bounds check above, not as the element.
    if (AudioUnitSetParameter(
            m_mixerUnit, 3 /* gain */, kAudioUnitScope_Output, 0, caGainForLevel(volumeIndex), 0) !=
        noErr) {
        NSLog(@"CAComponent setPlayerVolume: gain failed");
        return false;
    }
    return true;
}

// Resume a prepared or paused voice (forwarded from caHandlePlay). Split the packed handle into
// voice = handle >> 16 (a signed bounds check against m_voiceCount rejects the 0xffffffff a bad
// handle decodes to) and generation = handle & 0xffff; only when the generation matches and the
// voice is prepared (state 1) or paused (state 3) does it move to playing (state 2). The binary
// spells "state == 1 || state == 3" as the bit-trick (state | 2) == 3.
bool CAComponent::startVoice(int handle) {
    const int voice = static_cast<int>(static_cast<uint32_t>(handle) >> 16);
    if (voice >= m_voiceCount) {
        return false;
    }
    CAVoice *v = m_voices[voice].get();
    if (v->generation != (handle & 0xffff)) {
        return false;
    }
    if ((v->state | kVoicePlaying) != kVoicePaused) {
        return false; // only states 1 (prepared) and 3 (paused) satisfy (x | 2) == 3
    }
    v->state = kVoicePlaying;
    return true;
}

// Mark the voice finished so reserveVoice can recycle it (forwarded from caHandleStop). Same handle
// split and generation check as startVoice.
bool CAComponent::stopVoice(int handle) {
    const int voice = static_cast<int>(static_cast<uint32_t>(handle) >> 16);
    if (voice >= m_voiceCount) {
        return false;
    }
    CAVoice *v = m_voices[voice].get();
    if (v->generation != (handle & 0xffff)) {
        return false;
    }
    v->state = kVoiceFinished;
    return true;
}

// Return the voice's state, or -1 for an out-of-range or stale handle (forwarded from
// caHandleGetState). Same handle split and generation check as startVoice.
int CAComponent::voiceState(int handle) const {
    const int voice = static_cast<int>(static_cast<uint32_t>(handle) >> 16);
    if (voice >= m_voiceCount) {
        return -1;
    }
    CAVoice *v = m_voices[voice].get();
    if (v->generation != (handle & 0xffff)) {
        return -1;
    }
    return v->state;
}

// Set the mixer's master gain. The caPlayerMgr forwarder loads its CAComponent (offset 0) and
// tail-calls setPlayerVolume(nVolume, 0) exactly once. setPlayerVolume always writes the master
// output-scope element 0 gain, so this single call sets the overall volume; `voice = 0` is only the
// bounds argument.
void CAComponent::setAllVolume(int volumeIndex) {
    setPlayerVolume(volumeIndex, 0);
}

// Drop `source` from any voice still pointing at it.
void CAComponent::clearSourceRef(CASound *source) {
    for (int i = 0; i < m_voiceCount; i++) {
        if (m_voices[i]->source == source) {
            m_voices[i]->source = nullptr;
        }
    }
}

// Pause the voice named by a raw packed handle (forwarded from caHandlePause). Split it into
// voice = handle >> 16 (the signed bounds check against m_voiceCount rejects the 0xffffffff a bad
// handle decodes to) and generation = handle & 0xffff; on a generation match, write state = 3 and
// return true. The caplayer stub has already validated the 0x20000000 tag and stripped the top four
// bits before this body runs.
bool CAComponent::pauseVoice(int handle) {
    const int voice = static_cast<int>(static_cast<uint32_t>(handle) >> 16);
    if (voice >= m_voiceCount) {
        return false;
    }
    CAVoice *v = m_voices[voice].get();
    if (v->generation != (handle & 0xffff)) {
        return false;
    }
    v->state = kVoicePaused;
    return true;
}

// Free the voice named by a raw packed handle (state 4 + drop its source) so reserveVoice can
// recycle it immediately (forwarded from caHandleStopAndClear). Split the handle into
// voice = handle >> 16 (the signed bounds check against m_voiceCount rejects the 0xffffffff a bad
// handle decodes to) and generation = handle & 0xffff; on a generation match, write state = 4 and
// clear the source. The binary always returns 1; this returns void. The caplayer stub has already
// validated the 0x20000000 tag before this body runs.
void CAComponent::stopAndClearVoice(int handle) {
    const int voice = static_cast<int>(static_cast<uint32_t>(handle) >> 16);
    if (voice >= m_voiceCount) {
        return;
    }
    CAVoice *v = m_voices[voice].get();
    if (v->generation == (handle & 0xffff)) {
        v->state = kVoiceFinished;
        v->source = nullptr;
    }
}

// The per-voice render body. Only an actively-playing voice (state 2) contributes sound; a
// merely-prepared (1), paused (3), finished (4) or free (-1) voice is left as the silence the
// callback pre-cleared. The prepare -> play (1 -> 2) transition is issued by the caplayer play
// path. When the source runs dry, the voice is marked finished so reserveVoice can recycle it. The
// actual copy + loop/finish lives in CASound::read, called with &total at voice+0x8 and &playPos at
// voice+0xc.
size_t CAComponent::CAVoice::readInto(void *dst, size_t size) {
    if (source != nullptr && state == 2) {
        const size_t got = source->read(dst, size, &total, &playPos);
        if (got != 0) {
            return got;
        }
        state = 4; // source exhausted -> finished (voice becomes reusable)
    }
    return 0;
}

// The AURenderCallback. Clear the output buffer, then let the voice (passed as refCon) mix its next
// PCM span in via readInto.
OSStatus CAComponent::renderProc(void *refCon,
                                 AudioUnitRenderActionFlags * /*flags*/,
                                 const AudioTimeStamp *,
                                 UInt32,
                                 UInt32 /*frames*/,
                                 AudioBufferList *data) {
    CAVoice *v = static_cast<CAVoice *>(refCon);
    AudioBuffer &out = data->mBuffers[0];
    std::memset(out.mData, 0, out.mDataByteSize);
    v->readInto(out.mData, out.mDataByteSize);
    return noErr;
}
