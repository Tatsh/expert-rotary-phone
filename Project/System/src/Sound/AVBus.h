/** @file
 * A single AVAudioPlayer-backed audio "bus"/voice in the sound engine. Wraps one
 * AVAudioPlayer, tracks a small playback state machine, and acts as the player's delegate so
 * end-of-play and audio-session interruptions update that state.
 */

#pragma once

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

/**
 * @brief A loaded sound-source descriptor.
 * @details Exactly one of url or data selects how the voice is (re)loaded; loop drives
 * AVAudioPlayer.numberOfLoops (-1 vs 0). The bus stores a non-owning pointer to one of these.
 */
typedef struct AVSource {
    NSURL *__unsafe_unretained url;   /*!< Source URL; nil to load from data instead (+0x00). */
    NSData *__unsafe_unretained data; /*!< In-memory source data used when url is nil (+0x04). */
    bool loop;                        /*!< Whether the voice should loop indefinitely (+0x08). */
} AVSource;

/**
 * @brief Playback state kept in mStatus.
 * @details The raw values are the ones the binary stores.
 */
typedef NS_ENUM(int, AVBusStatus) {
    AVBusStatusNone = -1,    /*!< Initial default; no active source. */
    AVBusStatusPrepared = 1, /*!< prepareToPlay has been issued. */
    AVBusStatusPlaying = 2,  /*!< play has been issued. */
    AVBusStatusPaused = 3,   /*!< Paused; the player is stopped but resumable via offPause. */
    AVBusStatusStopped = 4,  /*!< Stopped or finished. */
};

/**
 * @brief A single AVAudioPlayer-backed audio bus or voice.
 *
 * Wraps one AVAudioPlayer, tracks a small playback state machine, and acts as its delegate so
 * end-of-play and audio-session interruptions update that state.
 */
@interface AVBus : NSObject <AVAudioPlayerDelegate>

/**
 * @brief Initialise an empty bus with no loaded source.
 * @return The initialised bus, or nil on failure.
 * @ghidraAddress 0x207a4
 */
- (instancetype)init;

/**
 * @brief (Re)load this voice from a URL.
 * @details This is NOT part of the ARC init family: it returns a BOOL success flag and may be
 * called repeatedly on an already-initialised bus, so it opts out via
 * objc_method_family(none).
 * @param url The URL to load the sound from.
 * @param loop Whether the voice should loop indefinitely.
 * @return YES on success, NO on failure.
 * @ghidraAddress 0x207e4
 */
- (BOOL)initWithContentsOfURL:(NSURL *)url
                       isLoop:(BOOL)loop __attribute__((objc_method_family(none)));
/**
 * @brief (Re)load this voice from in-memory data.
 * @details This is NOT part of the ARC init family: it returns a BOOL success flag and may be
 * called repeatedly on an already-initialised bus, so it opts out via
 * objc_method_family(none).
 * @param data The in-memory sound data to load.
 * @param loop Whether the voice should loop indefinitely.
 * @return YES on success, NO on failure.
 * @ghidraAddress 0x208b0
 */
- (BOOL)initWithContentsOfData:(NSData *)data
                        isLoop:(BOOL)loop __attribute__((objc_method_family(none)));

/**
 * @brief Set the current source descriptor and (re)load the voice from it.
 * @details Loads from the source's data when its url is nil, otherwise from the url.
 * @param source The source descriptor to adopt; stored as a non-owning pointer.
 * @return The current generation ID after loading.
 * @ghidraAddress 0x2098c
 */
- (uint16_t)setSource:(AVSource *)source;
/**
 * @brief Clear the current source, bump the generation ID, and release the player.
 * @return YES if a player was loaded and released, NO otherwise.
 * @ghidraAddress 0x209e0
 */
- (BOOL)removeSource;

/**
 * @brief Prepare the loaded voice for playback.
 * @return YES if preparation was issued, NO if there is no player or it is already playing.
 * @ghidraAddress 0x20a30
 */
- (BOOL)prepare;
/**
 * @brief Start playback when prepared or paused.
 * @return YES if playback started, NO otherwise.
 * @ghidraAddress 0x20a84
 */
- (BOOL)play;
/**
 * @brief Stop playback.
 * @return YES if a player was present and stopped, NO otherwise.
 * @ghidraAddress 0x20acc
 */
- (BOOL)stop;
/**
 * @brief Pause playback, keeping the voice resumable via offPause.
 * @return YES if a player was present, NO otherwise.
 * @ghidraAddress 0x20b0c
 */
- (BOOL)pause;
/**
 * @brief Resume a paused voice.
 * @return YES if a paused player was resumed, NO otherwise.
 * @ghidraAddress 0x20b74
 */
- (BOOL)offPause;

/**
 * @brief Set the playback volume.
 * @param volume The volume to apply to the player.
 * @return YES if a player was present, NO otherwise.
 * @ghidraAddress 0x20bb8
 */
- (BOOL)setVolume:(float)volume;
/**
 * @brief Get the current playback volume.
 * @return The player's volume, or 1.0 (full volume) when no player is loaded.
 * @ghidraAddress 0x20bf0
 */
- (float)volume;
/**
 * @brief Get the current playback state.
 * @return The current AVBusStatus value.
 * @ghidraAddress 0x20c18
 */
- (int)status;

/**
 * @brief Test whether a descriptor is the bus's current source.
 * @param source The source descriptor to compare against.
 * @return YES if it is the same descriptor pointer, NO otherwise.
 * @ghidraAddress 0x20cf4
 */
- (BOOL)isSameSource:(AVSource *)source;
/**
 * @brief Get the current generation ID, bumped on each removeSource.
 * @return The current generation ID.
 * @ghidraAddress 0x20d0c
 */
- (uint16_t)currentID;

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
