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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface TreasureData : NSManagedObject

@property (nonatomic, retain) NSNumber *mainMapId;        // Integer16
@property (nonatomic, retain) NSNumber *subMapId;         // Integer16
@property (nonatomic, retain) NSNumber *clearCnt;         // Integer16
@property (nonatomic, retain) NSNumber *friendMeetCnt;    // Integer16
@property (nonatomic, retain) NSNumber *musicPiece;       // Integer16
@property (nonatomic, retain) NSNumber *wallPaperPiece;   // Integer16
@property (nonatomic, retain) NSNumber *goalCharaTicket;  // Integer16
@property (nonatomic, retain) NSNumber *goalTouchSound;   // Integer16
@property (nonatomic, retain) NSNumber *fastRecord;       // Integer16

// Fetch the record for a given main/sub map (nil if none). Ghidra:
// getTreasureData:subMapId:inManagedObjectContext: @ 0xc088c.
+ (TreasureData *)getTreasureData:(short)mainMapId
                         subMapId:(short)subMapId
             inManagedObjectContext:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
