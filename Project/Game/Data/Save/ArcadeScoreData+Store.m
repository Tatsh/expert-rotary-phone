//
//  ArcadeScoreData+Store.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "ArcadeScoreData+Store.h"

@implementation ArcadeScoreData (Store)

// Ghidra: @ 0xcea60
+ (ArcadeScoreData *)getDataFromMusicId:(short)musicId
                                  refId:(NSString *)refId
                 inManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"ArcadeScoreData"
                                 inManagedObjectContext:context];
    request.predicate =
        [NSPredicate predicateWithFormat:@"musicId==%d and refId==%@", (int)musicId, refId];
    NSArray *results = [context executeFetchRequest:request error:nil];
    return results.count ? results.lastObject : nil;
}

// Ghidra: @ 0xceb78
+ (NSArray *)getLatestDataLimit:(short)limit
                          refId:(NSString *)refId
         inManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"ArcadeScoreData"
                                 inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:@"refId==%@", refId];
    request.fetchLimit = (NSUInteger)limit;
    // Newest first.
    request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"updateDate"
                                                               ascending:NO] ];
    return [context executeFetchRequest:request error:nil];
}

// Ghidra: @ 0xcece8
+ (NSArray *)getDataFromCategory:(short)category
                           refId:(NSString *)refId
          inManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"ArcadeScoreData"
                                 inManagedObjectContext:context];
    request.predicate =
        [NSPredicate predicateWithFormat:@"category==%d and refId==%@", (int)category, refId];
    request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES] ];
    return [context executeFetchRequest:request error:nil];
}

// Ghidra: @ 0xcf164
+ (ArcadeScoreData *)addRecordWithMusicId:(short)musicId
                                    refId:(NSString *)refId
                   inManagedObjectContext:(NSManagedObjectContext *)context {
    [context reset];
    ArcadeScoreData *record =
        [NSEntityDescription insertNewObjectForEntityForName:@"ArcadeScoreData"
                                      inManagedObjectContext:context];
    record.musicId = [NSNumber numberWithShort:musicId];
    record.refId = refId;
    [record reset];
    [context save:nil];
    return record;
}

// Ghidra: -[ArcadeScoreData reset] @ 0xcf220
- (void)reset {
    self.title = @"";
    self.genre = @"";
    self.category = @0;
    self.updateDate = NSDate.date;

    self.topNameEs = @"";
    self.topNameN = @"";
    self.topNameH = @"";
    self.topNameEx = @"";

    self.topScoreEs = @0;
    self.topScoreN = @0;
    self.topScoreH = @0;
    self.topScoreEx = @0;

    self.meanScoreEs = @0;
    self.meanScoreN = @0;
    self.meanScoreH = @0;
    self.meanScoreEx = @0;

    self.myScoreEs = @0;
    self.myScoreN = @0;
    self.myScoreH = @0;
    self.myScoreEx = @0;
}

@end
