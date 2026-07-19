//
//  AudioManager.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++: BGM/VOICE play through AVAudioPlayer; sound effects go
//  through one of two C++ backends — the low-latency CoreAudio neAVCAPlayer
//  (group 0) or the AVFoundation neAVSePlayer (other groups).
//

#import "AudioManager.h"
#import "neAVCAPlayer.h"
#import "neAVSePlayer.h"
#import "neDebugLog.h"

// Fade thresholds: at or below these the BGM start/stop/pause happens instantly
// rather than through a fade timer. Ghidra: DAT_0001fe08 / DAT_0001ff50 /
// DAT_0001fec0
// == 0.05 (one fade tick; float 0.05 widened to double = 0x3fa99999a0000000).
constexpr float kBgmInstantFade = 0.05f;

constexpr int kSeGroupCount = 16;
constexpr int kSeVoiceCount = 8; // onStartPlayer starts each backend with 8 voices

// One live SE instance tracked for voice-stealing (Ghidra: the 8-entry seList,
// 0xc bytes each). handle == kFreeInstance marks a free slot. The struct is 12
// bytes: the reap/steal/add paths write handle at offset 0 and group at offset
// 8 (e.g. stopSeAll @ 0x1f630 reads group at [entry+0x8], stride 0xc), leaving a
// reserved word at offset 4, so group must sit at +8 rather than +4.
static const RSND_INSTANCE_ID kFreeInstance = static_cast<RSND_INSTANCE_ID>(-1);
struct SeInstance {
    RSND_INSTANCE_ID handle;
    int reserved;
    int group; // 0 = caplayer, else AVFoundation
};

// The caplayer-only "SetGroup" SE pool (Ghidra: the seManageId 2-D array, 2
// banks of 8 slots, 0xc bytes each). Unlike m_seList, every slot owns a *fixed*
// caplayer voice for its lifetime (banks 0/1 own voices 0..7 / 8..15) and
// prepare/play/stop always go through m_caPlayer. handle == kFreeInstance marks
// an idle slot.
constexpr int kSeSetGroupCount = 2;
constexpr int kSeSetGroupVoices = 8;
struct SeVoiceSlot {
    RSND_INSTANCE_ID handle;
    int voiceIndex;
    int reserved;
};

@implementation AudioManager {
    BOOL m_isStart;
    BOOL m_isSuspend;
    BOOL m_isInterruption; // BGM interrupted
    BOOL m_isInterruptionVoice;
    BOOL m_isPlaying; // BGM playing
    BOOL m_isPlayingVoice;
    BOOL m_isOnPause; // BGM paused
    BOOL m_isOnPauseVoice;
    AVAudioPlayer *m_bgmPlayer;
    AVAudioPlayer *m_pushBgmPlayer; // the ducked/saved BGM
    AVAudioPlayer *m_voicePlayer;   // the VOICE channel (a second BGM-like player)
    NSString *m_loadedBgmPath;      // path of the currently loaded BGM
    NSTimeInterval m_voicePlayTime; // VOICE resume position
    float m_bgmSettingVolume;
    float m_unitVolume; // per-tick fade delta
    NSTimer *m_fadeTimer;
    neAVCAPlayer *m_caPlayer;      // CoreAudio SE (group 0)
    neAVSePlayer *m_seAVPlayer;    // AVFoundation SE (other groups)
    NSMutableArray *m_seRidList;   // source ids in load order
    NSMutableArray *m_seNameList;  // registered call names
    NSMutableDictionary *m_seType; // key (name or rid) -> packed handle/type
    float m_seVolume[kSeGroupCount];
    SeInstance m_seList[8]; // live SE instances (oldest first)
    SeVoiceSlot m_seManageId[kSeSetGroupCount][kSeSetGroupVoices]; // SetGroup pool
}

// .cxx_construct @ 0x207a0 — compiler-emitted C++ ivar constructor (constructs
// the C++ SeInstance/SeVoiceSlot ivars); not hand-written.

// @ 0x1df8c
// @complete
- (instancetype)init {
    if ((self = [super init])) {
        m_caPlayer = new neAVCAPlayer();
        m_seAVPlayer = new neAVSePlayer();
        m_isStart = NO;
        for (int i = 0; i < 8; i++) {
            m_seList[i].handle = kFreeInstance;
        }
        m_seNameList = [[NSMutableArray alloc] init];
        m_seRidList = [[NSMutableArray alloc] init];
        m_isInterruption = NO;
        m_isInterruptionVoice = NO;
        m_isPlaying = NO;
        m_isPlayingVoice = NO;
        m_isSuspend = NO;
        m_isOnPauseVoice = NO;
        m_isOnPause = NO;
        m_bgmSettingVolume = 1.0f;
        m_loadedBgmPath = nil;
        // Each SetGroup bank starts empty; its 8 slots own consecutive caplayer
        // voices (bank 0 -> 0..7, bank 1 -> 8..15).
        for (int g = 0; g < kSeSetGroupCount; g++) {
            m_seVolume[g] = 0x7f;
            for (int v = 0; v < kSeSetGroupVoices; v++) {
                m_seManageId[g][v].handle = kFreeInstance;
                m_seManageId[g][v].voiceIndex = g * kSeSetGroupVoices + v;
            }
        }
        m_seType = [[NSMutableDictionary alloc] init];
    }
    return self;
}

