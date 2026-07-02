//
//  CAComponent.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. An AUGraph
//  (3D-mixer -> RemoteIO) whose mixer inputs each stream one CASound via a render
//  callback. Output format: 44100 Hz, stereo, interleaved signed 16-bit.
//

#include <cstdlib>
#include <cstring>

#import "CAComponent.h"
#import "CASound.h"

namespace {

// Per-voice mixer gains, indexed by the caller's volume level. Ghidra:
// DAT_0012e3c8 (a float gain table). Modelled as a normalised 0..1 ramp; the
// exact table values live at that address if a byte-accurate copy is needed.
float caGainForLevel(int level) {
    if (level < 0) level = 0;
    if (level > 100) level = 100;
    return (float)level / 100.0f;
}

}  // namespace

CAComponent::CAComponent(int voices) {
    if (prepareGraph()) {
        initGraph(voices);
    }
}

CAComponent::~CAComponent() {
    if (m_graph != nullptr) {
        AUGraphStop(m_graph);
        AUGraphUninitialize(m_graph);
        AUGraphClose(m_graph);
        DisposeAUGraph(m_graph);
    }
    if (m_voices != nullptr) {
        for (int i = 0; i < m_voiceCount; i++) {
            delete m_voices[i];
        }
        free(m_voices);
    }
}

// Ghidra: FUN_00023a6c — build the AUGraph: a 3D-mixer feeding RemoteIO output.
bool CAComponent::prepareGraph() {
    AudioComponentDescription outDesc = {
        kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple, 0, 0
    };
    AudioComponentDescription mixDesc = {
        kAudioUnitType_Mixer, kAudioUnitSubType_AU3DMixerEmbedded, kAudioUnitManufacturer_Apple, 0, 0
    };

    if (NewAUGraph(&m_graph) != noErr) {
        NSLog(@"CAComponent prepareGraph: NewAUGraph failed"); return false;
    }
    if (AUGraphAddNode(m_graph, &outDesc, &m_ioNode) != noErr) {
        NSLog(@"CAComponent prepareGraph: AUGraphAddNode remoteIO failed"); return false;
    }
    if (AUGraphAddNode(m_graph, &mixDesc, &m_mixerNode) != noErr) {
        NSLog(@"CAComponent prepareGraph: AUGraphAddNode mixer failed"); return false;
    }
    if (AUGraphConnectNodeInput(m_graph, m_mixerNode, 0, m_ioNode, 0) != noErr) {
        NSLog(@"CAComponent prepareGraph: AUGraphConnectNodeInput failed"); return false;
    }
    if (AUGraphOpen(m_graph) != noErr) {
        NSLog(@"CAComponent prepareGraph: AUGraphOpen failed"); return false;
    }
    if (AUGraphNodeInfo(m_graph, m_ioNode, nullptr, &m_ioUnit) != noErr) {
        NSLog(@"CAComponent prepareGraph: AUGraphNodeInfo remoteIO failed"); return false;
    }
    if (AUGraphNodeInfo(m_graph, m_mixerNode, nullptr, &m_mixerUnit) != noErr) {
        NSLog(@"CAComponent prepareGraph: AUGraphNodeInfo mixer failed"); return false;
    }
    return true;
}

