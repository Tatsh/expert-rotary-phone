//
//  AVBus.mm
//  pop'n rhythmin
//
//  One AVAudioPlayer voice with a tiny playback state machine; the bus is the
//  player's delegate.
//

#import "AVBus.h"

@implementation AVBus {
    AVAudioPlayer *mPlayer; // the wrapped voice (strong)
    int mStatus;            // AVBusStatus
    AVSource *mSource;      // non-owning pointer to the current source descriptor
    uint16_t mCurrentID;    // generation, bumped on removeSource
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        mStatus = AVBusStatusNone;
    }
    return self;
}

- (BOOL)initWithContentsOfURL:(NSURL *)url isLoop:(BOOL)loop {
    if (mPlayer != nil) {
        mPlayer = nil; // release old player before reloading
    }
    NSError *error = nil;
    // The binary did [AVAudioPlayer new] then re-init the same object (a double
    // init). Modern iOS's AVAudioPlayer -init yields a
    // non-functional player and the following initWithContentsOfURL: leaves
    // mPlayer unusable without setting `error`, so every SE voice was silent. Use
    // the single designated initializer instead, exactly as the data variant
    // already does. This is a modern-iOS correctness fix, not a behaviour change.
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (player != nil && error == nil) {
        mPlayer = player;
        player.numberOfLoops = loop ? -1 : 0;
        mPlayer.delegate = self;
        mStatus = AVBusStatusNone;
        return YES;
    }
    return NO; // ARC releases the failed player as it leaves scope
}

- (BOOL)initWithContentsOfData:(NSData *)data isLoop:(BOOL)loop {
    if (mPlayer != nil) {
        mPlayer = nil; // release old player before reloading
    }
    NSError *error = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithData:data error:&error];
    if (error == nil) {
        mPlayer = player; // the binary retains here; the strong ivar handles it under ARC
        player.numberOfLoops = loop ? -1 : 0;
        mPlayer.delegate = self;
        mStatus = AVBusStatusNone;
        return YES;
    }
    return NO; // ARC releases the failed player as it leaves scope
}

- (uint16_t)setSource:(AVSource *)source {
    mSource = source;
    if (source->url == nil) {
        [self initWithContentsOfData:source->data isLoop:source->loop];
    } else {
        [self initWithContentsOfURL:source->url isLoop:source->loop];
    }
    return mCurrentID;
}

- (BOOL)removeSource {
    mSource = NULL;
    mCurrentID = static_cast<uint16_t>(mCurrentID + 1);
    BOOL had = (mPlayer != nil);
    if (had) {
        mPlayer = nil; // release and clear
    }
    return had;
}

- (BOOL)prepare {
    if (mPlayer != nil && !mPlayer.isPlaying) {
        [mPlayer prepareToPlay];
        mStatus = AVBusStatusPrepared;
        return YES;
    }
    return NO;
}

- (BOOL)play {
    // (mStatus | 2) == 3, i.e. Prepared(1) or Paused(3).
    if (((mStatus | 2) == 3) && mPlayer != nil) {
        [mPlayer play];
        mStatus = AVBusStatusPlaying;
        return YES;
    }
    return NO;
}

- (BOOL)stop {
    if (mPlayer != nil) {
        [mPlayer stop];
        mStatus = AVBusStatusStopped;
        return YES;
    }
    return NO;
}

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

- (BOOL)offPause {
    if (mPlayer != nil && mStatus == AVBusStatusPaused) {
        [mPlayer play];
        mStatus = AVBusStatusPlaying;
        return YES;
    }
    return NO;
}

- (BOOL)setVolume:(float)volume {
    if (mPlayer != nil) {
        mPlayer.volume = volume;
        return YES;
    }
    return NO;
}

// When no player is loaded the binary returns 1.0f (full volume), not 0.0f.
- (float)volume {
    if (mPlayer != nil) {
        return mPlayer.volume;
    }
    return 1.0f;
}

- (int)status {
    return mStatus;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    mStatus = AVBusStatusStopped;
}

- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    if (mStatus != AVBusStatusPlaying) {
        return;
    }
    mStatus = player.isPlaying ? AVBusStatusPlaying : AVBusStatusStopped;
}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player {
    if (mStatus != AVBusStatusPlaying) {
        return;
    }
    [player play];
}

// dealloc is ARC-omitted. The original dealloc only did [mPlayer release] then
// [super dealloc]; both are automatic under ARC (mPlayer is a strong ivar). It
// performed no real teardown (it did not stop the player), so no explicit
// dealloc is required.

- (BOOL)isSameSource:(AVSource *)source {
    return mSource == source;
}

- (uint16_t)currentID {
    return mCurrentID;
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
