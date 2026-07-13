//
//  TreasureData+Store.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "TreasureData+Store.h"

@implementation TreasureData (Store)

// Ghidra: @ 0xc088c
+ (TreasureData *)getTreasureData:(short)mainMapId
                         subMapId:(short)subMapId
           inManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"TreasureData"
                                 inManagedObjectContext:context];
    request.predicate = [NSPredicate
        predicateWithFormat:@"mainMapId==%d and subMapId==%d", (int)mainMapId, (int)subMapId];
    NSArray *results = [context executeFetchRequest:request error:nil];
    return results.count ? results.lastObject : nil;
}

// Ghidra: @ 0xc0bd0
+ (TreasureData *)addRecordWithMainMapId:(short)mainMapId
                                subMapId:(short)subMapId
                  inManagedObjectContext:(NSManagedObjectContext *)context {
    [context reset];
    TreasureData *record = [NSEntityDescription insertNewObjectForEntityForName:@"TreasureData"
                                                         inManagedObjectContext:context];
    record.mainMapId = [NSNumber numberWithShort:mainMapId];
    record.subMapId = [NSNumber numberWithShort:subMapId];
    [record reset];
    [context save:nil];
    return record;
}

// Ghidra: @ 0xc0d90
+ (BOOL)isOpenMusic:(short)mainMapId inManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"TreasureData"
                                 inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:@"mainMapId==%d", (int)mainMapId];
    NSArray *results = [context executeFetchRequest:request error:nil];

    // Each row contributes its low 3 music-piece bits; the map's music unlocks
    // once more than 8 fragments have been gathered map-wide.
    int fragments = 0;
    for (TreasureData *record in results) {
        int pieces = record.musicPiece.intValue;
        for (int bit = 0; bit < 3; bit++) {
            if (pieces & (1 << bit)) {
                fragments++;
            }
        }
    }
    return fragments > 8;
}

// Ghidra: -[TreasureData reset] @ 0xc0c9c
- (void)reset {
    self.musicPiece = @0;
    self.wallPaperPiece = @0;
    self.clearCnt = @0;
    self.friendMeetCnt = @0;
    self.fastRecord = @(-1);
    self.goalCharaTicket = @0;
    self.goalTouchSound = @0;
}

@end