// @ 0x206d8 — invalidate the fade timer and tear down the CoreAudio SE engine.
// Per the binary only m_caPlayer is destroyed here (m_seAVPlayer is torn down
// in cleanupSe / systemTerminate); the ObjC-object releases and [super dealloc]
// are dropped under ARC.
// @complete
- (void)dealloc {
    [m_fadeTimer invalidate];
    if (m_caPlayer != nullptr) {
        delete m_caPlayer; // ~neAVCAPlayer: frees the AUGraph / CASound pool
        m_caPlayer = nullptr;
    }
}

// @ 0x1dea0 — thread-safe lazy singleton.
// @complete
+ (instancetype)sharedManager {
    static AudioManager *sInstance = nil;
    @synchronized(self) {
        if (sInstance == nil) {
            sInstance = [[AudioManager alloc] init];
        }
    }
    return sInstance;
}

#pragma mark - System lifecycle

// @ 0x1e198 — start initialisation asynchronously via a zero-delay run-loop
// timer.
// @complete
- (void)systemStart {
    NSTimer *timer = [NSTimer timerWithTimeInterval:0
                                             target:self
                                           selector:@selector(onStartPlayer:)
                                           userInfo:nil
                                            repeats:NO];
    [NSRunLoop.currentRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
}

// @ 0x1e224 — the legacy synchronous start.
// @complete
- (void)systemStartBlock {
    [self onStartPlayer:nil];
}

// @ 0x1e414 — bring both SE backends up and mark the system started.
// @complete
- (void)onStartPlayer:(id)sender {
    m_caPlayer->systemStart(kSeVoiceCount);
    m_seAVPlayer->systemStart(kSeVoiceCount);
    m_isStart = YES;
}

// @ 0x20790
// @complete
- (BOOL)isStart {
    return m_isStart;
}

// @ 0x205e0 — pause both SE backends + both BGM slots.
// @complete
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
// @complete
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
// @complete
- (void)initBgm:(BOOL)loop {
    m_bgmPlayer.numberOfLoops = loop ? -1 : 0;
    m_bgmPlayer.delegate = self;
    [m_bgmPlayer prepareToPlay];
}

// @ 0x1ef74 — stop and release the current BGM + its remembered path.
// @complete
- (void)releaseBgm {
    if (m_bgmPlayer != nil) {
        [m_bgmPlayer stop];
        m_bgmPlayer = nil;
    }
    m_loadedBgmPath = nil;
}

// @ 0x1e4a8 — load a BGM file (skipping the reload if the same path is already
// loaded). Returns NO on a nil path or a decode error.
// @complete
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

// @ 0x1e5b0 — load the BGM straight from in-memory data (the play scene hands
// in the decoded .orb "bgm" entry) rather than a file path. Mirrors
// loadBgm:isLoop:; releaseBgm clears the cached path and the data variant has
// none to re-store.
// @complete
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

// @ 0x1e63c — wrap a copy of the raw bytes in an NSData and load it as BGM.
// @complete
- (BOOL)loadBgmDataWithBytes:(const void *)bytes length:(NSUInteger)length isLoop:(BOOL)loop {
    NSData *data = [NSData dataWithBytes:bytes length:length];
    return [self loadBgmData:data isLoop:loop];
}

// @ 0x1e67c — as above but without copying (NSData frees the buffer when done).
// @complete
- (BOOL)loadBgmDataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length isLoop:(BOOL)loop {
    NSData *data = [NSData dataWithBytesNoCopy:bytes length:length];
    return [self loadBgmData:data isLoop:loop];
}

// @ 0x1e6bc — as above, letting the caller decide whether NSData frees the
// buffer.
// @complete
- (BOOL)loadBgmDataWithBytesNoCopy:(void *)bytes
                            length:(NSUInteger)length
                      freeWhenDone:(BOOL)freeWhenDone
                            isLoop:(BOOL)loop {
    NSData *data = [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:freeWhenDone];
    return [self loadBgmData:data isLoop:loop];
}

// @ 0x1fcc0 — start the BGM, instantly or via a fade-in timer.
// @complete
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

// @ 0x1fe10 — stop the BGM (immediately for a ~zero fade, else via a fade
// timer).
// @complete
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

// @ 0x1fff8 — YES only when a player is loaded and actually playing.
// @complete
- (BOOL)isPlayingBgm {
    if (m_bgmPlayer == nil) {
        return NO;
    }
    return [m_bgmPlayer isPlaying];
}

// @ 0x1ff58 — the player's current playhead (seconds); 0 when nothing is
// loaded.
// @complete
- (NSTimeInterval)bgmCurrentTime {
    if (m_bgmPlayer == nil) {
        return 0;
    }
    return m_bgmPlayer.currentTime;
}

// @ 0x1ff84 — the audio device's absolute clock as seen by the BGM player; 0
// when nothing is loaded.
// @complete
- (NSTimeInterval)bgmDeviceCurrentTime {
    if (m_bgmPlayer == nil) {
        return 0;
    }
    return m_bgmPlayer.deviceCurrentTime;
}

// @ 0x1ffb0 — move the playhead and re-prime the player so playback resumes
// cleanly.
// @complete
- (void)setBgmCurrentTime:(NSTimeInterval)time {
    if (m_bgmPlayer == nil) {
        return;
    }
    m_bgmPlayer.currentTime = time;
    [m_bgmPlayer prepareToPlay];
}

// @ 0x1fec8 — pause the BGM (immediately or via a fade-out timer).
// @complete
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
// @complete
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

// @ 0x1fc6c — set the BGM player's volume immediately (no fade, no stored
// target).
// @complete
- (BOOL)setJustBgmVolume:(float)volume {
    if (m_bgmPlayer == nil) {
        return NO;
    }
    if (volume < 0.0f || volume > 1.0f) {
        return NO;
    }
    m_bgmPlayer.volume = volume;
    return YES;
}

// @ 0x1fa04 — cancel any running BGM fade timer.
// @complete
- (void)deleteFadeTimer {
    if (m_fadeTimer != nil) {
        [m_fadeTimer invalidate];
        m_fadeTimer = nil;
    }
}

#pragma mark - BGM push/pop

// @ 0x201dc — duck the current BGM onto the stack.
// @complete
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
// @complete
- (void)popBgm {
    [self releaseBgm];
    m_bgmPlayer = m_pushBgmPlayer;
    m_bgmPlayer.delegate = self;
    m_pushBgmPlayer = nil;
}

// @ 0x202c8
// @complete
- (BOOL)isPushBgm {
    return m_pushBgmPlayer != nil;
}

#pragma mark - SE

// @ 0x1e8b8 — the group a loaded SE belongs to (0 = caplayer, else
// AVFoundation), looked up in m_seType by call name or by boxed resource id.
// @complete
- (int)getGroupID:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId {
    id key = name ? name : @(static_cast<unsigned>(resourceId));
    return [[m_seType objectForKey:key] intValue];
}

// @ 0x1e914 — load a sound effect into one of the two backends. (See loadSe
// body unchanged below; kept from the previous reconstruction.)
// @complete
- (RSND_SOURCE_ID)loadSe:(NSString *)path
                  isLoop:(BOOL)loop
                callName:(NSString *)name
                   group:(int)group {
    if (path == nil) {
        return RSND_INSTANCE_ID_ERROR;
    }
    if (group == 0) {
        const char *cpath = path.UTF8String;
        if (name == nil) {
            RSND_SOURCE_ID rid = m_caPlayer->load(cpath, loop);
            if (rid != static_cast<RSND_SOURCE_ID>(-1)) {
                [m_seRidList addObject:@(static_cast<unsigned>(rid))];
            }
            // The returned source id is the raw rid tagged with the group-0 backend
            // bit; it is both the caller's handle and the m_seType key (value = group
            // 0).
            RSND_SOURCE_ID packed =
                static_cast<RSND_SOURCE_ID>(static_cast<unsigned>(rid) | 0x10000000u);
            m_seType[@(static_cast<unsigned>(packed))] = @(0);
            return packed;
        }
        if (m_caPlayer->loadNamed(cpath, name.UTF8String, loop)) {
            [m_seNameList addObject:name];
        }
        m_seType[name] = @(group);
        return RSND_INSTANCE_ID_ERROR;
    }
    NSURL *url = [NSURL fileURLWithPath:path];
    if (name == nil) {
        RSND_SOURCE_ID rid = static_cast<RSND_SOURCE_ID>(m_seAVPlayer->load(url, loop));
        if (rid != static_cast<RSND_SOURCE_ID>(-1)) {
            [m_seRidList addObject:@(static_cast<unsigned>(rid))];
        }
        // As above: return the AVFoundation-tagged packed id and key m_seType by it
        // (value = group).
        RSND_SOURCE_ID packed =
            static_cast<RSND_SOURCE_ID>(static_cast<unsigned>(rid) | 0x60000000u);
        m_seType[@(static_cast<unsigned>(packed))] = @(group);
        return packed;
    }
    if (m_seAVPlayer->loadNamed(url, name, loop)) {
        [m_seNameList addObject:name];
    }
    m_seType[name] = @(group);
    return RSND_INSTANCE_ID_ERROR;
}

// @ 0x1f00c — reserve a playing instance in the right backend, stealing an old
// instance if the backend is out of voices; register it and return the handle.
// @complete
- (RSND_INSTANCE_ID)prepare:(NSString *)name
                 resourceId:(RSND_SOURCE_ID)resourceId
                     volume:(float)volume {
    [self orderInstanceList];
    int group = [self getGroupID:name resourceId:resourceId];

    RSND_INSTANCE_ID handle = [self prepareInGroup:group
                                              name:name
                                        resourceId:resourceId
                                            volume:volume];
    if (handle == static_cast<RSND_INSTANCE_ID>(-1)) {
        [self stopOldInstance];
        handle = [self prepareInGroup:group name:name resourceId:resourceId volume:volume];
    }
    [self addInstance:handle group:group];
    return handle;
}

// Dispatch a prepare to the CoreAudio or AVFoundation backend, by id or name.
- (RSND_INSTANCE_ID)prepareInGroup:(int)group
                              name:(NSString *)name
                        resourceId:(RSND_SOURCE_ID)resourceId
                            volume:(float)volume {
    if (name == nil) {
        uint32_t rid = static_cast<uint32_t>(resourceId & 0xfffffff);
        return (group == 0) ? m_caPlayer->prepare(rid, volume) : m_seAVPlayer->prepare(rid, volume);
    }
    return (group == 0) ? m_caPlayer->prepareNamed(name.UTF8String, volume) :
                          m_seAVPlayer->prepareNamed(name, volume);
}

// @ 0x1f234 — play a sound effect; group 0 goes through the CoreAudio caplayer,
// others through the AVFoundation player.
// @complete
- (RSND_INSTANCE_ID)playSe:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId {
    if (name == nil && resourceId == static_cast<RSND_SOURCE_ID>(-1)) {
        // Temporary NE_DBG: a -1 id means the SE never loaded (loadSe returned an error),
        // so the menu voice was never registered.
        NE_DBG(neDebugLog("playSe idERR rid=-1 (SE not loaded)"));
        return RSND_INSTANCE_ID_ERROR;
    }
    int group = [self getGroupID:name resourceId:resourceId];
    RSND_INSTANCE_ID handle = [self prepare:name resourceId:resourceId volume:m_seVolume[group]];
    if (handle == static_cast<RSND_INSTANCE_ID>(-1)) {
        // Temporary NE_DBG: diagnose the silent main-menu mode SEs. A -1 here means
        // prepare found no free voice or a bad source id.
        NE_DBG(neDebugLog("playSe prepFAIL rid=0x%x group=%d vol=%.0f",
                          static_cast<unsigned>(resourceId),
                          group,
                          static_cast<double>(m_seVolume[group])));
        return RSND_INSTANCE_ID_ERROR;
    }
    bool played;
    if (group == 0) {
        played = m_caPlayer->play(static_cast<uint32_t>(handle));
    } else {
        played = m_seAVPlayer->play(static_cast<uint32_t>(handle));
    }
    // Temporary NE_DBG: group should be 1 for the menu voices; played==0 points at
    // the AVBus/session, group==0 at a getGroupID (m_seType key) miss, vol==0 at a
    // volume issue.
    NE_DBG(neDebugLog("playSe rid=0x%x group=%d vol=%.0f handle=0x%x played=%d",
                      static_cast<unsigned>(resourceId),
                      group,
                      static_cast<double>(m_seVolume[group]),
                      static_cast<unsigned>(handle),
                      played ? 1 : 0));
    return handle;
}

// @ 0x1f2d8 — as playSe:resourceId: but with an explicit per-shot volume level
// rather than the group's stored level. Self-contained in the binary: it clamps
// the level, prepares the instance at that level, and starts it; it does not
// touch m_seVolume nor delegate to playSe:resourceId:. The level is an integer
// clamped to [0, 127] (0x1f302: blt -> 0; 0x1f306: cmp #0x7f, gt -> 0x7f) and
// forwarded raw to prepare:resourceId:volume: — the same raw 32-bit forwarding
// the other play/prepare paths use (m_seVolume itself holds the integer level
// 0..127, e.g. init @ 0x1e0b2 stores 0x7f, not the float 127.0f), so the level
// is passed straight through with no int->float conversion.
//
// NOT marked @complete: the control flow now matches the binary (the prior
// reconstruction wrongly wrote m_seVolume[group] and delegated to
// playSe:resourceId:), but prepare:resourceId:volume: is declared with a float
// volume, so passing the clamped int level implies an int->float conversion the
// binary does not perform (it stores the raw int level into the forwarded
// slot). Making this bit-faithful requires re-typing the whole prepare/backend
// volume path (m_seVolume is a float[] yet init stores the integer 0x7f into
// it) across sibling files, which is outside this file's scope.
- (RSND_INSTANCE_ID)playSe:(NSString *)name
                resourceId:(RSND_SOURCE_ID)resourceId
                    Volume:(int)volume {
    if (name == nil && resourceId == static_cast<RSND_SOURCE_ID>(-1)) {
        return RSND_INSTANCE_ID_ERROR;
    }
    int level = volume;
    if (level < 0) {
        level = 0;
    } else if (level > 0x7f) {
        level = 0x7f;
    }
    int group = [self getGroupID:name resourceId:resourceId];
    RSND_INSTANCE_ID handle = [self prepare:name resourceId:resourceId volume:level];
    if (handle == static_cast<RSND_INSTANCE_ID>(-1)) {
        return RSND_INSTANCE_ID_ERROR;
    }
    if (group != 0) {
        m_seAVPlayer->play(static_cast<uint32_t>(handle));
    } else {
        m_caPlayer->play(static_cast<uint32_t>(handle));
    }
    return handle;
}

// @ 0x1f3d0 — stop the SE instance `handle` in whichever backend owns it.
// @complete
- (BOOL)stopSe:(RSND_INSTANCE_ID)instanceId {
    for (int i = 0; i < 8; i++) {
        if (m_seList[i].handle == instanceId) {
            return m_seList[i].group != 0 ? m_seAVPlayer->stop(static_cast<uint32_t>(instanceId)) :
                                            m_caPlayer->stop(static_cast<uint32_t>(instanceId));
        }
    }
    return NO;
}

// @ 0x1f630 — stop every tracked SE instance.
// @complete
- (BOOL)stopSeAll {
    for (int i = 0; i < 8; i++) {
        if (m_seList[i].group != 0) {
            m_seAVPlayer->stop(static_cast<uint32_t>(m_seList[i].handle));
        } else {
            m_caPlayer->stop(static_cast<uint32_t>(m_seList[i].handle));
        }
    }
    return YES;
}

// @ 0x1f6dc — reap finished SE instances (state -1/4), freeing their voices,
// then compact the list so the oldest live instance is first.
// @complete
- (void)orderInstanceList {
    for (int i = 0; i < 8; i++) {
        if (m_seList[i].handle == kFreeInstance) {
            break;
        }
        int state = m_seList[i].group != 0 ?
                        m_seAVPlayer->voiceState(static_cast<uint32_t>(m_seList[i].handle)) :
                        m_caPlayer->voiceState(static_cast<uint32_t>(m_seList[i].handle));
        if (state == -1 || state == 4) {
            if (m_seList[i].group != 0) {
                m_seAVPlayer->stop(static_cast<uint32_t>(m_seList[i].handle));
            } else {
                m_caPlayer->stop(static_cast<uint32_t>(m_seList[i].handle));
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

// @ 0x1f8fc — steal the oldest instance's voice to make room, shifting the
// list.
// @complete
- (void)stopOldInstance {
    if (m_seList[0].group != 0) {
        m_seAVPlayer->stop(static_cast<uint32_t>(m_seList[0].handle));
    } else {
        m_caPlayer->stop(static_cast<uint32_t>(m_seList[0].handle));
    }
    for (int i = 0; i < 7; i++) {
        m_seList[i] = m_seList[i + 1];
    }
    m_seList[7].handle = kFreeInstance;
    m_seList[7].group = 0;
}

// @ 0x1f964 — record a newly-prepared instance in the first free slot.
// @complete
- (void)addInstance:(RSND_INSTANCE_ID)handle group:(int)group {
    for (int i = 0; i < 8; i++) {
        if (m_seList[i].handle == kFreeInstance) {
            m_seList[i].handle = handle;
            m_seList[i].group = group;
            return;
        }
    }
}

// @ 0x1f99c — set the SE volume for a group (level 0..127): the caplayer sets
// its 8 voices, the AVFoundation pool scales each player. The group index is
// stored unconditionally (no bounds check in the binary; 0x1f9bc:
// str.w volume,[seVolume,group,lsl #2]) before the group split.
// @complete
- (void)setSeVolume:(int)volume groupId:(int)group {
    if (volume >= 0x80) {
        return; // 0x1f9a8: cmp #0x7f, bhi
    }
    m_seVolume[group] = volume;
    if (group != 0) {
        // 0x1f9dc tail-calls into neAVSePlayer::setGroupVolume with the raw
        // integer level; the /127.0f conversion happens inside that method
        // (0x210b6: vcvt.f32.s32; 0x210d4: vdiv by 127.0f), not here.
        m_seAVPlayer->setGroupVolume(volume);
    } else {
        // 0x1f9e0: the caplayer level is applied by calling the per-voice gain
        // setter (Ghidra caHandleSetVolume @ 0x267e4) once for each of the 8
        // voices (0x1f9e4: r5 = 8; 0x1f9f8: subs/bne loop).
        for (int i = 0; i < kSeVoiceCount; i++) {
            m_caPlayer->setAllVoiceVolume(volume);
        }
    }
}

// @ 0x1f434 — pause the SE instance `instanceId` in whichever backend owns it.
// @complete
- (BOOL)onPauseSe:(RSND_INSTANCE_ID)instanceId {
    for (int i = 0; i < 8; i++) {
        if (m_seList[i].handle == instanceId) {
            return m_seList[i].group != 0 ? m_seAVPlayer->pause(static_cast<uint32_t>(instanceId)) :
                                            m_caPlayer->pause(static_cast<uint32_t>(instanceId));
        }
    }
    return NO;
}

// @ 0x1f498 — resume the SE instance `instanceId` in whichever backend owns it.
// @complete
- (BOOL)offPauseSe:(RSND_INSTANCE_ID)instanceId {
    for (int i = 0; i < 8; i++) {
        if (m_seList[i].handle == instanceId) {
            return m_seList[i].group != 0 ? m_seAVPlayer->play(static_cast<uint32_t>(instanceId)) :
                                            m_caPlayer->play(static_cast<uint32_t>(instanceId));
        }
    }
    return NO;
}

// @ 0x1f4fc — YES if the SE instance `instanceId` is currently playing (state
// 2).
// @complete
- (BOOL)isPlayingSe:(RSND_INSTANCE_ID)instanceId {
    for (int i = 0; i < 8; i++) {
        if (m_seList[i].handle == instanceId) {
            int state = m_seList[i].group != 0 ?
                            m_seAVPlayer->voiceState(static_cast<uint32_t>(instanceId)) :
                            m_caPlayer->voiceState(static_cast<uint32_t>(instanceId));
            return state == 2;
        }
    }
    return NO;
}

// @ 0x1f568 — pause every tracked SE instance (all 8 slots, backend per slot).
// @complete
- (BOOL)onPauseSeAll {
    for (int i = 0; i < 8; i++) {
        if (m_seList[i].group != 0) {
            m_seAVPlayer->pause(static_cast<uint32_t>(m_seList[i].handle));
        } else {
            m_caPlayer->pause(static_cast<uint32_t>(m_seList[i].handle));
        }
    }
    return YES;
}

// @ 0x1f5cc — resume every tracked SE instance.
// @complete
- (BOOL)offPauseSeAll {
    for (int i = 0; i < 8; i++) {
        if (m_seList[i].group != 0) {
            m_seAVPlayer->play(static_cast<uint32_t>(m_seList[i].handle));
        } else {
            m_caPlayer->play(static_cast<uint32_t>(m_seList[i].handle));
        }
    }
    return YES;
}

#pragma mark - SE SetGroup pool (caplayer, fixed voices)

// @ 0x1f7ec — reap finished voices in the bank, compact the live slots to the
// front (each keeping its fixed voiceIndex), and return the first free slot
// index, or -1 when the bank is full.
// @complete
- (int)orderInstanceList:(int)groupId {
    for (int i = 0; i < kSeSetGroupVoices; i++) {
        RSND_INSTANCE_ID handle = m_seManageId[groupId][i].handle;
        if (handle == kFreeInstance) {
            break;
        }
        int state = m_caPlayer->voiceState(static_cast<uint32_t>(handle));
        if (state == -1 || state == 4) {
            m_caPlayer->stop(static_cast<uint32_t>(handle)); // stop-and-clear the voice
            m_seManageId[groupId][i].handle = kFreeInstance;
        }
    }
    // Compact: pull a later live slot forward, swapping handle + fixed
    // voiceIndex.
    for (int i = 0; i < kSeSetGroupVoices - 1; i++) {
        if (m_seManageId[groupId][i].handle == kFreeInstance) {
            int j = i + 1;
            while (j < kSeSetGroupVoices && m_seManageId[groupId][j].handle == kFreeInstance) {
                j++;
            }
            if (j >= kSeSetGroupVoices) {
                break;
            }
            RSND_INSTANCE_ID movedHandle = m_seManageId[groupId][j].handle;
            int savedVoice = m_seManageId[groupId][i].voiceIndex;
            m_seManageId[groupId][i].handle = movedHandle;
            m_seManageId[groupId][i].voiceIndex = m_seManageId[groupId][j].voiceIndex;
            m_seManageId[groupId][j].handle = kFreeInstance;
            m_seManageId[groupId][j].voiceIndex = savedVoice;
            if (m_seManageId[groupId][i].handle == kFreeInstance) {
                break;
            }
        }
    }
    for (int i = 0; i < kSeSetGroupVoices; i++) {
        if (m_seManageId[groupId][i].handle == kFreeInstance) {
            return i;
        }
    }
    return -1;
}

// @ 0x1f164 — reserve a caplayer voice in the given bank (stealing the bank's
// oldest instance if it is full), prepare it on that slot's fixed voice, record
// the handle and return it.
// @complete
- (RSND_INSTANCE_ID)prepareSetGroup:(NSString *)name
                         resourceId:(RSND_SOURCE_ID)resourceId
                            groupId:(int)groupId {
    int slot = [self orderInstanceList:groupId];
    if (slot == -1) {
        [self stopSe:m_seManageId[groupId][0].handle];
        slot = [self orderInstanceList:groupId];
        if (slot == -1) {
            return RSND_INSTANCE_ID_ERROR;
        }
    }
    int voiceIndex = m_seManageId[groupId][slot].voiceIndex;
    RSND_INSTANCE_ID handle;
    if (name == nil) {
        handle = m_caPlayer->prepareAtVoice(static_cast<uint32_t>(resourceId), voiceIndex);
    } else {
        handle = m_caPlayer->prepareNamedAtVoice(name, voiceIndex);
    }
    m_seManageId[groupId][slot].handle = handle;
    return handle;
}

// @ 0x1f380 — prepare a SetGroup voice and start it.
// @complete
- (RSND_INSTANCE_ID)playSeSetGroup:(NSString *)name
                        resourceId:(RSND_SOURCE_ID)resourceId
                           groupId:(int)groupId {
    if (name != nil || resourceId != static_cast<RSND_SOURCE_ID>(-1)) {
        RSND_INSTANCE_ID handle = [self prepareSetGroup:name resourceId:resourceId groupId:groupId];
        if (handle != static_cast<RSND_INSTANCE_ID>(-1)) {
            m_caPlayer->play(static_cast<uint32_t>(handle));
            return handle;
        }
    }
    return RSND_INSTANCE_ID_ERROR;
}

#pragma mark - SE resource release

// @ 0x1eba8 — free a single loaded SE source (by call name or source id) from
// its backend and drop it from the load-order lists and the type table.
// @complete
- (void)releaseSe:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId {
    int group = [self getGroupID:name resourceId:resourceId];
    if (name == nil) {
        if (group == 0) {
            m_caPlayer->unregisterSource(static_cast<uint32_t>(resourceId & 0xfffffff));
        } else {
            m_seAVPlayer->unregisterSource(static_cast<uint32_t>(resourceId & 0xfffffff));
        }
        NSUInteger count = m_seRidList.count;
        for (NSUInteger i = 0; i < count; i++) {
            if ((RSND_SOURCE_ID)[m_seRidList[i] intValue] == resourceId) {
                [m_seRidList removeObjectAtIndex:i];
                break;
            }
            count = m_seRidList.count;
        }
        [m_seType removeObjectForKey:[NSNumber numberWithInt:static_cast<int>(resourceId)]];
    } else {
        if (group == 0) {
            m_caPlayer->unregisterSourceNamed(name);
        } else {
            m_seAVPlayer->unregisterSourceNamed(name);
        }
        NSUInteger count = m_seNameList.count;
        for (NSUInteger i = 0; i < count; i++) {
            if ([name compare:m_seNameList[i]] == NSOrderedSame) {
                [m_seNameList removeObjectAtIndex:i];
                break;
            }
            count = m_seNameList.count;
        }
        [m_seType removeObjectForKey:name];
    }
}

// @ 0x1eda8 — free every loaded SE source in both backends and clear the
// tables.
// @complete
- (void)releaseSeAll {
    NSUInteger nameCount = m_seNameList.count;
    for (NSUInteger i = 0; i < nameCount; i++) {
        NSString *name = m_seNameList[i];
        if ([self getGroupID:name resourceId:0] == 0) {
            m_caPlayer->unregisterSourceNamed(name);
        } else {
            m_seAVPlayer->unregisterSourceNamed(name);
        }
        nameCount = m_seNameList.count;
    }
    [m_seNameList removeAllObjects];

    NSUInteger ridCount = m_seRidList.count;
    for (NSUInteger i = 0; i < ridCount; i++) {
        RSND_SOURCE_ID rid = (RSND_SOURCE_ID)[m_seRidList[i] intValue];
        if ([self getGroupID:nil resourceId:rid] == 0) {
            m_caPlayer->unregisterSource(static_cast<uint32_t>(rid & 0xfffffff));
        } else {
            m_seAVPlayer->unregisterSource(static_cast<uint32_t>(rid & 0xfffffff));
        }
        ridCount = m_seRidList.count;
    }
    [m_seRidList removeAllObjects];
    [m_seType removeAllObjects];
}

// @ 0x1e238 — full SE teardown/reset: release every source, destroy and rebuild
// both backends, reset the lookup lists and both instance pools, then restart
// the engines. The C++ engines are explicitly destroyed and re-created; the
// ObjC-list releases are dropped under ARC (the reassignments free the old
// objects).
// @complete
- (void)cleanupSe {
    [self releaseSeAll];

    delete m_caPlayer;   // ~neAVCAPlayer
    delete m_seAVPlayer; // ~neAVSePlayer (audio mixer)
    m_caPlayer = new neAVCAPlayer();
    m_seAVPlayer = new neAVSePlayer();

    m_seNameList = [[NSMutableArray alloc] init];
    m_seRidList = [[NSMutableArray alloc] init];
    m_seType = [[NSMutableDictionary alloc] init];

    for (int i = 0; i < 8; i++) {
        m_seList[i].handle = kFreeInstance;
    }
    for (int g = 0; g < kSeSetGroupCount; g++) {
        m_seVolume[g] = 0x7f;
        for (int v = 0; v < kSeSetGroupVoices; v++) {
            m_seManageId[g][v].handle = kFreeInstance;
            m_seManageId[g][v].voiceIndex = g * kSeSetGroupVoices + v;
        }
    }
    [self onStartPlayer:nil];
}

#pragma mark - VOICE channel (a second BGM-like player)

// @ 0x1e708
// @complete
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

// @ 0x1e7f0 — load the VOICE channel straight from in-memory data.
// @complete
- (BOOL)loadVoiceData:(NSData *)data isLoop:(BOOL)loop {
    if (data == nil) {
        return NO;
    }
    m_voicePlayer = nil; // ARC releases the previous player
    NSError *error = nil;
    m_voicePlayer = [[AVAudioPlayer alloc] initWithData:data error:&error];
    if (error != nil) {
        return NO;
    }
    m_voicePlayer.numberOfLoops = loop ? -1 : 0;
    m_voicePlayer.delegate = self;
    [m_voicePlayer prepareToPlay];
    return YES;
}

// @ 0x1efdc — release the VOICE player.
// @complete
- (void)releaseVoice {
    if (m_voicePlayer == nil) {
        return;
    }
    m_voicePlayer = nil; // ARC releases the player
}

// @ 0x2042c — YES only when a VOICE player is loaded and actually playing.
// @complete
- (BOOL)isPlayingVoice {
    if (m_voicePlayer == nil) {
        return NO;
    }
    return [m_voicePlayer isPlaying];
}

// @ 0x2030c
// @complete
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
// @complete
- (BOOL)stopVoice {
    if (m_voicePlayer == nil) {
        return NO;
    }
    [m_voicePlayer stop];
    m_isPlayingVoice = NO;
    return YES;
}

// @ 0x203c8
// @complete
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
// @complete
- (void)seekBgmToTop {
    if (m_bgmPlayer != nil) {
        m_bgmPlayer.currentTime = 0;
    }
}

// @ 0x1fa38 — ramp the BGM volume up to its target over `seconds`.
// @complete
- (void)createBgmFadeInTimer:(float)seconds {
    [self deleteFadeTimer];
    const float kTick = 0.05f; // Ghidra: DAT_0001fb20 (per-tick interval, 0.05s)
    m_unitVolume = (m_bgmSettingVolume / seconds) * kTick;
    m_fadeTimer = [NSTimer timerWithTimeInterval:kTick
                                          target:self
                                        selector:@selector(onFadeInTimer:)
                                        userInfo:nil
                                         repeats:YES];
    [NSRunLoop.currentRunLoop addTimer:m_fadeTimer forMode:NSRunLoopCommonModes];
}

// @ 0x1fb28 — ramp the BGM volume down to zero over `seconds`.
// @complete
- (void)createBgmFadeOutTimer:(float)seconds {
    [self deleteFadeTimer];
    const float kTick = 0.05f; // Ghidra: DAT_0001fc18 (per-tick interval, 0.05s)
    m_unitVolume = (-m_bgmSettingVolume / seconds) * kTick;
    m_fadeTimer = [NSTimer timerWithTimeInterval:kTick
                                          target:self
                                        selector:@selector(onFadeOutTimer:)
                                        userInfo:nil
                                         repeats:YES];
    [NSRunLoop.currentRunLoop addTimer:m_fadeTimer forMode:NSRunLoopCommonModes];
}

// @ 0x2002c — ramp the BGM volume up one tick; clamp to the target and stop the
// timer once reached. Ignores stale timers that have already been replaced.
// @complete
- (void)onFadeInTimer:(NSTimer *)timer {
    if (m_fadeTimer != timer) {
        return;
    }
    float v = m_bgmPlayer.volume + m_unitVolume;
    if (v >= m_bgmSettingVolume) {
        m_bgmPlayer.volume = m_bgmSettingVolume;
        [m_fadeTimer invalidate];
        m_fadeTimer = nil;
    }
    m_bgmPlayer.volume = v;
}

// @ 0x200ec — ramp the BGM volume down one tick; on reaching zero stop the
// timer and either pause (when this fade is a pause) or stop the player
// outright.
// @complete
- (void)onFadeOutTimer:(NSTimer *)timer {
    if (m_fadeTimer != timer) {
        return;
    }
    float v = m_bgmPlayer.volume + m_unitVolume;
    if (v < 0.0f) {
        m_bgmPlayer.volume = 0;
        [m_fadeTimer invalidate];
        m_fadeTimer = nil;
        if (!m_isOnPause) {
            [m_bgmPlayer stop];
            m_isPlaying = NO;
            return;
        }
        [m_bgmPlayer pause];
        return;
    }
    m_bgmPlayer.volume = v;
}

// @ 0x20500 — interrupt a channel (0 = BGM, 1 = VOICE), stopping its player.
// @complete
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
// @complete
- (void)resumePlayer:(int)which {
    if (which > 1) {
        return;
    }
    if (which == 1) {
        if (!m_isInterruptionVoice) {
            return;
        }
        m_isInterruptionVoice = NO;
        if (m_isPlayingVoice && !m_isOnPauseVoice) {
            [self playVoice];
        }
    } else {
        if (!m_isInterruption) {
            return;
        }
        m_isInterruption = NO;
        if (m_isPlaying && !m_isOnPause) {
            // 0x205ba loads the double 0.3 (literal @ 0x205d8 = 0x3fd3333340000000,
            // i.e. 0.3f widened), so resume fades the BGM back in over 0.3s.
            [self playBgm:0.3f];
        }
    }
}

#pragma mark - Global stop

// @ 0x1f694 — stop the BGM, the VOICE channel and every SE instance at once.
// @complete
- (BOOL)stopAll {
    [self stopBgm:0];
    [self stopVoice];
    [self stopSeAll];
    return YES;
}

#pragma mark - AVAudioPlayerDelegate

// @ 0x20460 — a player finished: clear the matching channel's playing flag.
// @complete
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (m_bgmPlayer == player) {
        m_isPlaying = NO;
    }
    if (m_voicePlayer == player) {
        m_isPlayingVoice = NO;
    }
}

// @ 0x204ac — audio session interrupted: mark the matching channel interrupted.
// @complete
- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    if (m_bgmPlayer == player) {
        m_isInterruption = YES;
    } else {
        m_isInterruptionVoice = YES;
    }
}

// @ 0x204d4 — interruption ended: resume the matching channel (0 = BGM, 1 =
// VOICE).
// @complete
- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player {
    [self resumePlayer:(m_bgmPlayer != player) ? 1 : 0];
}

// Tear the SE backends down. Ghidra: systemTerminate.
- (void)systemTerminate {
    [self stopSeAll];
    m_caPlayer->suspend();
    m_seAVPlayer->suspend();
    m_isStart = NO;
}

@end
