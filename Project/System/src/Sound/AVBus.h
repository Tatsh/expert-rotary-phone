//
//  AVBus.h
//  pop'n rhythmin
//
//  A single AVAudioPlayer-backed audio "bus"/voice in the sound engine. Wraps one
//  AVAudioPlayer, tracks a small playback state machine, and acts as the player's
//  delegate so end-of-play and audio-session interruptions update that state.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (FUN at 0x207a4..0x20d0c).
//

#pragma once

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

// A loaded sound-source descriptor. Exactly one of url/data selects how the voice
// is (re)loaded; loop drives AVAudioPlayer.numberOfLoops (-1 vs 0). The bus stores
// a non-owning pointer to one of these. Ghidra: AVSource (12-byte struct).
typedef struct AVSource {
    NSURL *__unsafe_unretained url;    // +0x00 (nil -> load from data)
    NSData *__unsafe_unretained data;  // +0x04
    bool loop;                         // +0x08
} AVSource;

// Playback state kept in mStatus. Raw values are the ones the binary stores.
typedef NS_ENUM(int, AVBusStatus) {
    AVBusStatusNone     = -1,  // init default / no active source
    AVBusStatusPrepared =  1,  // prepareToPlay issued
    AVBusStatusPlaying  =  2,  // play issued
    AVBusStatusPaused   =  3,  // paused (player stopped, resumable via offPause)
    AVBusStatusStopped  =  4,  // stopped / finished
};

@interface AVBus : NSObject <AVAudioPlayerDelegate>

- (instancetype)init;

// (Re)load this voice from a URL / from in-memory data. These are NOT part of the
// ARC init family: they return a BOOL success flag and may be called repeatedly on
// an already-initialized bus, so they opt out via objc_method_family(none).
- (BOOL)initWithContentsOfURL:(NSURL *)url isLoop:(BOOL)loop __attribute__((objc_method_family(none)));
- (BOOL)initWithContentsOfData:(NSData *)data isLoop:(BOOL)loop __attribute__((objc_method_family(none)));

- (uint16_t)setSource:(AVSource *)source;
- (BOOL)removeSource;

- (BOOL)prepare;
- (BOOL)play;
- (BOOL)stop;
- (BOOL)pause;
- (BOOL)offPause;

- (BOOL)setVolume:(float)volume;
- (float)volume;
- (int)status;

- (BOOL)isSameSource:(AVSource *)source;
- (uint16_t)currentID;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
