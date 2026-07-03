//
//  AudioManager.h
//  pop'n rhythmin
//
//  The app-wide sound singleton. BGM plays through AVAudioPlayer with a push/pop
//  stack (so a screen can duck the current BGM and restore it); VOICE is a second
//  BGM-like channel; sound effects go through a low-latency C++ CoreAudio player
//  (caplayer / lib_rsnd, group 0) or an AVFoundation player (other groups).
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin, cross-checked
//  against the developer manual left in the app bundle (readme.txt) and its
//  changelog (log.txt). Per that manual the class is REFLEC-derived, modelled on
//  jubeat's AudioManager, with SE using the same API as the SSC sound library and
//  a dedicated VOICE channel added. It depends on inc/caplayer.h and the lib_rsnd
//  static library (CoreAudio) plus the AudioToolbox and AVFoundation frameworks.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

// lib_rsnd handles (readme.txt). loadSe returns a source id; playSe returns a
// playing-instance id used to stop that instance later.
typedef unsigned long RSND_SOURCE_ID;
typedef unsigned long RSND_INSTANCE_ID;
static const RSND_INSTANCE_ID RSND_INSTANCE_ID_ERROR = (RSND_INSTANCE_ID)-1;

@interface AudioManager : NSObject <AVAudioPlayerDelegate>

// Thread-safe (@synchronized) lazy singleton. Ghidra: @ 0x1dea0
+ (instancetype)sharedManager;

// System lifecycle (readme.txt "システム開始/終了"). systemStart kicks off
// initialisation on a timer and returns immediately; poll isStart for completion.
// systemStartBlock does the same work synchronously (the legacy ~3s block).
- (void)systemStart;                 // selector @ 0x11a1e0
- (void)systemStartBlock;            // Ghidra: @ 0x1e224
- (BOOL)isStart;                     // selector @ 0x102c30 / 0x11a3ff
- (void)systemTerminate;

// Interruption / resume — call from applicationWillResignActive /
// applicationDidBecomeActive. Ghidra: systemSuspend @ 0x205e0 / systemResume @ 0x2065c.
- (void)systemSuspend;               // selector @ 0x1170a9
- (void)systemResume;                // selector @ 0x1170d9

// --- BGM: one loaded resource at a time, with a save/restore stack ---
- (BOOL)loadBgm:(NSString *)path isLoop:(BOOL)loop;   // Ghidra: @ 0x1e4a8
- (BOOL)loadBgmData:(NSData *)data isLoop:(BOOL)loop; // Ghidra: @ 0x1e5b0 (in-memory BGM)
// Convenience loaders that wrap raw bytes in an NSData and forward to
// loadBgmData:isLoop:. The NoCopy variants let the caller keep ownership of the
// buffer (freeWhenDone: chooses whether NSData frees it). Ghidra:
// loadBgmDataWithBytes:length:isLoop: @ 0x1e63c,
// loadBgmDataWithBytesNoCopy:length:isLoop: @ 0x1e67c,
// loadBgmDataWithBytesNoCopy:length:freeWhenDone:isLoop: @ 0x1e6bc.
- (BOOL)loadBgmDataWithBytes:(const void *)bytes length:(NSUInteger)length isLoop:(BOOL)loop;
- (BOOL)loadBgmDataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length isLoop:(BOOL)loop;
- (BOOL)loadBgmDataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length freeWhenDone:(BOOL)freeWhenDone isLoop:(BOOL)loop;
- (BOOL)playBgm:(float)fadeSeconds;                   // Ghidra: @ 0x1fcc0
- (BOOL)onPauseBgm:(float)fadeSeconds;                // Ghidra: @ 0x1fec8
- (void)seekBgmToTop;                                 // selector @ 0x11a3d6
- (BOOL)setBgmVolume:(float)volume;                   // Ghidra: @ 0x1fc20
// Set the BGM volume immediately with no fade (the "just" variant used while a
// volume slider is being dragged). Ghidra: AudioManager::setJustBgmVolume_
// (PTR_s_setJustBgmVolume__0015b43c), called from -[SoundSettingView bgmSliderValChanged:].
- (BOOL)setJustBgmVolume:(float)volume;
- (BOOL)stopBgm:(float)fadeSeconds;                   // Ghidra: @ 0x1fe10
// Stop the BGM, the VOICE channel and every SE instance in one call. Ghidra:
// stopAll @ 0x1f694.
- (BOOL)stopAll;
// YES while the BGM player exists and is playing. Ghidra: isPlayingBgm @ 0x1fff8.
- (BOOL)isPlayingBgm;
// The BGM player's playhead (seconds). Ghidra: bgmCurrentTime @ 0x1ff58 /
// setBgmCurrentTime: @ 0x1ffb0 (the setter also re-primes the player via prepareToPlay).
- (NSTimeInterval)bgmCurrentTime;
- (void)setBgmCurrentTime:(NSTimeInterval)time;
// The audio device's absolute clock as seen by the BGM player (used to schedule
// playback with playAtTime:); 0 when nothing is loaded. Ghidra: @ 0x1ff84.
- (NSTimeInterval)bgmDeviceCurrentTime;
// Save/restore the current BGM so another can play over it and be swapped back.
- (void)pushBgm;                                      // Ghidra: @ 0x201dc
- (void)popBgm;                                       // Ghidra: @ 0x2027c
- (BOOL)isPushBgm;                                    // Ghidra: @ 0x202c8

