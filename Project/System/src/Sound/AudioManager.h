//
//  AudioManager.h
//  pop'n rhythmin
//
//  The app-wide sound singleton. BGM plays through AVAudioPlayer with a push/pop
//  stack (so a screen can duck the current BGM and restore it); sound effects go
//  through one of two backends — a low-latency C++ CoreAudio player (caplayer,
//  group 0) or an AVFoundation player (other groups). Reconstructed from Ghidra
//  project rb420, program PopnRhythmin.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@interface AudioManager : NSObject <AVAudioPlayerDelegate>

// Thread-safe (@synchronized) lazy singleton. Ghidra: @ 0x1dea0
+ (instancetype)sharedManager;

// App lifecycle. Ghidra: systemStartBlock @ 0x1e224 / systemSuspend @ 0x205e0 /
// systemResume @ 0x2065c.
- (void)systemStartBlock;
- (void)systemSuspend;
- (void)systemResume;

// BGM push/pop stack. Ghidra: pushBgm @ 0x201dc / popBgm @ 0x2027c / isPushBgm @ 0x202c8.
- (void)pushBgm;
- (void)popBgm;
- (BOOL)isPushBgm;

// BGM control.
- (void)loadBgm:(NSString *)path isLoop:(BOOL)loop;        // Ghidra: @ 0x1e4a8
- (void)setBgmVolume:(float)volume;                        // Ghidra: @ 0x1fc20
- (void)stopBgm:(float)fadeSeconds;                        // Ghidra: @ 0x1fe10

// SE. Ghidra: loadSe @ 0x1e914 / playSe:resourceId: @ 0x1f234 / ...Volume: @ 0x1f2d8.
- (void)loadSe:(NSString *)path isLoop:(BOOL)loop callName:(NSString *)name group:(int)group;
- (unsigned long)playSe:(NSString *)name resourceId:(long)resourceId;
- (unsigned long)playSe:(NSString *)name resourceId:(long)resourceId Volume:(float)volume;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
