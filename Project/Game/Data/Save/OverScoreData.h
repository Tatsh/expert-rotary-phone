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

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@interface OverScoreData : NSManagedObject

@property(nonatomic, retain) NSNumber *music;     // Integer32
@property(nonatomic, retain) NSNumber *sheet;     // Integer16
@property(nonatomic, retain) NSNumber *isTouched; // Integer16
@property(nonatomic, retain) NSString *playerId;
@property(nonatomic, retain) NSString *updateDate;

#pragma mark Recovered selectors
// Recovered from call sites (previously declared as local category seams).

// No-op stub taking a context argument (not the designated initializer).
// Ghidra: @ 0xba0a0.
+ (void)init:(NSManagedObjectContext *)context;

// Delete every persisted OverScoreData record (device-change / initForConvert
// reset).
+ (void)deleteAll:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
