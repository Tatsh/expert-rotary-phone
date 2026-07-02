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

// Fade thresholds: at or below these the BGM start/stop/pause happens instantly
// rather than through a fade timer. Ghidra: DAT_0001fe08 / DAT_0001ff50 / DAT_0001fec0.
static const float kBgmInstantFade = 0.0f;

static const int kSeGroupCount = 16;
static const int kSeVoiceCount = 8;   // onStartPlayer starts each backend with 8 voices

@implementation AudioManager {
    BOOL m_isStart;
    BOOL m_isSuspend;
    BOOL m_isInterruption;
    BOOL m_isPlaying;                 // BGM playing
    BOOL m_isOnPause;                 // BGM paused
    AVAudioPlayer *m_bgmPlayer;
    AVAudioPlayer *m_pushBgmPlayer;   // the ducked/saved BGM
    NSString *m_loadedBgmPath;        // path of the currently loaded BGM
    float m_bgmSettingVolume;
    NSTimer *m_fadeTimer;
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

#pragma mark - System lifecycle

// @ 0x1e198 — start initialisation asynchronously via a zero-delay run-loop timer.
- (void)systemStart {
    NSTimer *timer = [NSTimer timerWithTimeInterval:0
                                             target:self
                                           selector:@selector(onStartPlayer:)
                                           userInfo:nil
                                            repeats:NO];
    [NSRunLoop.currentRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
}

// @ 0x1e224 — the legacy synchronous start.
- (void)systemStartBlock {
    [self onStartPlayer:nil];
}

// @ 0x1e414 — bring both SE backends up and mark the system started.
- (void)onStartPlayer:(id)sender {
    m_caPlayer->systemStart(kSeVoiceCount);
    m_seAVPlayer->systemStart(kSeVoiceCount);
    m_isStart = YES;
}

// @ 0x20790
- (BOOL)isStart {
    return m_isStart;
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

// @ 0x1e454 — configure a freshly-loaded BGM player.
- (void)initBgm:(BOOL)loop {
    m_bgmPlayer.numberOfLoops = loop ? -1 : 0;
    m_bgmPlayer.delegate = self;
    [m_bgmPlayer prepareToPlay];
}

// @ 0x1ef74 — stop and release the current BGM + its remembered path.
- (void)releaseBgm {
    if (m_bgmPlayer != nil) {
        [m_bgmPlayer stop];
        m_bgmPlayer = nil;
    }
    m_loadedBgmPath = nil;
}

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

// @ 0x1fcc0 — start the BGM, instantly or via a fade-in timer.
- (BOOL)playBgm:(float)fadeSeconds {
    if (m_bgmPlayer == nil) {
        return NO;
    }
    if (!m_isInterruption) {
        [self deleteFadeTimer];
        if (fadeSeconds <= kBgmInstantFade) {
            [m_bgmPlayer setVolume:m_bgmSettingVolume];
            if (![m_bgmPlayer play]) {
                if (![m_bgmPlayer prepareToPlay] || ![m_bgmPlayer play]) {
                    return NO;
                }
            }
        } else {
            [m_bgmPlayer setVolume:0];
            if (![m_bgmPlayer play]) {
                if (![m_bgmPlayer prepareToPlay] || ![m_bgmPlayer play]) {
                    return NO;
                }
            }
            [self createBgmFadeInTimer:fadeSeconds];
        }
    }
    m_isOnPause = NO;
    m_isPlaying = YES;
    return YES;
}

// @ 0x1fe10 — stop the BGM (immediately for a ~zero fade, else via a fade timer).
- (BOOL)stopBgm:(float)fadeSeconds {
    if (m_bgmPlayer == nil) {
        return NO;
    }
    [self deleteFadeTimer];
    if (fadeSeconds <= kBgmInstantFade) {
        [m_bgmPlayer stop];
        [m_bgmPlayer setCurrentTime:0];
        m_isPlaying = NO;
        m_isOnPause = NO;
    } else {
        [self createBgmFadeOutTimer:fadeSeconds];
    }
    return YES;
}

// @ 0x1fec8 — pause the BGM (immediately or via a fade-out timer).
- (BOOL)onPauseBgm:(float)fadeSeconds {
    if (m_bgmPlayer == nil) {
        return NO;
    }
    m_isOnPause = YES;
    [self deleteFadeTimer];
    if (fadeSeconds <= kBgmInstantFade) {
        [m_bgmPlayer pause];
    } else {
        [self createBgmFadeOutTimer:fadeSeconds];
    }
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

// @ 0x1fa04 — cancel any running BGM fade timer.
- (void)deleteFadeTimer {
    if (m_fadeTimer != nil) {
        [m_fadeTimer invalidate];
        m_fadeTimer = nil;
    }
}

#pragma mark - BGM push/pop

// @ 0x201dc — duck the current BGM onto the stack.
- (void)pushBgm {
    if (m_pushBgmPlayer != nil && m_bgmPlayer == nil) {
        return;
    }
    [self onPauseBgm:0];
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

// @ 0x1e8b8 — the group a loaded SE belongs to (0 = caplayer, else AVFoundation),
// looked up in m_seType by call name or by boxed resource id.
- (int)getGroupID:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId {
    id key = name ? name : @((unsigned)resourceId);
    return [[m_seType objectForKey:key] intValue];
}

// @ 0x1e914 — load a sound effect into one of the two backends. (See loadSe body
// unchanged below; kept from the previous reconstruction.)
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

// @ 0x1f00c — reserve a playing instance in the right backend, stealing an old
// instance if the backend is out of voices; register it and return the handle.
- (RSND_INSTANCE_ID)prepare:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId volume:(float)volume {
    [self orderInstanceList];
    int group = [self getGroupID:name resourceId:resourceId];

    RSND_INSTANCE_ID handle = [self prepareInGroup:group name:name resourceId:resourceId volume:volume];
    if (handle == (RSND_INSTANCE_ID)-1) {
        [self stopOldInstance];
        handle = [self prepareInGroup:group name:name resourceId:resourceId volume:volume];
    }
    [self addInstance:handle group:group];
    return handle;
}

// Dispatch a prepare to the CoreAudio or AVFoundation backend, by id or name.
- (RSND_INSTANCE_ID)prepareInGroup:(int)group name:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId volume:(float)volume {
    if (name == nil) {
        uint32_t rid = (uint32_t)(resourceId & 0xfffffff);
        return (group == 0) ? m_caPlayer->prepare(rid, volume)
                            : m_seAVPlayer->prepare(rid, volume);
    }
    return (group == 0) ? m_caPlayer->prepareNamed(name.UTF8String, volume)
                        : m_seAVPlayer->prepareNamed(name, volume);
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

#pragma mark - Helpers still to be filled (bodies tracked in HANDOFF)

// SE instance-list housekeeping (voice stealing). Ghidra: orderInstanceList
// @ 0x1f??? / stopOldInstance / addInstance:group:.
- (void)orderInstanceList {}
- (void)stopOldInstance {}
- (void)addInstance:(RSND_INSTANCE_ID)handle group:(int)group {}

// BGM fade timers ramp the AVAudioPlayer volume toward 1.0 / 0.0 over `seconds`.
// Ghidra: createBgmFadeInTimer: / createBgmFadeOutTimer:.
- (void)createBgmFadeInTimer:(float)seconds {}
- (void)createBgmFadeOutTimer:(float)seconds {}

// Per-backend suspend/resume book-keeping. Ghidra: suspendPlayer: / resumePlayer:.
- (void)suspendPlayer:(int)which {}
- (void)resumePlayer:(int)which {}

@end
