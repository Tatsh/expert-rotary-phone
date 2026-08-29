/**
 * @file
 * @brief Fetch, insert and reset methods on the ArcadeScoreData entity, the arcade-machine score
 * mirror.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 */

#import <CoreData/CoreData.h>

#import "ArcadeScoreData.h"

/**
 * @brief Fetch, insert and reset helpers for the ArcadeScoreData entity.
 */
@interface ArcadeScoreData (Store)

/**
 * @brief The record for a music id and ref-id.
 * @param musicId The arcade music track.
 * @param refId The e-AMUSEMENT ref-id.
 * @param context The managed object context to fetch from.
 * @return The last matching record, or nil when there is none.
 * @ghidraAddress 0xcea60
 */
+ (ArcadeScoreData *)getDataFromMusicId:(short)musicId
                                  refId:(NSString *)refId
                 inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Up to @p limit records for @p refId, newest first (sorted by updateDate descending).
 * @param limit The maximum number of records to return.
 * @param refId The e-AMUSEMENT ref-id.
 * @param context The managed object context to fetch from.
 * @return An array of ArcadeScoreData.
 * @ghidraAddress 0xceb78
 */
+ (NSArray *)getLatestDataLimit:(short)limit
                          refId:(NSString *)refId
         inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Records for a category and ref-id, sorted by title ascending.
 * @param category The arcade song category.
 * @param refId The e-AMUSEMENT ref-id.
 * @param context The managed object context to fetch from.
 * @return An array of ArcadeScoreData.
 * @ghidraAddress 0xcece8
 */
+ (NSArray *)getDataFromCategory:(short)category
                           refId:(NSString *)refId
          inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Insert a fresh (reset) record for a music id and ref-id, then save.
 * @param musicId The arcade music track.
 * @param refId The e-AMUSEMENT ref-id.
 * @param context The managed object context to insert into.
 * @return The new record.
 * @ghidraAddress 0xcf164
 */
+ (ArcadeScoreData *)addRecordWithMusicId:(short)musicId
                                    refId:(NSString *)refId
                   inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Clear every score, name and metadata field to its default; musicId and refId are
 * preserved.
 * @ghidraAddress 0xcf220
 */
- (void)reset;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
