//
//  AudioManager.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++ (ARC): the low-latency SE path uses the C++ caplayer.
//

#import "AudioManager.h"

// C++ CoreAudio SE player (caplayer, group 0) + the AVFoundation SE player
// (other groups). Cited engine helpers.
extern "C" {
void neCAPlayerSuspend(void *player);           // Ghidra: FUN_000261e0
void neCAPlayerResume(void *player);            // Ghidra: FUN_000261ec
void neCAPlayerPlay(void *player, int handle);  // Ghidra: FUN_00026784
void neAVSePlayerSuspend(void *player);         // Ghidra: FUN_00021288
void neAVSePlayerResume(void *player);          // Ghidra: FUN_00021294
void neAVSePlayerPlay(void *player, int handle);// Ghidra: FUN_000214a8
}

static const int kSeGroupCount = 16;

@implementation AudioManager {
    BOOL m_isStart;
    BOOL m_isSuspend;
    AVAudioPlayer *m_bgmPlayer;
    AVAudioPlayer *m_pushBgmPlayer;   // the ducked/saved BGM
    void *m_sePlayer;                 // C++ caplayer (group 0)
    void *m_seAVPlayer;               // AVFoundation SE pool (other groups)
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
        neCAPlayerSuspend(m_sePlayer);
        neAVSePlayerSuspend(m_seAVPlayer);
        [self suspendPlayer:0];
        [self suspendPlayer:1];
        m_isSuspend = YES;
    }
}

// @ 0x2065c
- (void)systemResume {
    if (m_isStart && m_isSuspend) {
        neCAPlayerResume(m_sePlayer);
        neAVSePlayerResume(m_seAVPlayer);
        [self resumePlayer:0];
        [self resumePlayer:1];
        m_isSuspend = NO;
    }
}

#pragma mark - BGM push/pop

// @ 0x201dc — duck the current BGM onto the stack.
- (void)pushBgm {
    if (m_pushBgmPlayer != nil && m_bgmPlayer == nil) {
        return;
    }
    [self onPauseBgm:nil];
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

// @ 0x1f234 — play a sound effect by name; group 0 uses the low-latency C++
// caplayer, other groups use the AVFoundation player.
- (unsigned long)playSe:(NSString *)name resourceId:(long)resourceId {
    if (name == nil && resourceId == -1) {
        return (unsigned long)-1;
    }
    int group = [self getGroupID:name resourceId:resourceId];
    int handle = (int)[self prepare:name resourceId:resourceId volume:m_seVolume[group]];
    if (handle == -1) {
        return (unsigned long)-1;
    }
    if (group == 0) {
        neCAPlayerPlay(m_sePlayer, handle);
    } else {
        neAVSePlayerPlay(m_seAVPlayer, handle);
    }
    return (unsigned long)handle;
}

- (unsigned long)playSe:(NSString *)name resourceId:(long)resourceId Volume:(float)volume {
    // @ 0x1f2d8 — as above but with an explicit volume (pending exact body).
    return [self playSe:name resourceId:resourceId];
}

#pragma mark - Declared helpers (bodies pending)

- (void)onStartPlayer:(BOOL)flag {}                 // Ghidra: onStartPlayer:
- (void)suspendPlayer:(int)which {}                 // Ghidra: suspendPlayer:
- (void)resumePlayer:(int)which {}                  // Ghidra: resumePlayer:
- (void)onPauseBgm:(id)sender {}                    // Ghidra: onPauseBgm:
- (void)releaseBgm {}                               // Ghidra: releaseBgm
- (int)getGroupID:(NSString *)name resourceId:(long)resourceId { return 0; } // getGroupID:resourceId:
- (long)prepare:(NSString *)name resourceId:(long)resourceId volume:(float)volume { return -1; }
- (void)loadBgm:(NSString *)path isLoop:(BOOL)loop {}
- (void)setBgmVolume:(float)volume {}
- (void)stopBgm:(float)fadeSeconds {}
- (void)loadSe:(NSString *)path isLoop:(BOOL)loop callName:(NSString *)name group:(int)group {}

@end
