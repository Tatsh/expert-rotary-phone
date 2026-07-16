//
//  neAVCAPlayer.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (FUN_00026xxx). The game's low-latency SE backend: a pool of loaded CASound
//  sources played through a CAComponent (AUGraph mixer). Both are reconstructed
//  classes (the lib_rsnd static library is not available), not imported.
//

#include <cstdlib>
#include <cstring>

#import "CAComponent.h"
#import "CASound.h"
#import "neAVCAPlayer.h"

namespace {
constexpr int kSourceGrow = 20;
}

// Ghidra: FUN_0002615c. The binary mallocs 0x50 bytes and NEON-zeroes them (five
// 16-byte vst1 stores); calloc(20, sizeof) is the behavioural equivalent.
// @complete
void neAVCAPlayer::systemStart(int voices) {
    m_component = new CAComponent(voices);
    m_component->start();
    m_nameMap = [[NSMutableDictionary alloc] init];
    m_capacity = kSourceGrow;
    m_sources = static_cast<CASound **>(std::calloc(kSourceGrow, sizeof(CASound *)));
}

// Ghidra: FUN_000261e0 — AUGraphStop via the component.
// @complete
void neAVCAPlayer::suspend() {
    if (m_component) {
        m_component->stop();
    }
}

// Ghidra: FUN_000261ec — AUGraphStart via the component.
// @complete
void neAVCAPlayer::resume() {
    if (m_component) {
        m_component->start();
    }
}

// Add a source into the first free slot, growing the array as needed. Ghidra:
// FUN_0002644c, which delegates the scan/grow to FUN_000267ec (grow = malloc a
// (capacity+20)-entry array, memset it to zero, memcpy the old entries in, free
// the old array — realloc + tail memset is the behavioural equivalent).
// @complete
uint32_t neAVCAPlayer::addSource(CASound *source) {
    for (int i = 0; i < m_capacity; i++) {
        if (m_sources[i] == nullptr) {
            m_sources[i] = source;
            return (uint32_t)i;
        }
    }
    int old = m_capacity;
    m_capacity += kSourceGrow;
    m_sources = static_cast<CASound **>(std::realloc(m_sources, m_capacity * sizeof(CASound *)));
    std::memset(m_sources + old, 0, kSourceGrow * sizeof(CASound *));
    m_sources[old] = source;
    return (uint32_t)old;
}

// Ghidra: FUN_00026320.
// The two NSLog literals are the exact UTF-16 CFStrings the binary references
// (@ 0x135538 / the failure format @ 0x135548, the latter carrying a %s that
// takes `path`); load() success is CASound::load() returning 1.
// @complete
uint32_t neAVCAPlayer::load(const char *path, bool loop) {
    if (path == nullptr) {
        NSLog(@"CAPlayer load: filePathが指定されていません");
        return (uint32_t)-1;
    }
    CASound *source = new CASound();
    if (!source->load(path, loop)) {
        NSLog(@"CAPlayer load ファイルが音楽ファイルではありません。:%s", path);
        delete source;
        return (uint32_t)-1;
    }
    return addSource(source);
}

// Ghidra: FUN_0002648c. The binary also NSLogs the JP CFStrings "…filePathが指
// 定されていません" (null path) and "…指定された名前は既に登録済みです。" (name already
// registered @ 0x135558); those are bare debug logs and are elided here.
// @complete
uint32_t neAVCAPlayer::loadNamed(const char *path, const char *callName, bool loop) {
    NSString *key = @(callName);
    if (m_nameMap[key] != nil) {
        return 0;
    }
    CASound *source = new CASound();
    if (!source->load(path, loop)) {
        delete source;
        return 0;
    }
    uint32_t rid = addSource(source);
    m_nameMap[key] = @(rid);
    return 1;
}

// Ghidra: FUN_0002669c — reserve a mixer voice for a loaded source id.
// @complete
uint32_t neAVCAPlayer::prepare(uint32_t sourceId, float volume) {
    if ((int)sourceId < m_capacity && m_sources[sourceId] != nullptr) {
        return m_component->reserveVoice(m_sources[sourceId], (int)volume) | kCAPlayerHandleFlag;
    }
    return (uint32_t)-1;
}

