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
