/** @file
 * The app-wide sound singleton. BGM plays through AVAudioPlayer with a push/pop stack (so a screen
 * can duck the current BGM and restore it); VOICE is a second BGM-like channel; sound effects go
 * through a low-latency C++ CoreAudio player (caplayer / lib_rsnd, group 0) or an AVFoundation
 * player (other groups). The class is REFLEC-derived, modelled on jubeat's AudioManager, with SE
 * using the same API as the SSC sound library and a dedicated VOICE channel added. It depends on
 * inc/caplayer.h and the lib_rsnd static library (CoreAudio) plus the AudioToolbox and AVFoundation
 * frameworks.
 */

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

/** A lib_rsnd source identifier returned by loadSe. */
typedef unsigned long RSND_SOURCE_ID;
/**
 * A lib_rsnd playing-instance identifier returned by playSe and used to stop that instance later.
 */
typedef unsigned long RSND_INSTANCE_ID;
/** Sentinel returned in place of a valid instance identifier when an SE operation fails. */
static const RSND_INSTANCE_ID RSND_INSTANCE_ID_ERROR = (RSND_INSTANCE_ID)-1;

/**
 * @brief The app-wide sound singleton: BGM, VOICE, and sound-effect playback.
 *
 * BGM plays through AVAudioPlayer with a push/pop stack (so a screen can duck the current BGM and
 * restore it); VOICE is a second BGM-like channel; sound effects use the low-latency CoreAudio
 * player (group 0) or an AVFoundation player (other groups).
 */
@interface AudioManager : NSObject <AVAudioPlayerDelegate>

/**
 * @brief Return the thread-safe lazy singleton, creating it on first use.
 * @return The shared AudioManager instance.
 * @ghidraAddress 0x1dea0
 */
+ (instancetype)sharedManager;

/**
 * @brief Start initialisation asynchronously and return immediately.
 * @details Kicks off the work on a zero-delay run-loop timer; poll isStart for completion.
 * @ghidraAddress 0x1e198
 */
- (void)systemStart;
/**
 * @brief Run the same initialisation as systemStart synchronously.
 * @details This is the legacy start that blocks (historically around three seconds).
 * @ghidraAddress 0x1e224
 */
- (void)systemStartBlock;
/**
 * @brief Report whether initialisation has completed.
 * @return YES once both SE backends are up and the system is marked started.
 * @ghidraAddress 0x20790
 */
- (BOOL)isStart;
/**
 * @brief Tear down both SE backends and mark the system stopped.
 */
- (void)systemTerminate;

/**
 * @brief Interrupt playback, pausing both SE backends and both BGM slots.
 * @details Call from applicationWillResignActive.
 * @ghidraAddress 0x205e0
 */
- (void)systemSuspend;
/**
 * @brief Resume playback after a suspend, restarting both SE backends and both BGM slots.
 * @details Call from applicationDidBecomeActive.
 * @ghidraAddress 0x2065c
 */
- (void)systemResume;

/**
 * @brief Load a BGM file, skipping the reload when the same path is already loaded.
 * @param path The file path to load.
 * @param loop YES to loop the BGM indefinitely.
 * @return YES on success; NO on a nil path or a decode error.
 * @ghidraAddress 0x1e4a8
 */
- (BOOL)loadBgm:(NSString *)path isLoop:(BOOL)loop;
/**
 * @brief Load the BGM straight from in-memory data rather than a file path.
 * @param data The in-memory audio data to load.
 * @param loop YES to loop the BGM indefinitely.
 * @return YES on success; NO on nil data or a decode error.
 * @ghidraAddress 0x1e5b0
 */
- (BOOL)loadBgmData:(NSData *)data isLoop:(BOOL)loop;
/**
 * @brief Wrap a copy of the raw bytes in an NSData and load it as BGM.
 * @param bytes The raw audio bytes to copy and load.
 * @param length The number of bytes.
 * @param loop YES to loop the BGM indefinitely.
 * @return YES on success; NO on a decode error.
 * @ghidraAddress 0x1e63c
 */
