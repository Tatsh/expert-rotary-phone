//
//  AudioManager.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++: BGM/VOICE play through AVAudioPlayer; sound effects go through
//  one of two C++ backends — the low-latency CoreAudio neAVCAPlayer (group 0) or
//  the AVFoundation neAVSePlayer (other groups).
//

#import "AudioManager.h"
#import "neAVCAPlayer.h"
#import "neAVSePlayer.h"

// Fade threshold below which stopBgm: stops immediately instead of fading out.
// Ghidra: DAT_0001fec0 (a double compared against the requested fade seconds).
static const float kBgmStopImmediateFade = 0.0f;

static const int kSeGroupCount = 16;

@implementation AudioManager {
    BOOL m_isStart;
    BOOL m_isSuspend;
    BOOL m_isPlaying;                 // BGM playing
    BOOL m_isOnPause;                 // BGM paused
    AVAudioPlayer *m_bgmPlayer;
    AVAudioPlayer *m_pushBgmPlayer;   // the ducked/saved BGM
    NSString *m_loadedBgmPath;        // path of the currently loaded BGM
    float m_bgmSettingVolume;
    neAVCAPlayer *m_caPlayer;         // CoreAudio SE (group 0)
    neAVSePlayer *m_seAVPlayer;       // AVFoundation SE (other groups)
    NSMutableArray *m_seRidList;      // source ids in load order
    NSMutableArray *m_seNameList;     // registered call names
    NSMutableDictionary *m_seType;    // key (name or rid) -> packed handle/type
    float m_seVolume[kSeGroupCount];
}

// @ 0x1dea0 — thread-safe lazy singleton.
+ (instancetype)sharedManager {
    static AudioManager *sInstance = nil;
    @synchronized (self) {
        if (sInstance == nil) {
            sInstance = [[AudioManager alloc] init];
        }
    }
    return sInstance;
}

// @ 0x1e224
- (void)systemStartBlock {
    [self onStartPlayer:NO];
}

// @ 0x205e0 — pause both SE backends + both BGM slots.
- (void)systemSuspend {
    if (m_isStart && !m_isSuspend) {
        m_caPlayer->suspend();
        m_seAVPlayer->suspend();
        [self suspendPlayer:0];
        [self suspendPlayer:1];
        m_isSuspend = YES;
    }
}

// @ 0x2065c
- (void)systemResume {
    if (m_isStart && m_isSuspend) {
        m_caPlayer->resume();
        m_seAVPlayer->resume();
        [self resumePlayer:0];
        [self resumePlayer:1];
        m_isSuspend = NO;
    }
}

#pragma mark - BGM

// @ 0x1e4a8 — load a BGM file (skipping the reload if the same path is already
// loaded). Returns NO on a nil path or a decode error.
- (BOOL)loadBgm:(NSString *)path isLoop:(BOOL)loop {
    if (path == nil) {
        return NO;
    }
    if ([path isEqualToString:m_loadedBgmPath]) {
        return YES;
    }
    [self releaseBgm];
    m_loadedBgmPath = nil;

    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    m_bgmPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (error != nil) {
        return NO;
    }
    [self initBgm:loop];
    m_loadedBgmPath = [path copy];
    return YES;
}

// @ 0x1fc20 — remember the requested BGM volume (0..1).
- (BOOL)setBgmVolume:(float)volume {
    if (m_bgmPlayer == nil) {
        return NO;
    }
    if (volume < 0.0f || volume > 1.0f) {
        return NO;
    }
    m_bgmSettingVolume = volume;
    return YES;
}

// @ 0x1fe10 — stop the BGM, immediately when the fade is (near) zero, otherwise
// via a fade-out timer.
- (BOOL)stopBgm:(float)fadeSeconds {
    if (m_bgmPlayer == nil) {
        return NO;
    }
    [self deleteFadeTimer];
    if (fadeSeconds <= kBgmStopImmediateFade) {
        [m_bgmPlayer stop];
        [m_bgmPlayer setCurrentTime:0];
        m_isPlaying = NO;
        m_isOnPause = NO;
    } else {
        [self createBgmFadeOutTimer:fadeSeconds];
    }
    return YES;
}

#pragma mark - BGM push/pop

// @ 0x201dc — duck the current BGM onto the stack.
- (void)pushBgm {
    if (m_pushBgmPlayer != nil && m_bgmPlayer == nil) {
        return;
    }
    [self onPauseBgm];
    if (m_pushBgmPlayer != nil) {
        [m_pushBgmPlayer stop];
        m_pushBgmPlayer = nil;
    }
    m_pushBgmPlayer = m_bgmPlayer;
    m_bgmPlayer.delegate = nil;
    m_bgmPlayer = nil;
}

