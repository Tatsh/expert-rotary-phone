//
//  neAVCAPlayer.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (FUN_00026xxx).
//  The game's low-latency SE backend: a pool of loaded CASound sources played
//  through a CAComponent (AUGraph mixer). Both are reconstructed classes (the
//  lib_rsnd static library is not available), not imported.
//

#include <cstdlib>
#include <cstring>

#import "CAComponent.h"
#import "CASound.h"
#import "neAVCAPlayer.h"

namespace {
constexpr int kSourceGrow = 20;
}

// Ghidra: FUN_0002615c.
void neAVCAPlayer::systemStart(int voices) {
    m_component = new CAComponent(voices);
    m_component->start();
    m_nameMap = [[NSMutableDictionary alloc] init];
    m_capacity = kSourceGrow;
    m_sources = static_cast<CASound **>(std::calloc(kSourceGrow, sizeof(CASound *)));
}

// Ghidra: FUN_000261e0 — AUGraphStop via the component.
void neAVCAPlayer::suspend() {
    if (m_component) {
        m_component->stop();
    }
}

// Ghidra: FUN_000261ec — AUGraphStart via the component.
void neAVCAPlayer::resume() {
    if (m_component) {
        m_component->start();
    }
}

// Add a source into the first free slot, growing the array as needed. Ghidra:
// FUN_0002644c.
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
uint32_t neAVCAPlayer::load(const char *path, bool loop) {
    if (path == nullptr) {
        NSLog(@"CAComponent load: null path");
        return (uint32_t)-1;
    }
    CASound *source = new CASound();
    if (!source->load(path, loop)) {
        NSLog(@"CAComponent load failed");
        delete source;
        return (uint32_t)-1;
    }
    return addSource(source);
}

// Ghidra: FUN_0002648c.
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
uint32_t neAVCAPlayer::prepare(uint32_t sourceId, float volume) {
    if ((int)sourceId < m_capacity && m_sources[sourceId] != nullptr) {
        return m_component->reserveVoice(m_sources[sourceId], (int)volume) | kCAPlayerHandleFlag;
    }
    return (uint32_t)-1;
}

// Ghidra: FUN_000266f8.
uint32_t neAVCAPlayer::prepareNamed(const char *callName, float volume) {
    NSNumber *rid = m_nameMap[@(callName)];
    if (rid != nil) {
        return prepare((uint32_t)rid.intValue, volume);
    }
    return (uint32_t)-1;
}

// Ghidra: FUN_00026784 — the voice is already streaming once reserved; a stale
// generation (low 16 bits) or a non-caplayer handle is rejected.
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
