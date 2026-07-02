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

// One live SE instance tracked for voice-stealing (Ghidra: the 8-entry seList,
// 0xc bytes each). handle == kFreeInstance marks a free slot.
static const RSND_INSTANCE_ID kFreeInstance = (RSND_INSTANCE_ID)-1;
struct SeInstance {
    RSND_INSTANCE_ID handle;
    int group;   // 0 = caplayer, else AVFoundation
};

@implementation AudioManager {
    BOOL m_isStart;
    BOOL m_isSuspend;
    BOOL m_isInterruption;            // BGM interrupted
    BOOL m_isInterruptionVoice;
    BOOL m_isPlaying;                 // BGM playing
    BOOL m_isPlayingVoice;
    BOOL m_isOnPause;                 // BGM paused
    BOOL m_isOnPauseVoice;
    AVAudioPlayer *m_bgmPlayer;
    AVAudioPlayer *m_pushBgmPlayer;   // the ducked/saved BGM
    AVAudioPlayer *m_voicePlayer;     // the VOICE channel (a second BGM-like player)
    NSString *m_loadedBgmPath;        // path of the currently loaded BGM
    NSTimeInterval m_voicePlayTime;   // VOICE resume position
    float m_bgmSettingVolume;
    float m_unitVolume;               // per-tick fade delta
    NSTimer *m_fadeTimer;
    neAVCAPlayer *m_caPlayer;         // CoreAudio SE (group 0)
    neAVSePlayer *m_seAVPlayer;       // AVFoundation SE (other groups)
    NSMutableArray *m_seRidList;      // source ids in load order
    NSMutableArray *m_seNameList;     // registered call names
    NSMutableDictionary *m_seType;    // key (name or rid) -> packed handle/type
    float m_seVolume[kSeGroupCount];
    SeInstance m_seList[8];           // live SE instances (oldest first)
}

- (instancetype)init {
    if ((self = [super init])) {
        m_caPlayer = new neAVCAPlayer();
        m_seAVPlayer = new neAVSePlayer();
        m_seRidList = [[NSMutableArray alloc] init];
        m_seNameList = [[NSMutableArray alloc] init];
        m_seType = [[NSMutableDictionary alloc] init];
        for (int i = 0; i < 8; i++) {
            m_seList[i].handle = kFreeInstance;
            m_seList[i].group = 0;
        }
    }
    return self;
}

