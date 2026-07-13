//
//  CharaTicketData.m
//  pop'n rhythmin
//

#import "CharaTicketData.h"

@implementation CharaTicketData

@dynamic productId;

// @ 0xe2da0 — fetch every "CharaTicketData" row, sorted by productId ascending.
+ (id)getAllData:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"CharaTicketData"
                                 inManagedObjectContext:context];
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"productId" ascending:YES];
    request.sortDescriptors = @[ sort ];
    return [context executeFetchRequest:request error:NULL];
}

// Delete every persisted CharaTicketData row (called by -[UserSettingData
// initForConvert]).
// @ 0xe2ebc
+ (void)deleteAll:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"CharaTicketData"
                                 inManagedObjectContext:context];
    NSArray *all = [context executeFetchRequest:request error:NULL];
    for (NSManagedObject *object in all) {
        [context deleteObject:object];
    }
}

@end
