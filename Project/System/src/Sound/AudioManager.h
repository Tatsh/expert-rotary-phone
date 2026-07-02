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
- (BOOL)playBgm:(float)fadeSeconds;                   // Ghidra: @ 0x1fcc0
- (BOOL)onPauseBgm:(float)fadeSeconds;                // Ghidra: @ 0x1fec8
- (void)seekBgmToTop;                                 // selector @ 0x11a3d6
- (BOOL)setBgmVolume:(float)volume;                   // Ghidra: @ 0x1fc20
- (BOOL)stopBgm:(float)fadeSeconds;                   // Ghidra: @ 0x1fe10
// Save/restore the current BGM so another can play over it and be swapped back.
- (void)pushBgm;                                      // Ghidra: @ 0x201dc
- (void)popBgm;                                       // Ghidra: @ 0x2027c
- (BOOL)isPushBgm;                                    // Ghidra: @ 0x202c8

// --- VOICE: a second BGM-like channel (no fade). readme.txt "VOICE操作" ---
- (void)loadVoice:(NSString *)path isLoop:(BOOL)loop;
- (void)playVoice;                   // selector @ 0x11a0ef
- (void)stopVoice;                   // selector @ 0x11a007
- (void)onPauseVoice;                // selector @ 0x11a3e3

// --- SE: low-latency CoreAudio (caplayer). readme.txt "SE操作" ---
// Load a sound; keep it addressable by callName and/or the returned source id.
// `group` selects the backend (0 = caplayer, others = AVFoundation).
- (RSND_SOURCE_ID)loadSe:(NSString *)path isLoop:(BOOL)loop callName:(NSString *)name group:(int)group;  // Ghidra: @ 0x1e914
// Play by callName or by source id; returns the playing-instance id.
- (RSND_INSTANCE_ID)playSe:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId;                       // Ghidra: @ 0x1f234
- (RSND_INSTANCE_ID)playSe:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId Volume:(float)volume;  // Ghidra: @ 0x1f2d8
- (void)stopSe:(RSND_INSTANCE_ID)instanceId;         // selector @ 0x119656

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
