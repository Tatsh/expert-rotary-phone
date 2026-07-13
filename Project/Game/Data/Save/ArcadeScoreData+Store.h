//
//  ArcadeScoreData+Store.h
//  pop'n rhythmin
//
//  Fetch / insert / reset methods on the ArcadeScoreData entity (arcade-machine
//  score mirror). Reconstructed from Ghidra project rb420, program
//  PopnRhythmin.
//

#import "ArcadeScoreData.h"
#import <CoreData/CoreData.h>

@interface ArcadeScoreData (Store)

// Record for musicId + refId (last match, or nil).  Ghidra: @ 0xcea60
+ (ArcadeScoreData *)getDataFromMusicId:(short)musicId
                                  refId:(NSString *)refId
                 inManagedObjectContext:(NSManagedObjectContext *)context;

// Up to `limit` records for refId, newest first (sorted by updateDate desc).
// Ghidra: @ 0xceb78
+ (NSArray *)getLatestDataLimit:(short)limit
                          refId:(NSString *)refId
         inManagedObjectContext:(NSManagedObjectContext *)context;

// Records for category + refId, sorted by title ascending.  Ghidra: @ 0xcece8
+ (NSArray *)getDataFromCategory:(short)category
                           refId:(NSString *)refId
          inManagedObjectContext:(NSManagedObjectContext *)context;

// Insert a fresh (reset) record for musicId + refId and save.  Ghidra: @
// 0xcf164
+ (ArcadeScoreData *)addRecordWithMusicId:(short)musicId
                                    refId:(NSString *)refId
                   inManagedObjectContext:(NSManagedObjectContext *)context;

// Clear all score/name/meta fields to defaults (musicId/refId preserved).
// Ghidra: -[ArcadeScoreData reset] @ 0xcf220
- (void)reset;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