- (BOOL)loadBgmDataWithBytes:(const void *)bytes length:(NSUInteger)length isLoop:(BOOL)loop;
/**
 * @brief Load the raw bytes as BGM without copying them.
 * @details The NSData wrapper takes ownership and frees the buffer when done.
 * @param bytes The raw audio bytes to load without copying.
 * @param length The number of bytes.
 * @param loop YES to loop the BGM indefinitely.
 * @return YES on success; NO on a decode error.
 * @ghidraAddress 0x1e67c
 */
- (BOOL)loadBgmDataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length isLoop:(BOOL)loop;
/**
 * @brief Load the raw bytes as BGM without copying, letting the caller keep ownership.
 * @param bytes The raw audio bytes to load without copying.
 * @param length The number of bytes.
 * @param freeWhenDone YES to have the NSData wrapper free the buffer; NO to keep ownership.
 * @param loop YES to loop the BGM indefinitely.
 * @return YES on success; NO on a decode error.
 * @ghidraAddress 0x1e6bc
 */
- (BOOL)loadBgmDataWithBytesNoCopy:(void *)bytes
                            length:(NSUInteger)length
                      freeWhenDone:(BOOL)freeWhenDone
                            isLoop:(BOOL)loop;
/**
 * @brief Start the BGM, instantly or via a fade-in timer.
 * @param fadeSeconds The fade-in duration; at or below one fade tick the start is instant.
 * @return YES on success; NO when no BGM is loaded or playback fails to start.
 * @ghidraAddress 0x1fcc0
 */
- (BOOL)playBgm:(float)fadeSeconds;
/**
 * @brief Pause the BGM, instantly or via a fade-out timer.
 * @param fadeSeconds The fade-out duration; at or below one fade tick the pause is instant.
 * @return YES on success; NO when no BGM is loaded.
 * @ghidraAddress 0x1fec8
 */
- (BOOL)onPauseBgm:(float)fadeSeconds;
/**
 * @brief Rewind the BGM playhead to the start.
 * @ghidraAddress 0x202e0
 */
- (void)seekBgmToTop;
/**
 * @brief Remember the requested BGM volume applied on the next play.
 * @param volume The target volume in the range 0 to 1.
 * @return YES on success; NO when no BGM is loaded or the volume is out of range.
 * @ghidraAddress 0x1fc20
 */
- (BOOL)setBgmVolume:(float)volume;
/**
 * @brief Set the BGM volume immediately with no fade and no stored target.
 * @details This is the variant used while a volume slider is being dragged.
 * @param volume The volume in the range 0 to 1.
 * @return YES on success; NO when no BGM is loaded or the volume is out of range.
 * @ghidraAddress 0x1fc6c
 */
- (BOOL)setJustBgmVolume:(float)volume;
/**
 * @brief Stop the BGM, instantly or via a fade-out timer.
 * @param fadeSeconds The fade-out duration; at or below one fade tick the stop is instant.
 * @return YES on success; NO when no BGM is loaded.
 * @ghidraAddress 0x1fe10
 */
- (BOOL)stopBgm:(float)fadeSeconds;
/**
 * @brief Stop the BGM, the VOICE channel, and every SE instance in one call.
 * @return YES.
 * @ghidraAddress 0x1f694
 */
- (BOOL)stopAll;
/**
 * @brief Report whether the BGM is playing.
 * @return YES while the BGM player exists and is playing.
 * @ghidraAddress 0x1fff8
 */
- (BOOL)isPlayingBgm;
/**
 * @brief Return the BGM player's current playhead.
 * @return The playhead in seconds; 0 when nothing is loaded.
 * @ghidraAddress 0x1ff58
 */
- (NSTimeInterval)bgmCurrentTime;
/**
 * @brief Move the BGM playhead and re-prime the player so playback resumes cleanly.
 * @param time The new playhead position in seconds.
 * @ghidraAddress 0x1ffb0
 */
