/**
 * @file
 * @brief Fetch, insert and integrity class methods on the ScoreData entity.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 *
 * The score record carries an MD5 tamper-check (`chksco`) computed over the music id and the three
 * difficulty scores; checkScore: validates it and the caller resets the record if it fails.
 */

#import <CoreData/CoreData.h>

#import "ScoreData.h"

/**
 * @brief Fetch, insert and integrity helpers for the ScoreData entity.
 */
@interface ScoreData (Store)

/**
 * @brief Fetch the record for @p musicId, creating a fresh (reset) one if absent. An existing
 * record that fails its integrity check is reset in place.
 * @param musicId The music track to fetch.
 * @param context The managed object context to fetch from.
 * @return The record.
 * @ghidraAddress 0x6da30
 */
+ (ScoreData *)getScoreData:(int)musicId inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Insert a new record for @p musicId, reset it to defaults, and save.
 * @param musicId The music track to insert.
 * @param context The managed object context to insert into.
 * @return The new record.
 * @ghidraAddress 0x6ded0
 */
+ (ScoreData *)recordWithMusicId:(int)musicId
          inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Fetch every ScoreData row.
 * @param context The managed object context to fetch from.
 * @return An array of ScoreData.
 * @ghidraAddress 0x6dca4
 */
+ (NSArray *)getAllScoreData:(NSManagedObjectContext *)context;

/**
 * @brief Reset a record to default and empty values, then re-stamp its checksum.
 * @param record The record to reset.
 * @ghidraAddress 0x6df80
 */
+ (void)reset:(ScoreData *)record;

/**
 * @brief Validate a record's stored checksum against a freshly computed one.
 * @param record The record to check.
 * @return YES when the checksums match.
 * @ghidraAddress 0x6e354
 */
+ (BOOL)checkScore:(ScoreData *)record;

/**
 * @brief Compute the MD5 checksum for a record's current scores.
 * @param record The record to hash.
 * @return The 16-byte digest.
 * @ghidraAddress 0x6e260
 */
+ (NSData *)hashScore:(ScoreData *)record;

/**
 * @brief Compute the raw 16-byte checksum for explicit score values.
 * @param musicId The music track.
 * @param scoreN The Normal-difficulty score.
 * @param scoreH The Hyper-difficulty score.
 * @param scoreEx The EX-difficulty score.
 * @param outDigest16 Receives the 16-byte digest.
 * @ghidraAddress 0x6e20c
 */
+ (void)hashScoreForTune:(int)musicId
                  Normal:(int)scoreN
                   Hyper:(int)scoreH
                      Ex:(int)scoreEx
                    Hash:(unsigned char *)outDigest16;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
