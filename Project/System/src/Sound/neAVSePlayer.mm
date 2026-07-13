//
//  neAVSePlayer.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (FUN_00020xxx
//  / FUN_00021xxx). The AVFoundation SE backend: loaded sources are kept as
//  AVSource descriptors and played on a pool of AVBus voices (the reconstructed
//  AVAudioPlayer wrapper). The original stored the voice pool + a call-name map
//  + a growable source table in one flat object; here the tables are modelled
//  with ARC collections (NSNull marks a freed source slot) rather than raw C
//  arrays.
//

#import <AVFoundation/AVFoundation.h>

#import "AVBus.h"
#import "neAVSePlayer.h"

// A loaded source held by the SE table: owns the URL / data (Ghidra:
// soundSourceInit copies the URL; soundSourceRelease releases it) and vends a
// stable AVSource the voices point at. The AVSource's url/data are
// __unsafe_unretained, so this object must outlive any voice using it — the
// source table (m_sources) keeps it alive until the slot is freed.
@interface neSeSource : NSObject {
@public
    AVSource av; // av.url / av.data alias the strong properties below; av.loop is
                 // the loop flag
}
@property(nonatomic, strong) NSURL *url;
@property(nonatomic, strong) NSData *data;
- (instancetype)initWithURL:(NSURL *)url loop:(BOOL)loop;
@end
@implementation neSeSource
// Ghidra: soundSourceInit @ 0x239c0 — copy the source's URL and record its loop
// flag (the data slot stays nil). The URL copy is owned by this object, so the
// __unsafe_unretained av.url stays valid for as long as the source table keeps
// this descriptor alive.
- (instancetype)initWithURL:(NSURL *)url loop:(BOOL)loop {
    if ((self = [super init])) {
        _url = [url copy];
        av.url = _url;
        av.data = nil;
        av.loop = loop;
    }
    return self;
}
@end

namespace {
constexpr float kAVSeVolumeScale = 127.0f; // Ghidra: DAT_00020f84 (raw 0..127 -> 0..1)
}

// Ghidra: soundEngine_ctor @ 0x2120c -> audioMixerInit @ 0x20d1c. Build the
// AVBus voice pool and the (empty) source table + name map.
void neAVSePlayer::systemStart(int voices) {
    m_voiceCount = voices;
    m_buses = [[NSMutableArray alloc] init];
    for (int i = 0; i < voices; i++) {
        [m_buses addObject:[[AVBus alloc] init]];
    }
    m_nameMap = [[NSMutableDictionary alloc] init];
    m_sources = [[NSMutableArray alloc] init];
}

// Ghidra: audioMixerDtor @ 0x212a0 (the source table + name map teardown; the
// AVBus pool and its array are released here too under ARC).
neAVSePlayer::~neAVSePlayer() {
    m_sources = nil;
    m_nameMap = nil;
    m_buses = nil;
}

// Register a new source: build its descriptor (soundSourceInit) and drop it
// into a reserved slot (allocSoundSlot), mirroring registerSound @ 0x212d0
// (soundSourceInit + allocSoundSlot + store).
int neAVSePlayer::addSource(NSURL *url, bool loop) {
    neSeSource *source = [[neSeSource alloc] initWithURL:url loop:loop];
    int slot = allocSoundSlot();
    m_sources[slot] = source;
    return slot;
}

// Ghidra: allocSoundSlot @ 0x21510 — return the index of the first free source
// slot, appending an empty one when the table is full. The binary grows a raw
// pointer array in blocks of 20 and hands back the old element count; the ARC
// table (NSNull marks a free slot) grows one element at a time, which is
// behaviourally identical to callers.
int neAVSePlayer::allocSoundSlot() {
    for (NSUInteger i = 0; i < m_sources.count; i++) {
        if (m_sources[i] == NSNull.null) {
            return (int)i;
        }
    }
    [m_sources addObject:NSNull.null];
    return (int)(m_sources.count - 1);
}

// Ghidra: registerSound @ 0x212d0.
int neAVSePlayer::load(NSURL *url, bool loop) {
    if (url == nil) {
        NSLog(@"AVSePlayer load: null url");
        return -1;
    }
    return addSource(url, loop);
}

// Ghidra: registerSoundNamed @ 0x21328.
int neAVSePlayer::loadNamed(NSURL *url, NSString *callName, bool loop) {
    if (m_nameMap[callName] != nil) {
        NSLog(@"AVSePlayer loadNamed: already registered");
        return 0;
    }
    int rid = load(url, loop);
    if (rid < 0) {
        return 0;
    }
    m_nameMap[callName] = @(rid);
    return 1;
}

// Ghidra: findFreeAudioBus @ 0x20f88 / isAudioBusFree @ 0x21114 — the first
// voice whose status is free (none / stopped) or merely prepared (a playing or
// paused voice is busy); -1 if none.
static int findFreeBus(NSArray *buses, int count) {
    for (int i = 0; i < count; i++) {
        AVBus *bus = buses[i];
        int status = [bus status];
        bool free = (status == -1 || status == 4) || (status == 1);
        if (free) {
            return i;
        }
    }
    return -1;
}

