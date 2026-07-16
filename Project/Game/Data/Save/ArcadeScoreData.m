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

// @ 0xcee4c — every ArcadeScoreData record for `refId`, sorted by category
// (descending) then title (ascending).
// @complete
+ (NSArray *)getAllData:(NSString *)refId context:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"ArcadeScoreData"
                                 inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:@"refId = %@", refId];
    NSSortDescriptor *byCategory = [[NSSortDescriptor alloc] initWithKey:@"category" ascending:NO];
    NSSortDescriptor *byTitle = [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES];
    request.sortDescriptors = [NSArray arrayWithObjects:byCategory, byTitle, nil];
    return [context executeFetchRequest:request error:NULL];
}

// Delete every persisted ArcadeScoreData row (called by -[UserSettingData
// initForConvert]). Resets the context first, then (only when the fetch returns
// rows) deletes them and saves.
// @ 0xcefd8
// @complete
+ (void)deleteAll:(NSManagedObjectContext *)context {
    // Binary resets the context, guards on a non-nil/non-empty fetch result, and
    // saves after deleting (0xcf002 reset, 0xcf09e/0xcf0b4 count guard, 0xcf148
    // save) — matching OverScoreData's deleteAll.
    [context reset];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"ArcadeScoreData"
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
