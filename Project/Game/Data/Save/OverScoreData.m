//
//  OverScoreData.m
//  pop'n rhythmin
//

#import "OverScoreData.h"

@implementation OverScoreData

@dynamic music;
@dynamic sheet;
@dynamic isTouched;
@dynamic playerId;
@dynamic updateDate;

// @ 0xba0a0 — no-op stub taking a context argument (not the designated
// initializer); the original IMP does nothing and returns void.
+ (void)init:(NSManagedObjectContext *)context {
}

// Delete every persisted OverScoreData row (called by -[UserSettingData
// initForConvert]). Resets the context first, then (only when the fetch returns
// rows) deletes them and saves.
// @ 0xbaacc
+ (void)deleteAll:(NSManagedObjectContext *)context {
    [context reset];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"OverScoreData"
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

// @ 0xba2b0 — fetch every OverScoreData row on the context.
+ (NSArray<OverScoreData *> *)getAllOverScoreData:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"OverScoreData"
                                 inManagedObjectContext:context];
    return [context executeFetchRequest:request error:NULL];
}

// @ 0xba6e8 — delete every "over" record for `music` (all sheets), then save.
+ (void)deleteRecordWithMusic:(int)music inManagedObjectContext:(NSManagedObjectContext *)context {
    [context reset];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"OverScoreData"
                                 inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:@"music = %d", music];
    NSArray *matches = [context executeFetchRequest:request error:NULL];
    if (matches.count == 0) {
        return;
    }
    for (NSManagedObject *object in matches) {
        [context deleteObject:object];
    }
    [context save:NULL];
}

@end
