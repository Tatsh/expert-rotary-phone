//
//  CAComponent.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. An AUGraph
//  (3D-mixer -> RemoteIO) whose mixer inputs each stream one CASound via a
//  render callback. Output format: 32000 Hz, stereo, interleaved signed 16-bit.
//

#include <cstring>
#include <memory>

#import "CAComponent.h"
#import "CASound.h"
#import "SDKCompat.h"

namespace {

// Per-voice mixer gains, indexed by the caller's volume level. Ghidra:
// DAT_0012e3c8 (a float gain table). Modelled as a normalised 0..1 ramp; the
// exact table values live at that address if a byte-accurate copy is needed.
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

// Ghidra: auGraphSetup @ 0x23a4c — build the AUGraph (auGraphCreate =
// prepareGraph) and, only if that succeeds, size and initialise the mixer
// (auGraphInitMixer = initGraph). The caplayer manager ctor (caPlayerMgr_ctor @
// 0x26172) runs this on a freshly-allocated CAComponent.
// @complete
CAComponent::CAComponent(int voices) {
    if (prepareGraph()) {
        initGraph(voices);
    }
}

CAComponent::~CAComponent() {
    terminate();
}

// Ghidra: auGraphTerminate @ 0x23d40 — stop the graph, dispose it, and free the
// voice pool. Idempotent: safe to call from both the caplayer dtor
// (caPlayerMgr_dtor) and ~CAComponent. Verified against the disassembly:
//   * 0x23d46: stop() is guarded on m_running (offset 0x14), not on m_graph.
//   * 0x23d52: DisposeAUGraph(m_graph) is called UNCONDITIONALLY (offset 0);
//     there is no AUGraphUninitialize / AUGraphClose. On a non-zero (failure)
//     status the binary logs and returns early, so the voice pool is only freed
//     when the dispose succeeds; m_graph is never nulled.
//   * The voice free-loop is guarded on m_voices (offset 0x1c): each voice's
//     source (offset 0) is zeroed then the voice is `operator delete`d
//     (0x12feb8), and the pool itself is released with `operator delete[]`
//     (0x12feb4), after which m_voices is set to nullptr.
// @complete
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

// Ghidra: FUN_00023a6c — build the AUGraph: a 3D-mixer feeding RemoteIO output.
// The RemoteIO/Output descriptor ('auou'/'rioc'/'appl') is added first (m_ioNode
// @ offset 4), the 3D-mixer descriptor ('aumx'/'3dem'/'appl', i.e.
// SpatialMixer's FourCC) second (m_mixerNode @ offset 8); the connect wires
// mixer output 0 -> io input 0. Verified against the byte-exact FourCCs.
// @complete
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

// Ghidra: FUN_00023b74 — size the mixer, allocate the voices, set the output
// format, then initialise the graph.
// The voice pool is `operator new[]` (0x12febc) and each voice `operator new`
// (0x12fec0, 24 bytes) in the binary; the loop writes every slot. All ASBD fields
// (32000.0 sample rate, 'lpcm', flags 0xc2c, 4/1/4/2/16) verified byte-exact.
// @complete
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

// Ghidra: FUN_00023ccc.
// @complete
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

// Ghidra: auGraphStop @ 0x23d0c (also reached via the caplayer's FUN_000261e0
// suspend).
// @complete
void CAComponent::stop() {
    if (m_running) {
        if (AUGraphStop(m_graph) != noErr) {
            NSLog(@"CAComponent suspend: AUGraphStop failed");
            return;
        }
        m_running = false;
    }
}

// Ghidra: FUN_00023f08 — find a free (or finished) voice and prepare it.
// @complete
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

// Ghidra: auMixerPreparePlayer (FUN_00023dac) — bind `source` to voice `voice`:
// set the input stream format, install the render callback, set volume, reset
// the cursors, mark it playing.
// @complete
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

// Ghidra: FUN_00023e5c — install the render callback for a voice's mixer input.
// @complete
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

// Ghidra: FUN_00023eb0 — set a voice's mixer gain from the volume table.
// Control flow verified: bounds-check voice against m_voiceCount, then
// AudioUnitSetParameter(mixerUnit, id 3, Output scope, element 0, gain, 0). The
// gain is a float loaded from the table at DAT_0012e3c8 indexed by volumeIndex
// (0x23eda: vldr s0, [base + volumeIndex*4]); caGainForLevel models this as a
// 0..1 ramp — the value is an acknowledged approximation, the lookup structure
// is exact.
// @complete
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

// Ghidra: caCAMixer play body @ 0x23f5c (forwarded from caHandlePlay) — resume a
// prepared or paused voice. Split the packed handle into voice = handle >> 16
// (a signed bounds check against m_voiceCount rejects the 0xffffffff a bad handle
// decodes to) and generation = handle & 0xffff; only when the generation matches
// and the voice is prepared (state 1) or paused (state 3) does it move to playing
// (state 2). The binary spells "state == 1 || state == 3" as the bit-trick
// (state | 2) == 3.
// @complete
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

// Ghidra: caCAMixer stop body @ 0x23f90 (forwarded from caHandleStop) — mark the
// voice finished so reserveVoice can recycle it. Same handle split and generation
// check as startVoice.
// @complete
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

// Ghidra: caCAMixer state body @ 0x23fe8 (forwarded from caHandleGetState) —
// return the voice's state, or -1 for an out-of-range or stale handle. Same
// handle split and generation check as startVoice.
// @complete
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

// Ghidra: caHandleSetVolume @ 0x267e4 (body at 0x23d04) — set the mixer's master
// gain. The caPlayerMgr forwarder loads its CAComponent (offset 0) and
// tail-calls setPlayerVolume(nVolume, 0) exactly once (0x23d04: `movs r2, #0`;
// `b setPlayerVolume`). setPlayerVolume always writes the master output-scope
// element 0 gain, so this single call sets the overall volume; `voice = 0` is
// only the bounds argument.
// @complete
void CAComponent::setAllVolume(int volumeIndex) {
    setPlayerVolume(volumeIndex, 0);
}

// Ghidra: auClearSourceRef @ 0x24014 — drop `source` from any voice still
// pointing at it.
// @complete
void CAComponent::clearSourceRef(CASound *source) {
    for (int i = 0; i < m_voiceCount; i++) {
        if (m_voices[i]->source == source) {
            m_voices[i]->source = nullptr;
        }
    }
}

// Ghidra: caCAMixer pause body @ 0x23fbc (forwarded from caHandlePause @
// 0x267b4) — pause the voice named by a raw packed handle. Split it into
// voice = handle >> 16 (the signed bounds check against m_voiceCount rejects the
// 0xffffffff a bad handle decodes to) and generation = handle & 0xffff; on a
// generation match, write state = 3 and return true. The 0x267b4 caplayer stub
// has already validated the 0x20000000 tag and stripped the top four bits before
// this body runs.
// @complete
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

// Ghidra: caCAMixer stop-and-clear body @ 0x2406c (forwarded from
// caHandleStopAndClear @ 0x26864) — free the voice named by a raw packed handle
// (state 4 + drop its source) so reserveVoice can recycle it immediately. Split
// the handle into voice = handle >> 16 (the signed bounds check against
// m_voiceCount rejects the 0xffffffff a bad handle decodes to) and
// generation = handle & 0xffff; on a generation match, write state = 4 and clear
// the source. The binary always returns 1; this returns void. The 0x26864
// caplayer stub has already validated the 0x20000000 tag before this body runs.
// @complete
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

// Ghidra: auMixerStartIfReady @ 0x23a20 — the per-voice render body. Only an
// actively-playing voice (state 2) contributes sound; a merely-prepared (1),
// paused (3), finished (4) or free (-1) voice is left as the silence the
// callback pre-cleared. The prepare -> play (1 -> 2) transition is issued by
// the caplayer play path. When the source runs dry, the voice is marked
// finished so reserveVoice can recycle it. The actual copy + loop/finish lives
// in CASound::read (Ghidra: caSourceRead @ 0x27e10, called with &total at
// voice+0x8 and &playPos at voice+0xc).
// @complete
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

// Ghidra: auRenderCallback @ 0x24044 — the AURenderCallback. Clear the output
// buffer, then let the voice (passed as refCon) mix its next PCM span in via
// readInto (auMixerStartIfReady).
// @complete
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
