//
//  OverScoreData+Store.h
//  pop'n rhythmin
//
//  Fetch / insert / update / delete class methods on the OverScoreData entity
//  (online rival scores). Reconstructed from Ghidra project rb420, program
//  PopnRhythmin.
//

#import <CoreData/CoreData.h>

#import "OverScoreData.h"

@interface OverScoreData (Store)

// Single record matching music + sheet + playerId (last match, or nil).
// Ghidra: @ 0xba0a4
+ (OverScoreData *)getOverScoreDataWithMusic:(int)music
                                       sheet:(short)sheet
                                    playerId:(NSString *)playerId
                      inManagedObjectContext:(NSManagedObjectContext *)context;

// All records matching music + sheet.
// Ghidra: @ 0xba1c0
+ (NSArray *)getOverScoreDataWithMusic:(int)music
                                 sheet:(short)sheet
                inManagedObjectContext:(NSManagedObjectContext *)context;

// Every OverScoreData row.  Ghidra: @ 0xba2b0
+ (NSArray *)getAllOverScoreData:(NSManagedObjectContext *)context;

// Update updateDate on the record matching music + sheet + playerId.
// Ghidra: @ 0xba350
+ (OverScoreData *)updateOverScoreDateWithMusic:(int)music
                                          sheet:(short)sheet
                                       playerId:(NSString *)playerId
                                           date:(NSString *)date
                         inManagedObjectContext:(NSManagedObjectContext *)context;

// Mark every record for `music` as touched (isTouched = 1). Returns match
// count. Ghidra: @ 0xba3d4
+ (NSUInteger)updateOverScoreTouchedWithMusic:(int)music
                       inManagedObjectContext:(NSManagedObjectContext *)context;

// Insert a new rival-score record (isTouched = 0) and save.
// Ghidra: @ 0xba5e4
+ (OverScoreData *)addRecordWithMusic:(int)music
                                sheet:(short)sheet
                             playerId:(NSString *)playerId
                                 date:(NSString *)date
               inManagedObjectContext:(NSManagedObjectContext *)context;

// Delete every record for `music`. Returns match count. Ghidra: @ 0xba6e8
+ (NSUInteger)deleteRecordWithMusic:(int)music
             inManagedObjectContext:(NSManagedObjectContext *)context;

// Delete every record for music + sheet. Returns match count. Ghidra: @ 0xba8d8
+ (NSUInteger)deleteRecordWithMusic:(int)music
                              sheet:(short)sheet
             inManagedObjectContext:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