// Ghidra: FUN_00023b74 — size the mixer, allocate the voices, set the output
// format, then initialise the graph.
bool CAComponent::initGraph(int voices) {
    if (voices > 0xfff) {
        return false;
    }
    UInt32 count = (UInt32)voices;
    if (AudioUnitSetProperty(m_mixerUnit, kAudioUnitProperty_ElementCount,
                             kAudioUnitScope_Input, 0, &count, sizeof(count)) != noErr) {
        NSLog(@"CAComponent initGraph: ElementCount failed");
        m_voiceCount = 0;
        return false;
    }
    m_voiceCount = (int)count;
    m_voices = static_cast<CAVoice **>(std::calloc(count, sizeof(CAVoice *)));
    for (int i = 0; i < m_voiceCount; i++) {
        m_voices[i] = new CAVoice();   // state -1 (free), generation 0
    }

    AudioStreamBasicDescription out = {};
    out.mSampleRate = 44100.0;
    out.mFormatID = kAudioFormatLinearPCM;
    out.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;  // raw 0xc2c
    out.mBytesPerPacket = 4;
    out.mFramesPerPacket = 1;
    out.mBytesPerFrame = 4;
    out.mChannelsPerFrame = 2;
    out.mBitsPerChannel = 16;
    if (AudioUnitSetProperty(m_ioUnit, kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, 0, &out, sizeof(out)) != noErr) {
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

// Ghidra: FUN_000261e0.
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

// Ghidra: FUN_00023dac — bind `source` to voice `voice`: set the input stream
// format, install the render callback, set volume, mark it playing.
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
    if (AudioUnitSetProperty(m_mixerUnit, kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, voice, &in, sizeof(in)) != noErr) {
        NSLog(@"CAComponent preparePlayer: input stream format failed");
        return -1;
    }

    setRenderCallback(voice);
    setPlayerVolume(volumeIndex, voice);
    v->playPos = 0;
    v->state = 1;   // playing
    return (int)(generation | (voice << 16));
}

// Ghidra: FUN_00023e5c — install the render callback for a voice's mixer input.
void CAComponent::setRenderCallback(int voice) {
    if (voice >= m_voiceCount || m_voices[voice]->callbackSet) {
        return;
    }
    AURenderCallbackStruct cb;
    cb.inputProc = &CAComponent::renderProc;
    cb.inputProcRefCon = m_voices[voice];
    if (AudioUnitSetProperty(m_mixerUnit, kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input, voice, &cb, sizeof(cb)) == noErr) {
        m_voices[voice]->callbackSet = true;
    } else {
        NSLog(@"CAComponent setRenderCallback: SetRenderCallback failed");
    }
}

// Ghidra: FUN_00023eb0 — set a voice's mixer gain from the volume table.
bool CAComponent::setPlayerVolume(int volumeIndex, int voice) {
    if (voice >= m_voiceCount) {
        return false;
    }
    if (AudioUnitSetParameter(m_mixerUnit, 3 /* gain */, kAudioUnitScope_Output,
                              voice, caGainForLevel(volumeIndex), 0) != noErr) {
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
    m_voices[voice]->state = 4;   // finished
    return true;
}

int CAComponent::voiceState(int voice) const {
    if (voice < 0 || voice >= m_voiceCount) {
        return -1;
    }
    return m_voices[voice]->state;
}

// Ghidra: FUN_000267e4 applied across the mixer inputs.
void CAComponent::setAllVolume(int volumeIndex) {
    for (int i = 0; i < m_voiceCount; i++) {
        setPlayerVolume(volumeIndex, i);
    }
}

// Ghidra: FUN_00024044 — the AURenderCallback: copy this voice's PCM into the
// mixer, looping or finishing at the end of the source buffer.
OSStatus CAComponent::renderProc(void *refCon, AudioUnitRenderActionFlags *flags,
                                 const AudioTimeStamp *, UInt32, UInt32 /*frames*/,
                                 AudioBufferList *data) {
    CAVoice *v = static_cast<CAVoice *>(refCon);
    CASound *source = v->source;
    AudioBuffer &out = data->mBuffers[0];

    if (source == nullptr || v->state != 1) {
        std::memset(out.mData, 0, out.mDataByteSize);
        if (flags) *flags |= kAudioUnitRenderAction_OutputIsSilence;
        return noErr;
    }

    const uint8_t *src = static_cast<const uint8_t *>(source->buffer());
    UInt32 total = source->bufferSize();
    uint8_t *dst = static_cast<uint8_t *>(out.mData);
    UInt32 want = out.mDataByteSize;
    UInt32 written = 0;

    while (written < want) {
        UInt32 avail = total - v->playPos;
        UInt32 chunk = (avail < want - written) ? avail : (want - written);
        std::memcpy(dst + written, src + v->playPos, chunk);
        written += chunk;
        v->playPos += chunk;
        if (v->playPos >= total) {
            if (source->isLoop()) {
                v->playPos = 0;   // wrap
            } else {
                std::memset(dst + written, 0, want - written);   // pad silence
                v->state = 4;     // finished -> voice becomes reusable
                break;
            }
        }
    }
    return noErr;
}
