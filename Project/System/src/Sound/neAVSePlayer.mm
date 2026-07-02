//
//  neAVSePlayer.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (FUN_00021xxx).
//  The AVFoundation SE backend: loaded sources are kept as URLs and played on a
//  pool of AVAudioPlayer "voices" (the original AVBus voice class, reconstructed
//  here directly on AVAudioPlayer since lib_rsnd is not available).
//

#import <AVFoundation/AVFoundation.h>

#import "neAVSePlayer.h"

// A single voice: an AVAudioPlayer plus the generation counter packed into a play
// handle so a stale handle can't restart a recycled voice.
@interface neAVSeVoice : NSObject
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic) uint16_t generation;
@property (nonatomic) uint16_t currentID;   // generation currently loaded (Ghidra: currentID)
@end
@implementation neAVSeVoice
@end

namespace {
constexpr int kVoiceGrow = 20;
}

// Ghidra: FUN_0002120c.
void neAVSePlayer::systemStart(int voices) {
    m_nameMap = [[NSMutableDictionary alloc] init];
    m_sources = [[NSMutableArray alloc] init];
    m_capacity = voices > 0 ? voices : kVoiceGrow;
    m_voices = [[NSMutableArray alloc] initWithCapacity:m_capacity];
    for (int i = 0; i < m_capacity; i++) {
        [m_voices addObject:[[neAVSeVoice alloc] init]];
    }
}

// Ghidra: FUN_00021510 — take the first free source slot (growing the array).
int neAVSePlayer::addSource(NSURL *url, bool loop) {
    NSDictionary *source = @{ @"url": url, @"loop": @(loop) };
    for (NSUInteger i = 0; i < m_sources.count; i++) {
        if (m_sources[i] == NSNull.null) {
            m_sources[i] = source;
            return (int)i;
        }
    }
    [m_sources addObject:source];
    return (int)(m_sources.count - 1);
}

// Ghidra: FUN_000212d0.
int neAVSePlayer::load(NSURL *url, bool loop) {
    if (url == nil) {
        NSLog(@"AVSePlayer load: null url");
        return -1;
    }
    // Validate the URL is playable up front (Ghidra: FUN_000239c0 init).
    NSError *error = nil;
    AVAudioPlayer *probe = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (probe == nil || error != nil) {
        return -1;
    }
    return addSource(url, loop);
}

// Ghidra: FUN_00021328.
int neAVSePlayer::loadNamed(NSURL *url, NSString *callName, bool loop) {
    if (m_nameMap[callName] != nil) {
        return 0;
    }
    int rid = load(url, loop);
    if (rid < 0) {
        return 0;
    }
    m_nameMap[callName] = @(rid);
    return 1;
}

// Ghidra: FUN_00021438 — reserve a free voice for a loaded source id and load it.
uint32_t neAVSePlayer::prepare(uint32_t sourceId, float volume) {
    if ((int)sourceId >= (int)m_sources.count || m_sources[sourceId] == NSNull.null) {
        return (uint32_t)-1;
    }
    NSDictionary *source = m_sources[sourceId];
    for (NSUInteger i = 0; i < m_voices.count; i++) {
        neAVSeVoice *voice = m_voices[i];
        if (voice.player == nil || !voice.player.isPlaying) {
            NSError *error = nil;
            voice.player = [[AVAudioPlayer alloc] initWithContentsOfURL:source[@"url"] error:&error];
            if (voice.player == nil) {
                return (uint32_t)-1;
            }
            voice.player.numberOfLoops = [source[@"loop"] boolValue] ? -1 : 0;
            voice.player.volume = volume;
            [voice.player prepareToPlay];
            voice.generation = (uint16_t)(voice.generation + 1);
            voice.currentID = voice.generation;
            return ((uint32_t)i << 16 | voice.generation) | kAVSePlayerHandleFlag;
        }
    }
    return (uint32_t)-1;
}

// Ghidra: FUN_00021464.
uint32_t neAVSePlayer::prepareNamed(NSString *callName, float volume) {
    NSNumber *rid = m_nameMap[callName];
    if (rid != nil) {
        return prepare((uint32_t)rid.intValue, volume);
    }
    return (uint32_t)-1;
}

// Ghidra: FUN_00020fd8 — resolve a handle to its live voice (matching generation).
static neAVSeVoice *voiceForHandle(NSArray *voices, uint32_t handle) {
    uint32_t index = (handle & 0x0fffffff) >> 16;
    if (index >= voices.count) {
        return nil;
    }
    neAVSeVoice *voice = voices[index];
    return (voice.currentID == (handle & 0xffff)) ? voice : nil;
}

// Ghidra: FUN_000214a8.
bool neAVSePlayer::play(uint32_t handle) {
    if ((handle & kAVSePlayerHandleFlag) == 0) {
        return false;
    }
    neAVSeVoice *voice = voiceForHandle(m_voices, handle);
    if (voice != nil) {
        [voice.player play];
        return true;
    }
    return false;
}

// Ghidra: FUN_000214c0.
bool neAVSePlayer::stop(uint32_t handle) {
    neAVSeVoice *voice = voiceForHandle(m_voices, handle);
    if (voice != nil) {
        [voice.player stop];
        return true;
    }
    return false;
}

// Ghidra: FUN_000214f0.
int neAVSePlayer::voiceState(uint32_t handle) {
    neAVSeVoice *voice = voiceForHandle(m_voices, handle);
    if (voice == nil) {
        return -1;
    }
    return voice.player.isPlaying ? 1 : 4;
}

// Set the volume of every AVAudioPlayer voice.
void neAVSePlayer::setGroupVolume(float volume) {
    for (neAVSeVoice *voice in m_voices) {
        voice.player.volume = volume;
    }
}

// Ghidra: FUN_00021288 — pause every voice.
void neAVSePlayer::suspend() {
    for (neAVSeVoice *voice in m_voices) {
        [voice.player pause];
    }
}

// Ghidra: FUN_00021294 — resume every voice.
void neAVSePlayer::resume() {
    for (neAVSeVoice *voice in m_voices) {
        if (voice.player != nil && !voice.player.isPlaying) {
            [voice.player play];
        }
    }
}
