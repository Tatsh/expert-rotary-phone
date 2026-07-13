//
//  TreasureData+Store.h
//  pop'n rhythmin
//
//  Fetch / insert / query / reset methods on the TreasureData entity (sugoroku
//  board progress). Reconstructed from Ghidra project rb420, program
//  PopnRhythmin.
//

#import "TreasureData.h"
#import <CoreData/CoreData.h>

@interface TreasureData (Store)

// Record for a main-map + sub-map cell (last match, or nil).  Ghidra: @ 0xc088c
+ (TreasureData *)getTreasureData:(short)mainMapId
                         subMapId:(short)subMapId
           inManagedObjectContext:(NSManagedObjectContext *)context;

// Insert a fresh (reset) record for main-map + sub-map and save.  Ghidra: @
// 0xc0bd0
+ (TreasureData *)addRecordWithMainMapId:(short)mainMapId
                                subMapId:(short)subMapId
                  inManagedObjectContext:(NSManagedObjectContext *)context;

// YES once enough music-piece fragments (>8 of the low-3-bit flags summed over
// every sub-map row of `mainMapId`) have been collected.  Ghidra: @ 0xc0d90
+ (BOOL)isOpenMusic:(short)mainMapId inManagedObjectContext:(NSManagedObjectContext *)context;

// Clear collectible/progress fields to defaults (map ids preserved; fastRecord
// reset to -1).  Ghidra: -[TreasureData reset] @ 0xc0c9c
- (void)reset;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
