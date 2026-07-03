//
//  ArcadeScoreData.m
//  pop'n rhythmin
//

#import "ArcadeScoreData.h"

@implementation ArcadeScoreData

@dynamic musicId;
@dynamic category;
@dynamic refId;
@dynamic title;
@dynamic genre;
@dynamic updateDate;
@dynamic myScoreEs;
@dynamic myScoreN;
@dynamic myScoreH;
@dynamic myScoreEx;
@dynamic meanScoreEs;
@dynamic meanScoreN;
@dynamic meanScoreH;
@dynamic meanScoreEx;
@dynamic topScoreEs;
@dynamic topScoreN;
@dynamic topScoreH;
@dynamic topScoreEx;
@dynamic topNameEs;
@dynamic topNameN;
@dynamic topNameH;
@dynamic topNameEx;


// @ 0xcea60 — the single record matching musicId + refId (nil when none).
+ (ArcadeScoreData *)getDataFromMusicId:(short)musicId
                                  refId:(NSString *)refId
                 inManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"ArcadeScoreData"
                                 inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:@"musicId = %d and refId = %@",
                         musicId, refId];
    ArcadeScoreData *result = nil;
    NSArray *fetched = [context executeFetchRequest:request error:NULL];
    if (fetched.count != 0) {
        result = [fetched lastObject];
    }
    return result;
}

// @ 0xceb78 — up to `limit` records for refId, newest first (updateDate descending).
+ (NSArray *)getLatestDataLimit:(short)limit
                          refId:(NSString *)refId
         inManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"ArcadeScoreData"
                                 inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:@"refId = %@", refId];
    request.fetchLimit = limit;
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"updateDate" ascending:NO];
    request.sortDescriptors = [NSArray arrayWithObjects:sort, nil];
    return [context executeFetchRequest:request error:NULL];
}

// @ 0xcece8 — one category's records under refId, sorted by title ascending.
+ (NSArray *)getDataFromCategory:(short)category
                           refId:(NSString *)refId
          inManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"ArcadeScoreData"
                                 inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:@"category = %d and refId=%@",
                         category, refId];
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES];
    request.sortDescriptors = [NSArray arrayWithObjects:sort, nil];
    return [context executeFetchRequest:request error:NULL];
}

// @ 0xcf164 — insert + save a fresh record keyed on musicId / refId.
+ (ArcadeScoreData *)addRecordWithMusicId:(short)musicId
                                    refId:(NSString *)refId
                   inManagedObjectContext:(NSManagedObjectContext *)context {
    [context reset];
    ArcadeScoreData *record =
        [NSEntityDescription insertNewObjectForEntityForName:@"ArcadeScoreData"
                                      inManagedObjectContext:context];
    record.musicId = [NSNumber numberWithShort:musicId];
    record.refId = refId;
    // The binary issues a second `reset` selector on the new record here (Ghidra
    // @ 0xcf164) before saving; it is a no-op against NSManagedObject and omitted.
    [context save:NULL];
    return record;
}

// Delete every persisted ArcadeScoreData row (called by -[UserSettingData initForConvert]).
+ (void)deleteAll:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"ArcadeScoreData" inManagedObjectContext:context];
    NSArray *all = [context executeFetchRequest:request error:NULL];
    for (NSManagedObject *object in all) {
        [context deleteObject:object];
    }
}

@end
