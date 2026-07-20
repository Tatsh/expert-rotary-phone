//
//  AVBus.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (FUN at 0x207a4..0x20d0c). One AVAudioPlayer voice with a tiny playback
//  state machine; the bus is the player's delegate.
//

#import "AVBus.h"

@implementation AVBus {
    AVAudioPlayer *mPlayer; // the wrapped voice (strong)
    int mStatus;            // AVBusStatus
    AVSource *mSource;      // non-owning pointer to the current source descriptor
    uint16_t mCurrentID;    // generation, bumped on removeSource
}

// @ 0x207a4
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        mStatus = AVBusStatusNone;
    }
    return self;
}

// @ 0x207e4
- (BOOL)initWithContentsOfURL:(NSURL *)url isLoop:(BOOL)loop {
    if (mPlayer != nil) {
        mPlayer = nil; // Ghidra: release old player before reloading
    }
    NSError *error = nil;
    // Ghidra: +new then re-init on the same object (double init, faithful).
    AVAudioPlayer *player = [AVAudioPlayer new];
    player = [player initWithContentsOfURL:url error:&error];
    if (error == nil) {
        mPlayer = player;
        player.numberOfLoops = loop ? -1 : 0;
        mPlayer.delegate = self;
        mStatus = AVBusStatusNone;
        return YES;
    }
    return NO; // ARC releases the failed player as it leaves scope
}

// @ 0x208b0
- (BOOL)initWithContentsOfData:(NSData *)data isLoop:(BOOL)loop {
    if (mPlayer != nil) {
        mPlayer = nil; // Ghidra: release old player before reloading
    }
    NSError *error = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithData:data error:&error];
    if (error == nil) {
        mPlayer = player; // Ghidra retains here; the strong ivar handles it under ARC
        player.numberOfLoops = loop ? -1 : 0;
        mPlayer.delegate = self;
        mStatus = AVBusStatusNone;
        return YES;
    }
    return NO; // ARC releases the failed player as it leaves scope
}

// @ 0x2098c
- (uint16_t)setSource:(AVSource *)source {
    mSource = source;
    if (source->url == nil) {
        [self initWithContentsOfData:source->data isLoop:source->loop];
    } else {
        [self initWithContentsOfURL:source->url isLoop:source->loop];
    }
    return mCurrentID;
}

// @ 0x209e0
- (BOOL)removeSource {
    mSource = NULL;
    mCurrentID = static_cast<uint16_t>(mCurrentID + 1);
    BOOL had = (mPlayer != nil);
    if (had) {
        mPlayer = nil; // Ghidra: release + clear
    }
    return had;
}

// @ 0x20a30
- (BOOL)prepare {
    if (mPlayer != nil && !mPlayer.isPlaying) {
        [mPlayer prepareToPlay];
        mStatus = AVBusStatusPrepared;
        return YES;
    }
    return NO;
}

// @ 0x20a84
- (BOOL)play {
    // Ghidra: (mStatus | 2) == 3, i.e. Prepared(1) or Paused(3).
    if (((mStatus | 2) == 3) && mPlayer != nil) {
        [mPlayer play];
        mStatus = AVBusStatusPlaying;
        return YES;
    }
    return NO;
}

// @ 0x20acc
- (BOOL)stop {
    if (mPlayer != nil) {
        [mPlayer stop];
        mStatus = AVBusStatusStopped;
        return YES;
    }
    return NO;
}

// @ 0x20b0c
- (BOOL)pause {
    if (mPlayer != nil) {
        if (mPlayer.isPlaying) {
            [mPlayer stop];
            mStatus = AVBusStatusPaused;
        } else {
            mStatus = AVBusStatusStopped;
        }
        return YES;
    }
    return NO;
}

// @ 0x20b74
- (BOOL)offPause {
    if (mPlayer != nil && mStatus == AVBusStatusPaused) {
        [mPlayer play];
        mStatus = AVBusStatusPlaying;
        return YES;
    }
    return NO;
}

// @ 0x20bb8
- (BOOL)setVolume:(float)volume {
    if (mPlayer != nil) {
        mPlayer.volume = volume;
        return YES;
    }
    return NO;
}

// @ 0x20bf0 -- when no player is loaded the binary returns 1.0f (full volume),
// not 0.0f: the nil path is `mov.eq.w r0,#0x3f800000` at 0x20c02.
- (float)volume {
    if (mPlayer != nil) {
        return mPlayer.volume;
    }
    return 1.0f; // 0x3f800000
}

// @ 0x20c18
- (int)status {
    return mStatus;
}

// @ 0x20c28
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    mStatus = AVBusStatusStopped;
}

// @ 0x20c3c
- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    if (mStatus != AVBusStatusPlaying) {
        return;
    }
    mStatus = player.isPlaying ? AVBusStatusPlaying : AVBusStatusStopped;
}

// @ 0x20c78
- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player {
    if (mStatus != AVBusStatusPlaying) {
        return;
    }
    [player play];
}

// @ 0x20ca0 dealloc -- ARC-omitted. The original dealloc only did
// [mPlayer release] then [super dealloc]; both are automatic under ARC (mPlayer
// is a strong ivar). It performed no real teardown (it did not stop the
// player), so no explicit dealloc is required.

// @ 0x20cf4
- (BOOL)isSameSource:(AVSource *)source {
    return mSource == source;
}

// @ 0x20d0c
- (uint16_t)currentID {
    return mCurrentID;
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
