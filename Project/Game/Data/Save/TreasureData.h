//
//  TreasureData.h
//  pop'n rhythmin
//
//  Core Data managed object.
//  Reconstructed from ScoreData.momd/ScoreData_v2.mom (entity "TreasureData").
//
//  Progress on the "sugoroku" (board-game) meta-mode: which main/sub map the
//  player is on, collectible counts (music pieces, wallpaper pieces, character
//  tickets earned by reaching goals), clear/meet counters and per-map option
//  flags such as the goal-touch sound and the fast-record toggle.
//
//  NOTE: this Core Data entity "TreasureData" is unrelated to the third-party
//  TreasureData analytics SDK (also present in the binary) — the name collision
//  is coincidental; this is the local sugoroku save record.
//
//  Numeric attributes are NSNumber-backed (non-scalar Core Data codegen; see
//  ScoreData.h for the confirming call site). All attributes are Integer16.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@interface TreasureData : NSManagedObject

@property(nonatomic, retain) NSNumber *mainMapId;       // Integer16
@property(nonatomic, retain) NSNumber *subMapId;        // Integer16
@property(nonatomic, retain) NSNumber *clearCnt;        // Integer16
@property(nonatomic, retain) NSNumber *friendMeetCnt;   // Integer16
@property(nonatomic, retain) NSNumber *musicPiece;      // Integer16
@property(nonatomic, retain) NSNumber *wallPaperPiece;  // Integer16
@property(nonatomic, retain) NSNumber *goalCharaTicket; // Integer16
@property(nonatomic, retain) NSNumber *goalTouchSound;  // Integer16
@property(nonatomic, retain) NSNumber *fastRecord;      // Integer16

// Fetch the record for a given main/sub map (nil if none). Ghidra:
// getTreasureData:subMapId:inManagedObjectContext: @ 0xc088c.
+ (TreasureData *)getTreasureData:(short)mainMapId
                         subMapId:(short)subMapId
           inManagedObjectContext:(NSManagedObjectContext *)context;

// Fetch every persisted TreasureData record on the given context (the whole
// sugoroku save table). Ghidra: getAllTreasureData: @ 0xc09a4.
+ (NSArray<TreasureData *> *)getAllTreasureData:(NSManagedObjectContext *)context;

// YES if `mainMapId` is one of the two root ("default") maps (0 or 6). Ghidra:
// @ 0xc0f64.
+ (BOOL)isDefaultMap:(short)mainMapId;

// Delete every persisted TreasureData record (device-change / initForConvert
// reset).
+ (void)deleteAll:(NSManagedObjectContext *)context;

// Seed the default treasure-map rows into the store (device-change reset); impl
// in .m @0x...
+ (id)init:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
