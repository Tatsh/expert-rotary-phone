//
//  neAVCAPlayer.mm
//  pop'n rhythmin
//
//  The game's low-latency SE backend: a pool of loaded CASound sources played
//  through a CAComponent (AUGraph mixer). Both are reconstructed classes (the
//  lib_rsnd static library is not available), not imported.
//

#import "neAVCAPlayer.h"

#include <cstdlib>
#include <cstring>

#import "CAComponent.h"
#import "CASound.h"

namespace {
constexpr int kSourceGrow = 20;

// A caplayer play handle packs (voice << 16 | generation) in its low 28 bits and
// is tagged 0x20000000; decode the low 28 bits, treating a non-caplayer handle as
// invalid (0xffffffff, which every CAComponent method's voice bounds check then
// rejects). This prologue is shared by the caplayer handle forwarders (play, stop,
// voiceState, pause, and stopAndClear).
inline uint32_t caHandleBits(uint32_t handle) {
    return (handle & kCAPlayerHandleFlag) ? (handle & 0x0fffffff) : 0xffffffffu;
}
} // namespace

// The binary mallocs 0x50 bytes and NEON-zeroes them (five 16-byte vst1 stores);
// calloc(20, sizeof) is the behavioural equivalent.
void neAVCAPlayer::systemStart(int voices) {
    m_component = new CAComponent(voices);
    m_component->start();
    m_nameMap = [[NSMutableDictionary alloc] init];
    m_capacity = kSourceGrow;
    m_sources = static_cast<CASound **>(std::calloc(kSourceGrow, sizeof(CASound *)));
}

// AUGraphStop via the component.
void neAVCAPlayer::suspend() {
    if (m_component) {
        m_component->stop();
    }
}

// AUGraphStart via the component.
void neAVCAPlayer::resume() {
    if (m_component) {
        m_component->start();
    }
}

// Add a source into the first free slot, growing the array as needed. The binary
// delegates the scan and grow to a helper (grow = malloc a (capacity+20)-entry
// array, memset it to zero, memcpy the old entries in, free the old array; realloc
// plus a tail memset is the behavioural equivalent).
uint32_t neAVCAPlayer::addSource(CASound *source) {
    for (int i = 0; i < m_capacity; i++) {
        if (m_sources[i] == nullptr) {
            m_sources[i] = source;
            return static_cast<uint32_t>(i);
        }
    }
    int old = m_capacity;
    m_capacity += kSourceGrow;
    m_sources = static_cast<CASound **>(std::realloc(m_sources, m_capacity * sizeof(CASound *)));
    std::memset(m_sources + old, 0, kSourceGrow * sizeof(CASound *));
    m_sources[old] = source;
    return static_cast<uint32_t>(old);
}

// The two NSLog literals are the exact UTF-16 CFStrings the binary references (the
// failure format carries a %s that takes `path`); load() success is
// CASound::load() returning 1.
uint32_t neAVCAPlayer::load(const char *path, bool loop) {
    if (path == nullptr) {
        NSLog(@"CAPlayer load: filePathが指定されていません");
        return static_cast<uint32_t>(-1);
    }
    CASound *source = new CASound();
    if (!source->load(path, loop)) {
        NSLog(@"CAPlayer load ファイルが音楽ファイルではありません。:%s", path);
        delete source;
        return static_cast<uint32_t>(-1);
    }
    return addSource(source);
}

// The binary also NSLogs the JP CFStrings "…filePathが指定されていません" (null path)
// and "…指定された名前は既に登録済みです。" (name already
// registered); those are bare debug logs and are elided here.
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

// Reserve a mixer voice for a loaded source id.
uint32_t neAVCAPlayer::prepare(uint32_t sourceId, float volume) {
    if (static_cast<int>(sourceId) < m_capacity && m_sources[sourceId] != nullptr) {
        return m_component->reserveVoice(m_sources[sourceId], static_cast<int>(volume)) |
               kCAPlayerHandleFlag;
    }
    return static_cast<uint32_t>(-1);
}