// Ghidra: FUN_000266f8.
// @complete
uint32_t neAVCAPlayer::prepareNamed(const char *callName, float volume) {
    NSNumber *rid = m_nameMap[@(callName)];
    if (rid != nil) {
        return prepare((uint32_t)rid.intValue, volume);
    }
    return (uint32_t)-1;
}

// Ghidra: FUN_00026784.
// DEVIATION (not @complete): the binary does NOT bounds-check against
// m_capacity/m_sources. It decodes the handle to caHandleBits(handle) (the low
// 28 bits, or 0xffffffff for a non-caplayer handle) and tail-calls a CAComponent
// method @ 0x23f5c with that whole value; the component internally extracts
// voice = bits >> 16 and generation = bits & 0xffff, bounds-checks the voice,
// verifies the generation, and — only if the voice is prepared (state 1) or
// paused (state 3) — sets it playing (state 2), returning that success bool. The
// reconstruction instead performs a local slot bounds/null check and never calls
// the component, so it neither starts the voice nor honours the state machine.
// Faithful form would be `return m_component->startVoice(caHandleBits(handle));`,
// but CAComponent.h declares no such method (its stopVoice/voiceState/pauseVoice
// signatures likewise take a pre-split voice index rather than the raw handle the
// binary passes), so fixing it correctly is a CAComponent.h change out of scope
// for this file.
bool neAVCAPlayer::play(uint32_t handle) {
    if ((handle & kCAPlayerHandleFlag) == 0) {
        return false;
    }
    uint32_t voice = (handle & 0x0fffffff) >> 16;
    if ((int)voice >= m_capacity || m_sources[voice] == nullptr) {
        return false;
    }
    return true;
}

// Ghidra: FUN_0002679c.
// DEVIATION (not @complete): the binary passes the *whole* decoded handle
// (caHandleBits(handle) = the low 28 bits, or 0xffffffff for a non-caplayer
// handle) to the CAComponent method @ 0x23f90, which itself does voice =
// bits >> 16 AND a generation check (bits & 0xffff vs the slot's stored
// generation). The reconstruction pre-shifts to a voice index and drops the
// generation, so a stale handle would not be rejected. Faithful form passes the
// unshifted handle bits; CAComponent.h's stopVoice(int voice) signature would
// need to become stopVoice(uint32_t handle) to match (out of scope here).
bool neAVCAPlayer::stop(uint32_t handle) {
    return m_component->stopVoice((int)((handle & 0x0fffffff) >> 16));
}

// Ghidra: FUN_000267cc.
// DEVIATION (not @complete): as with stop(), the binary passes the whole decoded
// handle (caHandleBits(handle)) to the CAComponent method @ 0x23fe8, which does
// voice = bits >> 16 plus a generation check (bits & 0xffff). The reconstruction
// pre-shifts to a voice index and drops the generation, so a stale handle is not
// rejected. Faithful form passes the unshifted handle bits (CAComponent.h's
// voiceState(int voice) signature would need widening — out of scope here).
int neAVCAPlayer::voiceState(uint32_t handle) {
    return m_component->voiceState((int)((handle & 0x0fffffff) >> 16));
}

// Ghidra: FUN_000267e4 (applied to all voices by setSeVolume:groupId:).
// @complete
void neAVCAPlayer::setAllVoiceVolume(int level) {
    m_component->setAllVolume(level);
}

namespace {
// A caplayer play handle packs (voice << 16 | generation) in its low 28 bits
// and is tagged 0x20000000; decode the voice index / generation, treating a
// non-caplayer handle as invalid.
inline uint32_t caHandleBits(uint32_t handle) {
    return (handle & kCAPlayerHandleFlag) ? (handle & 0x0fffffff) : 0xffffffffu;
}
} // namespace

