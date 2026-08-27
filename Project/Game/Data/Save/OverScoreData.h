/** @file
 * Core Data managed object — added in model version v2. Reconstructed from
 * ScoreData.momd/ScoreData_v2.mom (entity "OverScoreData").
 *
 * Tracks online / cross-player ("over") scores keyed by remote playerId, per music and sheet
 * (difficulty index). `isTouched` flags whether the local user has viewed or acknowledged this
 * rival record.
 *
 * Numeric attributes are NSNumber-backed (non-scalar Core Data codegen; see ScoreData.h for the
 * confirming call site). The storage width is noted per property.
 */

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

/**
 * @brief An online rival's score for one music and sheet, keyed by their remote player id.
 */
@interface OverScoreData : NSManagedObject

/** The music track this row scores. Integer32. */
@property(nonatomic, retain) NSNumber *music;
/** The sheet (difficulty index). Integer16. */
@property(nonatomic, retain) NSNumber *sheet;
/** Whether the local user has viewed or acknowledged this record. Integer16. */
@property(nonatomic, retain) NSNumber *isTouched;
/** The remote player id this score belongs to. */
@property(nonatomic, retain) NSString *playerId;
/** When the record was last updated, as a server-formatted string. */
@property(nonatomic, retain) NSString *updateDate;

#pragma mark Recovered selectors

// Recovered from call sites; previously declared as local category seams.

/**
 * @brief A no-op stub taking a context argument. It is not the designated initialiser.
 * @param context The managed object context; ignored.
 * @ghidraAddress 0xba0a0
 */
+ (void)init:(NSManagedObjectContext *)context;

/**
 * @brief Delete every persisted OverScoreData record; the device-change and initForConvert reset.
 * @param context The managed object context to delete from.
 */
+ (void)deleteAll:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