// @ 0x2027c — restore the pushed BGM.
- (void)popBgm {
    [self releaseBgm];
    m_bgmPlayer = m_pushBgmPlayer;
    m_bgmPlayer.delegate = self;
    m_pushBgmPlayer = nil;
}

// @ 0x202c8
- (BOOL)isPushBgm {
    return m_pushBgmPlayer != nil;
}

#pragma mark - SE

// @ 0x1e914 — load a sound effect into one of the two backends (group 0 =
// CoreAudio caplayer, else AVFoundation). If callName is given the sound is
// addressable by name; otherwise the returned source id is recorded in the rid
// list. The packed value stored in m_seType carries the backend flag in its high
// bits (0x10000000 caplayer / 0x60000000 AVFoundation | group).
- (RSND_SOURCE_ID)loadSe:(NSString *)path isLoop:(BOOL)loop callName:(NSString *)name group:(int)group {
    if (path == nil) {
        return RSND_INSTANCE_ID_ERROR;
    }

    if (group == 0) {
        const char *cpath = path.UTF8String;
        if (name == nil) {
            RSND_SOURCE_ID rid = m_caPlayer->load(cpath, loop);
            if (rid != (RSND_SOURCE_ID)-1) {
                [m_seRidList addObject:@((unsigned)rid)];
            }
            m_seType[@(0)] = @((unsigned)rid | 0x10000000u);
            return rid;
        }
        if (m_caPlayer->loadNamed(cpath, name.UTF8String, loop)) {
            [m_seNameList addObject:name];
        }
        m_seType[name] = @(group);
        return RSND_INSTANCE_ID_ERROR;
    }

    NSURL *url = [NSURL fileURLWithPath:path];
    if (name == nil) {
        RSND_SOURCE_ID rid = (RSND_SOURCE_ID)m_seAVPlayer->load(url, loop);
        if (rid != (RSND_SOURCE_ID)-1) {
            [m_seRidList addObject:@((unsigned)rid)];
        }
        m_seType[@((unsigned)rid)] = @((unsigned)rid | 0x60000000u);
        return rid;
    }
    if (m_seAVPlayer->loadNamed(url, name, loop)) {
        [m_seNameList addObject:name];
    }
    m_seType[name] = @(group);
    return RSND_INSTANCE_ID_ERROR;
}

// @ 0x1f234 — play a sound effect; group 0 goes through the CoreAudio caplayer,
// others through the AVFoundation player.
- (RSND_INSTANCE_ID)playSe:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId {
    if (name == nil && resourceId == (RSND_SOURCE_ID)-1) {
        return RSND_INSTANCE_ID_ERROR;
    }
    int group = [self getGroupID:name resourceId:resourceId];
    RSND_INSTANCE_ID handle = [self prepare:name resourceId:resourceId volume:m_seVolume[group]];
    if (handle == (RSND_INSTANCE_ID)-1) {
        return RSND_INSTANCE_ID_ERROR;
    }
    if (group == 0) {
        m_caPlayer->play((uint32_t)handle);
    } else {
        m_seAVPlayer->play((uint32_t)handle);
    }
    return handle;
}

// @ 0x1f2d8 — as above but sets the SE volume before playing.
- (RSND_INSTANCE_ID)playSe:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId Volume:(float)volume {
    int group = [self getGroupID:name resourceId:resourceId];
    if (group >= 0 && group < kSeGroupCount) {
        m_seVolume[group] = volume;
    }
    return [self playSe:name resourceId:resourceId];
}

#pragma mark - Declared helpers (bodies still pending; see HANDOFF deferred list)

- (void)onStartPlayer:(BOOL)block {}                // Ghidra: onStartPlayer:
- (void)suspendPlayer:(int)which {}                 // Ghidra: suspendPlayer:
- (void)resumePlayer:(int)which {}                  // Ghidra: resumePlayer:
- (void)onPauseBgm {}                               // Ghidra: onPauseBgm:
- (void)releaseBgm {}                               // Ghidra: releaseBgm
- (void)initBgm:(BOOL)loop {}                       // Ghidra: initBgm:
- (void)deleteFadeTimer {}                          // Ghidra: deleteFadeTimer
- (void)createBgmFadeOutTimer:(float)seconds {}     // Ghidra: createBgmFadeOutTimer:
- (int)getGroupID:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId { return 0; }  // getGroupID:resourceId:
- (RSND_INSTANCE_ID)prepare:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId volume:(float)volume { return (RSND_INSTANCE_ID)-1; }

@end
