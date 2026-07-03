//
//  TreasureData.m
//  pop'n rhythmin
//

#import "TreasureData.h"

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

@end
