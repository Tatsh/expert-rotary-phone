//
//  TreasureData.m
//  pop'n rhythmin
//

#import "TreasureData.h"
#import "TreasureData+Store.h"   // addRecordWithMainMapId:subMapId:inManagedObjectContext:

@implementation TreasureData

@dynamic mainMapId;
@dynamic subMapId;
@dynamic clearCnt;
@dynamic friendMeetCnt;
@dynamic musicPiece;
@dynamic wallPaperPiece;
@dynamic goalCharaTicket;
@dynamic goalTouchSound;
@dynamic fastRecord;

// @ 0xc088c — fetch the "TreasureData" entity matching (mainMapId, subMapId).
+ (TreasureData *)getTreasureData:(short)mainMapId
                         subMapId:(short)subMapId
             inManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"TreasureData"
                                 inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:@"mainMapId=%d and subMapId=%d",
                         mainMapId, subMapId];
    NSArray *results = [context executeFetchRequest:request error:NULL];
    TreasureData *found = (results.count != 0) ? [results lastObject] : nil;
    return found;
}

// @ 0xc09a4 — fetch every persisted "TreasureData" row (the whole sugoroku save
// table; no predicate).
+ (id)getAllTreasureData:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"TreasureData"
                                 inManagedObjectContext:context];
    NSArray *results = [context executeFetchRequest:request error:NULL];
    return results;
}

// @ 0xc07c4 — seed the sugoroku save table. First ensure the two root maps
// (main ids 0 and 6, sub 0) exist; then, for each map 0..8 whose parent map is
// already present, insert its (still-missing) row. The parent-map ids come from
// the getTreasureMapValue table @ 0x12fb30 (−1 means "no parent"). Callers ignore
// the result (the original IMP returns void).
+ (id)init:(NSManagedObjectContext *)context {
    static const short kRootMapIds[2] = {0, 6};          // DAT_0012fa28
    for (int i = 0; i < 2; i++) {
        short mainMapId = kRootMapIds[i];
        if ([self getTreasureData:mainMapId
                         subMapId:0
           inManagedObjectContext:context] == nil) {
            [self addRecordWithMainMapId:mainMapId
                                subMapId:0
                  inManagedObjectContext:context];
        }
    }

    static const short kParentMapId[9] = {5, 2, 3, 4, -1, 1, 7, -1, -1};   // DAT_0012fb30
    for (short mapId = 0; mapId < 9; mapId++) {
        short parentMapId = kParentMapId[mapId];
        if (parentMapId < 0) {
            continue;
        }
        if ([self getTreasureData:mapId
                         subMapId:0
           inManagedObjectContext:context] != nil) {
            continue;
        }
        if ([self getTreasureData:parentMapId
                         subMapId:0
           inManagedObjectContext:context] != nil) {
            [self addRecordWithMainMapId:mapId
                                subMapId:0
                  inManagedObjectContext:context];
        }
    }
    return nil;
}


// @ 0xc0f64 — YES if `mainMapId` is one of the two root ("default") maps (0 or 6).
+ (BOOL)isDefaultMap:(short)mainMapId {
    static const short kRootMapIds[2] = {0, 6};   // DAT_0012fa28
    for (int i = 0; i < 2; i++) {
        if (kRootMapIds[i] == mainMapId) {
            return YES;
        }
    }
    return NO;
}

// Delete every persisted TreasureData row (called by -[UserSettingData initForConvert]).
// @ 0xc0a44
+ (void)deleteAll:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"TreasureData" inManagedObjectContext:context];
    NSArray *all = [context executeFetchRequest:request error:NULL];
    for (NSManagedObject *object in all) {
        [context deleteObject:object];
    }
}

@end
