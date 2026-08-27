/** @file
 * Fetch, insert, query and reset methods on the TreasureData entity (sugoroku board progress).
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 */

#import <CoreData/CoreData.h>

#import "TreasureData.h"

/**
 * @brief Fetch, insert, query and reset helpers for the TreasureData entity.
 */
@interface TreasureData (Store)

/**
 * @brief The record for a main-map and sub-map cell.
 * @param mainMapId The main map id.
 * @param subMapId The sub map id.
 * @param context The managed object context to fetch from.
 * @return The last matching record, or nil when there is none.
 * @ghidraAddress 0xc088c
 */
+ (TreasureData *)getTreasureData:(short)mainMapId
                         subMapId:(short)subMapId
           inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Insert a fresh (reset) record for a main-map and sub-map cell, then save.
 * @param mainMapId The main map id.
 * @param subMapId The sub map id.
 * @param context The managed object context to insert into.
 * @return The new record.
 * @ghidraAddress 0xc0bd0
 */
+ (TreasureData *)addRecordWithMainMapId:(short)mainMapId
                                subMapId:(short)subMapId
                  inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Whether enough music-piece fragments have been collected on a map to unlock its song.
 *
 * The test is more than 8 of the low-three-bit flags summed over every sub-map row of
 * @p mainMapId.
 * @param mainMapId The main map id.
 * @param context The managed object context to fetch from.
 * @return YES once the song is unlocked.
 * @ghidraAddress 0xc0d90
 */
+ (BOOL)isOpenMusic:(short)mainMapId inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Clear the collectible and progress fields to their defaults; the map ids are preserved
 * and fastRecord is reset to -1.
 * @ghidraAddress 0xc0c9c
 */
- (void)reset;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