- (void)dealloc {
    delete m_caPlayer;
    delete m_seAVPlayer;
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

// @ 0x1e5b0 — load the BGM straight from in-memory data (the play scene hands in the
// decoded .orb "bgm" entry) rather than a file path. Mirrors loadBgm:isLoop:; releaseBgm
// clears the cached path and the data variant has none to re-store.
- (BOOL)loadBgmData:(NSData *)data isLoop:(BOOL)loop {
    if (data == nil) {
        return NO;
    }
    [self releaseBgm];
    NSError *error = nil;
    m_bgmPlayer = [[AVAudioPlayer alloc] initWithData:data error:&error];
    if (error != nil) {
        return NO;
    }
    [self initBgm:loop];
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

// @ 0x1f3d0 — stop the SE instance `handle` in whichever backend owns it.
- (BOOL)stopSe:(RSND_INSTANCE_ID)instanceId {
    for (int i = 0; i < 8; i++) {
        if (m_seList[i].handle == instanceId) {
            return m_seList[i].group != 0 ? m_seAVPlayer->stop((uint32_t)instanceId)
                                          : m_caPlayer->stop((uint32_t)instanceId);
        }
    }
    return NO;
}

// @ 0x1f630 — stop every tracked SE instance.
- (BOOL)stopSeAll {
    for (int i = 0; i < 8; i++) {
        if (m_seList[i].group != 0) {
            m_seAVPlayer->stop((uint32_t)m_seList[i].handle);
        } else {
            m_caPlayer->stop((uint32_t)m_seList[i].handle);
        }
    }
    return YES;
}

// @ 0x1f6dc — reap finished SE instances (state -1/4), freeing their voices, then
// compact the list so the oldest live instance is first.
- (void)orderInstanceList {
    for (int i = 0; i < 8; i++) {
        if (m_seList[i].handle == kFreeInstance) {
            break;
        }
        int state = m_seList[i].group != 0 ? m_seAVPlayer->voiceState((uint32_t)m_seList[i].handle)
                                           : m_caPlayer->voiceState((uint32_t)m_seList[i].handle);
        if (state == -1 || state == 4) {
            if (m_seList[i].group != 0) {
                m_seAVPlayer->stop((uint32_t)m_seList[i].handle);
            } else {
                m_caPlayer->stop((uint32_t)m_seList[i].handle);
            }
            m_seList[i].handle = kFreeInstance;
        }
    }
    // Compact: pull later live entries forward over the freed gaps.
    for (int i = 0; i < 7; i++) {
        if (m_seList[i].handle == kFreeInstance) {
            for (int j = i + 1; j < 8; j++) {
                if (m_seList[j].handle != kFreeInstance) {
                    m_seList[i] = m_seList[j];
                    m_seList[j].handle = kFreeInstance;
                    break;
                }
            }
        }
    }
}

// @ 0x1f8fc — steal the oldest instance's voice to make room, shifting the list.
- (void)stopOldInstance {
    if (m_seList[0].group != 0) {
        m_seAVPlayer->stop((uint32_t)m_seList[0].handle);
    } else {
        m_caPlayer->stop((uint32_t)m_seList[0].handle);
    }
    for (int i = 0; i < 7; i++) {
        m_seList[i] = m_seList[i + 1];
    }
    m_seList[7].handle = kFreeInstance;
    m_seList[7].group = 0;
}

// @ 0x1f964 — record a newly-prepared instance in the first free slot.
- (void)addInstance:(RSND_INSTANCE_ID)handle group:(int)group {
    for (int i = 0; i < 8; i++) {
        if (m_seList[i].handle == kFreeInstance) {
            m_seList[i].handle = handle;
            m_seList[i].group = group;
            return;
        }
    }
}

// @ 0x1f99c — set the SE volume for a group (level 0..127): the caplayer sets its
// 8 voices, the AVFoundation pool scales each player.
- (void)setSeVolume:(int)volume groupId:(int)group {
    if (volume >= 0x80) {
        return;
    }
    if (group >= 0 && group < kSeGroupCount) {
        m_seVolume[group] = volume;
    }
    if (group != 0) {
        m_seAVPlayer->setGroupVolume((float)volume / 127.0f);
    } else {
        m_caPlayer->setAllVoiceVolume(volume);
    }
}

#pragma mark - VOICE channel (a second BGM-like player)

// @ 0x1e708
- (BOOL)loadVoice:(NSString *)path isLoop:(BOOL)loop {
    if (path == nil) {
        return NO;
    }
    m_voicePlayer = nil;
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    m_voicePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (error != nil) {
        return NO;
    }
    m_voicePlayer.numberOfLoops = loop ? -1 : 0;
    m_voicePlayer.delegate = self;
    [m_voicePlayer prepareToPlay];
    return YES;
}

// @ 0x2030c
- (BOOL)playVoice {
    if (m_voicePlayer == nil) {
        return NO;
    }
    if (m_isOnPauseVoice) {
        m_voicePlayer.currentTime = m_voicePlayTime;
    }
    [m_voicePlayer play];
    m_isPlayingVoice = YES;
    m_isOnPauseVoice = NO;
    return YES;
}

// @ 0x20388
- (BOOL)stopVoice {
    if (m_voicePlayer == nil) {
        return NO;
    }
    [m_voicePlayer stop];
    m_isPlayingVoice = NO;
    return YES;
}

// @ 0x203c8
- (BOOL)onPauseVoice {
    if (m_voicePlayer == nil) {
        return NO;
    }
    m_voicePlayTime = m_voicePlayer.currentTime;
    [m_voicePlayer stop];
    m_isOnPauseVoice = YES;
    return YES;
}

#pragma mark - BGM seek / fades / suspend

// @ 0x202e0
- (void)seekBgmToTop {
    if (m_bgmPlayer != nil) {
        m_bgmPlayer.currentTime = 0;
    }
}

// @ 0x1fa38 — ramp the BGM volume up to its target over `seconds`.
- (void)createBgmFadeInTimer:(float)seconds {
    [self deleteFadeTimer];
    const float kTick = 1.0f / 60.0f;   // Ghidra: DAT_0001fb20 (per-tick interval)
    m_unitVolume = (m_bgmSettingVolume / seconds) * kTick;
    m_fadeTimer = [NSTimer timerWithTimeInterval:kTick target:self
                                        selector:@selector(onFadeInTimer:)
                                        userInfo:nil repeats:YES];
    [NSRunLoop.currentRunLoop addTimer:m_fadeTimer forMode:NSRunLoopCommonModes];
}

// @ 0x1fb28 — ramp the BGM volume down to zero over `seconds`.
- (void)createBgmFadeOutTimer:(float)seconds {
    [self deleteFadeTimer];
    const float kTick = 1.0f / 60.0f;   // Ghidra: DAT_0001fc18
    m_unitVolume = (-m_bgmSettingVolume / seconds) * kTick;
    m_fadeTimer = [NSTimer timerWithTimeInterval:kTick target:self
                                        selector:@selector(onFadeOutTimer:)
                                        userInfo:nil repeats:YES];
    [NSRunLoop.currentRunLoop addTimer:m_fadeTimer forMode:NSRunLoopCommonModes];
}

- (void)onFadeInTimer:(NSTimer *)timer {
    float v = m_bgmPlayer.volume + m_unitVolume;
    if (v >= m_bgmSettingVolume) {
        v = m_bgmSettingVolume;
        [self deleteFadeTimer];
    }
    m_bgmPlayer.volume = v;
}

- (void)onFadeOutTimer:(NSTimer *)timer {
    float v = m_bgmPlayer.volume + m_unitVolume;
    if (v <= 0.0f) {
        v = 0.0f;
        [self deleteFadeTimer];
        [m_bgmPlayer pause];
    }
    m_bgmPlayer.volume = v;
}

// @ 0x20500 — interrupt a channel (0 = BGM, 1 = VOICE), stopping its player.
- (void)suspendPlayer:(int)which {
    if (which > 1) {
        return;
    }
    if (which == 1) {
        m_isInterruptionVoice = YES;
        [m_voicePlayer stop];
    } else {
        m_isInterruption = YES;
        [m_bgmPlayer stop];
    }
}

// @ 0x20550 — resume a channel that was interrupted and had been playing.
- (void)resumePlayer:(int)which {
    if (which > 1) {
        return;
    }
    if (which == 1) {
        if (!m_isInterruptionVoice) return;
        m_isInterruptionVoice = NO;
        if (m_isPlayingVoice && !m_isOnPauseVoice) {
            [self playVoice];
        }
    } else {
        if (!m_isInterruption) return;
        m_isInterruption = NO;
        if (m_isPlaying && !m_isOnPause) {
            [self playBgm:0];
        }
    }
}

// Tear the SE backends down. Ghidra: systemTerminate.
- (void)systemTerminate {
    [self stopSeAll];
    m_caPlayer->suspend();
    m_seAVPlayer->suspend();
    m_isStart = NO;
}

@end