// Ghidra: getAudioBusForHandle @ 0x20fd8 — resolve a (voice << 16 | generation)
// play handle to its live AVBus voice: the high 16 bits pick the voice, the low
// 16 must still match the voice's currentID (a recycled voice bumps its id, so
// a stale handle resolves to nil). `this` is the AVBus voice pool (Ghidra: the
// audioMixer object, +4 = voiceCount, +8 = voice array). The AVFoundation
// routing flag the AudioManager packs into the handle is masked off here so
// callers can pass the raw play handle straight through.
AVBus *neAVSePlayer::busForHandle(uint32_t handle) {
    uint32_t bits = (handle & kAVSePlayerHandleFlag) ? (handle & 0x0fffffff) : 0xffffffffu;
    int index = (int)(bits >> 16);
    if (index < 0 || index >= m_voiceCount) {
        return nil;
    }
    AVBus *bus = m_buses[index];
    return ([bus currentID] == (uint16_t)(bits & 0xffff)) ? bus : nil;
}

// Ghidra: audioPlaySource @ 0x20ed8 — grab a free voice, (re)load the source
// onto it, prepare it, pack the play handle (voice << 16 | id) and apply the
// volume. Returns -1 when the pool is full.
static uint32_t audioPlaySource(NSArray *buses, int count, neSeSource *source, float volume) {
    int busIndex = findFreeBus(buses, count);
    if (busIndex == -1) {
        return (uint32_t)-1;
    }
    AVBus *bus = buses[busIndex];
    [bus removeSource];
    uint16_t id = [bus setSource:&source->av];
    [bus prepare];
    uint32_t handle = (uint32_t)id | ((uint32_t)busIndex << 16);
    // The voice just grabbed is exactly the one this handle resolves to, so set
    // its volume directly (equivalent to re-resolving via getAudioBusForHandle).
    [bus setVolume:volume / kAVSeVolumeScale];
    return handle;
}

// Ghidra: playSoundByIndex @ 0x21438.
uint32_t neAVSePlayer::prepare(uint32_t sourceId, float volume) {
    if ((int)sourceId >= (int)m_sources.count) {
        return 0;
    }
    id slot = m_sources[sourceId];
    if (slot == NSNull.null) {
        return (uint32_t)-1;
    }
    return audioPlaySource(m_buses, m_voiceCount, (neSeSource *)slot, volume) |
           kAVSePlayerHandleFlag;
}

// Ghidra: playSoundNamed @ 0x21464.
uint32_t neAVSePlayer::prepareNamed(NSString *callName, float volume) {
    NSNumber *rid = m_nameMap[callName];
    if (rid != nil) {
        return prepare((uint32_t)rid.intValue, volume);
    }
    return 0;
}

// Ghidra: audioHandlePlay @ 0x214a8.
bool neAVSePlayer::play(uint32_t handle) {
    AVBus *bus = busForHandle(handle);
    if (bus != nil) {
        [bus play];
        return true;
    }
    return false;
}

// Ghidra: audioHandleStop @ 0x214c0.
bool neAVSePlayer::stop(uint32_t handle) {
    AVBus *bus = busForHandle(handle);
    if (bus != nil) {
        [bus stop];
        return true;
    }
    return false;
}

// Ghidra: audioHandlePause @ 0x214d8.
bool neAVSePlayer::pause(uint32_t handle) {
    AVBus *bus = busForHandle(handle);
    if (bus != nil) {
        [bus pause];
        return true;
    }
    return false;
}

// Ghidra: audioHandleStopAndRemove @ 0x21588.
void neAVSePlayer::stopAndRemove(uint32_t handle) {
    AVBus *bus = busForHandle(handle);
    if (bus != nil) {
        [bus stop];
        [bus removeSource];
    }
}

// Ghidra: audioHandleGetStatus @ 0x214f0.
int neAVSePlayer::voiceState(uint32_t handle) {
    AVBus *bus = busForHandle(handle);
    if (bus == nil) {
        return -1;
    }
    return [bus status];
}

// Ghidra: audioRemoveSourceAll @ 0x21168 — detach `source` from every voice
// still holding it.
static void audioRemoveSourceAll(NSArray *buses, int count, neSeSource *source) {
    for (int i = 0; i < count; i++) {
        AVBus *bus = buses[i];
        if ([bus isSameSource:&source->av]) {
            [bus removeSource];
        }
    }
}

// Ghidra: unregisterSound @ 0x213d4.
void neAVSePlayer::unregisterSource(uint32_t sourceId) {
    if ((int)sourceId >= (int)m_sources.count) {
        return;
    }
    id slot = m_sources[sourceId];
    if (slot == NSNull.null) {
        return;
    }
    audioRemoveSourceAll(m_buses, m_voiceCount, (neSeSource *)slot);
    // soundSourceRelease (@ 0x239e4): release the source's URL/data; freeing the
    // slot here also drops the descriptor (ARC releases the neSeSource and, with
    // it, the copied URL).
    m_sources[sourceId] = NSNull.null;
}

// Ghidra: unregisterSoundNamed @ 0x213fc.
void neAVSePlayer::unregisterSourceNamed(NSString *callName) {
    NSNumber *rid = m_nameMap[callName];
    if (rid != nil) {
        unregisterSource((uint32_t)rid.intValue);
    }
}

// Set the volume of every AVBus voice.
void neAVSePlayer::setGroupVolume(float volume) {
    for (AVBus *bus in m_buses) {
        [bus setVolume:volume];
    }
}

// Ghidra: audioPauseAll @ 0x21288 — pause every voice.
void neAVSePlayer::suspend() {
    for (AVBus *bus in m_buses) {
        [bus pause];
    }
}

// Ghidra: audioResumeAll @ 0x21294 — resume every paused voice.
void neAVSePlayer::resume() {
    for (AVBus *bus in m_buses) {
        [bus offPause];
    }
}
