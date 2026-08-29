/**
 * @file
 * @brief Fetch, insert, update and delete class methods on the OverScoreData entity, the online
 * rival scores.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin.
 */

#import <CoreData/CoreData.h>

#import "OverScoreData.h"

/**
 * @brief Fetch, insert, update and delete helpers for the OverScoreData entity.
 */
@interface OverScoreData (Store)

/**
 * @brief The single record matching music, sheet and player id.
 * @param music The music track.
 * @param sheet The sheet index.
 * @param playerId The remote player id.
 * @param context The managed object context to fetch from.
 * @return The last matching record, or nil when there is none.
 * @ghidraAddress 0xba0a4
 */
+ (OverScoreData *)getOverScoreDataWithMusic:(int)music
                                       sheet:(short)sheet
                                    playerId:(NSString *)playerId
                      inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Every record matching music and sheet.
 * @param music The music track.
 * @param sheet The sheet index.
 * @param context The managed object context to fetch from.
 * @return An array of OverScoreData.
 * @ghidraAddress 0xba1c0
 */
+ (NSArray *)getOverScoreDataWithMusic:(int)music
                                 sheet:(short)sheet
                inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Every OverScoreData row.
 * @param context The managed object context to fetch from.
 * @return An array of OverScoreData.
 * @ghidraAddress 0xba2b0
 */
+ (NSArray *)getAllOverScoreData:(NSManagedObjectContext *)context;

/**
 * @brief Update updateDate on the record matching music, sheet and player id.
 * @param music The music track.
 * @param sheet The sheet index.
 * @param playerId The remote player id.
 * @param date The new update date string.
 * @param context The managed object context to update in.
 * @return The updated record, or nil when there is no match.
 * @ghidraAddress 0xba350
 */
+ (OverScoreData *)updateOverScoreDateWithMusic:(int)music
                                          sheet:(short)sheet
                                       playerId:(NSString *)playerId
                                           date:(NSString *)date
                         inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Mark every record for @p music as touched, setting isTouched to 1.
 * @param music The music track.
 * @param context The managed object context to update in.
 * @return The number of records matched.
 * @ghidraAddress 0xba3d4
 */
+ (NSUInteger)updateOverScoreTouchedWithMusic:(int)music
                       inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Insert a new rival-score record with isTouched cleared, then save.
 * @param music The music track.
 * @param sheet The sheet index.
 * @param playerId The remote player id.
 * @param date The update date string.
 * @param context The managed object context to insert into.
 * @return The new record.
 * @ghidraAddress 0xba5e4
 */
+ (OverScoreData *)addRecordWithMusic:(int)music
                                sheet:(short)sheet
                             playerId:(NSString *)playerId
                                 date:(NSString *)date
               inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Delete every record for @p music.
 * @param music The music track.
 * @param context The managed object context to delete from.
 * @return The number of records matched.
 * @ghidraAddress 0xba6e8
 */
+ (NSUInteger)deleteRecordWithMusic:(int)music
             inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Delete every record for @p music and @p sheet.
 * @param music The music track.
 * @param sheet The sheet index.
 * @param context The managed object context to delete from.
 * @return The number of records matched.
 * @ghidraAddress 0xba8d8
 */
+ (NSUInteger)deleteRecordWithMusic:(int)music
                              sheet:(short)sheet
             inManagedObjectContext:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
