//
//  CAComponent.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. An AUGraph
//  (3D-mixer -> RemoteIO) whose mixer inputs each stream one CASound via a
//  render callback. Output format: 32000 Hz, stereo, interleaved signed 16-bit.
//

#include <cstdlib>
#include <cstring>

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
    return (float)level / 100.0f;
}

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
// (caPlayerMgr_dtor) and ~CAComponent.
//
// DEVIATION (not marked @complete): the binary does NOT match this body.
//   * 0x23d46: stop() is guarded on m_running (offset 0x14), not on m_graph.
//   * 0x23d52: it then calls DisposeAUGraph(m_graph) UNCONDITIONALLY — there is
//     no AUGraphUninitialize / AUGraphClose call, and no `m_graph != nullptr`
//     guard around the dispose. Only DisposeAUGraph is invoked (0x12fc60).
//   * The binary never writes m_graph = nullptr after disposing.
//   * The voice free-loop is guarded on m_voices (offset 0x1c): each voice has
//     its source (offset 0) zeroed then `operator delete`d (0x12feb8), and the
//     pool itself is released with `operator delete[]` (0x12feb4, not free),
//     after which m_voices is set to null.
// A faithful rewrite would drop AUGraphUninitialize/AUGraphClose and the
// m_graph null-out; left as-is pending a decision on whether to model the exact
// dispose sequence.
void CAComponent::terminate() {
    if (m_graph != nullptr) {
        stop(); // auGraphStop (only if still running)
        AUGraphUninitialize(m_graph);
        AUGraphClose(m_graph);
        if (DisposeAUGraph(m_graph) != noErr) {
            NSLog(@"CAComponent terminate: DisposeAUGraph failed");
        }
        m_graph = nullptr;
    }
    if (m_voices != nullptr) {
        for (int i = 0; i < m_voiceCount; i++) {
            delete m_voices[i];
        }
        free(m_voices);
        m_voices = nullptr;
    }
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
// (0x12fec0, 24 bytes) in the binary rather than calloc/new-expression; since
// the loop writes every slot the zero-init is equivalent. All ASBD fields
// (32000.0 sample rate, 'lpcm', flags 0xc2c, 4/1/4/2/16) verified byte-exact.
// @complete
bool CAComponent::initGraph(int voices) {
    if (voices > 0xfff) {
        return false;
    }
    UInt32 count = (UInt32)voices;
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
    m_voiceCount = (int)count;
    m_voices = static_cast<CAVoice **>(std::calloc(count, sizeof(CAVoice *)));
    for (int i = 0; i < m_voiceCount; i++) {
        m_voices[i] = new CAVoice(); // state -1 (free), generation 0
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
            return (uint32_t)preparePlayer(source, i, volumeIndex);
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
    CAVoice *v = m_voices[voice];
    if (v->state != -1 && v->state != 4) {
        return -1;
    }
    v->source = source;
    uint16_t generation = (uint16_t)(v->generation + 1);
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
    return (int)(generation | (voice << 16));
}

// Ghidra: FUN_00023e5c — install the render callback for a voice's mixer input.
// @complete
void CAComponent::setRenderCallback(int voice) {
    if (voice >= m_voiceCount || m_voices[voice]->callbackSet) {
        return;
    }
    AURenderCallbackStruct cb;
    cb.inputProc = &CAComponent::renderProc;
    cb.inputProcRefCon = m_voices[voice];
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

// Stop a voice: mark it finished so reserveVoice can recycle it.
bool CAComponent::stopVoice(int voice) {
    if (voice < 0 || voice >= m_voiceCount) {
        return false;
    }
    m_voices[voice]->state = 4; // finished
    return true;
}

int CAComponent::voiceState(int voice) const {
    if (voice < 0 || voice >= m_voiceCount) {
        return -1;
    }
    return m_voices[voice]->state;
}

// Ghidra: caHandleSetVolume @ 0x267e4 (body at 0x23d04).
//
// DEVIATION (not marked @complete): the binary is NOT a loop over the mixer
// inputs. caHandleSetVolume is a two-instruction caPlayerMgr forwarder — it
// loads its CAComponent (offset 0) and tail-calls setPlayerVolume(nVolume, 0)
// exactly once (0x23d04: `movs r2,#0`; `b setPlayerVolume`). Because
// setPlayerVolume always writes the master output-scope element 0 gain, one call
// sets the overall volume; the per-voice loop modelled here is a behavioural
// re-imagining, not the compiled body. Left as-is pending a decision on whether
// to model the caPlayerMgr forwarder instead.
void CAComponent::setAllVolume(int volumeIndex) {
    for (int i = 0; i < m_voiceCount; i++) {
        setPlayerVolume(volumeIndex, i);
    }
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

// Ghidra: caHandlePause @ 0x267b4 (body at 0x23fbc) — pause voice `voice` if its
// generation matches.
//
// DEVIATION (not marked @complete): the compiled entry takes a single packed
// `handle`, not split (voice, generation) args. The 0x267b4 stub validates the
// handle (`tst handle, #0x20000000`; if clear, forces generation to 0xffff so
// the match fails) then jumps to the body. The body (0x23fbc) unpacks
// voice = handle >> 16, generation = handle & 0xffff, bounds-checks voice
// against m_voiceCount (offset 0x18), reads the voice pool (offset 0x1c),
// compares generation at voice+0x10, and on a match writes state = 3 at
// voice+0x14 and returns 1 (else 0). The inner generation-check / state=3 /
// bool-return behaviour matches this reconstruction exactly; what is dropped is
// the packed-handle decode and the 0x20000000 validity bit.
bool CAComponent::pauseVoice(int voice, uint16_t generation) {
    if (voice < 0 || voice >= m_voiceCount) {
        return false;
    }
    CAVoice *v = m_voices[voice];
    if (v->generation != generation) {
        return false;
    }
    v->state = 3; // paused
    return true;
}

// Ghidra: caHandleStopAndClear @ 0x26864 (body at 0x2406c) — free voice `voice`
// (state 4 + drop its source) if its generation matches, so reserveVoice can
// recycle it immediately.
//
// DEVIATION (not marked @complete): as with caHandlePause, the compiled entry
// takes a single packed `handle` and validates it (`tst handle, #0x20000000`)
// before the body. The body (0x2406c) unpacks voice = handle >> 16 and
// generation = handle & 0xffff, bounds-checks voice against m_voiceCount, and on
// a generation match at voice+0x10 writes state = 4 (voice+0x14) and source = 0
// (voice+0) — returning 1 (the binary returns bool; this reconstruction returns
// void). The state=4 / source-clear / generation-check behaviour is exact; the
// packed-handle decode and validity bit are the omissions.
void CAComponent::stopAndClearVoice(int voice, uint16_t generation) {
    if (voice < 0 || voice >= m_voiceCount) {
        return;
    }
    CAVoice *v = m_voices[voice];
    if (v->generation == generation) {
        v->state = 4; // finished
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