- (void)setBgmCurrentTime:(NSTimeInterval)time;
/**
 * @brief Return the audio device's absolute clock as seen by the BGM player.
 * @details Used to schedule playback with playAtTime:.
 * @return The device clock in seconds; 0 when nothing is loaded.
 * @ghidraAddress 0x1ff84
 */
- (NSTimeInterval)bgmDeviceCurrentTime;
/**
 * @brief Duck the current BGM onto the stack so another can play over it.
 * @ghidraAddress 0x201dc
 */
- (void)pushBgm;
/**
 * @brief Restore the BGM previously ducked with pushBgm.
 * @ghidraAddress 0x2027c
 */
- (void)popBgm;
/**
 * @brief Report whether a BGM has been ducked onto the stack.
 * @return YES while a pushed BGM is held.
 * @ghidraAddress 0x202c8
 */
- (BOOL)isPushBgm;

/**
 * @brief Load a file into the VOICE channel, a second BGM-like channel with no fade.
 * @param path The file path to load.
 * @param loop YES to loop the VOICE indefinitely.
 * @return YES on success; NO on a nil path or a decode error.
 * @ghidraAddress 0x1e708
 */
- (BOOL)loadVoice:(NSString *)path isLoop:(BOOL)loop;
/**
 * @brief Load the VOICE channel straight from in-memory data.
 * @param data The in-memory audio data to load.
 * @param loop YES to loop the VOICE indefinitely.
 * @return YES on success; NO on nil data or a decode error.
 * @ghidraAddress 0x1e7f0
 */
- (BOOL)loadVoiceData:(NSData *)data isLoop:(BOOL)loop;
/**
 * @brief Start the VOICE channel, resuming from the paused position when applicable.
 * @return YES on success; NO when no VOICE is loaded.
 * @ghidraAddress 0x2030c
 */
- (BOOL)playVoice;
/**
 * @brief Stop the VOICE channel.
 * @return YES on success; NO when no VOICE is loaded.
 * @ghidraAddress 0x20388
 */
- (BOOL)stopVoice;
/**
 * @brief Pause the VOICE channel, remembering its position for the next play.
 * @return YES on success; NO when no VOICE is loaded.
 * @ghidraAddress 0x203c8
 */
- (BOOL)onPauseVoice;
/**
 * @brief Report whether the VOICE channel is playing.
 * @return YES while the VOICE player exists and is playing.
 * @ghidraAddress 0x2042c
 */
- (BOOL)isPlayingVoice;
/**
 * @brief Stop and free the VOICE player.
 * @ghidraAddress 0x1efdc
 */
- (void)releaseVoice;

/**
 * @brief Load a sound effect, keeping it addressable by call name and by the returned source id.
 * @param path The file path to load.
 * @param loop YES to loop the sound effect.
 * @param name The call name to register the sound under, or nil.
 * @param group The backend selector: 0 for the CoreAudio caplayer, other values for AVFoundation.
 * @return The source id, or RSND_INSTANCE_ID_ERROR when a call name was supplied or on failure.
 * @ghidraAddress 0x1e914
 */
- (RSND_SOURCE_ID)loadSe:(NSString *)path
                  isLoop:(BOOL)loop
                callName:(NSString *)name
                   group:(int)group;
/**
 * @brief Play a sound effect by call name or by source id at the group's stored volume.
 * @param name The registered call name, or nil to play by source id.
 * @param resourceId The source id to play when no call name is given.
 * @return The playing-instance id, or RSND_INSTANCE_ID_ERROR on failure.
 * @ghidraAddress 0x1f234
 */
- (RSND_INSTANCE_ID)playSe:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId;
/**
 * @brief Play a sound effect at an explicit per-shot volume rather than the group's stored level.
 * @param name The registered call name, or nil to play by source id.
 * @param resourceId The source id to play when no call name is given.
 * @param volume The per-shot level, clamped to the range 0 to 127.
 * @return The playing-instance id, or RSND_INSTANCE_ID_ERROR on failure.
 * @ghidraAddress 0x1f2d8
 */
