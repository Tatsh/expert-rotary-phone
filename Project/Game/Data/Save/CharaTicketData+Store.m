//
//  CharaTicketData+Store.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "CharaTicketData+Store.h"

@implementation CharaTicketData (Store)

// Ghidra: @ 0xe2c6c
+ (BOOL)isExistData:(NSString *)productId inManagedObjectContext:(NSManagedObjectContext *)context {
    return [self getDataFromProductId:productId inManagedObjectContext:context] != nil;
}

// Ghidra: @ 0xe2c98
+ (CharaTicketData *)getDataFromProductId:(NSString *)productId
                   inManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"CharaTicketData"
                                 inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:@"productId = %@", productId];
    NSArray *results = [context executeFetchRequest:request error:nil];
    return results.count ? results.lastObject : nil;
}

// Ghidra: @ 0xe3048
+ (void)addRecordWithProductId:(NSString *)productId
        inManagedObjectContext:(NSManagedObjectContext *)context {
    if ([self isExistData:productId inManagedObjectContext:context]) {
        return;
    }
    [context reset];
    CharaTicketData *record =
        [NSEntityDescription insertNewObjectForEntityForName:@"CharaTicketData"
                                      inManagedObjectContext:context];
    record.productId = productId;
    [context save:nil];
}

@end