uint32_t neAVCAPlayer::prepareNamed(const char *callName, float volume) {
    NSNumber *rid = m_nameMap[@(callName)];
    if (rid != nil) {
        return prepare(static_cast<uint32_t>(rid.intValue), volume);
    }
    return static_cast<uint32_t>(-1);
}

// Decode the handle to its low 28 bits (caHandleBits: 0xffffffff for a
// non-caplayer handle) and forward the whole value to the CAComponent play body,
// which splits voice = bits >> 16 and generation = bits & 0xffff, bounds-checks
// the voice, verifies the generation, and only moves a prepared/paused voice to
// playing.
bool neAVCAPlayer::play(uint32_t handle) {
    return m_component->startVoice(static_cast<int>(caHandleBits(handle)));
}

// Forward the decoded handle bits to the CAComponent stop body (voice = bits >> 16
// plus the generation check), which marks the voice finished.
bool neAVCAPlayer::stop(uint32_t handle) {
    return m_component->stopVoice(static_cast<int>(caHandleBits(handle)));
}

// Forward the decoded handle bits to the CAComponent state body (voice = bits >>
// 16 plus the generation check), which returns the voice state or -1.
int neAVCAPlayer::voiceState(uint32_t handle) {
    return m_component->voiceState(static_cast<int>(caHandleBits(handle)));
}

// Applied to all voices by setSeVolume:groupId:.
void neAVCAPlayer::setAllVoiceVolume(int level) {
    m_component->setAllVolume(level);
}

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

// Pause the voice named by `handle` (generation-checked). The binary passes the
// whole decoded handle to the CAComponent pause body, which splits it into
// voice = bits >> 16 and generation = bits & 0xffff.
bool neAVCAPlayer::pause(uint32_t handle) {
    return m_component->pauseVoice(static_cast<int>(caHandleBits(handle)));
}

// The binary passes the whole decoded handle to the CAComponent stop-and-clear
// body, which splits it into voice = bits >> 16 and generation = bits & 0xffff.
void neAVCAPlayer::stopAndClear(uint32_t handle) {
    m_component->stopAndClearVoice(static_cast<int>(caHandleBits(handle)));
}

// Detach a loaded source from any voice and free its PCM.
void neAVCAPlayer::unregisterSource(uint32_t sourceId) {
    if (static_cast<int>(sourceId) >= m_capacity || static_cast<int>(sourceId) < 0) {
        return;
    }
    CASound *source = m_sources[sourceId];
    if (source == nullptr) {
        return;
    }
    m_component->clearSourceRef(source); // auClearSourceRef
    source->freeBuffer();                // caSourceFreeBuffer
}

// Unregister a source by call name, then drop the name from the lookup map. (The
// binary only removes the key when unregisterSource reported a live source, an
// edge that cannot recur under the void return; the mainline behaviour is
// identical.)
void neAVCAPlayer::unregisterSourceNamed(NSString *callName) {
    NSNumber *rid = m_nameMap[callName];
    if (rid == nil) {
        return;
    }
    unregisterSource(static_cast<uint32_t>(rid.intValue));
    [m_nameMap removeObjectForKey:callName];
}

// Reserve a *fixed* mixer voice for a loaded source id.
uint32_t neAVCAPlayer::prepareAtVoice(uint32_t sourceId, int voiceIndex) {
    if (static_cast<int>(sourceId) >= m_capacity || static_cast<int>(sourceId) < 0) {
        return static_cast<uint32_t>(-1);
    }
    if (m_sources[sourceId] == nullptr) {
        return static_cast<uint32_t>(-1);
    }
    // The original also carries a volume-level argument; the SetGroup caller
    // leaves it at the default full level (0x7f).
    int handle = m_component->preparePlayer(m_sources[sourceId], voiceIndex, 0x7f);
    if (handle < 0) {
        return static_cast<uint32_t>(-1);
    }
    return static_cast<uint32_t>(handle) | kCAPlayerHandleFlag;
}

uint32_t neAVCAPlayer::prepareNamedAtVoice(NSString *callName, int voiceIndex) {
    NSNumber *rid = m_nameMap[callName];
    if (rid != nil) {
        return prepareAtVoice(static_cast<uint32_t>(rid.intValue), voiceIndex);
    }
    return static_cast<uint32_t>(-1);
}
