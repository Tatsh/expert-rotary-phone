//
//  CharaTicketData.m
//  pop'n rhythmin
//

#import "CharaTicketData.h"

@implementation CharaTicketData

@dynamic productId;

// @ 0xe2da0 — fetch every "CharaTicketData" row, sorted by productId ascending.
// @complete
+ (id)getAllData:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"CharaTicketData"
                                 inManagedObjectContext:context];
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"productId" ascending:YES];
    request.sortDescriptors = @[ sort ];
    return [context executeFetchRequest:request error:NULL];
}

// Delete every persisted CharaTicketData row (called by -[UserSettingData
// initForConvert]). Resets the context first, then (only when the fetch returns
// rows) deletes them and saves.
// @ 0xe2ebc
// @complete
+ (void)deleteAll:(NSManagedObjectContext *)context {
    // Binary resets the context, guards on a non-nil/non-empty fetch result, and
    // saves after deleting (0xe2ee6 reset, 0xe2f82/0xe2f98 count guard, 0xe302c
    // save) — matching OverScoreData's deleteAll.
    [context reset];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"CharaTicketData"
                                 inManagedObjectContext:context];
    NSArray *all = [context executeFetchRequest:request error:NULL];
    if (all.count == 0) {
        return;
    }
    for (NSManagedObject *object in all) {
        [context deleteObject:object];
    }
    [context save:NULL];
}

@end
