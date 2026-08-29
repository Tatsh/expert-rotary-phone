/**
 * @file
 * @brief The ArcadeScoreData Core Data managed object: the arcade-machine score mirror.
 *
 * Reconstructed from ScoreData.momd/ScoreData_v2.mom (entity "ArcadeScoreData").
 *
 * A mirror of arcade-machine ("AC") song records fetched from the network: per-song personal best
 * (my*), venue mean (mean*) and venue top (top*) scores across four arcade difficulties — Easy
 * (Es), Normal (N), Hyper (H) and EX — plus the name of whoever holds the top score at each
 * difficulty.
 *
 * Numeric attributes are NSNumber-backed (non-scalar Core Data codegen; see ScoreData.h for the
 * confirming call site). The storage width is noted per property.
 */

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

/**
 * @brief The local mirror of one arcade-machine song record: personal, venue-mean and venue-top
 * scores across the four arcade difficulties.
 */
@interface ArcadeScoreData : NSManagedObject

/** The arcade music track this row mirrors. Integer16. */
@property(nonatomic, retain) NSNumber *musicId;
/** The arcade song category. Integer16. */
@property(nonatomic, retain) NSNumber *category;
/** The e-AMUSEMENT ref-id these records belong to. */
@property(nonatomic, retain) NSString *refId;
/** The song title. */
@property(nonatomic, retain) NSString *title;
/** The song genre. */
@property(nonatomic, retain) NSString *genre;
/** When the mirror was last refreshed. */
@property(nonatomic, retain) NSDate *updateDate;

/** Personal best on Easy. Integer32. */
@property(nonatomic, retain) NSNumber *myScoreEs;
/** Personal best on Normal. Integer32. */
@property(nonatomic, retain) NSNumber *myScoreN;
/** Personal best on Hyper. Integer32. */
@property(nonatomic, retain) NSNumber *myScoreH;
/** Personal best on EX. Integer32. */
@property(nonatomic, retain) NSNumber *myScoreEx;

/** Venue mean on Easy. Integer32. */
@property(nonatomic, retain) NSNumber *meanScoreEs;
/** Venue mean on Normal. Integer32. */
@property(nonatomic, retain) NSNumber *meanScoreN;
/** Venue mean on Hyper. Integer32. */
@property(nonatomic, retain) NSNumber *meanScoreH;
/** Venue mean on EX. Integer32. */
@property(nonatomic, retain) NSNumber *meanScoreEx;

/** Venue top on Easy. Integer32. */
@property(nonatomic, retain) NSNumber *topScoreEs;
/** Venue top on Normal. Integer32. */
@property(nonatomic, retain) NSNumber *topScoreN;
/** Venue top on Hyper. Integer32. */
@property(nonatomic, retain) NSNumber *topScoreH;
/** Venue top on EX. Integer32. */
@property(nonatomic, retain) NSNumber *topScoreEx;

/** Who holds the Easy top score. */
@property(nonatomic, retain) NSString *topNameEs;
/** Who holds the Normal top score. */
@property(nonatomic, retain) NSString *topNameN;
/** Who holds the Hyper top score. */
@property(nonatomic, retain) NSString *topNameH;
/** Who holds the EX top score. */
@property(nonatomic, retain) NSString *topNameEx;

/**
 * @brief Every stored record for @p refId, sorted by category descending then title ascending.
 * @param refId The e-AMUSEMENT ref-id.
 * @param context The managed object context to fetch from.
 * @return An array of ArcadeScoreData.
 * @ghidraAddress 0xcee4c
 */
+ (NSArray *)getAllData:(NSString *)refId context:(NSManagedObjectContext *)context;

/**
 * @brief Delete every persisted ArcadeScoreData record; the device-change and initForConvert
 * reset.
 * @param context The managed object context to delete from.
 */
+ (void)deleteAll:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
