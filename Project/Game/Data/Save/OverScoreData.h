//
//  OverScoreData.h
//  pop'n rhythmin
//
//  Core Data managed object — added in model version v2.
//  Reconstructed from ScoreData.momd/ScoreData_v2.mom (entity "OverScoreData").
//
//  Tracks online / cross-player ("over") scores keyed by remote playerId, per
//  music + sheet (difficulty index). `isTouched` flags whether the local user
//  has viewed/acknowledged this rival record.
//
//  Numeric attributes are NSNumber-backed (non-scalar Core Data codegen; see
//  ScoreData.h for the confirming call site). Storage width noted per property.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface OverScoreData : NSManagedObject

@property (nonatomic, retain) NSNumber *music;        // Integer32
@property (nonatomic, retain) NSNumber *sheet;        // Integer16
@property (nonatomic, retain) NSNumber *isTouched;    // Integer16
@property (nonatomic, retain) NSString *playerId;
@property (nonatomic, retain) NSString *updateDate;

// Delete every "over" record for a given music + sheet from the store (the result
// screen clears them for the just-played chart before re-fetching). Ghidra:
// +[OverScoreData deleteRecordWithMusic:sheet:inManagedObjectContext:] (selector
// @ 0x15a8f4), called from PlayResultTask::resultSetup (FUN_0003dfe0 @ 0x3e2ec).
+ (void)deleteRecordWithMusic:(int)music sheet:(short)sheet inManagedObjectContext:(NSManagedObjectContext *)context;

#pragma mark Recovered selectors
// Recovered from call sites (previously declared as local category seams).

// Update (or create) the "over" record's date for a music + sheet + remote playerId.
+ (OverScoreData *)updateOverScoreDateWithMusic:(int)music sheet:(short)sheet playerId:(NSString *)playerId date:(NSString *)date inManagedObjectContext:(NSManagedObjectContext *)context;
// Insert a new "over" score record.
+ (void)addRecordWithMusic:(int)music sheet:(short)sheet playerId:(NSString *)playerId date:(NSString *)date inManagedObjectContext:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