- (RSND_INSTANCE_ID)playSe:(NSString *)name
                resourceId:(RSND_SOURCE_ID)resourceId
                    Volume:(int)volume;
/**
 * @brief Stop the SE instance in whichever backend owns it.
 * @param instanceId The playing-instance id to stop.
 * @return YES if the instance was found and stopped; NO otherwise.
 * @ghidraAddress 0x1f3d0
 */
- (BOOL)stopSe:(RSND_INSTANCE_ID)instanceId;
/**
 * @brief Stop every tracked SE instance across both backends.
 * @return YES.
 * @ghidraAddress 0x1f630
 */
- (BOOL)stopSeAll;
/**
 * @brief Set the SE volume for a group.
 * @details The caplayer sets its eight voices; the AVFoundation pool scales each player.
 * @param volume The level in the range 0 to 127.
 * @param group The group index whose volume is set.
 * @ghidraAddress 0x1f99c
 */
- (void)setSeVolume:(int)volume groupId:(int)group;
/**
 * @brief Play a sound effect through the caplayer's fixed-voice SetGroup pool.
 * @details The group id selects one of two banks of eight caplayer voices, each slot owning a fixed
 *          voice; the bank's oldest voice is stolen when it is full.
 * @param name The registered call name, or nil to play by source id.
 * @param resourceId The source id to play when no call name is given.
 * @param groupId The bank to play in.
 * @return The playing-instance id, or RSND_INSTANCE_ID_ERROR on failure.
 * @ghidraAddress 0x1f380
 */
- (RSND_INSTANCE_ID)playSeSetGroup:(NSString *)name
                        resourceId:(RSND_SOURCE_ID)resourceId
                           groupId:(int)groupId;
/**
 * @brief Pause a single playing SE instance in whichever backend owns it.
 * @param instanceId The playing-instance id to pause.
 * @return YES if the instance was found and paused; NO otherwise.
 * @ghidraAddress 0x1f434
 */
- (BOOL)onPauseSe:(RSND_INSTANCE_ID)instanceId;
/**
 * @brief Resume a single paused SE instance in whichever backend owns it.
 * @param instanceId The playing-instance id to resume.
 * @return YES if the instance was found and resumed; NO otherwise.
 * @ghidraAddress 0x1f498
 */
- (BOOL)offPauseSe:(RSND_INSTANCE_ID)instanceId;
/**
 * @brief Report whether a single SE instance is currently playing.
 * @param instanceId The playing-instance id to query.
 * @return YES while the instance is playing; NO otherwise.
 * @ghidraAddress 0x1f4fc
 */
- (BOOL)isPlayingSe:(RSND_INSTANCE_ID)instanceId;
/**
 * @brief Pause every tracked SE instance across both backends.
 * @return YES.
 * @ghidraAddress 0x1f568
 */
- (BOOL)onPauseSeAll;
/**
 * @brief Resume every tracked SE instance across both backends.
 * @return YES.
 * @ghidraAddress 0x1f5cc
 */
- (BOOL)offPauseSeAll;
/**
 * @brief Free a loaded SE source by call name or source id.
 * @details Called during scene teardown; drops the source from the load-order lists and the type
 *          table.
 * @param name The registered call name, or nil to release by source id.
 * @param resourceId The source id to release when no call name is given.
 * @ghidraAddress 0x1eba8
 */
- (void)releaseSe:(NSString *)name resourceId:(RSND_SOURCE_ID)resourceId;
/**
 * @brief Free every loaded SE source in both backends and clear the lookup tables.
 * @ghidraAddress 0x1eda8
 */
- (void)releaseSeAll;
/**
 * @brief Stop and free the current BGM resource and its remembered path.
 * @ghidraAddress 0x1ef74
 */
- (void)releaseBgm;
/**
 * @brief Tear down every playing SE instance and mixer state during scene teardown.
 * @details Releases every source, destroys and rebuilds both backends, resets the lookup lists and
 *          both instance pools, then restarts the engines.
 * @ghidraAddress 0x1e238
 */
- (void)cleanupSe;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