// Ghidra: caPlayerMgr_dtor @ 0x261f8.
// @complete
neAVCAPlayer::~neAVCAPlayer() {
    if (m_component != nullptr) {
        m_component->terminate(); // auGraphTerminate
        delete m_component;
        m_component = nullptr;
    }
    if (m_sources != nullptr) {
        for (int i = 0; i < m_capacity; i++) {
            CASound *source = m_sources[i];
            if (source != nullptr) {
                source->freeBuffer(); // caSourceFreeBuffer
                delete source;        // caSource_dtor + operator_delete
                m_sources[i] = nullptr;
            }
        }
        std::free(m_sources);
        m_sources = nullptr;
    }
    m_nameMap = nil; // ARC releases the name map
}

// Ghidra: caHandlePause @ 0x267b4 — pause the voice named by `handle`
// (generation-checked). The binary passes the whole decoded handle to the
// CAComponent method @ 0x23fbc, which splits it into voice = bits >> 16 and
// generation = bits & 0xffff; the two-argument pauseVoice(voice, generation)
// here carries exactly that decoded pair.
// @complete
bool neAVCAPlayer::pause(uint32_t handle) {
    const uint32_t bits = caHandleBits(handle);
    return m_component->pauseVoice((int)(bits >> 16), (uint16_t)(bits & 0xffff));
}

// Ghidra: caHandleStopAndClear @ 0x26864. The binary passes the whole decoded
// handle to the CAComponent method @ 0x2406c, which splits it into voice =
// bits >> 16 and generation = bits & 0xffff; the two-argument
// stopAndClearVoice(voice, generation) here carries exactly that decoded pair.
// @complete
void neAVCAPlayer::stopAndClear(uint32_t handle) {
    const uint32_t bits = caHandleBits(handle);
    m_component->stopAndClearVoice((int)(bits >> 16), (uint16_t)(bits & 0xffff));
}

// Ghidra: caUnregisterSource @ 0x26610 — detach a loaded source from any voice
// and free its PCM.
// @complete
void neAVCAPlayer::unregisterSource(uint32_t sourceId) {
    if ((int)sourceId >= m_capacity || (int)sourceId < 0) {
        return;
    }
    CASound *source = m_sources[sourceId];
    if (source == nullptr) {
        return;
    }
    m_component->clearSourceRef(source); // auClearSourceRef
    source->freeBuffer();                // caSourceFreeBuffer
}

// Ghidra: caUnregisterSourceNamed @ 0x26644 — unregister a source by call name,
// then drop the name from the lookup map. (The binary only removes the key when
// unregisterSource reported a live source, an edge that cannot recur under the
// void return; the mainline behaviour is identical.)
// @complete
void neAVCAPlayer::unregisterSourceNamed(NSString *callName) {
    NSNumber *rid = m_nameMap[callName];
    if (rid == nil) {
        return;
    }
    unregisterSource((uint32_t)rid.intValue);
    [m_nameMap removeObjectForKey:callName];
}

// Ghidra: caPrepareSourceByIndex @ 0x266c0 — reserve a *fixed* mixer voice for
// a loaded source id.
// @complete
uint32_t neAVCAPlayer::prepareAtVoice(uint32_t sourceId, int voiceIndex) {
    if ((int)sourceId >= m_capacity || (int)sourceId < 0) {
        return (uint32_t)-1;
    }
    if (m_sources[sourceId] == nullptr) {
        return (uint32_t)-1;
    }
    // The original also carries a volume-level argument; the SetGroup caller
    // leaves it at the default full level (0x7f).
    int handle = m_component->preparePlayer(m_sources[sourceId], voiceIndex, 0x7f);
    if (handle < 0) {
        return (uint32_t)-1;
    }
    return (uint32_t)handle | kCAPlayerHandleFlag;
}

// Ghidra: caPrepareSourceNamed @ 0x2673c.
// @complete
uint32_t neAVCAPlayer::prepareNamedAtVoice(NSString *callName, int voiceIndex) {
    NSNumber *rid = m_nameMap[callName];
    if (rid != nil) {
        return prepareAtVoice((uint32_t)rid.intValue, voiceIndex);
    }
    return (uint32_t)-1;
}