// --- VOICE: a second BGM-like channel (no fade). readme.txt "VOICE操作" ---
- (BOOL)loadVoice:(NSString *)path isLoop:(BOOL)loop;   // Ghidra: @ 0x1e708
// Load the VOICE channel straight from in-memory data. Ghidra: @ 0x1e7f0.
- (BOOL)loadVoiceData:(NSData *)data isLoop:(BOOL)loop;
- (BOOL)playVoice;                   // Ghidra: @ 0x2030c
- (BOOL)stopVoice;                   // Ghidra: @ 0x20388
- (BOOL)onPauseVoice;                // Ghidra: @ 0x203c8
// YES while the VOICE player exists and is playing. Ghidra: @ 0x2042c.
- (BOOL)isPlayingVoice;
// Stop and free the VOICE player. Ghidra: releaseVoice @ 0x1efdc.
- (void)releaseVoice;

// --- SE: low-latency CoreAudio (caplayer). readme.txt "SE操作" ---
// Load a sound; keep it addressable by callName and/or the returned source id.
// `group` selects the backend (0 = caplayer, others = AVFoundation).
- (RSND_SOURCE_ID)loadSe:(NSString *)path isLoop:(BOOL)loop callName:(NSString *)name group:(int)group;  // Ghidra: @ 0x1e914
// Play by callName or by source id; returns the playing-instance id.
- (RSND_INSTANCE_ID)playSe:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId;                       // Ghidra: @ 0x1f234
- (RSND_INSTANCE_ID)playSe:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId Volume:(float)volume;  // Ghidra: @ 0x1f2d8
- (BOOL)stopSe:(RSND_INSTANCE_ID)instanceId;         // Ghidra: @ 0x1f3d0
- (BOOL)stopSeAll;                                   // Ghidra: @ 0x1f630
- (void)setSeVolume:(int)volume groupId:(int)group;  // Ghidra: @ 0x1f99c
// Play an SE through the caplayer's fixed-voice "SetGroup" pool: groupId selects
// one of two banks of 8 caplayer voices (each slot owns a fixed voice), stealing
// the bank's oldest voice when it is full. Returns the play-instance id.
// Ghidra: playSeSetGroup:resourceId:groupId: @ 0x1f380.
- (RSND_INSTANCE_ID)playSeSetGroup:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId groupId:(int)groupId;
// Pause / resume / query a single playing SE instance in whichever backend owns it.
// Ghidra: onPauseSe: @ 0x1f434, offPauseSe: @ 0x1f498, isPlayingSe: @ 0x1f4fc.
- (BOOL)onPauseSe:(RSND_INSTANCE_ID)instanceId;
- (BOOL)offPauseSe:(RSND_INSTANCE_ID)instanceId;
- (BOOL)isPlayingSe:(RSND_INSTANCE_ID)instanceId;
// Pause / resume every tracked SE instance. Ghidra: onPauseSeAll @ 0x1f568,
// offPauseSeAll @ 0x1f5cc.
- (BOOL)onPauseSeAll;
- (BOOL)offPauseSeAll;
// Free a loaded SE source (by callName or source id). Ghidra: AudioManager::
// releaseSe:resourceId: (PTR_s_releaseSe_resourceId_), called during scene teardown.
- (void)releaseSe:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId;
// Free every loaded SE source in both backends and clear the lookup tables.
// Ghidra: releaseSeAll @ 0x1eda8.
- (void)releaseSeAll;
// Free the current BGM resource. Ghidra: AudioManager::releaseBgm (PTR_s_releaseBgm).
- (void)releaseBgm;
// Tear down every playing SE instance / mixer state (scene teardown). Ghidra:
// -[AudioManager cleanupSe] (selector @ 0x15a89c), called from PlayResultTask::
// resultGotoNext (FUN_0003f2e0 @ 0x3f3ce).
- (void)cleanupSe;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
